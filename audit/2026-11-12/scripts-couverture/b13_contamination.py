import json,glob,os,re,collections
RAW='android/app/src/main/res/raw/'
fr_in_en=re.compile(r"\b(Hachem|Chabbat|Moché|Rabbénou|Techouva|téchouva|Tsadik|tsaddik|hitbodedout|Roch Hachana|’Hanouka|Pessa’h|Soukkot|Chavouot|Chema|Tikoun|Choul’han|Michna|Guemara|Avraham|Its’hak|Ya’akov|Yaakov|Chlomo|Chmouel|l’Éternel|Éternel|béni soit|Saint, béni)\b")
en_in_fr=re.compile(r"\b(Hashem|Shabbat|Moshe|Rabbeinu|Teshuvah|Tzaddik|hitbodedut|Rosh Hashanah|Chanukah|Pesach|Sukkot|Shavuot|Shema|Tikkun|Shulchan|Mishnah|Gemara|Yitzchak|Shlomo|Shmuel|the LORD|blessed be He|Holy One)\b")
frw=re.compile(r"\b(le|la|les|des|une|est|dans|pour|qui|que|avec|sur|pas|ne|il|elle|nous|vous|ce|cette|son|ses|aux|du|et)\b",re.I)
enw=re.compile(r"\b(the|of|and|is|in|for|who|that|with|on|not|he|she|we|you|this|his|its|to|are|was)\b",re.I)
def scan(name,pairs):
    c=collections.Counter(); ex=collections.defaultdict(list)
    for key,fr,en in pairs:
        if en:
            m=fr_in_en.findall(en)
            if m: c['EN contient graphie FR']+=1; ex['EN contient graphie FR'].append((key,m[:3],en[:100]))
            f=len(frw.findall(en)); e=len(enw.findall(en)); 
            if f>e and f>=4: c['EN écrit en français ?']+=1; ex['EN écrit en français ?'].append((key,en[:120]))
        if fr:
            m=en_in_fr.findall(fr)
            if m: c['FR contient graphie EN']+=1; ex['FR contient graphie EN'].append((key,m[:3],fr[:100]))
            f=len(frw.findall(fr)); e=len(enw.findall(fr));
            if e>f and e>=4: c['FR écrit en anglais ?']+=1; ex['FR écrit en anglais ?'].append((key,fr[:120]))
    print(name,dict(c))
    for k,v in ex.items():
        for x in v[:6]: print('    ',k,x)
for f in sorted(glob.glob(RAW+'livre_*.json')):
    tx=json.load(open(f))['textes'][0]
    pairs=[((si,bi),b.get('fr'),b.get('en')) for si,s in enumerate(tx['sections']) for bi,b in enumerate(s['blocs']) if 't' in b]
    pairs+=[((si,'titre'),s.get('titre_fr'),s.get('titre_en')) for si,s in enumerate(tx['sections'])]
    scan(tx['id'],pairs)
d=json.load(open(RAW+'chizuk.json'))
scan('chizuk',[(it['id'],it['fr'],it['en']) for it in d['items']])
b=json.load(open(RAW+'bibliotheque.json'))
pairs=[]
for s in b['sections']:
    for ss in s['sous_sections']:
        for e in ss['entrees']:
            if e['type']=='source':
                for i,(f_,e_) in enumerate(zip(e['paragraphes_fr'],e['paragraphes_en'])): pairs.append(((e['id'],i),f_,e_))
            else: pairs.append((e['id'],e['resume_fr'],e['resume_en']))
scan('bibliotheque',pairs)
t=json.load(open(RAW+'tikkun_haklali.json'))
pairs=[]
for k in('ouverture','cloture','kavana','priere_rabbi_nathan'):
    for i,(f_,e_) in enumerate(zip(t[k]['paragraphes_fr'],t[k]['paragraphes_en'])): pairs.append(((k,i),f_,e_))
scan('tikkun liturgie',pairs)
g=json.load(open(RAW+'guide_sujets.json'))
scan('guide_sujets',[((s,k),v['fr'],v['en']) for s,t_ in g['sujets'].items() for k,v in t_.items()])
