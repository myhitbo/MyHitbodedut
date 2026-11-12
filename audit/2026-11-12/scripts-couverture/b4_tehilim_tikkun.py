import json,re,collections
RAW='android/app/src/main/res/raw/'
def ne(x): return isinstance(x,str) and x.strip()!=''
d=json.load(open(RAW+'tehilim.json'))
he=d['psaumes']; fr=d['traductions']['fr']['psaumes']; en=d['traductions']['en']['psaumes']
nv=sum(len(p) for p in he)
print('tehilim psaumes',len(he),'versets he',nv,'fr',sum(len(p) for p in fr),'en',sum(len(p) for p in en))
mis=[(i+1,len(he[i]),len(fr[i]),len(en[i])) for i in range(150) if not(len(he[i])==len(fr[i])==len(en[i]))]
print('count mismatches',mis)
print('empty fr',sum(1 for p in fr for v in p if not ne(v)),'empty en',sum(1 for p in en for v in p if not ne(v)))
print([ (i+1,j+1) for i,p in enumerate(fr) for j,v in enumerate(p) if not ne(v)][:20])
print([ (i+1,j+1) for i,p in enumerate(en) for j,v in enumerate(p) if not ne(v)][:20])
print('other keys',list(d.keys()), list(d['_meta'].keys()))
# tehilim extra: titles of books/days? 
t=json.load(open(RAW+'tikkun_haklali.json'))
print('tikkun keys',list(t.keys()))
c=collections.Counter()
for p in t['psaumes']:
    for v in p['versets']:
        c['v']+=1
        if ne(v.get('fr')): c['v_fr']+=1
        if ne(v.get('en')): c['v_en']+=1
print(dict(c))
for k,v in t.items():
    if k in('_meta','psaumes'): continue
    if isinstance(v,dict):
        print(k, {kk:(len(vv) if isinstance(vv,list) else (vv if not isinstance(vv,str) else vv[:70])) for kk,vv in v.items()})
        if 'paragraphes' in v:
            n=len(v['paragraphes'])
            print('   paragraphes',n,'fr',sum(1 for x in v.get('paragraphes_fr',[]) if ne(x)),'en',sum(1 for x in v.get('paragraphes_en',[]) if ne(x)))
    else:
        print(k,type(v), (len(v) if hasattr(v,'__len__') else v))
print(json.dumps(t['_meta'].get('continuite'),ensure_ascii=False))
