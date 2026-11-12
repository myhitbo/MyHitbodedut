import xml.etree.ElementTree as ET, sys, re, json
R='android/app/src/main/res/'
def load(p):
    t=ET.parse(p); root=t.getroot()
    d={}
    for e in root:
        name=e.get('name')
        if e.tag=='string':
            txt=''.join(e.itertext())
            d[name]=('string',txt,e.get('translatable'))
        elif e.tag=='plurals':
            d[name]=('plurals',{i.get('quantity'):''.join(i.itertext()) for i in e},e.get('translatable'))
        elif e.tag=='string-array':
            d[name]=('array',[''.join(i.itertext()) for i in e],e.get('translatable'))
        else:
            d[name]=(e.tag,''.join(e.itertext()),e.get('translatable'))
    return d
fr=load(R+'values/strings.xml'); en=load(R+'values-en/strings.xml'); he=load(R+'values-iw/strings.xml')
from collections import Counter
for n,d in (('fr',fr),('en',en),('he',he)):
    print(n,len(d),Counter(v[0] for v in d.values()))
nt=[k for k,v in fr.items() if v[2]=='false']
print('translatable=false',len(nt))
for k in nt: print('  ',k,'=',repr(fr[k][1])[:120])
tr=[k for k in fr if fr[k][2]!='false']
print('translatable fr',len(tr))
me=[k for k in tr if k not in en]; mh=[k for k in tr if k not in he]
print('missing en',len(me),me)
print('missing he',len(mh),mh)
print('extra en',[k for k in en if k not in fr])
print('extra he',[k for k in he if k not in fr])
print('nontranslatable present in en',[k for k in nt if k in en])
print('nontranslatable present in he',[k for k in nt if k in he])
# identical
ie=[k for k in tr if k in en and en[k][1]==fr[k][1]]
ih=[k for k in tr if k in he and he[k][1]==fr[k][1]]
print('identical en==fr',len(ie))
for k in ie: print('  ',k,'=',repr(fr[k][1])[:100])
print('identical he==fr',len(ih))
for k in ih: print('  ',k,'=',repr(fr[k][1])[:100])
# he values with no hebrew letters
heb=re.compile(r'[֐-׿]')
nh=[k for k in tr if k in he and he[k][0]=='string' and not heb.search(he[k][1])]
print('he without hebrew letters',len(nh))
for k in nh: print('  ',k,'=',repr(he[k][1])[:100])
# he values containing latin words
lat=re.compile(r'[A-Za-zÀ-ÿ]{3,}')
hl=[k for k in tr if k in he and he[k][0]=='string' and heb.search(he[k][1]) and lat.search(re.sub(r'%\d*\$?[sd]','',he[k][1]))]
print('he with latin words',len(hl))
for k in hl: print('  ',k,'=',repr(he[k][1])[:160])
# en values containing hebrew letters
eh=[k for k in tr if k in en and en[k][0]=='string' and heb.search(en[k][1])]
print('en with hebrew letters',len(eh))
for k in eh: print('  ',k,'=',repr(en[k][1])[:160])
fh=[k for k in tr if fr[k][0]=='string' and heb.search(fr[k][1])]
print('fr with hebrew letters',len(fh))
for k in fh: print('  ',k,'=',repr(fr[k][1])[:160])
# french accents in en
fa=re.compile(r'[éèêàùçôîû]')
ef=[k for k in tr if k in en and en[k][0]=='string' and fa.search(en[k][1])]
print('en with french accents',len(ef))
for k in ef: print('  ',k,'=',repr(en[k][1])[:160])
# plurals/arrays
for k,v in fr.items():
    if v[0]!='string':
        print(v[0],k, 'fr',(list(v[1].keys()) if isinstance(v[1],dict) else len(v[1])),'en',(list(en[k][1].keys()) if k in en and isinstance(en[k][1],dict) else (len(en[k][1]) if k in en else None)),'he',(list(he[k][1].keys()) if k in he and isinstance(he[k][1],dict) else (len(he[k][1]) if k in he else None)))
# placeholders mismatch
ph=re.compile(r'%(?:\d+\$)?[sd]')
for k in tr:
    if fr[k][0]!='string': continue
    a=sorted(ph.findall(fr[k][1]))
    for n,d in (('en',en),('he',he)):
        if k in d and sorted(ph.findall(d[k][1]))!=a:
            print('PLACEHOLDER MISMATCH',n,k,a,sorted(ph.findall(d[k][1])))
# empty
for n,d in (('fr',fr),('en',en),('he',he)):
    print('empty',n,[k for k,v in d.items() if v[0]=='string' and not v[1].strip()])
