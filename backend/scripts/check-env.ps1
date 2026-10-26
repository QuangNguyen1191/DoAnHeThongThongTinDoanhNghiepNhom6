<#
.SYNOPSIS
  Kiểm tra môi trường trước khi chạy backend: .NET 10 SDK, SQL Server (chế độ xác thực),
  CSDL CRM_Uniqlo / CRM_Uniqlo_Test và 3 login cổng. Chỉ ĐỌC, không thay đổi gì.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\check-env.ps1 -Server "localhost\SQLEXPRESS"
#>
param([string]$Server = "localhost\SQLEXPRESS")
$ok = $true
function Pass($m) { Write-Host "  [OK]   $m" -ForegroundColor Green }
function Fail($m) { Write-Host "  [LỖI]  $m" -ForegroundColor Red; $script:ok = $false }

Write-Host "1. .NET SDK" -ForegroundColor Cyan
$sdks = & dotnet --list-sdks 2>$null
if ($sdks -match "^10\.") { Pass ".NET 10 SDK: $(($sdks -match '^10\.') -join ', ')" }
else { Fail "Chưa có .NET 10 SDK. Tải tại https://dotnet.microsoft.com/download/dotnet/10.0" }

Write-Host "2. SQL Server ($Server)" -ForegroundColor Cyan
if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
    Fail "Không tìm thấy sqlcmd (cài cùng SSMS hoặc gói sqlcmd). Bỏ qua kiểm tra SQL."
} else {
    $q = "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar(20)) + '|' + CAST(SERVERPROPERTY('IsIntegratedSecurityOnly') AS varchar(1)) + '|' + ISNULL(CAST(DB_ID('CRM_Uniqlo') AS varchar(10)),'-') + '|' + ISNULL(CAST(DB_ID('CRM_Uniqlo_Test') AS varchar(10)),'-') + '|' + CAST((SELECT COUNT(*) FROM sys.server_principals WHERE name IN ('crm_app_admin','crm_app_quanly','crm_app_khachhang') AND is_disabled = 0) AS varchar(1)) + '|' + CASE WHEN OBJECT_ID('CRM_Uniqlo.api_kh.usp_LichSuGiaoDich') IS NULL THEN '0' ELSE '1' END"
    $r = & sqlcmd -S $Server -E -C -h -1 -W -Q $q 2>&1
    if ($LASTEXITCODE -ne 0) { Fail "Không kết nối được bằng Windows Authentication: $r" }
    else {
        $p = ($r | Select-Object -First 1).Trim().Split('|')
        Pass "Phiên bản SQL Server $($p[0])"
        if ($p[1] -eq '1') { Fail "Máy chủ đang ở chế độ CHỈ Windows Authentication. Bật 'SQL Server and Windows Authentication mode' rồi khởi động lại dịch vụ (README mục 2)." }
        else { Pass "Đã bật Mixed Mode (SQL Server and Windows Authentication)" }
        if ($p[2] -ne '-') { Pass "Có CSDL CRM_Uniqlo" } else { Fail "Chưa có CSDL CRM_Uniqlo (chạy script 01→08)" }
        if ($p[3] -ne '-') { Pass "Có CSDL CRM_Uniqlo_Test (cho kiểm thử)" } else { Write-Host "  [--]   Chưa có CRM_Uniqlo_Test (chỉ cần khi chạy kiểm thử: script 11)" -ForegroundColor Yellow }
        if ($p[2] -ne '-') {
            if ($p[5] -eq '1') { Pass "CSDL đã có phần bổ sung (script 18: quên mật khẩu, lịch sử mua hàng)" }
            else { Fail "CSDL chưa chạy script 18_BoSung_QuenMatKhau_LichSuMuaHang.sql (README mục 2.0)" }
        }
        if ($p[4] -eq '3') { Pass "3 login crm_app_* đang bật" } else { Fail "Thiếu login crm_app_* (chạy script 06)" }
    }
}

Write-Host "3. User Secrets của API" -ForegroundColor Cyan
$secrets = & dotnet user-secrets list --project (Join-Path $PSScriptRoot "..\src\CrmUniqlo.Api") 2>$null
foreach ($n in "CrmAdmin","CrmQuanLy","CrmKhachHang") {
    if ($secrets -match "ConnectionStrings:$n") { Pass "Đã đặt ConnectionStrings:$n" } else { Fail "Chưa đặt ConnectionStrings:$n (chạy scripts\set-secrets.ps1)" }
}

if ($ok) { Write-Host "`nMôi trường sẵn sàng." -ForegroundColor Green } else { Write-Host "`nCòn mục cần xử lý (xem [LỖI])." -ForegroundColor Red; exit 1 }
