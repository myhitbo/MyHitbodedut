import json,glob,re,collections,os
RAW='android/app/src/main/res/raw/'
HL=re.compile(r'[א-ת]')
def nh(s): return len(HL.findall(re.sub('<[^>]+>','',s)))
def ne(x): return isinstance(x,str) and x.strip()!=''
rows=[]  # (corpus, champ, n, fr, en, vol, vol_fr, vol_en)
def add(c,ch,n,fr,en,v=0,vf=0,ve=0): rows.append((c,ch,n,fr,en,v,vf,ve))
# livres
for f in sorted(glob.glob(RAW+'livre_*.json')):
    tx=json.load(open(f))['textes'][0]; lid=tx['id']
    n=fr=en=v=vf=ve=c=cv=0; st=sf=se=0
    for s in tx['sections']:
        st+=1; sf+=ne(s.get('titre_fr')); se+=ne(s.get('titre_en'))
        for b in s['blocs']:
            if 't' in b:
                h=nh(b['t']); n+=1; v+=h
                if ne(b.get('fr')): fr+=1; vf+=h
                if ne(b.get('en')): en+=1; ve+=h
            else: c+=1; cv+=nh(b['c'])
    add('livre:'+lid,'blocs t',n,fr,en,v,vf,ve); add('livre:'+lid,'intertitres c',c,0,0,cv,0,0); add('livre:'+lid,'titres de sections',st,sf,se)
# siddur
for nus in('edot','sefard','ashkenaz'):
    d=json.load(open(RAW+f'siddur_{nus}.json'))
    n=v=c=cv=st=0
    for tx in d['textes']:
        for s in tx['sections']:
            st+=1
            for b in s['blocs']:
                if 't' in b: n+=1; v+=nh(b['t'])
                else: c+=1; cv+=nh(b['c'])
    add('siddur:'+nus,'prières t',n,0,0,v,0,0); add('siddur:'+nus,'consignes c',c,0,0,cv,0,0); add('siddur:'+nus,'titres de sections',st,0,0)
    add('siddur:'+nus,'titres des textes',len(d['textes']),sum(ne(t['titre'].get('fr')) for t in d['textes']),sum(ne(t['titre'].get('en')) for t in d['textes']))
# tehilim
d=json.load(open(RAW+'tehilim.json'))
v=sum(nh(x) for p in d['psaumes'] for x in p); n=sum(len(p) for p in d['psaumes'])
add('tehilim','versets',n,sum(ne(x) for p in d['traductions']['fr']['psaumes'] for x in p),sum(ne(x) for p in d['traductions']['en']['psaumes'] for x in p),v,v,v)
t=json.load(open(RAW+'tikkun_haklali.json'))
vs=[x for p in t['psaumes'] for x in p['versets']]
v=sum(nh(x['he']) for x in vs); add('tikkun','versets',len(vs),sum(ne(x.get('fr')) for x in vs),sum(ne(x.get('en')) for x in vs),v,v,v)
n=v=fr=en=0
for k in('ouverture','cloture','kavana','priere_rabbi_nathan'):
    n+=len(t[k]['paragraphes']); v+=sum(nh(x) for x in t[k]['paragraphes']); fr+=sum(ne(x) for x in t[k]['paragraphes_fr']); en+=sum(ne(x) for x in t[k]['paragraphes_en'])
add('tikkun','liturgie (paragraphes)',n,fr,en,v,v,v)
b=json.load(open(RAW+'bibliotheque.json'))
n=v=fr=en=0;src=0;art=0
for s in b['sections']:
    for ss in s['sous_sections']:
        for e in ss['entrees']:
            if e['type']=='source':
                src+=1; n+=len(e['paragraphes']); v+=sum(nh(x) for x in e['paragraphes']); fr+=sum(ne(x) for x in e['paragraphes_fr']); en+=sum(ne(x) for x in e['paragraphes_en'])
            else: art+=1
add('bibliotheque','paragraphes des sources',n,fr,en,v,v,v)
c=json.load(open(RAW+'chizuk.json'))
v=sum(nh(i['he']) for i in c['items']); add('chizuk','textes',len(c['items']),sum(ne(i['fr']) for i in c['items']),sum(ne(i['en']) for i in c['items']),v,v,v)
bih=json.load(open(RAW+'ben_ish_hai.json'))
hs=[x for a in bih['annees'].values() for p in a.values() for x in p['h']]+bih['hanouka']['h']
add('ben_ish_hai','halakhot',len(hs),0,0,sum(nh(x) for x in hs),0,0)
print('BIH hanouka',len(bih['hanouka']['h']),'parachiot',sum(len(a) for a in bih['annees'].values()))
y=json.load(open(RAW+'yalkut_yosef.json'))
ys=[e for l in y['periodes'].values() for e in l]
add('yalkut_yosef (halakha du jour)','se’ifim',len(ys),0,0,sum(nh(e['t']) for e in ys),0,0)
h=json.load(open(RAW+'hilloulot.json'))
es=[e for l in h['jours'].values() for e in l]
add('hilloulot','noms',len(es),sum(ne(e.get('fr')) for e in es),sum(ne(e.get('en')) for e in es))
ds=[e['t'] for e in es if ne(e.get('t'))]
add('hilloulot','descriptions t',len(ds),0,0,sum(nh(x) for x in ds),0,0)
bb=json.load(open(RAW+'hilloulot_bios.json'))
bs=[bio[1] for l in bb.values() for e in l if e for bio in e]
add('hilloulot_bios','biographies',len(bs),0,0,sum(nh(x) for x in bs),0,0)
for r in rows: print(r)
json.dump(rows,open('/tmp/totaux.json','w'),ensure_ascii=False)
# totals "textes à lire" = rows with volume
def tot(filt):
    R=[r for r in rows if filt(r)]
    n=sum(r[2] for r in R); fr=sum(r[3] for r in R); en=sum(r[4] for r in R); v=sum(r[5] for r in R); vf=sum(r[6] for r in R); ve=sum(r[7] for r in R)
    return n,fr,en,v,vf,ve
lire=lambda r: r[5]>0
for name,f in (('tous textes à lire (3 siddourim)',lire),
               ('un seul siddour (edot)',lambda r: lire(r) and r[0] not in('siddur:sefard','siddur:ashkenaz')),
               ('hors hilloulot (un siddour)',lambda r: lire(r) and r[0] not in('siddur:sefard','siddur:ashkenaz','hilloulot','hilloulot_bios')),
               ('livres seuls',lambda r: r[0].startswith('livre:') and lire(r)),
               ('livres seuls blocs t',lambda r: r[0].startswith('livre:') and r[1]=='blocs t'),
               ('livres hors yalkut blocs t',lambda r: r[0].startswith('livre:') and r[1]=='blocs t' and 'yalkut' not in r[0]),
               ):
    n,fr,en,v,vf,ve=tot(f)
    print(f'{name}: unités {n} fr {fr} ({100*fr/n:.1f}%) en {en} ({100*en/n:.1f}%) | volume {v} fr {100*vf/v:.1f}% en {100*ve/v:.1f}%')
