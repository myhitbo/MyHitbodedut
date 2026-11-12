import json,os
RAW='android/app/src/main/res/raw/'
WEB='../myhitbodedut-web/data/'
def J(p): return json.load(open(p,encoding='utf-8'))
ok=0
for f in sorted(os.listdir(WEB+'livres')):
    if f=='table.json': continue
    w=J(WEB+'livres/'+f); r=J(RAW+'livre_'+f)
    same = w['sections']==r['textes'][0]['sections'] and w['id']==r['textes'][0]['id']
    ok+=same
    print(f,'sections identiques:',same)
t=J(WEB+'livres/table.json'); r=J(RAW+'livres_titres.json')
print('table groupes ==',t['groupes']==r['groupes'])
for a,b in zip(t['textes'],r['textes']):
    d={k:(a.get(k),b.get(k)) for k in set(a)|set(b) if a.get(k)!=b.get(k)}
    print(a['id'], {k:(str(v[0])[:80],str(v[1])[:80]) for k,v in d.items()})
