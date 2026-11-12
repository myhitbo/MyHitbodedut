import re,glob,os,collections,sys
K='android/app/src/main/java/com/myhitbodedut/'
heb=re.compile(r'[֐-׿]')
def strip_comments(src):
    out=[];i=0;n=len(src)
    while i<n:
        if src.startswith('/*',i):
            j=src.find('*/',i+2); j = n if j<0 else j+2
            out.append('\n'*src[i:j].count('\n')); i=j
        elif src.startswith('//',i):
            j=src.find('\n',i); j=n if j<0 else j
            i=j
        elif src.startswith('"""',i):
            j=src.find('"""',i+3); j=n if j<0 else j+3
            out.append(src[i:j]); i=j
        elif src[i]=='"':
            j=i+1
            while j<n and src[j]!='"':
                if src[j]=='\\': j+=1
                j+=1
            out.append(src[i:j+1]); i=j+1
        elif src[i]=="'":
            j=i+1
            while j<n and src[j]!="'":
                if src[j]=='\\': j+=1
                j+=1
            out.append(src[i:j+1]); i=j+1
        else:
            out.append(src[i]); i+=1
    return ''.join(out)
lit=re.compile(r'"""(.*?)"""|"((?:[^"\\]|\\.)*)"',re.S)
res=collections.defaultdict(list)
for f in sorted(glob.glob(K+'*.kt')):
    src=strip_comments(open(f,encoding='utf-8').read())
    for ln,line in enumerate(src.split('\n'),1):
        for m in lit.finditer(line):
            s=m.group(1) if m.group(1) is not None else m.group(2)
            t=re.sub(r'\$\{[^}]*\}|\$[A-Za-z_]+','',s)
            hasheb=bool(heb.search(t))
            words=re.findall(r"[A-Za-zÀ-ÿ’']{2,}",t)
            natural = hasheb or (len(words)>=2 and ' ' in t.strip()) or re.search(r'[àâçéèêëîïôùûœÉÀ]',t)
            if natural:
                res[os.path.basename(f)].append((ln,s,line.strip()[:200]))
mode=sys.argv[1] if len(sys.argv)>1 else 'count'
if mode=='count':
    for f,l in sorted(res.items(), key=lambda x:-len(x[1])): print(len(l),f)
else:
    for f in sys.argv[2:]:
        for ln,s,line in res.get(f,[]): print(f,ln,repr(s)[:230])
