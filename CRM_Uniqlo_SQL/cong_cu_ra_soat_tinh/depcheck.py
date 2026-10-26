"""Kiểm tra tĩnh thứ tự phụ thuộc và cấu trúc batch của bộ script 01–17.
Chạy trong thư mục sql:  python3 ../gen/depcheck.py
"""
import re, glob, sys

ORDER = ['01_TaoCSDL_Schema.sql', '02_TaoBang.sql', '03_ChiMuc_View.sql', '04_BaoMat_ThuTucNoiBo.sql',
         '05a_API_Chung_KhachHang.sql', '05b_API_QuanLy.sql', '05c_API_Admin.sql', '06_PhanQuyen_RLS.sql',
         '07_DuLieuHeThong.sql', '08_DuLieuMau.sql']
LATER = ['08b_KiemTra_SauTrienKhai.sql', '99_XoaCSDL_ThuNghiem.sql', '09_TruyVanBaoCao.sql', '10_SaoLuu.sql', '10b_PhucHoi.sql', '11_TaoBanSaoKiemThu.sql',
         '12_KiemThu_ToanVen.sql', '13_KiemThu_KhachHang.sql', '14_KiemThu_QuanLy.sql',
         '15_KiemThu_NhanVienCSKH.sql', '16_KiemThu_Admin.sql', '17_KiemThu_QTVTaiKhoan.sql']
SCHEMAS = {'crm', 'sec', 'audit', 'api_chung', 'api_kh', 'api_ql', 'api_admin'}
problems = []

def strip(s):
    s = re.sub(r'/\*.*?\*/', ' ', s, flags=re.S)
    s = re.sub(r'--[^\n]*', ' ', s)
    return s

def nostr(s):
    return re.sub(r"N?'(?:[^']|'')*'", "''", s)

def batches(text):
    parts = re.split(r'(?im)^\s*GO\s*(?:--.*)?$', text)
    return [p for p in parts if p.strip()]

created = {}          # 'schema.name' -> (file, kind)
types_ = set()
def reg(name, kind, f):
    created[name.lower()] = (f, kind)

CRE = re.compile(r'\bCREATE\s+(?:OR\s+ALTER\s+)?(TABLE|VIEW|PROC|PROCEDURE|FUNCTION|TRIGGER|TYPE|SECURITY\s+POLICY)\s+(\w+)\.(\w+)', re.I)
REF = re.compile(r'\b(' + '|'.join(SCHEMAS) + r')\.(\w+)\b', re.I)
SEP_FIRST = re.compile(r'^\s*(CREATE\s+(OR\s+ALTER\s+)?(PROC|PROCEDURE|VIEW|FUNCTION|TRIGGER|SCHEMA)\b)', re.I)

def check_file(f, strict_order=True):
    raw = open(f, encoding='utf-8-sig').read()
    if not open(f, 'rb').read(3) == b'\xef\xbb\xbf':
        problems.append((f, 0, 'thiếu BOM UTF-8'))
    for bi, b in enumerate(batches(raw), 1):
        s = nostr(strip(b))
        # 1. CREATE PROC/VIEW/FUNCTION/TRIGGER phải là câu lệnh đầu tiên của batch
        m = re.search(r'\bCREATE\s+(?:OR\s+ALTER\s+)?(PROC|PROCEDURE|VIEW|FUNCTION|TRIGGER)\b', s, re.I)
        if m and not SEP_FIRST.match(s):
            problems.append((f, bi, f'CREATE {m.group(1)} không đứng đầu batch'))
        if len(re.findall(r'\bCREATE\s+(?:OR\s+ALTER\s+)?(?:PROC|PROCEDURE|VIEW|FUNCTION|TRIGGER)\b', s, re.I)) > 1:
            problems.append((f, bi, 'nhiều CREATE PROC/VIEW/FUNCTION trong một batch'))
        # 2. biến cục bộ phải được khai báo trong batch
        is_module = bool(SEP_FIRST.match(s)) and not re.match(r'^\s*CREATE\s+SCHEMA', s, re.I)
        declared = set(x.lower() for x in re.findall(r'\bDECLARE\s+(@\w+)', s, re.I))
        declared |= set(x.lower() for x in re.findall(r',\s*(@\w+)\s+(?:AS\s+)?(?:[\w.]+)', s))  # DECLARE a, b
        if is_module:
            head = re.split(r'\bAS\b', s, maxsplit=1, flags=re.I)[0] if not re.match(r'^\s*CREATE\s+(OR\s+ALTER\s+)?FUNCTION', s, re.I) else s.split('RETURNS')[0]
            declared |= set(x.lower() for x in re.findall(r'(@\w+)', head))
            # TVF trả về biến bảng
            declared |= set(x.lower() for x in re.findall(r'RETURNS\s+(@\w+)', s, re.I))
        used = set(x.lower() for x in re.findall(r'(?<![@\w])(@\w+)', s))
        # tham số đặt tên khi EXEC / sp_executesql: @x = ...
        named_args = set(x.lower() for x in re.findall(r'(@\w+)\s*=', s))
        for v in sorted(used - declared):
            if v in named_args and not re.search(re.escape(v) + r'(?!\s*=)\b', s, re.I):
                continue
            # dùng như tên tham số khi gọi thủ tục (EXEC p @x = ...) -> bỏ qua nếu mọi lần xuất hiện đều là "@x ="
            occ = [mm.end() for mm in re.finditer(re.escape(v) + r'\b', s, re.I)]
            if all(re.match(r'\s*=(?!=)', s[o:]) for o in occ):
                continue
            # trong chuỗi sp_executesql đã bị xóa; biến thật chưa khai báo
            problems.append((f, bi, f'biến {v} chưa DECLARE trong batch'))
        # 3. tham chiếu đối tượng
        own = None
        mm = CRE.search(s)
        if mm:
            own = f'{mm.group(2)}.{mm.group(3)}'.lower()
        for m2 in REF.finditer(s):
            name = f'{m2.group(1)}.{m2.group(2)}'.lower()
            if name == own:
                continue
            if name not in created:
                # có thể là cột/alias kiểu "crm.X" ? chỉ báo nếu không phải tạo trong batch hiện tại
                local = [ (f'{a.group(2)}.{a.group(3)}').lower() for a in CRE.finditer(s)]
                if name in local:
                    # dùng trong cùng batch trước khi tạo?
                    if s.lower().find(name) < s.lower().find(name, ) or True:
                        continue
                problems.append((f, bi, f'tham chiếu {name} chưa được tạo trước đó'))
        for a in CRE.finditer(s):
            reg(f'{a.group(2)}.{a.group(3)}', a.group(1).upper(), f)
        # đối tượng tạo bằng EXEC(N'CREATE ...') trong chuỗi
        for a in re.finditer(r"CREATE\s+(?:OR\s+ALTER\s+)?(TABLE|VIEW|PROC|PROCEDURE|FUNCTION|TYPE)\s+(\w+)\.(\w+)", strip(b), re.I):
            reg(f'{a.group(2)}.{a.group(3)}', a.group(1).upper(), f)

for f in ORDER:
    check_file(f)
n_obj = len(created)
for f in LATER:
    check_file(f)

# 4. Tham số gọi thủ tục có tồn tại trong định nghĩa?
params = {}
for f in ORDER:
    s = nostr(strip(open(f, encoding='utf-8-sig').read()))
    for m in re.finditer(r'CREATE\s+(?:OR\s+ALTER\s+)?PROC(?:EDURE)?\s+(\w+\.\w+)(.*?)\bAS\b', s, re.I | re.S):
        params[m.group(1).lower()] = set(x.lower() for x in re.findall(r'(@\w+)', m.group(2)))
calls = 0
for f in ORDER + LATER:
    s = nostr(strip(open(f, encoding='utf-8-sig').read()))
    for m in re.finditer(r'\bEXEC(?:UTE)?\s+(?:@\w+\s*=\s*)?(\w+\.\w+)\s*([^;\n]*(?:\n\s+@[^;\n]*)*)', s, re.I):
        p = m.group(1).lower()
        if p.split('.')[0] in ('sys', 'dbo', 'master', 'msdb'):
            continue
        if p not in params:
            if p.split('.')[0] in SCHEMAS:
                problems.append((f, 0, f'EXEC {p}: thủ tục không tồn tại'))
            continue
        calls += 1
        for a in re.findall(r'(@\w+)\s*=', m.group(2)):
            if a.lower() not in params[p]:
                problems.append((f, 0, f'EXEC {p}: tham số {a} không có trong định nghĩa'))
        # tham số bắt buộc (không có giá trị mặc định) phải được truyền khi gọi theo tên
print(f'Đối tượng tạo trong 01–08: {n_obj}; thủ tục: {len(params)}; lời gọi EXEC kiểm tra: {calls}')
for p in problems:
    print(p)
print('Số vấn đề:', len(problems))
