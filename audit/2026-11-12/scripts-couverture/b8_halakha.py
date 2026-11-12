import json,re,collections
RAW='android/app/src/main/res/raw/'
heb=re.compile(r'[֐-׿]')
d=json.load(open(RAW+'ben_ish_hai.json'))
print('ben_ish_hai keys',list(d.keys()))
c=collections.Counter()
for a,ps in d['annees'].items():
    for p,v in ps.items():
        c['parachiot']+=1
        c['keys:'+','.join(sorted(v.keys()))]+=1
        c['halakhot']+=len(v['h'])
        c['chars']+=sum(len(x) for x in v['h'])
for k in d:
    if k!='annees': print(k, json.dumps(d[k],ensure_ascii=False)[:600])
print(dict(c))
d=json.load(open(RAW+'yalkut_yosef.json'))
print('yalkut keys',list(d.keys()))
for k in d:
    v=d[k]
    if isinstance(v,dict):
        print(k,'dict',list(v.keys())[:40])
    elif isinstance(v,list): print(k,'list',len(v), json.dumps(v[0],ensure_ascii=False)[:300])
    else: print(k,v)
print(json.dumps(d.get('_meta'),ensure_ascii=False)[:1500])
c=collections.Counter()
def walk(o,path=''):
    if isinstance(o,dict):
        if 't' in o and 's' in o:
            c['halakhot']+=1; c['chars']+=len(o['t'])
            for k in o: c['k:'+k]+=1
            return
        for k,v in o.items(): walk(v,path+'/'+k)
    elif isinstance(o,list):
        for x in o: walk(x,path)
walk(d)
print(dict(c))
