<#
  TRIỂN KHAI CSDL CRM_Uniqlo VÀ CHẠY TOÀN BỘ KIỂM THỬ BẰNG sqlcmd
  ------------------------------------------------------------------
  Cách dùng (PowerShell, đứng trong thư mục chứa các tệp .sql):
    powershell -ExecutionPolicy Bypass -File .\chay_trien_khai_va_kiem_thu.ps1 -Server "localhost\SQLEXPRESS"

  Tham số:
    -Server      : tên máy chủ SQL Server (mặc định localhost). Bản Express thường là localhost\SQLEXPRESS
    -SqlUser     : (tùy chọn) đăng nhập bằng SQL login có quyền sysadmin, ví dụ sa.
    -SqlPassword : mật khẩu của -SqlUser. Không truyền -SqlUser => dùng Windows (-E).
    -ChiKiemThu  : bỏ qua triển khai 01–08 và sao lưu 10; vẫn chạy 18 (bổ sung), rồi 08b + tạo bản sao + chạy 12–17, 19.

  Kết quả: thư mục .\ketqua\<ngày_giờ>\ chứa đầu ra từng script và TongKet.txt.
  Gửi NGUYÊN thư mục đó khi cần nhờ sửa lỗi.
  Script KHÔNG chạy 99_XoaCSDL_ThuNghiem.sql (xóa CSDL) – tệp đó phải tự mở và chạy.
#>
param(
    [string]$Server = "localhost",
    [string]$SqlUser = "",
    [string]$SqlPassword = "",
    [switch]$ChiKiemThu
)

$ErrorActionPreference = "Continue"   # "Stop" làm PowerShell 5.1 dừng khi sqlcmd ghi ra stderr
$ThuMuc = Split-Path -Parent $MyInvocation.MyCommand.Path
$KetQua = Join-Path (Join-Path $ThuMuc "ketqua") (Get-Date -Format "yyyyMMdd_HHmmss")
New-Item -ItemType Directory -Force -Path $KetQua | Out-Null
$TongKet = Join-Path $KetQua "TongKet.txt"

function Ghi([string]$Dong, [string]$Mau = "Gray") {
    Write-Host $Dong -ForegroundColor $Mau
    Add-Content -Path $TongKet -Value $Dong -Encoding UTF8
}

# ---------------- 0. Kiểm tra công cụ và kết nối ----------------
if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
    Ghi "LỖI: không tìm thấy sqlcmd. Cài 'Microsoft Command Line Utilities for SQL Server' hoặc dùng SSMS (xem hướng dẫn, cách B)." "Red"
    exit 1
}
# -C = tin chứng chỉ tự ký của SQL Server cài trên máy (sqlcmd/ODBC Driver 18 mặc định mã hóa và từ chối chứng chỉ này).
$XacThuc = @("-E", "-C")
if ($SqlUser -ne "") { $XacThuc = @("-U", $SqlUser, "-P", $SqlPassword, "-C") }

Ghi ("Thời điểm chạy : " + (Get-Date -Format "dd/MM/yyyy HH:mm:ss"))
Ghi ("Máy chủ        : " + $Server)
$thu = & sqlcmd -S $Server @XacThuc -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CONCAT(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(50)), ' | ', CAST(SERVERPROPERTY('Edition') AS NVARCHAR(100)), ' | sysadmin=', IS_SRVROLEMEMBER('sysadmin'))" 2>&1
if ($LASTEXITCODE -ne 0) {
    Ghi "LỖI: không kết nối được SQL Server. Kiểm tra tên -Server, dịch vụ SQL Server đã chạy, quyền đăng nhập." "Red"
    Ghi ($thu | Out-String) "Red"
    exit 1
}
Ghi ("Phiên bản      : " + ($thu | Out-String).Trim())
if (($thu | Out-String) -notmatch "sysadmin=1") {
    Ghi "LỖI: tài khoản đang dùng KHÔNG có quyền sysadmin – cần sysadmin để tạo CSDL, login, sao lưu." "Red"
    exit 1
}
if (Select-String -Path (Join-Path $ThuMuc "06_PhanQuyen_RLS.sql") -Pattern "Doi_MatKhau_" -Quiet) {
    Ghi "CẢNH BÁO: script 06 vẫn dùng mật khẩu mẫu 'Doi_MatKhau_...'. Được phép khi chạy thử, phải đổi trước khi dùng thật." "Yellow"
}

function Chay([string]$Tep, [string]$CSDL = "master", [switch]$DungKhiLoi) {
    $vao = Join-Path $ThuMuc $Tep
    $ra  = Join-Path $KetQua ($Tep + ".txt")
    $thamSo = @("-S", $Server) + $XacThuc + @("-I", "-f", "65001", "-d", $CSDL, "-i", $vao, "-o", $ra)
    if ($DungKhiLoi) { $thamSo += "-b" }
    Write-Host ">> $Tep (CSDL: $CSDL)"
    & sqlcmd @thamSo
    $ma = $LASTEXITCODE
    if ($DungKhiLoi -and $ma -ne 0) {
        Ghi "   FAIL: $Tep dừng vì lỗi (mã thoát $ma). Mở $ra, tìm dòng 'Msg ' đầu tiên." "Red"
        Ghi "KET LUAN CHUNG: KHONG DAT (triển khai dừng ở $Tep)" "Red"
        exit 1
    }
    if ($DungKhiLoi) { Ghi "   OK  : $Tep" "Green" }
}

function DocKetLuan([string]$Tep) {
    $ra = Join-Path $KetQua ($Tep + ".txt")
    $tk = Select-String -Path $ra -Pattern "TONG KET" | Select-Object -Last 1
    $kl = Select-String -Path $ra -Pattern "KET LUAN:" | Select-Object -Last 1
    if (-not $kl) {
        Ghi ("{0,-34} KHÔNG THẤY DÒNG KẾT LUẬN – script bị dừng giữa chừng, mở {1}.txt tìm 'Msg '" -f $Tep, $Tep) "Yellow"
        return $false
    }
    $dat = $kl.Line -match "KET LUAN: DAT"
    $mau = "Red"; if ($dat) { $mau = "Green" }
    Ghi ("{0,-34} {1}  =>  {2}" -f $Tep, $tk.Line.Trim(), $kl.Line.Trim()) $mau
    return $dat
}

# ---------------- 1. Triển khai (dừng ngay khi có lỗi) ----------------
if (-not $ChiKiemThu) {
    Ghi ""
    Ghi "=== BƯỚC 1: TRIỂN KHAI 01 -> 08 ==="
    foreach ($t in @("01_TaoCSDL_Schema.sql", "02_TaoBang.sql", "03_ChiMuc_View.sql",
                     "04_BaoMat_ThuTucNoiBo.sql", "05a_API_Chung_KhachHang.sql", "05b_API_QuanLy.sql",
                     "05c_API_Admin.sql", "06_PhanQuyen_RLS.sql", "07_DuLieuHeThong.sql", "08_DuLieuMau.sql")) {
        Chay $t "master" -DungKhiLoi
    }
}

# 18 chỉ THÊM đối tượng và chạy lại được nên luôn chạy (kể cả -ChiKiemThu):
# CSDL đã triển khai từ trước được nâng cấp tại chỗ, không mất dữ liệu.
Ghi ""
Ghi "=== BƯỚC 1b: BỔ SUNG QUÊN MẬT KHẨU + LỊCH SỬ MUA HÀNG (18) ==="
Chay "18_BoSung_QuenMatKhau_LichSuMuaHang.sql" "master" -DungKhiLoi

# ---------------- 2. Kiểm tra sau triển khai ----------------
Ghi ""
Ghi "=== BƯỚC 2: KIỂM TRA SAU TRIỂN KHAI (08b) ==="
Chay "08b_KiemTra_SauTrienKhai.sql" "CRM_Uniqlo"
$dat08b = DocKetLuan "08b_KiemTra_SauTrienKhai.sql"

if (-not $ChiKiemThu) {
    Ghi ""
    Ghi "=== BƯỚC 3: SAO LƯU (10) ==="
    Chay "10_SaoLuu.sql" "master" -DungKhiLoi
}

# ---------------- 3. Bản sao kiểm thử + kiểm thử ----------------
Ghi ""
Ghi "=== BƯỚC 4: TẠO CRM_Uniqlo_Test (11) VÀ CHẠY KIỂM THỬ 12 -> 17, 19 ==="
Chay "11_TaoBanSaoKiemThu.sql" "master" -DungKhiLoi
$tests = @("12_KiemThu_ToanVen.sql", "13_KiemThu_KhachHang.sql", "14_KiemThu_QuanLy.sql",
           "15_KiemThu_NhanVienCSKH.sql", "16_KiemThu_Admin.sql", "17_KiemThu_QTVTaiKhoan.sql",
           "19_KiemThu_BoSung.sql")
foreach ($t in $tests) { Chay $t "CRM_Uniqlo_Test" }   # mỗi tệp là một kết nối mới

Ghi ""
Ghi "================ TỔNG KẾT ================"
$tatCaDat = $dat08b
foreach ($t in $tests) { if (-not (DocKetLuan $t)) { $tatCaDat = $false } }
Ghi ""
if ($tatCaDat) {
    Ghi "KET LUAN CHUNG: DAT – 08b đạt và 187/187 ca kiểm thử PASS." "Green"
} else {
    Ghi "KET LUAN CHUNG: KHONG DAT – xem các dòng màu đỏ/vàng ở trên và tệp .txt tương ứng." "Red"
}
Ghi ("Kết quả lưu tại: " + $KetQua)
