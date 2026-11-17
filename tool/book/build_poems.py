import json,re,unicodedata
d=json.load(open('entries.json')); chapters=json.load(open('chapters.json'))
SECTIONS=[('أبواب الإيمان والرقائق',5),('الأبواب العامة',26)]
def sec_of(page): return 1 if page>=26 else 0
MARKS=re.compile('[ً-ٰٟۡؐ-ؚ]')
def plain(s): return MARKS.sub('',s)
AR2=str.maketrans('٠١٢٣٤٥٦٧٨٩','0123456789')
ERAS=['جاهلي','مخضرم','صدر الإسلام','أموي','عباسي','أندلسي','أيوبي','مملوكي','عثماني','حديث']
def parse_attr(a):
    if not a: return dict(poet='بلا نسبة',era='',death='',note='',raw='')
    raw=a.strip().replace('\u0640','').replace('\x00','')
    raw=re.sub(r'\)([^()]*)\(',r'(\1)',raw)
    era=''
    m=re.search(r'—\s*([^—]+)$',raw)
    if m and m.group(1).strip() in ERAS: era=m.group(1).strip(); body=raw[:m.start()].strip()
    else: body=raw
    if body.startswith('بلا نسبة'):
        pm=re.search(r'\((.*?)\)',body)
        return dict(poet='بلا نسبة',era=era,death='',note=pm.group(1) if pm else '',raw=raw)
    if body.startswith('بلا نسبة'): return dict(poet='بلا نسبة',era=era,death='',note='',raw=raw)
    death=''
    dm=re.search(r"'تـ?\s*(نحو\s*)?([٠-٩0-9]+)\s*ھ'",body)
    if dm: death=('نحو ' if dm.group(1) else '')+dm.group(2)+'هـ'
    name=re.split(r"\s*'تـ?|\s*\(|،",body)[0].strip()
    note=''
    rest=body[len(name):]
    nm=re.search(r"ھ'\s*،?\s*(.*)$",rest)
    if nm and nm.group(1).strip(): note=nm.group(1).strip()
    if name.startswith('يُنسب ل'):
        note=('يُنسب ولا يثبت' if 'لا يثبت' in body else 'يُنسب')
        name=name[len('يُنسب ل'):]
        if name.startswith('ل'): name='ا'+name
    if 'ولا يثبت' in body and not note: note='يُنسب ولا يثبت'
    return dict(poet=name,era=era,death=death,note=note,raw=raw)
def rhyme(lines):
    last=lines[-1][-1]
    s=re.sub(r'[^ء-ي]','',plain(last))
    s=s.rstrip('اويى') if len(s)>2 else s
    if s.endswith('ه') and len(s)>2 and s[-2] in 'اويى': s=s[:-2]
    c=s[-1:] if s else ''
    return {'ة':'ت','ى':'ي','أ':'ء','إ':'ء','ؤ':'ء','ئ':'ء','آ':'ء'}.get(c,c)
out=[];poets={}
for e in d['entries']:
    if not e['lines'] or e['chapter']<0: continue
    at=parse_attr(e['attr'])
    flags=list(e['flags'])
    if any(len(l)==1 for l in e['lines']): flags.append('سطر منفرد')
    if not e['attr']: flags.append('بلا سطر نسبة')
    if '①' in (e['attr'] or ''): flags.append('نسبة متعددة')
    ch=chapters[e['chapter']][0]
    item=dict(id=len(out)+1,ch=e['chapter'],sec=sec_of(chapters[e['chapter']][1]),page=e['page'],
              lines=e['lines'],notes=[n for n in e['notes'] if n and not re.fullmatch(r'[٠-٩\s]+',n)],
              poet=at['poet'],era=at['era'],death=at['death'],pnote=at['note'],attr=at['raw'],
              rhyme=rhyme(e['lines']),flags=flags)
    out.append(item)
    p=poets.setdefault(at['poet'],dict(name=at['poet'],era=at['era'],death=at['death'],count=0))
    p['count']+=1
    if not p['era'] and at['era']: p['era']=at['era']
    if not p['death'] and at['death']: p['death']=at['death']
# merge a short name into the longer name that starts with it
names=list(poets)
for n in names:
    if n=='بلا نسبة' or n not in poets: continue
    longer=[m for m in poets if m!=n and m.startswith(n+' ')]
    if len(longer)==1:
        L=longer[0]; poets[L]['count']+=poets[n]['count']; del poets[n]
        for o in out:
            if o['poet']==n: o['poet']=L
data=dict(book='منتقيات شعرية',author='أبو عبد الرحمن أحمد الأثري',
  sections=[s[0] for s in SECTIONS],
  chapters=[dict(name=c[0],sec=sec_of(c[1])) for c in chapters],
  eras=ERAS,poets=sorted(poets.values(),key=lambda p:-p['count']),poems=out)
json.dump(data,open('poems.json','w'),ensure_ascii=False,separators=(',',':'))
import collections
print(len(out),'poems',len(poets),'poets',sum(1 for o in out if o['flags']),'flagged')
print(collections.Counter(o['era'] for o in out))
print(collections.Counter(o['rhyme'] for o in out).most_common(30))
for p in data['poets'][:25]: print(p)
