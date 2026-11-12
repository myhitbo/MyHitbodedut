import json,re,collections
RAW='android/app/src/main/res/raw/'
heb=re.compile(r'[֐-׿]')
def ne(x): return isinstance(x,str) and x.strip()!=''
for n in ('edot','sefard','ashkenaz'):
    d=json.load(open(RAW+f'siddur_{n}.json'))
    c=collections.Counter(); bk=collections.Counter(); sk=collections.Counter(); tk=collections.Counter()
    for g in d['groupes']:
        c['groupes']+=1
        for l in ('he','fr','en'):
            if ne(g['titre'].get(l)): c['groupe_'+l]+=1
    for tx in d['textes']:
        for k in tx: tk[k]+=1
        c['textes']+=1
        for l in ('he','fr','en'):
            if ne(tx['titre'].get(l)): c['titre_'+l]+=1
        if tx['titre'].get('fr')==tx['titre'].get('en'): c['titre_fr==en']+=1
        if 'nusah' in tx:
            c['emprunt']+=1
        for s in tx['sections']:
            for k in s: sk[k]+=1
            c['sections']+=1
            if ne(s.get('titre')): c['sec_he']+=1
            if ne(s.get('titre_fr')): c['sec_fr']+=1
            if ne(s.get('titre_en')): c['sec_en']+=1
            for b in s['blocs']:
                for k in b: bk[k]+=1
                if 't' in b:
                    c['t']+=1; c['t_chars']+=len(b['t'])
                    if ne(b.get('fr')): c['t_fr']+=1
                    if ne(b.get('en')): c['t_en']+=1
                if 'c' in b:
                    c['c']+=1; c['c_chars']+=len(b['c'])
                    if heb.search(b['c']): c['c_heb']+=1
                    if re.search(r'[A-Za-z]{3,}',re.sub(r'<[^>]+>','',b['c'])): c['c_latin']+=1
    print(n, d['_meta']['nusah'])
    print('  tk',dict(tk)); print('  sk',dict(sk)); print('  bk',dict(bk))
    print('  ',dict(c))
    print('  meta keys', list(d['_meta'].keys()))
    print('  relecture:', d['_meta'].get('relecture'))
d=json.load(open(RAW+'siddur_edot.json'))
for tx in d['textes']: print(tx['id'], tx['titre'])
# sample c blocks
import itertools
cs=[b['c'] for tx in d['textes'] for s in tx['sections'] for b in s['blocs'] if 'c' in b]
for x in cs[:8]: print('C:',x[:160])
