import xml.etree.ElementTree as ET, re, json
R='android/app/src/main/res/'
def load(p):
    t=ET.parse(p).getroot(); d={}
    for e in t:
        if e.tag=='string': d[e.get('name')]=[''.join(e.itertext())]
        elif e.tag=='plurals': d[e.get('name')]=[''.join(i.itertext()) for i in e]
        elif 'array' in e.tag: d[e.get('name')]=[''.join(i.itertext()) for i in e]
    return d
fr=load(R+'values/strings.xml'); en=load(R+'values-en/strings.xml'); he=load(R+'values-iw/strings.xml')
ph=re.compile(r'%(\d+\$)?[sd]')
def phs(vs): return set(m.group(0) for v in vs for m in ph.finditer(v))
for n,d in (('en',en),('he',he)):
    print('==',n)
    for k,v in d.items():
        a=phs(fr[k]); b=phs(v)
        if a!=b: print('  placeholder mismatch',k,sorted(a),sorted(b))
# empty values
for n,d in (('fr',fr),('en',en),('he',he)):
    e=[k for k,v in d.items() if any(not x.strip() for x in v)]
    print(n,'empty',e)
# fr words in en : heuristics
frw=re.compile(r"\b(le|la|les|des|une|du|et|pour|avec|sans|dans|sur|est|vous|votre|vos|pas|plus|jour|jours|heure|heures|semaine|prière|aujourd|hier|demain|séance|réglages|fête|lune|matin|soir|nuit)\b",re.I)
print('== en values with french-looking words')
for k,v in en.items():
    for x in v:
        m=frw.findall(x)
        if m: print('  ',k,m,'|',x[:150])
# length ratio
print('== en much shorter than fr (ratio<0.5, len fr>40)')
for k,v in en.items():
    a=sum(len(x) for x in fr[k]); b=sum(len(x) for x in v)
    if a>40 and b<0.5*a: print('  ',k,a,b)
print('== he much shorter than fr (ratio<0.4, len fr>40)')
for k,v in he.items():
    a=sum(len(x) for x in fr[k]); b=sum(len(x) for x in v)
    if a>40 and b<0.4*a: print('  ',k,a,b, v[0][:100])
