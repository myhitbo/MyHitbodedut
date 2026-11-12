import json,re,collections
RAW='android/app/src/main/res/raw/'
heb=re.compile(r'[֐-׿]')
d=json.load(open(RAW+'siddur_annotations.json'))
print(json.dumps(d['_meta'],ensure_ascii=False))
import xml.etree.ElementTree as ET
fr={e.get('name') for e in ET.parse('android/app/src/main/res/values/strings.xml').getroot()}
lib=open('android/app/src/main/java/com/myhitbodedut/Libelles.kt').read()
libk=set(re.findall(r'"([a-z0-9_]+)" ->',lib))
for nus in d:
    if nus=='_meta': continue
    c=collections.Counter(); kc=collections.Counter(); libs=collections.Counter(); si=collections.Counter()
    for pri,l in d[nus].items():
        for a in l:
            c['n']+=1
            for k in a: kc[k]+=1
            if a.get('libelle'): libs[a['libelle']]+=1
            si[a.get('si')]+=1
            for k in('consigne','texte','retire'):
                if a.get(k):
                    c[k]+=1
                    if heb.search(a[k]): c[k+'_heb']+=1
    print(nus,dict(c)); print('   keys',dict(kc))
    print('   libelles distincts',len(libs),'absents de Libelles.kt',[k for k in libs if k not in libk],'absents de strings',[k for k in libs if k not in fr])
    print('   si distincts',len(si), [k for k in si if ('ajout_'+str(k)) not in libk][:40])
