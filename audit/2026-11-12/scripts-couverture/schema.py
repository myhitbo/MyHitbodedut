import json,sys,os,re
from collections import Counter,defaultdict
RAW='android/app/src/main/res/raw/'
heb=re.compile(r'[֐-׿]')
def walk(o,path,stats):
    if isinstance(o,dict):
        collapse = len(o)>12 or any(re.fullmatch(r'[0-9]+|[A-Z]{3}|[a-z0-9_]*\d+[a-z0-9_]*',k) for k in o)
        for k,v in o.items():
            walk(v,path+('.*' if collapse else '.'+k),stats)
    elif isinstance(o,list):
        for v in o:
            walk(v,path+'[]',stats)
    else:
        s=stats[path]
        s['n']+=1
        if isinstance(o,str):
            if o.strip(): s['nonempty']+=1
            if heb.search(o): s['heb']+=1
            s['chars']+=len(o)
            if len(s['ex'])<1 and o.strip(): s['ex'].append(o[:70])
        else:
            s['nonstr']+=1
for f in sorted(os.listdir(RAW)):
    if not f.endswith('.json'): continue
    if len(sys.argv)>1 and f not in sys.argv[1:]: continue
    d=json.load(open(RAW+f,encoding='utf-8'))
    stats=defaultdict(lambda:{'n':0,'nonempty':0,'heb':0,'chars':0,'nonstr':0,'ex':[]})
    walk(d,'',stats)
    print('=====',f, type(d).__name__, (len(d) if hasattr(d,'__len__') else ''))
    for p,s in stats.items():
        print(f"  {p:60s} n={s['n']:7d} nonempty={s['nonempty']:7d} heb={s['heb']:7d} chars={s['chars']:9d} nonstr={s['nonstr']} ex={s['ex']}")
