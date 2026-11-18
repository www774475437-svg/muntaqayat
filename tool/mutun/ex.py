import re,sys,json
def lines_of(path):
    raw=open(path,encoding='utf-8').read().split('\n')
    out=[]; cur=None
    for l in raw:
        if l.startswith('#META') : continue
        if l.startswith('~~'):
            if cur is not None: cur+=' '+l[2:].strip()
            continue
        if cur is not None: out.append(cur); cur=None
        if l.startswith('# '): cur=l[2:].strip()
        elif l.startswith('### |'): out.append('§'+l[5:].strip())
        else: out.append('¶'+l.strip())
    if cur: out.append(cur)
    return out
def clean(s):
    s=re.sub(r'PageV\d+P\d+','',s); s=re.sub(r'ms\d+','',s)
    s=re.sub(r'\(¬?\d+\)|\[\d+\]|¬\d*','',s); s=re.sub(r'\s+',' ',s).strip()
    return s
def verses(path):
    vs=[]
    for i,l in enumerate(lines_of(path)):
        if l[0] in '§¶': continue
        if '...' in l or '…' in l or '%~%' in l:
            p=re.split(r'\s*(?:\.\.\.|…|%~%)\s*',l)
            p=[clean(x) for x in p if clean(x)]
            if len(p)==2: vs.append((i,p))
            elif len(p)==4: vs.append((i,p[:2]));vs.append((i,p[2:]))
    return vs
if __name__=='__main__':
    v=verses(sys.argv[1]); print(len(v))
    for i,p in v[:int(sys.argv[2]) if len(sys.argv)>2 else 5]: print(i,' | '.join(p))
