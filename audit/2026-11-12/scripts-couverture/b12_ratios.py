import json,glob,os,re,collections,statistics
RAW='android/app/src/main/res/raw/'
heb=re.compile(r'[א-ת]')
def nonik(s): return re.sub(r'[֑-ׇ]','',re.sub(r'<[^>]+>','',s))
rows=[]
for f in sorted(glob.glob(RAW+'livre_*.json')):
    tx=json.load(open(f))['textes'][0]; lid=tx['id']
    for si,s in enumerate(tx['sections']):
        for bi,b in enumerate(s['blocs']):
            if 't' not in b or not b.get('fr'): continue
            nh=len(heb.findall(nonik(b['t'])))
            if nh<150: continue
            rows.append((lid,si,bi,nh,len(b['fr'])/nh,len(b['en'])/nh))
by=collections.defaultdict(list)
for r in rows: by[r[0]].append(r)
for lid,l in by.items():
    fr=[x[4] for x in l]; en=[x[5] for x in l]
    print(f'{lid:22} n={len(l):5} fr med={statistics.median(fr):.2f} min={min(fr):.2f} | en med={statistics.median(en):.2f} min={min(en):.2f}')
print('--- plus bas ratios FR (blocs >=150 lettres)')
for r in sorted(rows,key=lambda x:x[4])[:25]: print(r[0],r[1],r[2],'nh',r[3],'fr %.2f en %.2f'%(r[4],r[5]))
print('--- plus bas ratios EN')
for r in sorted(rows,key=lambda x:x[5])[:25]: print(r[0],r[1],r[2],'nh',r[3],'fr %.2f en %.2f'%(r[4],r[5]))
