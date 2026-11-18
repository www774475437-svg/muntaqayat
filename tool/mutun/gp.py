import re,sys
sys.path.insert(0,'/tmp/mtool')
from ex import lines_of, clean
SEP=r'\s*(?:\.\.\.|…|%~%|%)\s*'
def parse(path, sep=SEP):
    L=lines_of(path); vs=[]; heads=[]; frag=''; pend=None
    for l in L:
        if l[0]=='¶': continue
        if l[0]=='§':
            t=clean(l[1:]).strip(' :()-')
            if t and pend is None: heads.append((len(vs),t))
            continue
        x=clean(re.sub(r'</?span[^>]*>','',l)).strip()
        if not x or re.fullmatch(r'[:\s]*',x): continue
        has=re.search(sep,x) is not None
        if pend is not None:
            x=pend+' '+x if not x.startswith('...') else pend+' '+x
            pend=None; has=True
        if not has:
            if x.endswith(':') and len(x.split())<=6:
                heads.append((len(vs),x.strip(' :'))); continue
            frag=(frag+' '+x).strip(); continue
        if frag: x=frag+' '+x; frag=''
        parts=[p.strip() for p in re.split(sep,x)]
        if len(parts)==2 and parts[1]=='' : pend=x; continue
        if len(parts)==2 and parts[0]=='' : continue
        parts=[p for p in parts if p]
        if len(parts)%2==0:
            for k in range(0,len(parts),2): vs.append([parts[k],parts[k+1]])
        else:
            vs.append(parts[:2]+([' '.join(parts[2:])] if len(parts)>2 else []))
    # merge heads at same idx
    return vs,heads
if __name__=='__main__':
    v,h=parse(sys.argv[1]); print(len(v),'verses',len(h),'heads')
    bad=[(i,x) for i,x in enumerate(v) if len(x)!=2]
    print('bad',len(bad),bad[:5])
