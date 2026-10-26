# Hướng dẫn kiểm thử CRM Uniqlo (đăng nhập và phân quyền)

Tài liệu này hướng dẫn từng bước để tự chạy và kiểm tra: trang đăng nhập chung (Khách hàng, Quản lý), trang đăng nhập riêng của Admin, phân quyền theo URL và menu, đăng xuất, hết phiên, quên mật khẩu, đổi mật khẩu bắt buộc, đăng ký và lịch sử mua hàng.

Thư mục dùng trong tài liệu:

```
CRM PTTKHTTT/
├─ CRM_Uniqlo_SQL/   script CSDL
├─ backend/          API ASP.NET Core
└─ frontend/         giao diện (web-crm, web-admin)
```

---

## 1. Chuẩn bị (làm một lần)

| Cần có | Kiểm tra |
|---|---|
| .NET SDK 10 | `dotnet --list-sdks` |
| Node.js 20 trở lên | `node -v` |
| SQL Server, bật **SQL Server and Windows Authentication mode** | xem README backend mục 2.1 |

### 1.1. Cơ sở dữ liệu

Mở SSMS, chạy lần lượt trong `CRM_Uniqlo_SQL`:

1. `01` → `08` (tạo CSDL `CRM_Uniqlo`, bảng, thủ tục, quyền, dữ liệu mẫu). Nếu đã có CSDL từ trước thì bỏ qua.
2. **`18_BoSung_QuenMatKhau_LichSuMuaHang.sql`**: bắt buộc. Thiếu script này thì quên mật khẩu và lịch sử mua hàng báo lỗi.
3. `08b_KiemTra_SauTrienKhai.sql`: phải ra toàn bộ PASS.
4. `11_TaoBanSaoKiemThu.sql`: chỉ cần khi chạy kiểm thử tự động của backend (mục 6.1).

### 1.2. Chuỗi kết nối cho backend

```powershell
cd backend
powershell -ExecutionPolicy Bypass -File .\scripts\set-secrets.ps1 -Server "localhost\SQLEXPRESS"
```

Nhập mật khẩu 3 login `crm_app_admin`, `crm_app_quanly`, `crm_app_khachhang` khi được hỏi (gõ ẩn). Chi tiết ở README backend mục 3.

### 1.3. Cài thư viện giao diện

```powershell
cd frontend
npm ci
```

---

## 2. Khởi động hệ thống

Có hai cách. **Nên dùng cách A khi kiểm thử**, vì liên kết trong email quên mật khẩu trỏ đúng về cổng 5000/5001.

### Cách A: bản build, chỉ một cửa sổ (khuyên dùng)

```powershell
cd frontend
npm run build          # build web-crm và web-admin
npm run publish:api    # chép bản build vào backend/src/CrmUniqlo.Api/wwwroot

cd ..\backend
dotnet run --project src/CrmUniqlo.Api
```

| Trang | Địa chỉ |
|---|---|
| Đăng nhập chung (Khách hàng, Quản lý) | http://localhost:5000/login |
| Đăng nhập Admin | http://localhost:5001/login |

Mỗi lần sửa giao diện thì chạy lại `npm run build` và `npm run publish:api`.

### Cách B: chế độ dev, 3 cửa sổ (tự tải lại khi sửa code)

```powershell
# Cửa sổ 1
cd backend
dotnet run --project src/CrmUniqlo.Api

# Cửa sổ 2
cd frontend
npm run dev:crm        # http://localhost:5173

# Cửa sổ 3
cd frontend
npm run dev:admin      # http://localhost:5174
```

| Trang | Địa chỉ |
|---|---|
| Đăng nhập chung | http://localhost:5173/login |
| Đăng nhập Admin | http://localhost:5174/login |

Ở cách B, khi mở liên kết trong email quên mật khẩu, đổi cổng `5000` thành `5173` (hoặc `5001` thành `5174` với Admin).

---

## 3. Tài khoản kiểm thử

Mật khẩu chung: **`Demo@2026`**

**Trang đăng nhập chung**

| Tên đăng nhập | Vai trò | Kết quả mong đợi |
|---|---|---|
| `kh.an` | Khách hàng VIP | Vào `/customer` |
| `kh.binh` | Khách hàng VIP | Vào `/customer` |
| `kh.chau` | Khách hàng | Vào `/customer` |
| `ql.lan` | Quản lý (đủ quyền) | Vào `/manager` |
| `cskh.hoa` | Nhân viên CSKH | Vào `/manager`, không có menu Báo cáo |
| `kh.quyen` | Tài khoản bị khóa | Báo "Tài khoản đã bị khóa" |
| `kh.nam` | Hồ sơ đã xóa | Không đăng nhập được |

**Trang đăng nhập Admin**

| Tên đăng nhập | Vai trò | Kết quả mong đợi |
|---|---|---|
| `admin.it` | Admin (đủ quyền) | Vào `/admin` |
| `it.mai` | Quản trị tài khoản | Vào `/admin`, không có menu Vai trò và quyền |

---

## 4. Kịch bản kiểm thử thủ công

Đánh dấu ☐ → ☑ khi đạt. Địa chỉ dưới đây theo **cách A**; dùng cách B thì thay `5000` → `5173`, `5001` → `5174`.

Nên mở **cửa sổ ẩn danh** cho mỗi nhóm để không bị phiên cũ ảnh hưởng.

### 4.1. Trang đăng nhập chung

| # | Thao tác | Kết quả mong đợi | |
|---|---|---|---|
| 1 | Mở http://localhost:5000/login | Có ô Tên đăng nhập, Mật khẩu, Quên mật khẩu, Đăng ký thành viên. **Không** có ô tài khoản demo, không nhắc đến Admin | ☐ |
| 2 | Nhập `ql.lan` / `SaiMatKhau1` | Báo "Sai tên đăng nhập hoặc mật khẩu", ô mật khẩu bị xóa, tên vẫn giữ | ☐ |
| 3 | Nhập `khongtontai` / `abc12345` | Cùng thông báo như bước 2 | ☐ |
| 4 | Nhập `admin.it` / `Demo@2026` | Cùng thông báo "Sai tên đăng nhập hoặc mật khẩu" (Admin không đăng nhập ở trang chung) | ☐ |
| 5 | Nhập `kh.quyen` / `Demo@2026` | Báo tài khoản đã bị khóa | ☐ |
| 6 | Nhập `ql.lan` / `Demo@2026` | Vào `/manager`, trang Tổng quan có số liệu | ☐ |
| 7 | Bật Caps Lock khi gõ mật khẩu | Hiện "Caps Lock đang bật" | ☐ |
| 8 | Bấm biểu tượng con mắt ở ô mật khẩu | Hiện/ẩn mật khẩu | ☐ |

### 4.2. Trang đăng nhập Admin

| # | Thao tác | Kết quả mong đợi | |
|---|---|---|---|
| 1 | Mở http://localhost:5001/admin khi chưa đăng nhập | Chuyển sang http://localhost:5001/login, tiêu đề "Đăng nhập quản trị", có nhãn ADMIN | ☐ |
| 2 | Nhập `kh.an` / `Demo@2026` | Báo "Sai tên đăng nhập hoặc mật khẩu" | ☐ |
| 3 | Nhập `ql.lan` / `Demo@2026` | Báo "Sai tên đăng nhập hoặc mật khẩu" | ☐ |
| 4 | Nhập `admin.it` / `Demo@2026` | Vào `/admin` | ☐ |
| 5 | Trang Admin không có nút Đăng ký thành viên; có liên kết "Đến trang đăng nhập chung" | Liên kết mở trang đăng nhập ở cổng 5000 | ☐ |
| 6 | Đăng xuất | Về http://localhost:5001/login?da-dang-xuat=1, báo "Bạn đã đăng xuất an toàn" | ☐ |
| 7 | Mở http://localhost:5001/admin/audit-log khi chưa đăng nhập, rồi đăng nhập `admin.it` | Sau đăng nhập quay lại đúng trang Nhật ký | ☐ |

### 4.3. Chặn truy cập bằng cách gõ URL

| # | Đang đăng nhập | Gõ địa chỉ | Kết quả mong đợi | |
|---|---|---|---|---|
| 1 | `ql.lan` (cổng 5000) | http://localhost:5000/customer/profile | Trang "Bạn không có quyền truy cập trang này" (403) | ☐ |
| 2 | `ql.lan` (cổng 5000) | http://localhost:5000/admin | Trang "Không tìm thấy trang" (404) | ☐ |
| 3 | `ql.lan` (cổng 5000) | http://localhost:5001/admin | Ra trang đăng nhập Admin, không vào được | ☐ |
| 4 | `kh.an` | http://localhost:5000/manager/customers | Trang 403 | ☐ |
| 5 | `cskh.hoa` | http://localhost:5000/manager/reports | Khung "Không có quyền truy cập"; menu không có Báo cáo | ☐ |
| 6 | `it.mai` (cổng 5001) | http://localhost:5001/admin/roles | Khung "Không có quyền truy cập"; menu không có Vai trò và quyền | ☐ |
| 7 | Đang đăng nhập `ql.lan` | http://localhost:5000/login | Tự về `/manager` | ☐ |

### 4.4. Hai phiên trên cùng trình duyệt

| # | Thao tác | Kết quả mong đợi | |
|---|---|---|---|
| 1 | Tab 1: đăng nhập `admin.it` ở cổng 5001 | Vào `/admin` | ☐ |
| 2 | Tab 2: đăng nhập `ql.lan` ở cổng 5000 | Vào `/manager` | ☐ |
| 3 | Quay lại tab 1, bấm sang menu khác | Vẫn là `admin.it`, không bị đăng xuất | ☐ |

### 4.5. Đăng xuất và nút Back

| # | Thao tác | Kết quả mong đợi | |
|---|---|---|---|
| 1 | Đăng nhập `ql.lan`, bấm Đăng xuất, xác nhận | Về `/login?da-dang-xuat=1` | ☐ |
| 2 | Bấm nút Back của trình duyệt | Không thấy lại dữ liệu trang Quản lý | ☐ |
| 3 | Mở 2 tab cùng đăng nhập `kh.an`, đăng xuất ở tab 1 | Tab 2 cũng về trang đăng nhập | ☐ |

### 4.6. Hết phiên do không thao tác

Phiên tự hết sau 30 phút không thao tác, cảnh báo trước 2 phút. Để không phải chờ, giả lập bằng DevTools:

1. Đăng nhập `kh.an`, đợi trang chủ tải xong.
2. Nhấn F12 → tab **Console**, dán và Enter:
   ```js
   const c = JSON.parse(localStorage.getItem("crm.sessionClock")); c.issuedAt = Date.now() - 29 * 60000; localStorage.setItem("crm.sessionClock", JSON.stringify(c));
   ```
   → Trong vài giây hiện hộp thoại "Phiên làm việc sắp kết thúc" với 2 nút Tiếp tục làm việc / Đăng xuất. ☐
3. Bấm **Tiếp tục làm việc** → hộp thoại đóng, vẫn ở trang. ☐
4. Dán lại lệnh ở bước 2 nhưng đổi `29` thành `31` → tự về `/login?het-phien=1`, báo "Phiên đăng nhập đã hết". ☐
5. Đăng nhập lại → quay về đúng trang đang xem trước đó. ☐

### 4.7. Quên mật khẩu và đặt lại qua email

Email chỉ gửi được cho tài khoản **có email trong hồ sơ**. Cách dễ nhất là dùng tài khoản tự đăng ký ở mục 4.9 (nhớ điền email).

1. Ở trang đăng nhập, bấm **Quên mật khẩu?**, nhập tên đăng nhập và email trong hồ sơ, bấm **Gửi liên kết đặt lại** → màn hình "Kiểm tra email của bạn". ☐
2. Nhập sai email hoặc tên không tồn tại → vẫn hiện cùng thông báo (không lộ tài khoản có tồn tại hay không). ☐
3. Mở thư mục `backend/src/CrmUniqlo.Api/.mail/`, mở tệp `.eml` mới nhất bằng Notepad (hoặc Outlook), copy liên kết `http://localhost:5000/dat-lai-mat-khau#token=...`. ☐
4. Dán liên kết vào trình duyệt → trang "Đặt mật khẩu mới"; thanh địa chỉ tự xóa phần `#token=...`. ☐
5. Nhập mật khẩu mới 2 lần (ít nhất 8 ký tự, có chữ và số), bấm **Lưu mật khẩu mới** → về `/login` với thông báo "Đã đặt mật khẩu mới". ☐
6. Đăng nhập bằng mật khẩu mới → thành công; mật khẩu cũ → sai. ☐
7. Mở lại đúng liên kết đã dùng → "Liên kết không còn hiệu lực". ☐
8. Thử quên mật khẩu tài khoản `admin.it` ở **trang chung** (email `bao.tran@nv.example.com`) → không có thư nào được tạo. Làm lại ở http://localhost:5001/forgot-password → có thư, liên kết trỏ về cổng 5001. ☐

> Ở bước 8, nếu mở liên kết và đặt mật khẩu mới cho `admin.it`, hãy đặt đúng `Demo@2026` để các lần thử sau vẫn dùng được.

### 4.8. Đổi mật khẩu bắt buộc (mật khẩu tạm) và khóa tài khoản đang đăng nhập

Giao diện quản lý tài khoản của Admin chưa làm (đang hiện "đang xây dựng"), nên thao tác qua Console của trình duyệt bằng API thật.

**Cấp mật khẩu tạm cho `kh.chau`:**

1. Tab A: đăng nhập `admin.it` ở http://localhost:5001/login, F12 → Console, dán:
   ```js
   const t = (await (await fetch("/api/auth/antiforgery")).json()).xsrfToken;
   const acc = (await (await fetch("/api/admin/accounts?tuKhoa=kh.chau")).json()).find(a => a.tenDangNhap === "kh.chau");
   console.log((await (await fetch(`/api/admin/accounts/${acc.maTK}/reset-password`, { method: "POST", headers: { "X-XSRF-TOKEN": t } })).json()).matKhauTam);
   ```
   → Console in ra mật khẩu tạm. ☐
2. Cửa sổ ẩn danh: đăng nhập `kh.chau` bằng mật khẩu tạm → chuyển ngay tới "Đặt mật khẩu mới". ☐
3. Gõ http://localhost:5000/customer → vẫn bị đưa về trang đổi mật khẩu. ☐
4. Nhập mật khẩu tạm, mật khẩu mới 2 lần, bấm **Lưu và tiếp tục** → vào `/customer`. ☐
5. Trả `kh.chau` về mật khẩu demo: menu **Tài khoản** → đổi mật khẩu từ mật khẩu vừa đặt sang `Demo@2026`.

**Khóa tài khoản đang đăng nhập:**

1. Cửa sổ ẩn danh: đăng nhập `ql.lan`, đang ở `/manager`.
2. Tab Admin (tab A ở trên), Console:
   ```js
   const t2 = (await (await fetch("/api/auth/antiforgery")).json()).xsrfToken;
   await fetch("/api/admin/accounts/3/lock", { method: "PATCH", headers: { "Content-Type": "application/json", "X-XSRF-TOKEN": t2 }, body: JSON.stringify({ khoa: true, lyDo: "Thử khóa" }) });
   ```
3. Quay lại cửa sổ `ql.lan`, bấm sang menu khác → về `/login?het-phien=1`. ☐
4. **Mở khóa lại** (bắt buộc, nếu không `ql.lan` không dùng được nữa):
   ```js
   await fetch("/api/admin/accounts/3/lock", { method: "PATCH", headers: { "Content-Type": "application/json", "X-XSRF-TOKEN": t2 }, body: JSON.stringify({ khoa: false }) });
   ```

### 4.9. Đăng ký thành viên

| # | Thao tác | Kết quả mong đợi | |
|---|---|---|---|
| 1 | Trang đăng nhập chung → **Đăng ký thành viên**, bấm **Tạo tài khoản** khi chưa nhập gì | Báo lỗi ngay dưới từng ô | ☐ |
| 2 | Nhập SĐT `0901000001` (đã có người dùng) | Báo trùng số điện thoại tại ô SĐT | ☐ |
| 3 | Nhập đủ thông tin, SĐT mới, **có email**, chọn vài sở thích, bấm Tạo tài khoản | Tự đăng nhập và vào `/customer` | ☐ |

### 4.10. Lịch sử mua hàng

| # | Thao tác | Kết quả mong đợi | |
|---|---|---|---|
| 1 | Đăng nhập `kh.an`, menu **Lịch sử mua hàng** | Danh sách hóa đơn, tổng chi tiêu | ☐ |
| 2 | Bấm vào một hóa đơn | Mở ra danh sách sản phẩm, giảm giá, đổi trả (nếu có) | ☐ |
| 3 | Chọn Từ ngày lớn hơn Đến ngày | Báo lỗi, nút Lọc bị khóa | ☐ |
| 4 | Lọc khoảng ngày không có hóa đơn | "Chưa có hóa đơn nào trong khoảng thời gian này" | ☐ |
| 5 | Tài khoản mới đăng ký ở 4.9 | "Chưa có hóa đơn nào" | ☐ |

### 4.11. Giao diện điện thoại

F12 → bật **Toggle device toolbar** (Ctrl+Shift+M), chọn iPhone. Kiểm tra trang đăng nhập chung, trang đăng nhập Admin, trang chủ khách hàng, lịch sử mua hàng: không bị tràn ngang, menu mở bằng nút ☰. ☐

---

## 5. Lưu ý khi kiểm thử

- **Giới hạn đăng nhập:** sai quá 5 lần cùng một tài khoản, hoặc quá 30 lần gọi đăng nhập/đăng ký/quên mật khẩu trong 15 phút trên một máy → báo "Tạm khóa đăng nhập". Tắt API (Ctrl+C) và chạy lại để xóa bộ đếm.
- **Dữ liệu bị thay đổi:** mục 4.7, 4.8, 4.9 ghi vào CSDL `CRM_Uniqlo`. Script `08` chỉ chèn dữ liệu khi CSDL còn trống, nên muốn về đúng dữ liệu mẫu ban đầu phải tạo lại CSDL: chạy `99_XoaCSDL_ThuNghiem.sql` (xóa vĩnh viễn CSDL, đọc hướng dẫn ở đầu script trước khi chạy) rồi `01` → `08`, `18`. Thường không cần: chỉ cần đổi mật khẩu các tài khoản đã thử về `Demo@2026` và mở khóa `ql.lan` như hướng dẫn.
- Lỗi "Không kết nối được máy chủ" trên trang đăng nhập: API chưa chạy hoặc chạy sai cổng.
- Quên mật khẩu/lịch sử mua hàng báo lỗi máy chủ: CSDL chưa chạy script `18`.

---

## 6. Kiểm thử tự động

### 6.1. Backend (92 ca)

Cần CSDL `CRM_Uniqlo_Test` (script `11`, chạy sau `18`). Kiểm thử chỉ ghi vào CSDL kiểm thử, không đụng `CRM_Uniqlo`.

```powershell
cd backend
dotnet test
```

Kết quả mong đợi: `Passed: 92, Failed: 0`.

### 6.2. Giao diện đầu cuối (Playwright, 50 ca)

Cần API đang chạy và 2 máy chủ Vite (**cách B**, mục 2). Kịch bản có ghi dữ liệu (khóa/mở `ql.lan`, mật khẩu tạm `kh.chau`, đăng ký khách mới, đặt lại mật khẩu) nên chỉ chạy trên CSDL thử nghiệm.

```powershell
cd frontend
npm i -D playwright
npx playwright install chromium
node tests/e2e/dang-nhap-phan-quyen.cjs
```

Kết quả in ra từng dòng `PASS` / `FAIL`; ảnh chụp lưu ở `frontend/tests/e2e/anh-chup/`. Kết quả lần chạy gần nhất (50/50 PASS) nằm ở `frontend/docs/KetQua_E2E.txt`.

Sau khi chạy, `kh.chau` mang mật khẩu `Chau@2026x`: đăng nhập `kh.chau` / `Chau@2026x`, vào **Tài khoản** đổi về `Demo@2026` trước lần chạy tiếp theo. Khởi động lại API giữa hai lần chạy (giới hạn 30 lần đăng nhập / 15 phút).
