import json, glob, os, re, collections
RAW='android/app/src/main/res/raw/'
heb=re.compile(r'[֐-׿]')
def ne(x): return isinstance(x,str) and x.strip()!=''
tot=collections.Counter()
keys_seen=collections.Counter()
for f in sorted(glob.glob(RAW+'livre_*.json')):
    d=json.load(open(f))
    for tx in d['textes']:
        c=collections.Counter()
        skeys=collections.Counter(); bkeys=collections.Counter()
        for s in tx['sections']:
            for k in s: skeys[k]+=1
            c['sections']+=1
            if ne(s.get('titre')): c['sec_he']+=1
            if ne(s.get('titre_fr')): c['sec_fr']+=1
            if ne(s.get('titre_en')): c['sec_en']+=1
            for b in s['blocs']:
                for k in b: bkeys[k]+=1
                if 't' in b:
                    c['t']+=1
                    if ne(b.get('fr')): c['t_fr']+=1
                    if ne(b.get('en')): c['t_en']+=1
                    c['t_chars']+=len(b['t'])
                    if ne(b.get('fr')): c['t_chars_fr']+=len(b['t'])
                    if ne(b.get('en')): c['t_chars_en']+=len(b['t'])
                elif 'c' in b:
                    c['c']+=1
                    if ne(b.get('fr')): c['c_fr']+=1
                    if ne(b.get('en')): c['c_en']+=1
                    if heb.search(b['c']): c['c_heb']+=1
                else:
                    c['autre']+=1
        print(os.path.basename(f), tx['id'], 'groupe',tx.get('groupe'))
        print('   titre', tx['titre'])
        print('   keys tx', [k for k in tx if k!='sections'], 'traduction=',tx.get('traduction'), 'traductions=',list(tx.get('traductions',{}).keys()) )
        print('   skeys',dict(skeys),'bkeys',dict(bkeys))
        print('   ',dict(c))
        tot.update(c)
print('TOTAL',dict(tot))
