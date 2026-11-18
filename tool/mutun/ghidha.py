import re,sys
sys.path.insert(0,'/tmp/mtool')
from ex import clean
t=open(sys.argv[1],encoding='utf-8').read()
t=re.sub(r'#META[^\n]*','',t)
t=re.sub(r'\n~~',' ',t); t=re.sub(r'\n# ',' ',t); t=re.sub(r'PageV\d+P\d+|ms\d+|\|','',t); t=re.sub(r'\s+',' ',t)
vs=[]
for m in re.finditer(r'%\s*([^%]{8,90}?)\s*%\s*%\s*([^%]{8,90}?)\s*%\s*(\(\s*[^)]{1,30}\))?',t):
    a,b,c=m.group(1),m.group(2),m.group(3)
    if not re.search(r'دِ?ي?$',clean(b)): continue
    fw=re.findall(r'[ء-ي]+',a)
    if c and fw and fw[0][:3] in c: vs.append([clean(a),clean(b)])
# dedupe consecutive
out=[]
for v in vs:
    if not out or out[-1]!=v: out.append(v)
print(len(out))
import json; json.dump(out,open('/tmp/mtool/adab.json','w'),ensure_ascii=False)
for i,v in enumerate(out[:5]+out[-5:]): print(' | '.join(v))
