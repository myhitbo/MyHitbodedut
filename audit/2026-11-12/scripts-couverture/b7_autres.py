import json,re,collections
RAW='android/app/src/main/res/raw/'
def ne(x): return isinstance(x,str) and x.strip()!=''
heb=re.compile(r'[֐-׿]')
# guide_sujets
d=json.load(open(RAW+'guide_sujets.json'))
c=collections.Counter()
for s,t in d['sujets'].items():
    for k,v in t.items():
        c['n']+=1
        for l in('he','fr','en'):
            if ne(v.get(l)): c[l]+=1
print('guide_sujets sujets',len(d['sujets']),dict(c), d['_meta'])
# hilloulot
d=json.load(open(RAW+'hilloulot.json'))
print('hilloulot meta',json.dumps(d['_meta'],ensure_ascii=False)[:1500])
c=collections.Counter(); kc=collections.Counter()
dvals=collections.Counter()
for j,l in d['jours'].items():
    c['jours']+=1
    for e in l:
        c['n']+=1
        for k in e: kc[k]+=1
        for k in('he','fr','en','d','t','w','i','a'):
            if ne(e.get(k)): c[k]+=1
        if ne(e.get('fr')) and not ne(e.get('en')): c['fr_sans_en']+=1
        if ne(e.get('en')) and not ne(e.get('fr')): c['en_sans_fr']+=1
        if ne(e.get('d')):
            dvals[e['d']]+=1
            if heb.search(e['d']): c['d_heb']+=1
        if ne(e.get('t')) and heb.search(e['t']): c['t_heb']+=1
        if ne(e.get('fr')) and e.get('fr')==e.get('en'): c['fr==en']+=1
print(dict(c)); print(dict(kc))
print('d distinct',len(dvals)); 
for k,v in dvals.most_common(25): print('   ',v,k[:140])
# hilloulot_bios
b=json.load(open(RAW+'hilloulot_bios.json'))
c=collections.Counter(); src=collections.Counter()
ex=None
for j,l in b.items():
    for e in l:
        c['entrees']+=1
        if e==0 or not e: c['sans_bio']+=1; continue
        c['avec_bio']+=1
        for bio in e:
            c['bios']+=1
            src[bio[0]]+=1
            if ex is None: ex=bio
            for x in bio[1:]:
                if isinstance(x,str):
                    if heb.search(x): c['champ_heb']+=1
                    elif re.search('[A-Za-z]',x): c['champ_latin']+=1
print('bios',dict(c),dict(src)); print([str(x)[:200] for x in ex])
