# CRM Uniqlo – Backend API

Backend cho đồ án **Hệ thống CRM chuỗi bán lẻ thời trang Uniqlo** (môn Phân tích thiết kế HTTT, SGU, HK1 2026–2027).

- **Công nghệ:** ASP.NET Core 10 Web API, Dapper, Microsoft.Data.SqlClient, BCrypt.Net-Next, xUnit.
- **CSDL:** CSDL `CRM_Uniqlo` triển khai bằng bộ script `CRM_Uniqlo_SQL` (01→08) **cộng script bổ sung `18_BoSung_QuenMatKhau_LichSuMuaHang.sql`** (bản 19/10/2026: quên mật khẩu, lịch sử mua hàng). Backend không tự tạo hay sửa cấu trúc CSDL lúc chạy, chỉ gọi thủ tục `api_*` và đọc 4 view `api_chung`.
- **Tài liệu API:** [docs/02_DacTa_API.md](docs/02_DacTa_API.md). Khi chạy Development: giao diện thử API tại `http://localhost:5000/docs`.

## 1. Kiến trúc tóm tắt

```
Trình duyệt (web-crm :5000, web-admin :5001)
   │  cookie HttpOnly crm.auth (web-crm) / crm.admin.auth (web-admin) + header X-XSRF-TOKEN
   ▼
ASP.NET Core 10 (một tiến trình, nghe 5000 và 5001)
   ├─ Middleware: Correlation ID → xử lý lỗi → xác thực cookie → tách cổng / Origin / CSRF / 428 → phân quyền theo cổng
   ├─ Controllers: /api/auth, /api/catalog, /api/admin/*, /api/manager/*, /api/customer/*
   └─ CrmDb (Dapper): mở kết nối bằng login của cổng → EXEC sec.usp_DatNguCanh @MaTK → 1 thủ tục api_* → đọc mọi result set
   ▼
SQL Server – CRM_Uniqlo
   login crm_app_admin / crm_app_quanly / crm_app_khachhang (chỉ EXECUTE schema api của cổng mình)
   + sec.usp_KiemTraQuyen (quyền chức năng) + Row-Level Security (dữ liệu khách theo phiên)
```

Ba lớp bảo vệ chồng nhau: (1) API kiểm cổng theo nhóm route; (2) mỗi thủ tục kiểm quyền chức năng theo `VAI_TRO_QUYEN` (lỗi 50003); (3) RLS chặn đọc/ghi dữ liệu khách khác (lỗi 33504). Danh sách quyền trả cho giao diện chỉ để ẩn/hiện nút.

### Cấu trúc thư mục

```
backend/
├─ CrmUniqlo.sln
├─ src/CrmUniqlo.Api/
│  ├─ Program.cs                  Cấu hình dịch vụ và thứ tự middleware
│  ├─ appsettings.json            Cấu hình KHÔNG bí mật (cổng, phiên, CORS)
│  ├─ Auth/                       Cookie, CSRF, CORS, rate limit, đăng nhập, bcrypt, tách cổng
│  ├─ Data/                       Kết nối 3 cổng + DatNguCanh, gọi thủ tục, 5 kiểu TVP
│  ├─ Errors/                     Ánh xạ mã lỗi CSDL → HTTP, ProblemDetails
│  ├─ Controllers/                Auth, Catalog, Admin/*, Manager/*, Customer/*
│  ├─ Models/                     DTO đầu vào và kiểm tra dữ liệu
│  └─ Infrastructure/             JSON, Correlation ID, CSV, phục vụ SPA theo cổng, Email (gửi nền)
├─ tests/CrmUniqlo.Api.Tests/     Kiểm thử đơn vị + tích hợp (CRM_Uniqlo_Test)
├─ docs/02_DacTa_API.md           Đặc tả API
├─ requests/CrmUniqlo.http        Bộ request mẫu để chạy thử
├─ scripts/check-env.ps1          Kiểm tra môi trường (chỉ đọc)
├─ scripts/set-secrets.ps1        Lưu chuỗi kết nối vào User Secrets (nhập ẩn mật khẩu)
├─ scripts/reset-sql-logins.ps1   Đặt lại mật khẩu 3 login SQL + lưu User Secrets + thử kết nối (sửa lỗi 18456)
├─ .env.example, secrets.example.json   Mẫu cấu hình bí mật (giá trị giả)
└─ .github/workflows/ci.yml       Build + kiểm thử đơn vị trên GitHub
```

## 2. Chuẩn bị môi trường (Windows)

| Thành phần | Yêu cầu | Kiểm tra |
|---|---|---|
| .NET SDK | 10.0.x | `dotnet --list-sdks` |
| SQL Server | 2017+ (đang dùng SQL Server 2025 Express `localhost\SQLEXPRESS`) | SSMS |
| Chế độ xác thực | **SQL Server and Windows Authentication mode** | `scripts\check-env.ps1` |
| CSDL | `CRM_Uniqlo` (script 01→08 và **18**), `CRM_Uniqlo_Test` (script 11, chỉ cho kiểm thử) | SSMS |

Chạy kiểm tra tự động (chỉ đọc, không thay đổi gì):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-env.ps1 -Server "localhost\SQLEXPRESS"
```

### 2.0. Nâng cấp CSDL đã có (bản 19/10/2026)

Nếu `CRM_Uniqlo` đã được tạo trước ngày 19/10/2026, **không cần tạo lại**: mở `CRM_Uniqlo_SQL\18_BoSung_QuenMatKhau_LichSuMuaHang.sql` trong SSMS và Execute (hoặc `sqlcmd -I -i ...`). Script chỉ thêm bảng `crm.YEU_CAU_DAT_LAI_MK` và 4 thủ tục, chạy lại nhiều lần được, không đổi dữ liệu cũ. Sau đó chạy `08b` (phải 79/79 PASS) và `11` để bản sao kiểm thử cũng có phần mới. Thiếu bước này thì quên mật khẩu và lịch sử mua hàng trả 500 (log: `Could not find stored procedure`).

### 2.1. Bật Mixed Mode (bắt buộc)

Kết quả `08b` trên máy hiện tại báo **"Chế độ xác thực máy chủ: Chỉ Windows"**. Ở chế độ này 3 login `crm_app_*` không đăng nhập được nên backend không kết nối được.

1. SSMS → chuột phải tên máy chủ → **Properties** → **Security**.
2. Chọn **SQL Server and Windows Authentication mode** → OK.
3. Khởi động lại dịch vụ: SSMS chuột phải máy chủ → **Restart**, hoặc `services.msc` → **SQL Server (SQLEXPRESS)** → Restart.
4. Chạy lại `08b_KiemTra_SauTrienKhai.sql`: mục chế độ xác thực phải PASS (79/79).

Thao tác này là cấu hình máy chủ, không đổi cấu trúc CSDL.

### 2.2. Mật khẩu 3 login cổng

Script `06_PhanQuyen_RLS.sql` tạo `crm_app_admin`, `crm_app_quanly`, `crm_app_khachhang` với mật khẩu mặc định ghi trong script (`Doi_MatKhau_*#2026`). Mật khẩu mặc định đã nằm trong tài liệu nộp nên **nên đổi** trước khi demo/triển khai (đăng nhập SSMS bằng Windows Authentication):

```sql
ALTER LOGIN crm_app_admin     WITH PASSWORD = N'<mật khẩu mạnh 1>';
ALTER LOGIN crm_app_quanly    WITH PASSWORD = N'<mật khẩu mạnh 2>';
ALTER LOGIN crm_app_khachhang WITH PASSWORD = N'<mật khẩu mạnh 3>';
```

Không gửi các mật khẩu này qua chat, không ghi vào mã nguồn.

## 3. Cấu hình bí mật (User Secrets)

**Cách nhanh nhất (máy mới, ví dụ máy chấm bài):** sau khi đã cài CSDL bằng `CRM_Uniqlo_SQL\chay_trien_khai_va_kiem_thu.ps1`, chạy một lệnh:

```powershell
cd backend
powershell -ExecutionPolicy Bypass -File .\scripts\reset-sql-logins.ps1 -Server "localhost\SQLEXPRESS"
dotnet run --project src/CrmUniqlo.Api
```

Script tự sinh mật khẩu mới cho 3 login SQL, lưu vào User Secrets của máy đó và thử kết nối. Không cần biết hay gõ mật khẩu nào; tài khoản người dùng vẫn đăng nhập bằng `Demo@2026`. Cách thủ công bên dưới chỉ cần khi muốn tự chọn mật khẩu.

Chuỗi kết nối chỉ nằm trong User Secrets trên máy bạn (thư mục `%APPDATA%\Microsoft\UserSecrets\...`), không nằm trong repo.

**Cách thủ công (tự chọn mật khẩu), làm đủ 4 bước theo thứ tự:**

1. **Chọn 3 mật khẩu**, mỗi cái ≥ 10 ký tự, có chữ hoa, chữ thường, số, ký tự đặc biệt (`@ # ! _ - + . *`), **không chứa tên login**, **không có** `;` `=` `"` `'` và khoảng trắng.
2. **Đặt trên SQL Server**: SSMS, đăng nhập bằng Windows Authentication, chạy:
   ```sql
   ALTER LOGIN crm_app_admin     WITH PASSWORD = N'<MK1>' UNLOCK;
   ALTER LOGIN crm_app_quanly    WITH PASSWORD = N'<MK2>' UNLOCK;
   ALTER LOGIN crm_app_khachhang WITH PASSWORD = N'<MK3>' UNLOCK;
   ```
   Tab Messages phải là `Commands completed successfully`; lỗi 15118 = mật khẩu chưa đủ mạnh, đổi rồi chạy lại.
3. **Thử mật khẩu**: SSMS → Connect → Database Engine → SQL Server Authentication, login `crm_app_khachhang` + `<MK3>`, tích *Trust server certificate*. Kết nối được mới làm tiếp (làm tương tự cho 2 login còn lại nếu muốn).
4. **Lưu cho API** (PowerShell ở thư mục `backend`, gõ đúng 3 mật khẩu vừa thử):
   ```powershell
   dotnet user-secrets set "ConnectionStrings:CrmAdmin"     "Server=localhost\SQLEXPRESS;Database=CRM_Uniqlo;User ID=crm_app_admin;Password=<MK1>;Encrypt=True;TrustServerCertificate=True" --project src/CrmUniqlo.Api
   dotnet user-secrets set "ConnectionStrings:CrmQuanLy"    "Server=localhost\SQLEXPRESS;Database=CRM_Uniqlo;User ID=crm_app_quanly;Password=<MK2>;Encrypt=True;TrustServerCertificate=True" --project src/CrmUniqlo.Api
   dotnet user-secrets set "ConnectionStrings:CrmKhachHang" "Server=localhost\SQLEXPRESS;Database=CRM_Uniqlo;User ID=crm_app_khachhang;Password=<MK3>;Encrypt=True;TrustServerCertificate=True" --project src/CrmUniqlo.Api
   ```
   Hoặc dùng `.\scripts\set-secrets.ps1 -Server "localhost\SQLEXPRESS"` (nhập ẩn từng mật khẩu). Sau đó khởi động lại API.

Nếu API vẫn báo `Login failed for user 'crm_app_...'`, chạy `EXEC xp_readerrorlog 0, 1, N'crm_app_khachhang';` trong SSMS để xem `Reason:`; *Password did not match* nghĩa là bước 2 và bước 4 lệch nhau.

### 3.1. Email (quên mật khẩu)

Khi phát triển (`Development`), email không gửi thật mà ghi thành tệp `.eml` vào `src/CrmUniqlo.Api/.mail/` (đã nằm trong `.gitignore`); mở tệp bằng Outlook/Thunderbird hoặc Notepad để lấy liên kết đặt lại. Để gửi thật qua SMTP (ví dụ Gmail với *App password*):

```powershell
dotnet user-secrets set "Email:SmtpHost" "smtp.gmail.com" --project src/CrmUniqlo.Api
dotnet user-secrets set "Email:SmtpUser" "ban@gmail.com" --project src/CrmUniqlo.Api
dotnet user-secrets set "Email:SmtpPassword" "<app password>" --project src/CrmUniqlo.Api
dotnet user-secrets set "Email:From" "ban@gmail.com" --project src/CrmUniqlo.Api
dotnet user-secrets set "Email:PickupDirectory" "" --project src/CrmUniqlo.Api   # tắt ghi tệp
```

`Email:ResetUrlCrm` / `Email:ResetUrlAdmin` là địa chỉ trang "Đặt lại mật khẩu" của web-crm / web-admin, `{token}` được thay bằng mã (mặc định `http://localhost:5000/dat-lai-mat-khau#token={token}` và cổng 5001). Khi chạy front-end bằng Vite (5173/5174) thì đổi hai giá trị này cho khớp.

`TrustServerCertificate=True` cần cho SQL Server Express dùng chứng chỉ tự ký trên máy cá nhân. Khi triển khai thật dùng chứng chỉ hợp lệ và bỏ tùy chọn này. Khi triển khai, thay User Secrets bằng biến môi trường (xem `.env.example`).

## 4. Chạy thử

```powershell
cd backend
dotnet run --project src/CrmUniqlo.Api
```

- API nghe `http://localhost:5000` (web-crm) và `http://localhost:5001` (web-admin).
- Mở `http://localhost:5000/docs` để xem và thử API (chỉ ở Development).
- Mở `requests/CrmUniqlo.http` trong Visual Studio 2022 / Rider / VS Code (REST Client) để chạy bộ request mẫu theo thứ tự.
- Trang đăng nhập tách theo cổng: cổng 5000 (web-crm) chỉ nhận Khách hàng và Quản lý, cổng 5001 (web-admin) chỉ nhận Admin. Đăng nhập sai trang trả `401 LOGIN_FAILED` như sai mật khẩu. Quên/đặt lại mật khẩu cũng theo cổng. Tắt `Security:SeparatePortalsByPort` thì một cổng nhận cả 3 như cũ.
- Tài khoản demo (mật khẩu `Demo@2026`): `admin.it`, `it.mai` (Admin, chỉ đăng nhập ở cổng 5001); `ql.lan`, `gd.minh`, `cskh.hoa` (Quản lý); `kh.an`, `kh.binh` (VIP), `kh.chau`… (Khách hàng); `kh.quyen` bị khóa; `kh.nam` hồ sơ đã xóa.

Thử nhanh bằng PowerShell:

```powershell
$s = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$t = (Invoke-RestMethod http://localhost:5000/api/auth/antiforgery -WebSession $s).xsrfToken
$me = Invoke-RestMethod http://localhost:5000/api/auth/login -Method Post -WebSession $s `
      -Headers @{ "X-XSRF-TOKEN" = $t } -ContentType "application/json" `
      -Body '{"tenDangNhap":"ql.lan","matKhau":"Demo@2026"}'
Invoke-RestMethod "http://localhost:5000/api/manager/customers?soDong=5" -WebSession $s
```

### 4.1. Ghép với front-end (Vite)

Front-end gọi API **cùng origin**, không bật CORS. Khi dev, mỗi ứng dụng Vite proxy `/api` tới đúng cổng của API:

```ts
// web-crm/vite.config.ts
server: { port: 5173, proxy: { "/api": { target: "http://localhost:5000", changeOrigin: true } } }
// web-admin/vite.config.ts
server: { port: 5174, proxy: { "/api": { target: "http://localhost:5001", changeOrigin: true } } }
```

Luồng gọi API từ SPA: `GET /api/auth/antiforgery` khi tải trang → gửi `X-XSRF-TOKEN` ở mọi request ghi → sau đăng nhập/đăng ký/đổi mật khẩu dùng `xsrfToken` mới trong phản hồi → gặp 401 thì về `/login`, 428 thì về `/change-password`.

Khi build xong, chép `dist` của web-crm vào `src/CrmUniqlo.Api/wwwroot/web-crm` và của web-admin vào `wwwroot/web-admin`; API tự phục vụ theo cổng (thư mục này không đưa vào Git).

## 5. Kiểm thử

Kiểm thử tích hợp chạy API trong bộ nhớ và gọi CSDL **`CRM_Uniqlo_Test`**. Tên CSDL trong chuỗi kết nối luôn bị ghi đè sang CSDL kiểm thử, nên kiểm thử không bao giờ ghi vào `CRM_Uniqlo`.

1. Chạy lại `11_TaoBanSaoKiemThu.sql` để có bản sao sạch (các script 12–17 đã thay đổi dữ liệu trong CRM_Uniqlo_Test).
2. Đã đặt User Secrets như mục 3 (dùng chung với dự án kiểm thử).
3. Chạy:

```powershell
dotnet test                                        # toàn bộ: 35 đơn vị + 50 tích hợp
dotnet test --filter "Category!=Integration"       # chỉ kiểm thử đơn vị, không cần CSDL
$env:CRM_TEST_DATABASE = "CRM_Uniqlo_Test2"; dotnet test   # dùng CSDL kiểm thử khác
```

Các ca tích hợp chính:

| Nhóm | Nội dung |
|---|---|
| Xác thực | Đăng nhập 4 vai trò; sai tên và sai mật khẩu cùng một thông báo; tài khoản khóa → 403; hồ sơ đã xóa không vào được; lần sai thứ 6 → 429; thiếu X-XSRF-TOKEN → 400; Origin lạ → 403; cookie HttpOnly/Secure/SameSite=Lax và mới sau mỗi lần đăng nhập; đăng ký rồi tự đăng nhập; đăng ký trùng SĐT → 409 tại `sdt` |
| Phân quyền | `/api/admin` trên cổng 5000 → 404; cookie khách gọi Admin/Quản lý → 403; `cskh.hoa` thêm khách → 403 (50003); `it.mai` tự nâng lên ADMIN → 403; khách xem khảo sát không gửi cho mình → 404; sửa hồ sơ kèm `maKH` khác bị bỏ qua; **IT-01** 200 request xen kẽ 2 khách không lẫn dữ liệu; khóa tài khoản đang đăng nhập → request kế tiếp 401 |
| Quản lý | Tìm/sắp xếp/phân trang; hồ sơ 360°; thêm–sửa–cấp tài khoản–xóa mềm; mật khẩu tạm buộc đổi (428); phản hồi tiếp nhận–trả lời; báo cáo + CSV; dashboard ẩn khối thiếu quyền; vòng đời khảo sát: tạo → câu hỏi → xem trước → gửi → khách nộp → voucher → thống kê → đóng |
| Quên mật khẩu | Email sai/tài khoản không tồn tại → cùng 202 và cùng thông báo, không gửi thư; đúng → 1 thư có liên kết; mật khẩu yếu → 422; đặt lại → đăng nhập bằng mật khẩu mới, mật khẩu cũ 401; mã dùng lần 2 → 422 (52098); yêu cầu mới hủy mã cũ; đang đăng nhập → 422 |
| Lịch sử mua hàng | Chỉ hóa đơn của chính khách, mới nhất trước, chi tiết/đổi trả thuộc đúng các hóa đơn đó; lọc ngày; từ ngày > đến ngày → 422; nhân viên gọi → 403 |
| Admin | Dashboard, tình trạng 3 kết nối, nhật ký; vòng đời tài khoản nhân viên; không tự khóa/xóa mình; vai trò và quyền; tra cứu khách đã che; nạp hóa đơn → cộng điểm, trùng số hóa đơn → 409, đổi trả, xét hạng; QTV tài khoản không nạp giao dịch được; danh mục: thêm/sửa loại SP, NCC, sản phẩm, trùng SKU → 409 tại `maSKU`, sắp ra mắt thiếu ngày → 422, `it.mai` chỉ xem được (thêm → 403) |

Kết quả lần chạy gần nhất (SQL Server 2025, CSDL dựng từ bộ script 01→08 + 18): **85/85 PASS**.

## 6. Bảo mật đã áp dụng

| Rủi ro | Biện pháp |
|---|---|
| Lộ phiên qua XSS | Cookie `crm.auth` / `crm.admin.auth` HttpOnly, không trả token phiên cho JavaScript |
| Đánh cắp cookie trên đường truyền | Cookie `Secure` (`Security:CookieSecureAlways = true` ngoài Development), HSTS khi triển khai |
| Session fixation | Đăng xuất phiên cũ và phát cookie mới mỗi lần đăng nhập / đổi mật khẩu |
| Phiên quá dài | Hết hạn trượt 30 phút, tối đa 8 giờ kể từ khi đăng nhập; cookie phiên (không lưu xuống đĩa) |
| Tài khoản bị khóa vẫn còn cookie | Mỗi request gọi `sec.usp_DatNguCanh`; tài khoản khóa/xóa → 401 ngay request kế tiếp |
| CSRF | SameSite=Lax + token antiforgery bắt buộc ở mọi request ghi + kiểm `Origin` |
| CORS | Mặc định không mở (cùng origin + proxy Vite); chỉ mở cho danh sách `Security:AllowedOrigins`, không bao giờ `*` |
| Dò mật khẩu | 5 lần sai / 15 phút theo (IP, tên đăng nhập), 30 lần / 15 phút theo IP; tên không tồn tại vẫn chạy một lần bcrypt giả để cân bằng thời gian trả lời |
| Lưu mật khẩu | bcrypt cost 10 ở API; CSDL chỉ nhận chuỗi băm |
| SQL injection | Chỉ `CommandType.StoredProcedure` + tham số có kiểu; 4 câu `SELECT` danh mục là hằng số, liệt kê cột |
| Phân quyền dọc/ngang, IDOR | Kiểm cổng theo route + quyền chức năng trong thủ tục + RLS; API khách không nhận `maKH` |
| Lộ thông tin lỗi | ProblemDetails thống nhất, lỗi 500 không kèm chi tiết; tra cứu bằng `traceId` trong log |
| Bí mật trong mã nguồn | Không có; dùng User Secrets / biến môi trường; `.gitignore` chặn `.env`, `secrets*.json` |
| Log nhạy cảm | Không ghi thân request, mật khẩu, chuỗi băm, cookie |

## 7. Đưa lên GitHub

```powershell
cd backend
git remote add origin https://github.com/<tai-khoan>/crm-uniqlo-backend.git
git push -u origin main
```

Trước khi push, kiểm tra không có bí mật: `git grep -n "Password=" -- ':!*.md' ':!*.example*'` chỉ được ra các giá trị mẫu `<mat-khau-...>`.

## 8. Xử lý sự cố

| Hiện tượng | Nguyên nhân thường gặp |
|---|---|
| Khởi động báo "Thiếu chuỗi kết nối ConnectionStrings:…" | Chưa đặt User Secrets (mục 3), hoặc chạy với môi trường khác Development mà chưa đặt biến môi trường |
| Mọi API trả 500, log có `Login failed for user 'crm_app_…'` | Chưa bật Mixed Mode (mục 2.1) hoặc sai mật khẩu login |
| Log có `Login failed for user 'crm_app_...'` (18456, *Password did not match*) | Mật khẩu login SQL lệch User Secrets: chạy `scripts\reset-sql-logins.ps1` (sinh mật khẩu mới, lưu và thử kết nối), rồi khởi động lại API |
| Log có `The certificate chain was issued by an authority that is not trusted` | Thiếu `TrustServerCertificate=True` trong chuỗi kết nối (máy cá nhân) |
| `A network-related or instance-specific error` | Sai tên máy chủ: SQL Express thường là `localhost\SQLEXPRESS` hoặc `.\SQLEXPRESS` |
| Request ghi trả 400 `CSRF` | Chưa gửi `X-XSRF-TOKEN`, hoặc dùng token cũ sau khi đăng nhập (lấy `xsrfToken` trong phản hồi đăng nhập) |
| `/api/admin/...` trả 404 | Gọi qua cổng 5000; API Admin chỉ trả lời ở cổng 5001 |
| Kiểm thử tích hợp lỗi dữ liệu mẫu | CRM_Uniqlo_Test đã bị script 12–17 thay đổi: chạy lại script 11 |
| Quên mật khẩu / lịch sử mua hàng trả 500, log `Could not find stored procedure` | Chưa chạy script 18 trên CSDL (mục 2.0) |
| Bấm "quên mật khẩu" nhưng không thấy email | Development: xem thư mục `src/CrmUniqlo.Api/.mail/`. Email phải trùng email trong hồ sơ; mỗi tài khoản tối đa 3 yêu cầu / 15 phút; log có `Chưa cấu hình Email:SmtpHost` thì chưa cấu hình SMTP |
| Thời gian lệch 7 giờ | Máy chủ SQL không ở múi giờ +07:00: chỉnh `Database:TimeZoneOffset` |
