<#
.SYNOPSIS
  Đặt lại mật khẩu 3 login SQL của API (crm_app_admin, crm_app_quanly, crm_app_khachhang)
  và lưu ĐÚNG mật khẩu đó vào User Secrets trong một lần chạy, rồi thử kết nối bằng từng login.
  Dùng khi API báo "Login failed for user 'crm_app_...'" (18456, Password did not match).
.DESCRIPTION
  - Kết nối tới SQL Server bằng tài khoản Windows đang chạy script (cần quyền sysadmin hoặc ALTER ANY LOGIN).
  - Mật khẩu được sinh ngẫu nhiên (24 ký tự, không có ; = " ') nên không phải gõ và không thể gõ lệch.
    Không ai cần biết mật khẩu này: chỉ API dùng nó, và nó nằm trong User Secrets.
  - Không in mật khẩu ra màn hình, không ghi vào tệp nào trong thư mục dự án.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\reset-sql-logins.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\reset-sql-logins.ps1 -Server "localhost\SQLEXPRESS" -Database CRM_Uniqlo
#>
param(
    [string]$Server = "localhost\SQLEXPRESS",
    [string]$Database = "CRM_Uniqlo"
)
$ErrorActionPreference = "Stop"
$project = Join-Path $PSScriptRoot "..\src\CrmUniqlo.Api\CrmUniqlo.Api.csproj"
Add-Type -AssemblyName System.Data

function New-Password {
    # Đủ 4 nhóm ký tự để qua CHECK_POLICY của Windows.
    $groups = @("ABCDEFGHJKLMNPQRSTUVWXYZ", "abcdefghijkmnopqrstuvwxyz", "23456789", "@#!_-+.*")
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 24
    $rng.GetBytes($bytes)
    $chars = for ($i = 0; $i -lt 24; $i++) { $g = $groups[$i % 4]; $g[$bytes[$i] % $g.Length] }
    -join $chars
}

$logins = [ordered]@{
    "CrmAdmin"     = "crm_app_admin"
    "CrmQuanLy"    = "crm_app_quanly"
    "CrmKhachHang" = "crm_app_khachhang"
}

Write-Host "Máy chủ: $Server   CSDL: $Database" -ForegroundColor Cyan
$admin = New-Object System.Data.SqlClient.SqlConnection "Server=$Server;Database=master;Integrated Security=True;TrustServerCertificate=True"
$admin.Open()

$secrets = [ordered]@{}
foreach ($name in $logins.Keys) {
    $user = $logins[$name]
    $password = New-Password
    # Mật khẩu đi vào dưới dạng tham số, QUOTENAME lo phần trích dẫn: không có ký tự nào làm hỏng lệnh.
    $cmd = $admin.CreateCommand()
    $cmd.CommandText = @"
IF SUSER_ID(@login) IS NULL THROW 50000, N'Chưa có login này trên máy chủ: chạy script 06 trước.', 1;
DECLARE @lenh NVARCHAR(MAX) = N'ALTER LOGIN ' + QUOTENAME(@login) + N' WITH PASSWORD = ' + QUOTENAME(@mk, '''') + N' UNLOCK; '
                            + N'ALTER LOGIN ' + QUOTENAME(@login) + N' ENABLE;';
EXEC sys.sp_executesql @lenh;
"@
    [void]$cmd.Parameters.AddWithValue("@login", $user)
    [void]$cmd.Parameters.AddWithValue("@mk", $password)
    [void]$cmd.ExecuteNonQuery()
    Write-Host "  Đã đặt mật khẩu mới cho $user" -ForegroundColor Green

    $secrets["ConnectionStrings:$name"] = "Server=$Server;Database=$Database;User ID=$user;Password=$password;Encrypt=True;TrustServerCertificate=True;Application Name=CrmUniqlo.Api"
}
$admin.Close()

# Gửi qua stdin dạng JSON: Windows PowerShell 5.1 làm hỏng chuỗi có dấu " khi truyền làm tham số.
$secrets | ConvertTo-Json | dotnet user-secrets set --project $project | Out-Null
if ($LASTEXITCODE -ne 0) { throw "dotnet user-secrets set thất bại (mã $LASTEXITCODE)." }
Write-Host "  Đã lưu 3 chuỗi kết nối vào User Secrets" -ForegroundColor Green

# Thử kết nối bằng đúng chuỗi vừa lưu.
$ok = $true
foreach ($name in $logins.Keys) {
    $cs = $secrets["ConnectionStrings:$name"]
    try {
        $c = New-Object System.Data.SqlClient.SqlConnection $cs
        $c.Open(); $c.Close()
        Write-Host "  Kết nối thử bằng $($logins[$name]): OK" -ForegroundColor Green
    } catch {
        $ok = $false
        Write-Host "  Kết nối thử bằng $($logins[$name]): LỖI - $($_.Exception.Message)" -ForegroundColor Red
    }
}
if ($ok) {
    Write-Host "Xong. Khởi động lại API (Ctrl+C rồi dotnet run --project src/CrmUniqlo.Api)." -ForegroundColor Cyan
} else {
    Write-Host "Có login chưa kết nối được: xem thông báo lỗi đỏ ở trên." -ForegroundColor Yellow
}
