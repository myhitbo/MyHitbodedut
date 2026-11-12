import json,os,hashlib,glob,collections
RAW='android/app/src/main/res/raw/'
WEB='../myhitbodedut-web/data/'
def ne(x): return isinstance(x,str) and x.strip()!=''
def J(p): return json.load(open(p,encoding='utf-8'))
for f in sorted(os.listdir(WEB+'livres')):
    w=J(WEB+'livres/'+f)
    if f=='table.json':
        r=J(RAW+'livres_titres.json')
        print('table.json', type(w).__name__, (list(w.keys()) if isinstance(w,dict) else len(w)), 'identique à livres_titres:', w==r)
        if w!=r: print('   ',json.dumps(w,ensure_ascii=False)[:500])
        continue
    r=J(RAW+'livre_'+f)
    same=(w==r)
    # count
    def cnt(d):
        c=collections.Counter()
        txs=d['textes'] if isinstance(d,dict) and 'textes' in d else [d]
        for tx in txs:
            for s in tx.get('sections',[]):
                c['sec']+=1
                if ne(s.get('titre_fr')): c['sec_fr']+=1
                for b in s['blocs']:
                    if 't' in b:
                        c['t']+=1
                        if ne(b.get('fr')): c['fr']+=1
                        if ne(b.get('en')): c['en']+=1
                    else: c['c']+=1
        return dict(c)
    print(f, 'JSON identique=',same, 'octets', os.path.getsize(WEB+'livres/'+f), os.path.getsize(RAW+'livre_'+f), '' if same else (cnt(w),cnt(r), list(w.keys()) if isinstance(w,dict) else ''))
# bios
b=J(RAW+'hilloulot_bios.json')
tot=0;diff=0
allw={}
for f in os.listdir(WEB+'hilloulot_bios'):
    allw.update(J(WEB+'hilloulot_bios/'+f))
print('bios: clés web',len(allw),'clés raw',len(b),'identique',allw==b)
if allw!=b:
    k=[x for x in b if b[x]!=allw.get(x)]
    print('diff keys',len(k),k[:5]); print(json.dumps(J(WEB+'hilloulot_bios/1.json'),ensure_ascii=False)[:300])
