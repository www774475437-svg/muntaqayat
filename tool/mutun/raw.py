import sys
sys.path.insert(0,'/tmp/mtool')
from ex import lines_of
L=lines_of(sys.argv[1])
a,b=int(sys.argv[2]),int(sys.argv[3])
for i,l in enumerate(L[a:b],a): print(i,l[:170])
