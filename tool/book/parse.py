import json,re,unicodedata
pages=json.load(open('chunks.json'))
lay=open('layout.txt').read().split('\f')
MARKS=re.compile('[ً-ٰٟـۡؐ-ؚ‌-‏‪-‮]')
def skel(s): return re.sub(r'[^ء-ي]','',MARKS.sub('',unicodedata.normalize('NFKC',s)))
PF=re.compile('[ﭐ-﷿ﹰ-﻿]')
AR2=str.maketrans('٠١٢٣٤٥٦٧٨٩','0123456789')
# index chapters
idx=[]
for pg in range(105,109):
    for ch in sorted(pages[pg],key=lambda c:(c['y'],-c['x'])):
        pass
raw=open('/tmp/book_pypdf.txt').read()
ix=raw[raw.index('=====PAGE 106'):]
sections=[];chapters=[]
for line in ix.split('\n'):
    line=line.strip()
    m=re.match(r'^(.*?)([٠-٩]+)$',line)
    if not m or 'ﻬﺮس' in line: continue
    name=m.group(1).strip(); page=int(m.group(2)[::-1].translate(AR2))
    if PF.search(name): sections.append(page); continue
    chapters.append((name.replace('الـ','ال').replace('الج بن','الجبن'),page))
print(len(chapters),'chapters; sections at',sections)
json.dump(chapters,open('chapters.json','w'),ensure_ascii=False)

def fix_zero(txt,pageskel,flags):
    if '\x00' not in txt: return txt
    # trivial artifacts: after hamza-alef or shadda/tatweel and before tatweel
    s=txt
    s=re.sub('(?<=[أإآ])\x00','',s)
    if '\x00' not in s: return s
    # build regex over skeleton
    segs=[];cur=''
    for c in s:
        if c=='\x00': segs.append(cur);cur='';segs.append(None)
        else: cur+=c
    segs.append(cur)
    pat='';
    for g in segs:
        pat+= '([ء-ي]?)' if g is None else re.escape(skel(g))
    m=re.search(pat,pageskel)
    if not m:
        flags.add('حرف ناقص');return s.replace('\x00','')
    fills=iter(m.groups())
    return ''.join(next(fills) if g is None else g for g in segs)

def clean(t):
    t=t.replace('ـ','')
    t=re.sub(r'\s+',' ',t).strip()
    return t
entries=[];chap_i=-1;cur=None;heads=[]
for pi,parts in enumerate(pages):
    if pi<4 or pi>=105: continue
    pskel=skel(lay[pi]) if pi<len(lay) else ''
    lines={}
    top=min((c['y'] for c in parts),default=0)
    for c in parts:
        if c['y']-top<25: continue
        lines.setdefault(c['y'],[]).append(c)
    merged={}
    for y in sorted(lines):
        k=next((k for k in merged if abs(k-y)<=9),None)
        if k is None: merged[y]=list(lines[y])
        else: merged[k]+=lines[y]
    lines=merged
    for key in sorted(lines):
        L=sorted(lines[key],key=lambda c:-c['x'])
        text=''.join(c['t'] for c in L)
        fonts={c['f'] for c in L}; sizes={c['s'] for c in L}
        if any(c['s']>=21.5 and c['f']=='' for c in L) and PF.search(text):
            heads.append((pi+1,text)); chap_i+=1; continue
        if any(s>19 and s<20 for s in sizes) and PF.search(text): continue  # running header
        if any('ArefRuqaa' in f for f in fonts): # قال الشاعر
            cur=dict(page=pi+1,chapter=chap_i,lines=[],notes=[],attr=None,flags=set()); entries.append(cur); continue
        if cur is None: continue
        if '❁' in text:
            # attribution: rebuild by sorted x; reverse digit chunks
            segs=[]
            for c in L:
                t=c['t']
                if re.fullmatch(r'[٠-٩]+',t.strip()): t=t.strip()[::-1]
                segs.append(t)
            a=''.join(segs).replace('❁','').strip()
            cur['attr']=(cur['attr']+' ' if cur['attr'] else '')+a; continue
        verse=[c for c in L if abs(c['s']-18.9)<0.6]
        if verse:
            right=[c for c in verse if c['x']>200]; left=[c for c in verse if c['x']<=200]
            h1=''.join(c['t'] for c in right); h2=''.join(c['t'] for c in left)
            h1=clean(fix_zero(h1,pskel,cur['flags'])); h2=clean(fix_zero(h2,pskel,cur['flags']))
            cur['lines'].append([h1,h2] if h1 and h2 else [h1 or h2])
        else:
            cur['notes'].append(clean(fix_zero(text,pskel,cur['flags'])))
print('headings',len(heads),'entries',len(entries))
for e in entries: e['flags']=sorted(e['flags'])
json.dump(dict(entries=entries,heads=heads),open('entries.json','w'),ensure_ascii=False,indent=0)
