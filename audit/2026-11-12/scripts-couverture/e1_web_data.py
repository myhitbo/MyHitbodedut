import json,os,hashlib,glob
RAW='android/app/src/main/res/raw/'
WEB='../myhitbodedut-web/data/'
def sha(p): return hashlib.sha256(open(p,'rb').read()).hexdigest()[:12]
def canon(p): return hashlib.sha256(json.dumps(json.load(open(p,encoding='utf-8')),ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()[:12]
webfiles=sorted(os.listdir(WEB))
print('web data:',webfiles)
rawjson=sorted(os.path.basename(f) for f in glob.glob(RAW+'*.json'))
for f in rawjson:
    w=WEB+f
    if os.path.exists(w):
        same=sha(RAW+f)==sha(w)
        csame=canon(RAW+f)==canon(w)
        print(f'{f:36} octets identiques={same}  JSON identique={csame}  tailles {os.path.getsize(RAW+f)} / {os.path.getsize(w)}')
    else:
        print(f'{f:36} ABSENT de web/data')
print('--- livres'); print(sorted(os.listdir(WEB+'livres'))[:40], len(os.listdir(WEB+'livres')))
print('--- hilloulot_bios'); l=sorted(os.listdir(WEB+'hilloulot_bios')); print(l[:10], len(l))
