import xml.etree.ElementTree as ET, re, json, sys
R='android/app/src/main/res/'
def load(p):
    t=ET.parse(p).getroot()
    d={}
    for e in t:
        if e.tag=='string':
            d[('string',e.get('name'))]=(''.join(e.itertext()), e.get('translatable'))
        elif e.tag=='plurals':
            d[('plurals',e.get('name'))]=({i.get('quantity'):''.join(i.itertext()) for i in e}, e.get('translatable'))
        elif e.tag in('string-array','array','integer-array'):
            d[(e.tag,e.get('name'))]=([''.join(i.itertext()) for i in e], e.get('translatable'))
        else:
            d[(e.tag,e.get('name'))]=(''.join(e.itertext()), e.get('translatable'))
    return d
fr=load(R+'values/strings.xml'); en=load(R+'values-en/strings.xml'); he=load(R+'values-iw/strings.xml')
from collections import Counter
for n,d in (('fr',fr),('en',en),('he',he)):
    print(n, len(d), Counter(k[0] for k in d))
nt=[k for k,v in fr.items() if v[1]=='false']
print('translatable=false in fr:',len(nt))
for k in nt: print('   ',k, repr(fr[k][0])[:150])
tr=[k for k in fr if fr[k][1]!='false']
print('translatable fr:',len(tr))
for n,d in (('en',en),('he',he)):
    miss=[k for k in tr if k not in d]
    extra=[k for k in d if k not in fr]
    ntin=[k for k in nt if k in d]
    print(n,'missing',len(miss),miss)
    print(n,'extra',len(extra),extra)
    print(n,'non-translatable present',ntin)
# identical values
def norm(v): return json.dumps(v,ensure_ascii=False,sort_keys=True)
for n,d in (('en',en),('he',he)):
    same=[k for k in tr if k in d and norm(d[k][0])==norm(fr[k][0])]
    print('\n== identical to fr in',n,len(same))
    for k in same: print('   ',k[1],'=',repr(fr[k][0])[:140])
# plurals quantities
print('\n== plurals')
for k in fr:
    if k[0]=='plurals':
        print(k[1],'fr',sorted(fr[k][0]),'en',sorted(en[k][0]) if k in en else None,'he',sorted(he[k][0]) if k in he else None)
print('\n== arrays')
for k in fr:
    if 'array' in k[0]:
        print(k, len(fr[k][0]), len(en[k][0]) if k in en else None, len(he[k][0]) if k in he else None)
# Latin letters in he values / Hebrew in fr? French-looking words in en
heb=re.compile(r'[֐-׿]')
lat=re.compile(r'[A-Za-zÀ-ÿ]{3,}')
print('\n== he values with no Hebrew letters at all')
c=0
for k in tr:
    if k in he:
        v=norm(he[k][0])
        if not heb.search(v):
            c+=1; print('   ',k[1],'=',v[:120])
print(c)
print('\n== he values containing latin words (>=3 letters)')
c=0
for k in tr:
    if k in he:
        v=norm(he[k][0])
        w=[x for x in lat.findall(re.sub(r'%\d+\$[sd]','',v)) if x not in('one','other','two','many','zero','few')]
        if w and heb.search(v):
            c+=1; print('   ',k[1],'=',v[:160])
print(c)
print('\n== en values containing accented french chars')
acc=re.compile(r'[àâçéèêëîïôùûüœÀÉÈÊ]')
c=0
for k in tr:
    if k in en:
        v=norm(en[k][0])
        if acc.search(v):
            c+=1; print('   ',k[1],'=',v[:160])
print(c)
print('\n== en values containing Hebrew letters')
c=0
for k in tr:
    if k in en:
        v=norm(en[k][0])
        if heb.search(v):
            c+=1; print('   ',k[1],'=',v[:160])
print(c)
print('\n== fr values containing Hebrew letters')
c=0
for k in tr:
    v=norm(fr[k][0])
    if heb.search(v):
        c+=1; print('   ',k[1],'=',v[:160])
print(c)
