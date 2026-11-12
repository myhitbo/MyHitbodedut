import json,glob,os,re,collections,unicodedata
RAW='android/app/src/main/res/raw/'
heb=re.compile(r'[א-ת]')
def nonik(s): return re.sub(r'[֑-ׇ]','',re.sub(r'<[^>]+>','',s))
FR=set("le la les des une un du et pour avec sans dans sur est qui que ne pas il elle son sa ses ce cette au aux par plus car mais ou où se comme lui leur".split())
EN=set("the of and to in is that for with he his it as not be by this from which who was are on one all but they will shall their him".split())
def lang(s):
    w=re.findall(r"[a-zà-ÿ]+",s.lower())
    f=sum(1 for x in w if x in FR); e=sum(1 for x in w if x in EN)
    return f,e,len(w)
out=collections.defaultdict(list)
stats=collections.Counter()
for f in sorted(glob.glob(RAW+'livre_*.json')):
    d=json.load(open(f))
    tx=d['textes'][0]; lid=tx['id']
    seen_fr=collections.defaultdict(list)
    for si,s in enumerate(tx['sections']):
        for k,l in (('titre_fr','fr'),('titre_en','en')):
            v=s.get(k)
            if v:
                if heb.search(v): out['titre_'+l+'_avec_hebreu'].append((lid,si,v[:80]))
        if s.get('titre_fr') and s.get('titre_fr')==s.get('titre_en'): stats[(lid,'titre fr==en')]+=1
        for bi,b in enumerate(s['blocs']):
            if 't' not in b: continue
            he=nonik(b['t']); nh=len(heb.findall(he))
            fr=(b.get('fr') or '').strip(); en=(b.get('en') or '').strip()
            if not fr and not en: continue
            stats[(lid,'traduits')]+=1
            if fr==en: out['fr==en'].append((lid,si,bi,fr[:80]))
            for l,v in (('fr',fr),('en',en)):
                hh=len(heb.findall(v)); 
                if len(v) and hh/len(v)>0.3: out[l+'_majoritairement_hebreu'].append((lid,si,bi,v[:80]))
                elif hh>0: stats[(lid,l+' contient des lettres hébraïques')]+=1
                if nh>=40:
                    r=len(v)/nh
                    if r<0.9: out[l+'_trop_court'].append((lid,si,bi,round(r,2),nh,len(v),v[:70]))
                    if r>6: out[l+'_trop_long'].append((lid,si,bi,round(r,2),nh,len(v),v[:70]))
                if re.search(r'TODO|XXX|\[\.\.\.\]|lorem|traduction (manquante|indisponible)|translation (missing|unavailable)|\?\?\?',v,re.I): out[l+'_placeholder'].append((lid,si,bi,v[:80]))
                if '<' in v or '>' in v: stats[(lid,l+' contient des balises')]+=1
            f_,e_,n_=lang(fr)
            if n_>=8 and e_>f_: out['fr_semble_anglais'].append((lid,si,bi,fr[:90]))
            f_,e_,n_=lang(en)
            if n_>=8 and f_>e_: out['en_semble_francais'].append((lid,si,bi,en[:90]))
            if len(fr)>60: seen_fr[fr].append((si,bi))
    dup=[(k[:60],v) for k,v in seen_fr.items() if len(v)>1]
    stats[(lid,'fr dupliqués (>60 car.)')]=len(dup)
    if dup: out['dup_'+lid]=dup[:5]
for k,v in sorted(stats.items()): print(k,v)
for k,v in out.items():
    print('==',k,len(v))
    for x in v[:8]: print('   ',x)
json.dump({k:v for k,v in out.items()},open('/tmp/heuristiques_livres.json','w'),ensure_ascii=False,indent=0)
