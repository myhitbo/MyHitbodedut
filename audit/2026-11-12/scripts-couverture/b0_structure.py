import json, sys, os, glob
RAW='android/app/src/main/res/raw/'
def shape(o, depth=0, maxd=6):
    if isinstance(o, dict):
        if depth>=maxd: return '{...}'
        return {k: shape(v, depth+1, maxd) for k,v in list(o.items())[:40]}
    if isinstance(o, list):
        if not o: return []
        # merge keys of dicts
        if all(isinstance(x, dict) for x in o):
            keys={}
            for x in o[:2000]:
                for k,v in x.items():
                    if k not in keys: keys[k]=v
            return ['len=%d'%len(o), shape(keys, depth+1, maxd)]
        return ['len=%d'%len(o), shape(o[0], depth+1, maxd)]
    if isinstance(o,str): return 'str:'+o[:40]
    return o
for f in sorted(glob.glob(RAW+'*.json')):
    d=json.load(open(f))
    print('=====',os.path.basename(f))
    print(json.dumps(shape(d),ensure_ascii=False,indent=1)[:2500])
