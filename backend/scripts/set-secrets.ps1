<#
.SYNOPSIS
  Lưu 3 chuỗi kết nối (login SQL của 3 cổng) vào User Secrets của dự án API.
  Mật khẩu được nhập ẩn, KHÔNG ghi vào mã nguồn hay Git.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\set-secrets.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\set-secrets.ps1 -Server "localhost\SQLEXPRESS" -Database CRM_Uniqlo
#>
param(
    [string]$Server = "localhost\SQLEXPRESS",
    [string]$Database = "CRM_Uniqlo"
)
$ErrorActionPreference = "Stop"
$project = Join-Path $PSScriptRoot "..\src\CrmUniqlo.Api\CrmUniqlo.Api.csproj"

function Read-Secret([string]$prompt) {
    $secure = Read-Host -Prompt $prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

$logins = [ordered]@{
    "CrmAdmin"     = "crm_app_admin"
    "CrmQuanLy"    = "crm_app_quanly"
    "CrmKhachHang" = "crm_app_khachhang"
}

Write-Host "Máy chủ: $Server   CSDL: $Database" -ForegroundColor Cyan
$secrets = [ordered]@{}
foreach ($name in $logins.Keys) {
    $user = $logins[$name]
    $password = Read-Secret "Mật khẩu của login $user"
    # Đặt mật khẩu trong ngoặc kép để ký tự ; = trong mật khẩu không làm hỏng chuỗi kết nối.
    $escaped = '"' + $password.Replace('"', '""') + '"'
    $secrets["ConnectionStrings:$name"] = "Server=$Server;Database=$Database;User ID=$user;Password=$escaped;Encrypt=True;TrustServerCertificate=True;Application Name=CrmUniqlo.Api"
}
# Gửi qua stdin dạng JSON: Windows PowerShell 5.1 làm mất dấu " khi truyền chuỗi làm tham số cho chương trình ngoài.
$secrets | ConvertTo-Json | dotnet user-secrets set --project $project | Out-Null
if ($LASTEXITCODE -ne 0) { throw "dotnet user-secrets set thất bại (mã $LASTEXITCODE)." }
foreach ($name in $logins.Keys) { Write-Host "  Đã lưu ConnectionStrings:$name" -ForegroundColor Green }
Write-Host "Xong. Kiểm tra: dotnet user-secrets list --project src/CrmUniqlo.Api" -ForegroundColor Cyan
