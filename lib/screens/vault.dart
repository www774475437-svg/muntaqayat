import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../data.dart';
import '../services/cloud.dart';
import '../ui.dart';
import 'lists.dart';
import 'qawafi.dart';

/// The app's cloud storage (Cloudflare R2), reached through its gateway.
/// Nothing is uploaded without an account, and no background shows until the developer accepts it.
class Vault {
  /// The gateway's address. Empty until the gateway is deployed: everything here stays hidden meanwhile.
  static const base = '';

  static bool get ready => base.isNotEmpty;

  /// Profile backgrounds: off until the developer turns them on.
  static bool get backgrounds => ready && (Store.i.features['bg'] ?? false);

  static Future<Map<String, String>> _auth() async {
    final t = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {'authorization': 'Bearer ${t ?? ''}'};
  }

  static String bgUrl(String uid) => '$base/bg/$uid';
  static String pendingUrl(String uid) => '$base/pending/bg/$uid';
  static Future<Map<String, String>> headers() => _auth();

  static Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final r = await http.get(Uri.parse('$base$path'), headers: await _auth()).timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) return null;
      return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> usage({bool fresh = false}) => _get('/usage${fresh ? '?fresh=1' : ''}');
  static Future<Map<String, dynamic>?> mine() => _get('/mine');
  static Future<List<Map<String, dynamic>>> pending() async {
    final j = await _get('/pending');
    return [for (final x in (j?['items'] as List? ?? [])) Map<String, dynamic>.from(x as Map)];
  }

  static Future<bool> _post(String path) async {
    try {
      final r = await http.post(Uri.parse('$base$path'), headers: await _auth()).timeout(const Duration(seconds: 25));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> approve(String uid) => _post('/approve/$uid');
  static Future<bool> reject(String uid) => _post('/reject/$uid');
  static Future<bool> remove(String uid) => _post('/remove/$uid');

  static Future<bool> deleteMine() async {
    try {
      final r = await http.delete(Uri.parse('$base/bg'), headers: await _auth()).timeout(const Duration(seconds: 25));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// The upload's outcome as a short word: ok, big, type, full, auth or fail.
  static Future<String> uploadBackground(Uint8List bytes, String mime) async {
    try {
      final r = await http
          .put(Uri.parse('$base/bg'), headers: {...await _auth(), 'content-type': mime}, body: bytes)
          .timeout(const Duration(seconds: 60));
      if (r.statusCode == 200) return 'ok';
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      return (j is Map && j['error'] is String) ? j['error'] as String : 'fail';
    } catch (_) {
      return 'fail';
    }
  }

  /// A first look by the machine before the picture is sent: true = refuse it, false = let it wait
  /// for the developer, null = the check could not run. The developer's own look is what decides.
  static Future<bool?> looksForbidden(Uint8List bytes, String mime) async {
    try {
      final m = FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');
      final r = await m.generateContent([
        Content.multi([
          TextPart('Look at this image. Answer with one word only, YES or NO. Answer YES if the image shows any human being, any part of a human body or face, any animal, bird, fish or insect, any drawn or cartoon character or statue of a living creature, any nudity or sexual or indecent content, or any religious symbol such as a cross. Answer NO only if it shows none of these (for example landscapes, sky, sea, plants, buildings, patterns, calligraphy or objects).'),
          InlineDataPart(mime, bytes),
        ]),
      ]).timeout(const Duration(seconds: 40));
      final t = (r.text ?? '').trim().toUpperCase();
      if (t.startsWith('YES')) return true;
      if (t.startsWith('NO')) return false;
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// A number in Arabic digits, with up to [dec] decimals.
String _ar(num v, [int dec = 2]) {
  var t = v.toStringAsFixed(dec);
  if (t.contains('.')) t = t.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  const d = '٠١٢٣٤٥٦٧٨٩';
  return t.split('').map((c) => c == '.' ? '٫' : (int.tryParse(c) == null ? c : d[int.parse(c)])).join();
}

String _mb(num bytes) {
  if (bytes >= 1e9) return '${_ar(bytes / 1e9)} جيجا';
  if (bytes >= 1e6) return '${_ar(bytes / 1e6)} ميجا';
  return '${_ar(bytes / 1e3, 0)} كيلوبايت';
}

/// The accepted background at the top of a member's page. Shows nothing when there is none.
class VaultBanner extends StatelessWidget {
  final String uid;
  const VaultBanner({super.key, required this.uid});
  @override
  Widget build(BuildContext context) {
    if (!Vault.backgrounds || uid.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          Vault.bgUrl(uid),
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          loadingBuilder: (c, child, p) => p == null ? child : const SizedBox(height: 150),
        ),
      ),
    );
  }
}

/// «خلفية صفحتي»: the reader picks a picture, it waits for the developer, then it shows on his page.
class MyBackgroundScreen extends StatefulWidget {
  const MyBackgroundScreen({super.key});
  @override
  State<MyBackgroundScreen> createState() => _MyBackgroundScreenState();
}

class _MyBackgroundScreenState extends State<MyBackgroundScreen> {
  Map<String, dynamic>? state;
  bool busy = false;
  String note = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await Vault.mine();
    if (mounted) setState(() => state = s ?? {});
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
    if (x == null || !mounted) return;
    setState(() {
      busy = true;
      note = 'تُفحص الصورة…';
    });
    final bytes = await x.readAsBytes();
    final name = x.name.toLowerCase();
    final mime = name.endsWith('.png') ? 'image/png' : (name.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
    final bad = await Vault.looksForbidden(bytes, mime);
    if (bad == true) {
      if (mounted) {
        setState(() {
          busy = false;
          note = 'لم تُقبل الصورة: لا تُقبل صور ذوات الأرواح ولا ما يخالف الأدب. اختر منظراً أو زخرفة أو خطاً.';
        });
      }
      return;
    }
    if (mounted) setState(() => note = 'تُرفع الصورة…');
    final r = await Vault.uploadBackground(bytes, mime);
    if (!mounted) return;
    setState(() {
      busy = false;
      note = switch (r) {
        'ok' => 'وصلت الصورة، وتظهر في صفحتك بعد أن يراجعها المطوّر.',
        'big' => 'الصورة أكبر من ٢ ميجا. اختر صورة أصغر.',
        'type' => 'هذا الملف ليس صورة مقبولة (JPG أو PNG أو WebP).',
        'full' => 'امتلأت مساحة التخزين. أخبر المطوّر.',
        'auth' => 'ادخل بحسابك أولاً.',
        _ => 'تعذّر الرفع. تحقق من الإنترنت وحاول مرة أخرى.',
      };
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = Cloud.i;
    final pending = state?['pending'] == true, approved = state?['approved'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('خلفية صفحتي')),
      body: !c.signedIn
          ? const EmptyNote(Icons.lock_outline_rounded, 'ادخل بحسابك لتضيف خلفية لصفحتك.')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
              SoftCard(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('شروط الخلفية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
                  const SizedBox(height: 8),
                  Text(
                    'لا تُقبل صور ذوات الأرواح (إنسان أو حيوان أو طير، حقيقية أو مرسومة)، ولا ما فيه عري أو ما يخالف الأدب والشرع. تصلح المناظر والسماء والبحر والزخارف والخطوط.\n\nكل صورة يراجعها المطوّر قبل أن تظهر. ومن خالف حُذفت صورته، وقد يُوقف حسابه.',
                    style: TextStyle(fontSize: 15, height: 1.7, color: C.muted(context)),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              if (state == null) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
              if (approved) ...[
                Text('خلفيتك الظاهرة الآن', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context))),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network('${Vault.bgUrl(c.uid)}?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}', height: 150, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
                const SizedBox(height: 14),
              ],
              if (pending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(children: [
                    Icon(Icons.hourglass_top_rounded, color: C.accent(context)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('لك صورة تنتظر مراجعة المطوّر.', style: TextStyle(color: C.ink(context)))),
                  ]),
                ),
              if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(note, style: TextStyle(fontSize: 15, height: 1.6, color: C.accent(context)))),
              FilledButton.icon(
                onPressed: busy ? null : _pick,
                icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_photo_alternate_outlined),
                label: Text(approved || pending ? 'غيّر الصورة' : 'اختر صورة'),
              ),
              if (approved || pending)
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final ok = await Vault.deleteMine();
                          if (!context.mounted) return;
                          toast(context, ok ? 'حُذفت خلفيتك' : 'تعذّر الحذف');
                          _load();
                        },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('احذف خلفيتي'),
                ),
            ]),
    );
  }
}

/// Developer: the pictures waiting for his look. Nothing shows to readers before he accepts it.
class PendingBackgroundsScreen extends StatefulWidget {
  const PendingBackgroundsScreen({super.key});
  @override
  State<PendingBackgroundsScreen> createState() => _PendingBackgroundsScreenState();
}

class _PendingBackgroundsScreenState extends State<PendingBackgroundsScreen> {
  List<Map<String, dynamic>>? items;
  Map<String, String> headers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await Vault.headers();
    final l = await Vault.pending();
    if (mounted) {
      setState(() {
        headers = h;
        items = l;
      });
    }
  }

  Future<void> _act(String uid, bool accept) async {
    final ok = accept ? await Vault.approve(uid) : await Vault.reject(uid);
    if (!mounted) return;
    toast(context, ok ? (accept ? 'قُبلت وظهرت في صفحته' : 'رُفضت وحُذفت') : 'تعذّر التنفيذ');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = items;
    return Scaffold(
      appBar: AppBar(title: const Text('خلفيات تنتظر المراجعة'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: !Cloud.i.isDev
          ? const EmptyNote(Icons.lock_outline_rounded, 'هذه الصفحة للمطوّر.')
          : l == null
              ? const Center(child: CircularProgressIndicator())
              : l.isEmpty
                  ? const EmptyNote(Icons.image_outlined, 'لا صور تنتظر المراجعة.')
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
                      for (final x in l)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: SoftCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(Vault.pendingUrl('${x['uid']}'), headers: headers, height: 190, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 60, child: Center(child: Text('تعذّر عرض الصورة')))),
                              ),
                              const SizedBox(height: 8),
                              Text('الحجم: ${_mb((x['size'] ?? 0) as num)}', style: TextStyle(fontSize: 13, color: C.muted(context))),
                              const SizedBox(height: 6),
                              Row(children: [
                                Expanded(child: FilledButton(onPressed: () => _act('${x['uid']}', true), child: const Text('اقبلها'))),
                                const SizedBox(width: 8),
                                Expanded(child: OutlinedButton(onPressed: () => _act('${x['uid']}', false), child: const Text('ارفضها'))),
                                IconButton(
                                  tooltip: 'صفحة صاحبها',
                                  onPressed: () => openMember(context, uid: '${x['uid']}', name: ''),
                                  icon: const Icon(Icons.person_outline_rounded),
                                ),
                              ]),
                            ]),
                          ),
                        ),
                    ]),
    );
  }
}

/// Developer: how much of the storage is used, and what it would cost this month.
class StorageUsageScreen extends StatefulWidget {
  const StorageUsageScreen({super.key});
  @override
  State<StorageUsageScreen> createState() => _StorageUsageScreenState();
}

class _StorageUsageScreenState extends State<StorageUsageScreen> {
  Map<String, dynamic>? u;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _load(false);
  }

  Future<void> _load(bool fresh) async {
    setState(() {
      u = null;
      failed = false;
    });
    final r = await Vault.usage(fresh: fresh);
    if (mounted) {
      setState(() {
        u = r;
        failed = r == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final x = u;
    Widget line(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(a, style: TextStyle(fontSize: 16, color: C.muted(context)))),
            Text(b, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.ink(context))),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('التخزين السحابي'), actions: [IconButton(tooltip: 'أعد العدّ الآن', onPressed: () => _load(true), icon: const Icon(Icons.refresh_rounded))]),
      body: !Cloud.i.isDev
          ? const EmptyNote(Icons.lock_outline_rounded, 'هذه الصفحة للمطوّر.')
          : failed
              ? const EmptyNote(Icons.cloud_off_outlined, 'تعذّر الوصول إلى التخزين الآن.')
              : x == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
                      SoftCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          line('المستعمل', _mb((x['bytes'] ?? 0) as num)),
                          line('المجاني كل شهر', _mb((x['free'] ?? 0) as num)),
                          line('الحد الأقصى الذي وضعته', _mb((x['cap'] ?? 0) as num)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(minHeight: 10, value: (((x['bytes'] ?? 0) as num) / ((x['free'] ?? 1) as num)).clamp(0, 1).toDouble()),
                          ),
                          const SizedBox(height: 4),
                          Text('الشريط: ما استُعمل من المجاني', style: TextStyle(fontSize: 12, color: C.muted(context))),
                          const Divider(height: 26),
                          line('المتوقع عليك هذا الشهر', '${_ar((x['monthlyUsd'] ?? 0) as num)} دولار'),
                          Text(
                            'تقدير على سعر ${_ar((x['rate'] ?? 0) as num, 3)} دولار للجيجا الزائدة عن المجاني. الفاتورة الفعلية في Cloudflare، وقد تزيد قليلاً برسوم العمليات.',
                            style: TextStyle(fontSize: 13, height: 1.6, color: C.muted(context)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      Text('الحاويات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink(context))),
                      const SizedBox(height: 6),
                      for (final e in ((x['buckets'] as Map?) ?? {}).entries)
                        line('${e.key} · ${_ar(((e.value as Map)['count'] ?? 0) as num, 0)} ملفاً', _mb(((e.value as Map)['bytes'] ?? 0) as num)),
                      const SizedBox(height: 10),
                      Text('آخر عدّ: ${DateTime.fromMillisecondsSinceEpoch(((x['at'] ?? 0) as num).toInt()).toString().substring(0, 16)}', style: TextStyle(fontSize: 13, color: C.muted(context))),
                    ]),
    );
  }
}
