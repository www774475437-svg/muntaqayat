import sys,re,json
sys.path.insert(0,'/tmp/bio'); from bios import B
def norm(s):
    s=re.sub('[ً-ْٰـ]','',s); s=re.sub('[أإآٱ]','ا',s); s=s.replace('ى','ي').replace('ة','ه')
    return s
books=[('SiyarAclam','سير أعلام النبلاء، شمس الدين الذهبي'),('WafayatAcyan','وفيات الأعيان، ابن خلكان'),('FawatWafayat','فوات الوفيات، ابن شاكر الكتبي'),('TabaqatFuhul','طبقات فحول الشعراء، ابن سلّام الجمحي'),('MucjamShucara','معجم الشعراء، المرزباني')]
files=[l.strip() for l in open('/tmp/bio_src.txt')]
L={}
for k,_ in books:
    f=[x for x in files if k in x][0]
    raw=open('/tmp/oiti/'+f,encoding='utf-8').read()
    raw=re.sub(r'\n~~',' ',raw)
    L[k]=[norm(re.sub(r'PageV\d+P\d+|ms\d+|[#|*()\[\]\d\-–.:«»"]',' ',l)).split() for l in raw.split('\n') if l.startswith('#') and not l.startswith('#META')]
out={}
for key,(bio,keys) in B.items():
    src=[]
    ys=re.findall('سنة ([٠-٩]+)هـ',bio)
    year=int(ys[-1].translate(str.maketrans('٠١٢٣٤٥٦٧٨٩','0123456789'))) if ys else None
    lim={'SiyarAclam':700,'WafayatAcyan':681,'FawatWafayat':764,'TabaqatFuhul':231,'MucjamShucara':384}
    for k,title in books:
        hit=False
        if year is not None and year>lim[k]: continue
        if year is None and k not in ('TabaqatFuhul','MucjamShucara'): continue
        for kk in keys:
            w=norm(kk).split()
            for words in L[k]:
                if len(words)>9: continue
                for i in range(0,3):
                    if words[i:i+len(w)]==w: hit=True;break
                if hit: break
            if hit: break
        if hit: src.append(title)
    out[key]=src
json.dump(out,open('/tmp/bio/sources.json','w'),ensure_ascii=False)
print(sum(1 for v in out.values() if v),'with sources'); print({k:[x.split('،')[0][:9] for x in v] for k,v in out.items()})
