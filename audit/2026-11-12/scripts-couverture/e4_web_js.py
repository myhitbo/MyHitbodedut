import re,glob,os,sys,collections
W='web/src/js/'
heb=re.compile(r'[֐-׿]')
def strip(src):
    out=[];i=0;n=len(src);lits=[];line=1
    while i<n:
        ch=src[i]
        if src.startswith('/*',i):
            j=src.find('*/',i+2); j=n if j<0 else j+2
            line+=src[i:j].count('\n'); i=j
        elif src.startswith('//',i) and (i==0 or src[i-1]!=':'):
            j=src.find('\n',i); j=n if j<0 else j; i=j
        elif ch in '"\'`':
            q=ch;j=i+1
            while j<n and src[j]!=q:
                if src[j]=='\\': j+=1
                j+=1
            s=src[i+1:j]
            lits.append((line,s)); line+=s.count('\n'); i=j+1
        else:
            if ch=='\n': line+=1
            i+=1
    return lits
res={}
for f in sorted(glob.glob(W+'*.js')):
    src=open(f,encoding='utf-8').read()
    l=[]
    for ln,s in strip(src):
        t=re.sub(r'\$\{[^}]*\}','',s)
        t2=re.sub(r'<[^>]+>',' ',t)
        words=re.findall(r"[A-Za-zÀ-ÿ’']{3,}",t2)
        nat = heb.search(t2) or re.search(r'[àâçéèêëîïôùûœÉÀ]',t2) or (len(words)>=3 and ' ' in t2.strip() and not re.search(r'[{};=<>]|^\s*(import|export)|class=|\.js$',t2))
        if nat: l.append((ln,s))
    res[os.path.basename(f)]=l
if len(sys.argv)<2:
    for f,l in res.items(): print(len(l),f)
else:
    for f in sys.argv[1:]:
        for ln,s in res[f]: print(f,ln,repr(s)[:240])
