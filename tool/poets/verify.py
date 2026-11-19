import sys,re,glob
sys.path.insert(0,'/tmp/bio'); from newpoems import N
def norm(s):
    s=re.sub('[ً-ْٰـ]','',s); s=re.sub('[أإآٱ]','ا',s); s=s.replace('ى','ي').replace('ة','ه').replace('ؤ','و').replace('ئ','ي')
    return ' '.join(re.findall('[ء-ي]+',s))
files=[l.strip() for l in open('/tmp/poets_src.txt')]+[l.strip() for l in open('/tmp/bio_src.txt')]
cache={}
def text(key):
    f=[x for x in files if key in x][0]
    if f not in cache: cache[f]=norm(open('/tmp/oiti/'+f,encoding='utf-8').read())
    return cache[f]
alltxt=None
for poet,era,death,ch,key,vs in N:
    for v in vs.split('\n'):
        a,b=[norm(x) for x in v.split(' | ')]
        if key:
            t=text(key); ra,rb=a in t,b in t
        else: ra=rb=None
        if not (ra and rb):
            # try every file
            found=[k.split('/')[-1][:28] for k in files if a in text(k.split('/')[-1]) and b in text(k.split('/')[-1])] if True else []
            print(poet[:14],'|',a[:28],ra,rb,'ELSEWHERE:',found[:3])
print('done')
