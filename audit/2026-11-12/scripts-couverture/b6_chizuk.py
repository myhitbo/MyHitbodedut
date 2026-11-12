import json,re,collections
RAW='android/app/src/main/res/raw/'
def ne(x): return isinstance(x,str) and x.strip()!=''
heb=re.compile(r'[֐-׿]')
LIVRES=["Likoutei Etsot, Hit'hazkout ","Likoutei Etsot, Hitbodedout ","Likoutei Etsot, Téfila ","Rambam, Hilkhot Tefila ","Likoutei Moharan II, ","Likoutei Moharan I, ","Likoutei Tefilot II, ","Likoutei Tefilot I, ","Si'hot HaRan ","'Hayé Moharan ","Chiv'hei HaRan ","Tehilim ","Michlé ","Eikha ","Chmouel I ","Yechayahou ","Hochéa ","Bisdei Yaar, chap. "]
d=json.load(open(RAW+'chizuk.json'))
print('top keys',list(d.keys()))
print('meta keys',list(d['_meta'].keys()))
for k in d:
    if k=='_meta': continue
    v=d[k]
    print(k,type(v).__name__,len(v))
items=d.get('items') or d.get('textes') or []
kc=collections.Counter()
for it in items:
    for k in it: kc[k]+=1
print(dict(kc))
print(json.dumps(items[0],ensure_ascii=False,indent=1)[:1800])
c=collections.Counter()
for it in items:
    c['n']+=1
    for k,v in it.items():
        if isinstance(v,str) and v.strip(): c[k]+=1
        elif isinstance(v,dict):
            for kk,vv in v.items():
                if ne(vv): c[k+'.'+kk]+=1
        elif isinstance(v,list) and v: c[k+'[]']+=1
print(dict(c))
bad=[it['ref'] for it in items if not any(it.get('ref','').startswith(l) for l in LIVRES)]
print('refs inconnues chizuk',len(bad),bad[:20])
print('statuts',collections.Counter(it.get('statut_verif') for it in items))
print('themes',collections.Counter(json.dumps(it.get('theme'),ensure_ascii=False) for it in items))
print('moments',collections.Counter(json.dumps(it.get('moments'),ensure_ascii=False) for it in items).most_common(8))
b=json.load(open(RAW+'bibliotheque.json'))
refs=[e['ref'] for s in b['sections'] for ss in s['sous_sections'] for e in ss['entrees'] if e['type']=='source']
bad=[r for r in refs if not any(r.startswith(l) for l in LIVRES)]
print('refs inconnues biblio',len(bad),bad)
print(refs)
