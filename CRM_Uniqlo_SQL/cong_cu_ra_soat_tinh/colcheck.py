import re,glob
src={f:open(f,encoding='utf-8-sig').read() for f in sorted(glob.glob('*.sql'))}
def strip(s):
    s=re.sub(r'/\*.*?\*/','',s,flags=re.S); s=re.sub(r'--[^\n]*','',s)
    return re.sub(r"N?'(?:[^']|'')*'","''",s)
T={}
t=strip(src['02_TaoBang.sql'])
for m in re.finditer(r'CREATE TABLE\s+(\w+)\.(\w+)\s*\((.*?)\n\);',t,flags=re.S):
    cs=set()
    for line in m.group(3).split('\n'):
        mm=re.match(r'\s*(\w+)\s+(INT|BIGINT|VARCHAR|NVARCHAR|CHAR|DATE|DATETIME2|DECIMAL|TINYINT|SMALLINT|BIT|AS)\b',line)
        if mm and mm.group(1)!='CONSTRAINT': cs.add(mm.group(1))
    T[f"{m.group(1)}.{m.group(2)}".lower()]=cs
# views: parse select list output names
V={}
alltxt={f:strip(s) for f,s in src.items()}
for f,s in alltxt.items():
    for m in re.finditer(r'CREATE OR ALTER VIEW\s+(\w+\.\w+)\s+AS\s+(.*?)(?=\nGO|\Z)',s,flags=re.S):
        body=m.group(2)
        # final select list = text between last top-level SELECT before FROM ... crude: take from the SELECT that precedes the main FROM
        sel=re.findall(r'SELECT\s+(.*?)\s+FROM\s',body,flags=re.S)
        names=set()
        for part in sel:
            depth=0;cur='';items=[]
            for ch in part:
                if ch=='(':depth+=1
                if ch==')':depth-=1
                if ch==',' and depth==0: items.append(cur);cur=''
                else: cur+=ch
            items.append(cur)
            for it in items:
                it=it.strip()
                mm=re.search(r'\bAS\s+(\w+)\s*$',it)
                if mm: names.add(mm.group(1)); continue
                mm=re.search(r'(\w+)\s*$',it)
                if mm: names.add(mm.group(1))
        V[m.group(1).lower()]=names
OBJ={**T,**V}
kw={'on','where','join','left','inner','cross','outer','with','group','order','set','output','into','values','select','union','as','and','or','when','then','pivot','apply','option'}
problems=[]
for f,s in alltxt.items():
    for chunk in s.split(';'):
        binds={}
        for m in re.finditer(r'\b((?:crm|api_ql|api_admin|api_chung|audit)\.\w+)\s+(?:AS\s+)?(\w+)(?:\s+WITH\s*\(\w+(?:,\s*\w+)*\))?',chunk):
            obj,al=m.group(1).lower(),m.group(2)
            if al.lower() in kw: continue
            binds.setdefault(al,[]).append(obj)
        for m in re.finditer(r'\b(\w+)\.(\w+)\b',chunk):
            a,c=m.groups()
            if a in binds:
                ok=False;known=False
                for o in binds[a]:
                    if o in OBJ:
                        known=True
                        if c in OBJ[o]: ok=True
                if known and not ok: problems.append((f,a,c,binds[a]))
for p in sorted(set((x[0],x[1],x[2],tuple(x[3])) for x in problems)): print(p)
print("views parsed:",len(V),"tables:",len(T))
# INSERT column lists and UPDATE SET targets
for f,s in alltxt.items():
    for m in re.finditer(r'INSERT\s+(?:INTO\s+)?((?:crm|audit)\.\w+)\s*\(([^)]*)\)',s):
        o=m.group(1).lower()
        for c in [x.strip() for x in m.group(2).split(',')]:
            if c and c not in T.get(o,{c}): print("INSERT",f,o,c)
    for m in re.finditer(r'UPDATE\s+((?:crm|audit)\.\w+)\s+SET\s+(.*?)(?:\bWHERE\b|\bOUTPUT\b|;)',s,flags=re.S):
        o=m.group(1).lower()
        for mm in re.finditer(r'(?:^|,)\s*(\w+)\s*=',m.group(2)):
            if mm.group(1) not in T.get(o,{mm.group(1)}): print("UPDATE",f,o,mm.group(1))
print("insert/update check done")
