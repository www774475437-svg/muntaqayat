import re,sys,json
sys.path.insert(0,'/tmp/mtool')
from gp import parse
from ex import clean
P={}
for l in open('/tmp/want2.txt'):
    l=l.strip(); P[l.split('/')[-1]]='/tmp/oiti/'+l
def pth(k): return [v for kk,v in P.items() if k in kk][0]
def fix(v): return [[re.sub(r'\s+',' ',re.sub(r'[()\[\]«»"]','',h)).strip(' ,.') for h in x] for x in v]
def numheads(h):
    out=[]
    for i,t in h:
        t=re.sub(r'[()\[\]]','',t).strip(' -:')
        if re.sub(r'[\d\-\s.]','',t) and len(t)<60 and (not out or out[-1][0]!=i): out.append([i,t])
    return out
R={}
v,h=parse(pth('Qahtani')); v=fix(v); v=[[re.sub(r'\d+$','',a).strip(),re.sub(r'\d+$','',b).strip()] for a,b in v]; R['qahtani']=(v,[])
v,h=parse(pth('KafiyaShafiya')); v=fix(v); h=numheads(h)
v[0][0]=v[0][0].split('الرحيم')[-1].strip()
for i,x in enumerate(v):
    if x[0].startswith('فصل:') and len(x[0])>70:
        for cut in ['المجلس','عليهم']:
            if cut in x[0]:
                t,rest=x[0].split(cut,1); h.append([i,(t+cut).replace('فصل:','فصل').strip()]); x[0]=rest.strip()
h.sort()
R['kafiya']=(v,h)
v,h=parse(pth('Alfiyya')); R['alfiyya']=(fix(v),numheads(h))
v,h=parse(pth('TaiyyaFiQadar')); v=fix(v); v[0][0]=v[0][0].split(':',1)[-1].strip(); R['taiyya_qadar']=(v,[[0,'نص السؤال'],[8,'جواب شيخ الإسلام']])
v,h=parse(pth('ManzumaDaliya')); v=fix(v)[4:]; v[0][0]=v[0][0].split('المنظومة')[-1].strip(); R['daliya']=(v,[])
v,h=parse(pth('IlbiriDiwan') if False else pth('AbuIshaqIlbiri.Diwan')); v=fix(v)[:109]; v[0][0]=v[0][0].split('عليه')[-1].strip(); R['ilbiri']=(v,[])
v,h=parse(pth('IbnMubarak.Diwan')); v=fix(v)[:7]; v[0][0]=v[0][0].split('تام')[-1].strip(); R['mubarak']=(v,[])
v,h=parse(pth('Busti')); R['busti']=(fix(v),[])
# Durra
vs=[];hd=[]
for l in open(pth('DurraMudiyya'),encoding='utf-8'):
    m=re.match(r'#\s*\d+\s*\((.*?)%(.*?)\)?\s*(PageV\d+P\d+)?\s*$',l.strip())
    if m: vs.append([clean(m.group(1)),clean(m.group(2).rstrip('( '))]); continue
    m=re.match(r'#\s*\|\s*(.+)',l.strip())
    if m and vs is not None: hd.append([len(vs),clean(m.group(1))])
R['durra']=(fix(vs),numheads(hd))
# Mulha (JK, hemistichs separated by |)
txt=open(pth('MulhatIcrab.JK'),encoding='utf-8').read()
txt=re.sub(r'#META[^\n]*\n','',txt); txt=re.sub(r'\n~~',' ',txt); txt=txt.replace('| إذا أول أو\n~~وسط أو آخر ','').replace('إذا أول أو وسط أو آخر | ','')
vs=[];hd=[];buf=''
def flush():
    global buf
    hs=[clean(x) for x in buf.split('|')]; hs=[x for x in hs if x]
    for k in range(0,len(hs)-1,2): vs.append([hs[k],hs[k+1]])
    if len(hs)%2: print('MULHA odd',hs[-1][:40])
    buf=''
for l in txt.split('\n'):
    m=re.match(r'#\s*\|\s*1\s*\(\s*\d+\s*-\s*(.+?)\)\s*1',l)
    if m: flush(); hd.append([len(vs),clean(m.group(1))]); continue
    if l.startswith('# |') or l.startswith('#|'): buf+=' '+l.split('|',1)[1]
    elif l.startswith('# ') and buf: buf+=' '+l[2:]
flush()
vs=[x for x in vs if 'بسم الله' not in x[0]]
R['mulha']=(fix(vs),numheads(hd))
# Bayquni
v=[x.split(' | ') for x in open('/tmp/mtool/web/bayquni.txt',encoding='utf-8').read().strip().split('\n')]
R['bayquni']=(v,[])
R['adab']=(json.load(open('/tmp/mtool/adab.json')),[])
json.dump(R,open('/tmp/mtool/R.json','w'),ensure_ascii=False)
for k,(v,h) in R.items():
    bad=[i for i,x in enumerate(v) if len(x)!=2 or min(len(x[0]),len(x[1]))<6 or max(len(x[0]),len(x[1]))>70]
    print(k,len(v),'heads',len(h),'bad',len(bad),[(' | '.join(v[i]))[:80] for i in bad[:3]])
    print('   first:',' | '.join(v[0])[:90]); print('   last :',' | '.join(v[-1])[:90])
