import json,re
RAW='android/app/src/main/res/raw/'
d=json.load(open(RAW+'livre_yalkut_yosef_kitsour.json'))
tx=d['textes'][0]
print(tx.get('traduction')); print(tx.get('source'))
full=part=none=0
rng=[]
for i,s in enumerate(tx['sections']):
    t=[b for b in s['blocs'] if 't' in b]
    fr=sum(1 for b in t if (b.get('fr') or '').strip())
    en=sum(1 for b in t if (b.get('en') or '').strip())
    st='full' if fr==len(t) and t else ('none' if fr==0 else 'part')
    if st=='full': full+=1
    elif st=='part': part+=1
    else: none+=1
    rng.append((i,st,len(t),fr,en,bool(s.get('titre_fr')),s['titre'][:50]))
print('sections full',full,'part',part,'none',none)
# print runs
prev=None;start=0
for i,st,n,fr,en,tf,ti in rng:
    key=(st,tf)
    if key!=prev:
        if prev is not None: print(start,'-',i-1,prev)
        prev=key;start=i
print(start,'-',len(rng)-1,prev)
for r in rng[:3]+rng[88:96]: print(r)
# sections with titre_fr but no blocs translated, or vice versa
print([r for r in rng if r[5] and r[1]!='full'][:10])
print([r for r in rng if (not r[5]) and r[1]!='none'][:10])
# fr != en counts in blocks
fr_only=sum(1 for s in tx['sections'] for b in s['blocs'] if (b.get('fr') or '').strip() and not (b.get('en') or '').strip())
en_only=sum(1 for s in tx['sections'] for b in s['blocs'] if (b.get('en') or '').strip() and not (b.get('fr') or '').strip())
print('fr only',fr_only,'en only',en_only)
