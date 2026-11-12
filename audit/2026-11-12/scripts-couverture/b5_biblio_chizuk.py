import json,re,collections
RAW='android/app/src/main/res/raw/'
def ne(x): return isinstance(x,str) and x.strip()!=''
heb=re.compile(r'[֐-׿]')
d=json.load(open(RAW+'bibliotheque.json'))
print('meta',{k:(v if isinstance(v,str) else '...') for k,v in d['_meta'].items()})
c=collections.Counter(); keys=collections.defaultdict(collections.Counter)
for s in d['sections']:
    c['sections']+=1
    for l in('he','fr','en'):
        if ne(s['titre'].get(l)): c['sec_titre_'+l]+=1
    for ss in s['sous_sections']:
        c['sous_sections']+=1
        for l in('he','fr','en'):
            if ne(ss['titre'].get(l)): c['ss_titre_'+l]+=1
        for e in ss['entrees']:
            ty=e.get('type')
            c['entrees_'+str(ty)]+=1
            for k,v in e.items(): keys[ty][k]+=1
for ty,k in keys.items(): print(ty,dict(k))
print(dict(c))
# detail per field
c=collections.Counter()
ex={}
for s in d['sections']:
    for ss in s['sous_sections']:
        for e in ss['entrees']:
            ty=e['type']
            ex.setdefault(ty,e)
            for k,v in e.items():
                if isinstance(v,dict) and set(v.keys())&{'he','fr','en'}:
                    c[(ty,k,'n')]+=1
                    for l in('he','fr','en'):
                        if ne(v.get(l)) or (isinstance(v.get(l),list) and v.get(l)): c[(ty,k,l)]+=1
                elif isinstance(v,list) and k.startswith('paragraphes'):
                    c[(ty,k,'n')]+=len(v); c[(ty,k,'nonvide')]+=sum(1 for x in v if ne(x))
                elif isinstance(v,str):
                    c[(ty,k,'n')]+=1
                    if heb.search(v): c[(ty,k,'heb')]+=1
                    elif re.search('[A-Za-z]',v): c[(ty,k,'latin')]+=1
for k in sorted(c, key=str): print(k,c[k])
for ty,e in ex.items():
    print('--- exemple',ty); print(json.dumps(e,ensure_ascii=False,indent=1)[:2200])
