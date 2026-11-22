// بوابة تخزين «منتقيات الشعر» على Cloudflare R2.
// الربط المطلوب في إعدادات الـWorker:  BUCKET → الحاوية muntaqayat.
// اختياري: أي حاويات أخرى تُربط بأي اسم تُحسب في المجموع (مثل QURAN → quran-audio).
//
// لا يرفع أحد إلا بحساب في التطبيق (رمز Firebase)، ولا تظهر خلفية حتى يقبلها المطوّر.

const PROJECT = 'muntaqayat';
const DEV = 'www774475437@gmail.com';

const CAP = 200e9; // الحد الأقصى للتخزين كله: ٢٠٠ جيجا
const BG_MAX = 2e6; // أقصى حجم لصورة الخلفية: ٢ ميجا
const FREE = 10e9; // المجاني في الشهر
const RATE = 0.015; // دولار لكل جيجا زائدة في الشهر
const USAGE_TTL = 6 * 3600e3; // يُعاد عدّ المساحة كل ست ساعات

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, PUT, POST, DELETE, OPTIONS',
  'access-control-allow-headers': 'authorization, content-type',
  'access-control-max-age': '86400',
};

const json = (data, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { 'content-type': 'application/json; charset=utf-8', ...CORS } });

const b64 = (s) => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));

let keys = null;
let keysAt = 0;

// يتحقق من رمز Firebase: التوقيع والمشروع والمدة.
async function whoIs(req) {
  const h = req.headers.get('authorization') || '';
  if (!h.startsWith('Bearer ')) return null;
  const p = h.slice(7).split('.');
  if (p.length !== 3) return null;
  let head, body;
  try {
    head = JSON.parse(new TextDecoder().decode(b64(p[0])));
    body = JSON.parse(new TextDecoder().decode(b64(p[1])));
  } catch (e) {
    return null;
  }
  const now = Date.now() / 1000;
  if (head.alg !== 'RS256' || body.aud !== PROJECT || body.iss !== 'https://securetoken.google.com/' + PROJECT) return null;
  if (!(body.exp > now) || !(body.iat <= now + 300) || !body.sub) return null;
  if (!keys || Date.now() - keysAt > 3600e3) {
    const r = await fetch('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com');
    if (!r.ok) return null;
    keys = (await r.json()).keys;
    keysAt = Date.now();
  }
  const k = (keys || []).find((x) => x.kid === head.kid);
  if (!k) return null;
  try {
    const key = await crypto.subtle.importKey('jwk', { kty: k.kty, n: k.n, e: k.e, alg: 'RS256', ext: true }, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
    const ok = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, b64(p[2]), new TextEncoder().encode(p[0] + '.' + p[1]));
    if (!ok) return null;
  } catch (e) {
    return null;
  }
  return { uid: body.sub, dev: body.email_verified === true && body.email === DEV };
}

// صورة حقيقية؟ يُنظر في أول بايتاتها لا في الاسم.
function imageType(u8) {
  if (u8.length > 3 && u8[0] === 0xff && u8[1] === 0xd8 && u8[2] === 0xff) return 'image/jpeg';
  if (u8.length > 8 && u8[0] === 0x89 && u8[1] === 0x50 && u8[2] === 0x4e && u8[3] === 0x47) return 'image/png';
  if (u8.length > 12 && u8[0] === 0x52 && u8[1] === 0x49 && u8[2] === 0x46 && u8[3] === 0x46 && u8[8] === 0x57 && u8[9] === 0x45 && u8[10] === 0x42 && u8[11] === 0x50) return 'image/webp';
  return null;
}

async function countBucket(b) {
  let bytes = 0;
  let count = 0;
  let cursor;
  do {
    const l = await b.list({ cursor, limit: 1000 });
    for (const o of l.objects) {
      if (o.key.startsWith('_meta/')) continue;
      bytes += o.size;
      count++;
    }
    cursor = l.truncated ? l.cursor : undefined;
  } while (cursor);
  return { bytes, count };
}

// المساحة المستعملة في كل الحاويات المربوطة. تُحفظ ست ساعات حتى لا يُعاد العدّ في كل طلب.
async function usage(env, fresh) {
  if (!fresh) {
    const saved = await env.BUCKET.get('_meta/usage.json');
    if (saved) {
      const u = await saved.json();
      if (Date.now() - u.at < USAGE_TTL) return u;
    }
  }
  const buckets = {};
  let total = 0;
  for (const [name, b] of Object.entries(env)) {
    if (!b || typeof b.list !== 'function' || typeof b.put !== 'function') continue;
    buckets[name] = await countBucket(b);
    total += buckets[name].bytes;
  }
  const over = Math.max(0, total - FREE) / 1e9;
  const u = { at: Date.now(), bytes: total, cap: CAP, free: FREE, rate: RATE, monthlyUsd: Math.round(over * RATE * 100) / 100, buckets };
  await env.BUCKET.put('_meta/usage.json', JSON.stringify(u), { httpMetadata: { contentType: 'application/json' } });
  return u;
}

function serve(o, cache) {
  const h = new Headers(CORS);
  o.writeHttpMetadata(h);
  h.set('etag', o.httpEtag);
  h.set('cache-control', cache);
  return new Response(o.body, { headers: h });
}

export default {
  async fetch(req, env) {
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
    const url = new URL(req.url);
    const path = url.pathname.replace(/\/+$/, '') || '/';
    const B = env.BUCKET;
    try {
      // الخلفية المقبولة: يراها الجميع.
      let m = path.match(/^\/bg\/([A-Za-z0-9_-]{6,64})$/);
      if (m && req.method === 'GET') {
        const o = await B.get('bg/' + m[1]);
        return o ? serve(o, 'public, max-age=3600') : json({ error: 'none' }, 404);
      }
      if (path === '/') return json({ ok: true });

      const me = await whoIs(req);
      if (!me) return json({ error: 'auth' }, 401);

      // المساحة والتكلفة: للمطوّر.
      if (path === '/usage' && req.method === 'GET') {
        if (!me.dev) return json({ error: 'dev' }, 403);
        return json(await usage(env, url.searchParams.get('fresh') === '1'));
      }

      // حال خلفيتي.
      if (path === '/mine' && req.method === 'GET') {
        const [p, a] = await Promise.all([B.head('pending/bg/' + me.uid), B.head('bg/' + me.uid)]);
        return json({ pending: !!p, approved: !!a });
      }

      // رفع خلفية: تنتظر قبول المطوّر.
      if (path === '/bg' && req.method === 'PUT') {
        const len = Number(req.headers.get('content-length') || 0);
        if (len > BG_MAX) return json({ error: 'big', max: BG_MAX }, 413);
        const buf = await req.arrayBuffer();
        if (buf.byteLength === 0 || buf.byteLength > BG_MAX) return json({ error: 'big', max: BG_MAX }, 413);
        const type = imageType(new Uint8Array(buf.slice(0, 16)));
        if (!type) return json({ error: 'type' }, 415);
        const u = await usage(env, false);
        if (u.bytes + buf.byteLength > CAP) return json({ error: 'full' }, 507);
        await B.put('pending/bg/' + me.uid, buf, { httpMetadata: { contentType: type }, customMetadata: { at: String(Date.now()) } });
        return json({ ok: true, pending: true });
      }

      // أحذف خلفيتي (المنتظرة والمقبولة).
      if (path === '/bg' && req.method === 'DELETE') {
        await B.delete(['pending/bg/' + me.uid, 'bg/' + me.uid]);
        return json({ ok: true });
      }

      // صاحب الصورة أو المطوّر يرى المنتظرة.
      m = path.match(/^\/pending\/bg\/([A-Za-z0-9_-]{6,64})$/);
      if (m && req.method === 'GET') {
        if (!me.dev && me.uid !== m[1]) return json({ error: 'dev' }, 403);
        const o = await B.get('pending/bg/' + m[1]);
        return o ? serve(o, 'private, no-store') : json({ error: 'none' }, 404);
      }

      if (!me.dev) return json({ error: 'dev' }, 403);

      // قائمة ما ينتظر المراجعة.
      if (path === '/pending' && req.method === 'GET') {
        const l = await B.list({ prefix: 'pending/bg/', limit: 200 });
        return json({ items: l.objects.map((o) => ({ uid: o.key.slice('pending/bg/'.length), size: o.size, at: o.uploaded.getTime() })) });
      }

      m = path.match(/^\/(approve|reject|remove)\/([A-Za-z0-9_-]{6,64})$/);
      if (m && req.method === 'POST') {
        const uid = m[2];
        if (m[1] === 'approve') {
          const o = await B.get('pending/bg/' + uid);
          if (!o) return json({ error: 'none' }, 404);
          await B.put('bg/' + uid, await o.arrayBuffer(), { httpMetadata: o.httpMetadata, customMetadata: { at: String(Date.now()) } });
          await B.delete('pending/bg/' + uid);
        } else if (m[1] === 'reject') {
          await B.delete('pending/bg/' + uid);
        } else {
          await B.delete(['pending/bg/' + uid, 'bg/' + uid]);
        }
        return json({ ok: true });
      }

      return json({ error: 'path' }, 404);
    } catch (e) {
      return json({ error: 'server', detail: String(e && e.message ? e.message : e) }, 500);
    }
  },
};
