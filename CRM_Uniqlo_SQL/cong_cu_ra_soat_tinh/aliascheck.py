"""Kiểm tra alias.cot: alias trỏ tới bảng/view đã biết thì cột phải tồn tại.
Kiểm tra dữ liệu INSERT ... VALUES trong 07/08: độ dài chuỗi, NOT NULL, CHECK IN (...).
Chạy trong thư mục sql:  python3 ../gen/aliascheck.py
"""
import re, glob

def strip(s):
    s = re.sub(r'/\*.*?\*/', ' ', s, flags=re.S)
    return re.sub(r'--[^\n]*', ' ', s)
def nostr(s):
    return re.sub(r"N?'(?:[^']|'')*'", "''", s)

FILES = sorted(f for f in glob.glob('*.sql') if not f.startswith('00_'))
src = {f: open(f, encoding='utf-8-sig').read() for f in FILES}

# ---- cột bảng (kèm kiểu) ----
T = {}
t02 = strip(src['02_TaoBang.sql'])
for m in re.finditer(r'CREATE TABLE\s+(\w+\.\w+)\s*\((.*?)\n\);', t02, flags=re.S):
    cols = {}
    for line in m.group(2).split('\n'):
        mm = re.match(r'\s*(\w+)\s+(INT|BIGINT|VARCHAR|NVARCHAR|CHAR|NCHAR|DATE|DATETIME2|DECIMAL|TINYINT|SMALLINT|BIT|AS)\b(?:\s*\((\d+|MAX)(?:,\s*\d+)?\))?(.*)', line, re.I)
        if mm and mm.group(1).upper() != 'CONSTRAINT':
            cols[mm.group(1).lower()] = (mm.group(2).upper(), mm.group(3), 'NOT NULL' in mm.group(4).upper(), 'IDENTITY' in mm.group(4).upper() or 'DEFAULT' in mm.group(4).upper() or mm.group(2).upper() == 'AS')
    T[m.group(1).lower()] = cols
# kiểu bảng TVP
for f, s in src.items():
    for m in re.finditer(r'CREATE TYPE\s+(\w+\.\w+)\s+AS\s+TABLE\s*\((.*?)\)\s*;?\s*\'\s*\)', s, flags=re.S | re.I):
        pass

# ---- cột view: lấy qua alias cuối "AS Ten" hoặc t.Cot trong danh sách SELECT đầu tiên ----
def split_top(s):
    out, depth, cur = [], 0, ''
    for ch in s:
        if ch == '(': depth += 1
        if ch == ')': depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur); cur = ''
        else:
            cur += ch
    out.append(cur)
    return out
V = {}
for f, s in src.items():
    ss = nostr(strip(s))
    for m in re.finditer(r'CREATE\s+OR\s+ALTER\s+VIEW\s+(\w+\.\w+)(?:\s+WITH\s+\w+)?\s+AS\s+(.*?)(?=\bGO\b|\Z)', ss, flags=re.S | re.I):
        body = m.group(2)
        # bỏ CTE
        body2 = re.sub(r'^\s*WITH\s+.*?\)\s*(?=SELECT)', '', body, flags=re.S | re.I)
        sm = re.match(r'\s*SELECT\s+(?:DISTINCT\s+)?(?:TOP\s*\(?\d+\)?\s+)?(.*)', body2, flags=re.S | re.I)
        if not sm: continue
        # tìm FROM cấp ngoài cùng
        txt, depth, end = sm.group(1), 0, None
        for i, ch in enumerate(txt):
            if ch == '(': depth += 1
            elif ch == ')': depth -= 1
            elif depth == 0 and re.match(r'\bFROM\b', txt[i:i+5], re.I) and (i == 0 or not txt[i-1].isalnum()):
                end = i; break
        sel = txt[:end] if end else txt
        names = set()
        for it in split_top(sel):
            it = it.strip()
            a = re.search(r'\bAS\s+\[?(\w+)\]?\s*$', it, re.I)
            if a: names.add(a.group(1).lower()); continue
            b = re.search(r'(?:\w+\.)?(\w+)\s*$', it)
            if b: names.add(b.group(1).lower())
            if it.endswith('*'): names.add('*')
        V[m.group(1).lower()] = names

KW = set('''on where join inner left right full cross outer apply group order having union select set values
output when then else end as with and or not into from by for option cross pivot unpivot top distinct
merge using matched target source exists case'''.split())
problems = []
for f, s in src.items():
    ss = nostr(strip(s))
    for bi, b in enumerate(re.split(r'(?im)^\s*GO\s*$', ss), 1):
        alias = {}
        for m in re.finditer(r'\b(?:FROM|JOIN|UPDATE|INTO|USING|APPLY)\s+(\w+\.\w+)(?:\s+(?:AS\s+)?(\w+))?', b, re.I):
            obj = m.group(1).lower(); a = (m.group(2) or '').lower()
            alias[obj.split('.')[1]] = obj
            if a and a not in KW: alias[a] = obj
        for m in re.finditer(r'\b(\w+)\.(\w+)\b', b):
            a, c = m.group(1).lower(), m.group(2).lower()
            if a not in alias: continue
            obj = alias[a]
            if a in ('crm', 'sec', 'audit', 'api_chung', 'api_kh', 'api_ql', 'api_admin', 'sys', 'dbo'): continue
            cols = T.get(obj) or (V.get(obj) and {k: None for k in V[obj]})
            if not cols or '*' in cols: continue
            if c not in cols:
                problems.append((f, bi, f'{a}.{m.group(2)}: cột không có trong {obj}'))

# ---- kiểm tra dữ liệu INSERT VALUES ----
def parse_values(txt):
    rows, i, n = [], 0, len(txt)
    while i < n:
        if txt[i] == '(':
            depth, j, cur, vals, instr = 1, i + 1, '', [], False
            while j < n and depth:
                ch = txt[j]
                if instr:
                    cur += ch
                    if ch == "'":
                        if txt[j+1:j+2] == "'": cur += "'"; j += 1
                        else: instr = False
                elif ch == "'": instr = True; cur += ch
                elif ch == '(': depth += 1; cur += ch
                elif ch == ')':
                    depth -= 1
                    if depth: cur += ch
                elif ch == ',' and depth == 1: vals.append(cur.strip()); cur = ''
                else: cur += ch
                j += 1
            vals.append(cur.strip()); rows.append(vals); i = j
        elif txt[i] == ';' or txt[i:i+6].upper() in ('INSERT', 'SELECT', 'UPDATE', 'DECLAR') :
            break
        else:
            i += 1
    return rows
checks = {}
for m in re.finditer(r'CONSTRAINT\s+\w+\s+CHECK\s*\(\s*(\w+)\s+IN\s*\(([^)]*)\)\s*\)', t02, re.I):
    pass
# gắn CHECK IN đơn giản vào bảng
for m in re.finditer(r'CREATE TABLE\s+(\w+\.\w+)\s*\((.*?)\n\);', strip(src['02_TaoBang.sql']), flags=re.S):
    for c in re.finditer(r'CHECK\s*\(\s*(\w+)\s+IN\s*\(([^)]*)\)\s*\)', m.group(2), re.I):
        checks[(m.group(1).lower(), c.group(1).lower())] = set(x.strip().strip("N").strip("'") for x in c.group(2).split(','))
nrows = 0
for f in ['07_DuLieuHeThong.sql', '08_DuLieuMau.sql']:
    s = strip(src[f])
    for m in re.finditer(r'INSERT\s+(?:INTO\s+)?(\w+\.\w+)\s*\(([^)]*)\)\s*VALUES\s*', s, re.I):
        obj = m.group(1).lower(); cols = [c.strip().lower() for c in m.group(2).split(',')]
        if obj not in T: continue
        for r in parse_values(s[m.end():]):
            nrows += 1
            if len(r) != len(cols):
                problems.append((f, 0, f'{obj}: số giá trị {len(r)} ≠ số cột {len(cols)}: {r[:3]}')); continue
            for c, v in zip(cols, r):
                if c not in T[obj]:
                    problems.append((f, 0, f'{obj}: cột {c} không tồn tại')); continue
                typ, ln, nn, _ = T[obj][c]
                sv = re.fullmatch(r"N?'((?:[^']|'')*)'", v)
                if v.upper() == 'NULL' and nn:
                    problems.append((f, 0, f'{obj}.{c}: NULL vào cột NOT NULL'))
                if sv and ln and ln != 'MAX' and len(sv.group(1).replace("''", "'")) > int(ln) and typ in ('VARCHAR', 'NVARCHAR', 'CHAR', 'NCHAR'):
                    problems.append((f, 0, f'{obj}.{c}: chuỗi dài {len(sv.group(1))} > {ln}: {sv.group(1)[:40]}'))
                if sv and typ in ('VARCHAR', 'CHAR') and re.search(r'[^\x00-\x7f]', sv.group(1)):
                    problems.append((f, 0, f'{obj}.{c}: ký tự Unicode trong cột {typ}: {sv.group(1)[:40]}'))
                if sv and (obj, c) in checks and sv.group(1) not in checks[(obj, c)]:
                    problems.append((f, 0, f'{obj}.{c}: giá trị {sv.group(1)} ngoài CHECK {sorted(checks[(obj, c)])}'))
            missing = [c for c, (typ, ln, nn, hasdef) in T[obj].items() if nn and not hasdef and c not in cols]
            if missing:
                problems.append((f, 0, f'{obj}: thiếu cột NOT NULL không có DEFAULT: {missing}'))
print('bảng:', len(T), 'view:', len(V), 'dòng VALUES kiểm tra:', nrows)
seen = set()
for p in problems:
    if p in seen: continue
    seen.add(p); print(p)
print('Số vấn đề:', len(seen))
