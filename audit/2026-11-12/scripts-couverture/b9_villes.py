import json,re,collections
RAW='android/app/src/main/res/raw/'
heb=re.compile(r'[֐-׿]')
def ne(x): return isinstance(x,str) and x.strip()!=''
d=json.load(open(RAW+'villes.json'))
c=collections.Counter()
same=[]; heblat=[]
for v in d['villes']:
    c['n']+=1
    for l in('he','fr','en'):
        if ne(v['nom'].get(l)): c[l]+=1
    if not heb.search(v['nom'].get('he','')): heblat.append(v['nom'])
    if v['nom'].get('fr')==v['nom'].get('en'): c['fr==en']+=1
    if heb.search(v['nom'].get('fr','')) or heb.search(v['nom'].get('en','')): c['fr/en hebreu']+=1
print('villes',dict(c)); print('he sans lettres hébraïques',heblat[:10])
a=json.load(open(RAW+'aeroports.json'))
print('aeroports colonnes',a['_meta']['colonnes'], a['aeroports'][0], len(a['aeroports']))
n=json.load(open(RAW+'aeroports_noms.json'))
print('noms meta',json.dumps(n['_meta'],ensure_ascii=False))
c=collections.Counter()
for k,v in n['noms'].items():
    c['n']+=1
    for i,col in enumerate(n['_meta']['colonnes']):
        if ne(v[i]): c[col]+=1
print('aeroports_noms',dict(c), 'sur',len(a['aeroports']),'aéroports')
k=list(n['noms'].items())
for kk,v in k[:3]+[x for x in k if x[0] in('TLV','CDG','JFK','ORY','LHR')]: print(kk,v)
# aeroports: name/city columns language
cols=a['_meta']['colonnes']
print([dict(zip(cols,x)) for x in a['aeroports'] if x[0] in('TLV','CDG','JFK','GVA')])
