# CRM Uniqlo – Front-end (đăng nhập và phân quyền)

Nền tảng giao diện cho cả hệ thống: trang đăng nhập chung cho Khách hàng và Quản lý, trang đăng nhập riêng cho Admin, đăng ký khách hàng, quên mật khẩu và đặt lại qua email, đổi mật khẩu, bảo vệ route theo cổng và quyền, đăng xuất, hết phiên, xử lý `401 / 403 / 428`. Gọi **backend thật** (`../backend`), không dùng dữ liệu giả.

- **Công nghệ:** React 19 + TypeScript + Vite 7, React Router 7, TanStack Query 5, React Hook Form + Zod, Tailwind CSS 4, lucide-react, font Inter (tự host, có bộ chữ tiếng Việt).
- **Hai ứng dụng** theo đặc tả FrontEnd v1.2 mục 4.5:
  - `web-crm` (dev `:5173`, API `:5000`): trang đăng nhập chung **chỉ cho Khách hàng và Quản lý/NV CSKH**. `/login`, `/register`, `/forgot-password`, `/dat-lai-mat-khau`, `/change-password`, `/manager/*`, `/customer/*`. Không có `/admin` (gõ URL ra trang 404).
  - `web-admin` (dev `:5174`, API `:5001`): trang đăng nhập **riêng cho Admin**. `/login`, `/forgot-password`, `/dat-lai-mat-khau`, `/change-password`, `/admin/*`. Tài khoản Khách hàng/Quản lý đăng nhập ở đây bị từ chối với cùng thông báo "Sai tên đăng nhập hoặc mật khẩu" (không lộ tài khoản có tồn tại hay thuộc vai trò nào).
- `shared/` chứa mã dùng chung (không có trang nghiệp vụ): API client, xác thực, guard, khung trang, thành phần giao diện, design tokens.

## 1. Chạy thử (dev)

Yêu cầu: Node.js 20+ và backend đang chạy (`dotnet run --project src/CrmUniqlo.Api` trong `../backend`, xem README backend). CSDL cần chạy thêm script `18_BoSung_QuenMatKhau_LichSuMuaHang.sql` cho quên mật khẩu và lịch sử mua hàng.

```powershell
cd frontend
npm install
npm run dev:crm      # http://localhost:5173  (proxy /api → http://localhost:5000)
npm run dev:admin    # http://localhost:5174  (proxy /api → http://localhost:5001), mở cửa sổ terminal thứ 2
```

### Tài khoản demo

Trang đăng nhập không hiện sẵn tài khoản nào; tự gõ tên đăng nhập và mật khẩu dưới đây. Mật khẩu chung của mọi tài khoản demo: **`Demo@2026`**.

**Trang đăng nhập chung (web-crm):** dev `http://localhost:5173/login`, bản build `http://localhost:5000/login`

| Tên đăng nhập | Mật khẩu | Vai trò | Sau đăng nhập |
|---|---|---|---|
| `kh.an` | `Demo@2026` | Khách hàng (VIP) | `/customer` |
| `kh.binh` | `Demo@2026` | Khách hàng (VIP) | `/customer` |
| `kh.chau` | `Demo@2026` | Khách hàng | `/customer` |
| `ql.lan` | `Demo@2026` | Quản lý (đủ quyền QL_*) | `/manager` |
| `cskh.hoa` | `Demo@2026` | NV CSKH (không có Báo cáo, Thêm/Xóa/Khóa khách) | `/manager`, ẩn menu Báo cáo |
| `kh.quyen` | `Demo@2026` | Tài khoản bị khóa | Thông báo "Tài khoản đã bị khóa" |
| `kh.nam` | `Demo@2026` | Hồ sơ khách đã xóa | Không đăng nhập được |

**Trang đăng nhập Admin (web-admin):** dev `http://localhost:5174/login`, bản build `http://localhost:5001/login`

| Tên đăng nhập | Mật khẩu | Vai trò | Sau đăng nhập |
|---|---|---|---|
| `admin.it` | `Demo@2026` | Admin (đủ quyền AD_*) | `/admin` |
| `it.mai` | `Demo@2026` | QTV tài khoản (không có Phân quyền) | `/admin`, ẩn menu Vai trò và quyền |

Gõ tài khoản Admin ở trang chung, hoặc tài khoản Khách hàng/Quản lý ở trang Admin, đều nhận "Sai tên đăng nhập hoặc mật khẩu".

Proxy Vite đổi header `Origin` thành địa chỉ API vì API chặn request ghi có `Origin` khác máy chủ (403 `ORIGIN`). Không cần mở CORS ở backend.

## 2. Build và để API phục vụ

```powershell
npm run build                 # kiểm kiểu TypeScript + build 2 ứng dụng (web-crm/dist, web-admin/dist)
npm run publish:api           # chép dist vào ../backend/src/CrmUniqlo.Api/wwwroot/web-crm và /web-admin
# hoặc: npm run publish:api -- "D:\duong-dan\backend"
```

Sau đó chạy API: `http://localhost:5000` là web-crm, `http://localhost:5001` là web-admin (API tự phục vụ theo cổng, đã có fallback cho SPA). Bản build dùng `.env.production` (địa chỉ 5000/5001). Lưu ý: ngoài môi trường Development, backend đặt cookie `Secure` nên phải chạy qua HTTPS; khi demo trên máy cá nhân bằng HTTP hãy chạy API ở Development.

## 3. Biến môi trường

| Biến | Dev (`.env.development`) | Build (`.env.production`) | Ý nghĩa |
|---|---|---|---|
| `VITE_CRM_URL` | `http://localhost:5173` | `http://localhost:5000` | Gốc web-crm (liên kết "Đến trang đăng nhập chung" trên trang Admin) |
| `VITE_ADMIN_URL` | `http://localhost:5174` | `http://localhost:5001` | Gốc web-admin |

Đổi địa chỉ API khi dev: `CRM_API=http://localhost:5000 npm run dev:crm`, `ADMIN_API=... npm run dev:admin`.

## 4. Luồng xác thực và phân quyền

```
GET /api/auth/me khi tải trang ──► 200: có phiên │ 401: chưa đăng nhập
POST /api/auth/login (X-XSRF-TOKEN) ──► SessionResponse { cong, phaiDoiMatKhau, quyen[] } + cookie HttpOnly
   cổng 5000 (web-crm) chỉ nhận KHACH_HANG, QUAN_LY · cổng 5001 (web-admin) chỉ nhận ADMIN; sai trang → 401 như sai mật khẩu
   phaiDoiMatKhau = true → /change-password?batbuoc=1 (của chính ứng dụng)
   cong = QUAN_LY → /manager · KHACH_HANG → /customer · ADMIN → /admin
   ?quay-lai=… chỉ được dùng nếu là đường dẫn nội bộ thuộc đúng cổng của phiên (chống open redirect)
```

| Lớp | Cách làm | Tệp |
|---|---|---|
| Phiên | Cookie HttpOnly do API quản lý: `crm.auth` cho web-crm, `crm.admin.auth` cho web-admin, nên đăng nhập Admin và Quản lý trên cùng trình duyệt không ghi đè nhau; giao diện không lưu token, mật khẩu hay quyền vào localStorage. Thông tin phiên lấy từ `/api/auth/me` (cache 60 giây, tải lại khi quay lại tab). | `shared/src/auth/AuthProvider.tsx` |
| CSRF | Lấy token ở `GET /api/auth/antiforgery`, gửi `X-XSRF-TOKEN` ở mọi request ghi, thay token mới sau đăng nhập/đăng ký/đổi mật khẩu; gặp 400 `CSRF` thì lấy token mới và thử lại 1 lần. | `shared/src/api/client.ts` |
| Route theo cổng | `RequirePortal`: chưa đăng nhập → `/login?quay-lai=…` của chính ứng dụng; khác cổng → trang 403; đang phải đổi mật khẩu → `/change-password`. Gõ URL khu vực khác chỉ thấy trang 403 (hoặc 404 với `/admin` ở web-crm); web-admin chưa có phiên Admin luôn về trang đăng nhập Admin. | `shared/src/auth/guards.tsx` |
| Route theo quyền | `RequirePermission` đọc `quyen[]` của phiên (bảng route mục 7). Menu chỉ hiện mục có quyền. Thiếu quyền → trạng thái 403 trong khung trang. | `guards.tsx`, `layouts/PortalLayout.tsx` |
| Lớp thật | Guard chỉ phục vụ trải nghiệm. API vẫn kiểm cổng (403/404), CSDL kiểm quyền chức năng (50003) và RLS. | backend |

Xử lý lỗi toàn cục (`client.ts` → `AuthProvider`):

| Phản hồi | Giao diện |
|---|---|
| `401` ở bất kỳ request nào (hết phiên, tài khoản bị khóa/xóa giữa chừng) | Xóa cache dữ liệu, về `/login?het-phien=1&quay-lai=<trang đang xem>` với thông báo "Phiên đăng nhập đã hết" |
| `403` | Trang/khối "Bạn không có quyền…" (lỗi tải dữ liệu) hoặc thông báo trong form |
| `428 PASSWORD_CHANGE_REQUIRED` | Về `/change-password?batbuoc=1` |
| `429` khi đăng nhập | "Bạn đã nhập sai quá nhiều lần. Vui lòng thử lại sau ít phút." |
| Lỗi mạng / `5xx` | Thông báo + nút Thử lại + mã tra cứu (`traceId`), không lộ chi tiết |

Đăng xuất: `POST /api/auth/logout` → xóa toàn bộ cache → `/login?da-dang-xuat=1` của chính ứng dụng (Admin về trang đăng nhập Admin); các tab khác cùng ứng dụng cũng đăng xuất (BroadcastChannel); trang được khôi phục bằng nút Back sẽ tải lại để kiểm phiên.

Hết phiên do không thao tác: API dùng cookie trượt 30 phút (tối đa 8 giờ). Giao diện mô phỏng cách gia hạn của ASP.NET Core, hiện hộp thoại cảnh báo trước 2 phút (Tiếp tục làm việc / Đăng xuất), hết giờ thì gọi đăng xuất và về `/login?het-phien=1`.

## 5. Phạm vi đã làm và chưa làm

- **Hoạt động đầy đủ với API thật:** đăng nhập, đăng ký khách (kèm tỉnh/thành và sở thích từ `/api/catalog`), đổi mật khẩu (tự nguyện và bắt buộc), đăng xuất, hết phiên, trang 403/404, menu và route theo quyền, trang Tổng quan của 3 khu vực (đọc `/api/manager/dashboard`, `/api/customer/dashboard`, `/api/admin/dashboard`), trang Tài khoản của tôi.
- **Quên mật khẩu (L5):** `/forgot-password` gửi tên đăng nhập + email trong hồ sơ, luôn hiện cùng một thông báo (không lộ tài khoản có tồn tại hay không). Email chứa liên kết `/dat-lai-mat-khau#token=…` (30 phút, dùng một lần); trang đặt lại đọc mã sau dấu `#` rồi xóa khỏi thanh địa chỉ, đặt xong về `/login?da-dat-lai=1`. Trang ở web-admin chỉ phục vụ Admin, trang ở web-crm chỉ phục vụ Khách hàng và Quản lý. Khi chạy API ở Development, thư được ghi ra `../backend/src/CrmUniqlo.Api/.mail/*.eml`; liên kết trong thư trỏ về cổng 5000/5001 (bản build), khi chạy Vite dev thì đổi cổng thành 5173/5174 hoặc đặt `Email:ResetUrlCrm` / `Email:ResetUrlAdmin` cho backend.
- **Trang Khách hàng (đủ 5 chức năng, bản 22/10/2026):** CN1 đăng ký `/register`, CN8 đăng nhập `/login` (trang chung), `/customer` (trang chủ: hạng, điểm, khảo sát chờ, lối tắt), `/customer/profile` (CN2 xem và chỉnh sửa thông tin, sở thích), `/customer/feedback` (CN3 gửi phản hồi về sản phẩm: chọn sản phẩm, loại, 1–5 sao, nội dung; xem trạng thái và câu trả lời của cửa hàng; sản phẩm đã mua lấy từ `GET /api/customer/purchases` được xếp lên đầu), `/customer/surveys` và `/customer/surveys/:maKS` (CN4 khảo sát được gửi cho tài khoản, làm đủ 4 loại câu hỏi, nộp bài nhận voucher, xem lại bài đã nộp; danh sách voucher nhận từ khảo sát), `/customer/account` (đổi mật khẩu). Đã gỡ 2 trang ngoài đề: "Voucher của tôi" (gộp vào Khảo sát) và "Lịch sử mua hàng" (`/customer/orders`). Hướng dẫn test: `../HUONG_DAN_TEST_TRANG_KHACH_HANG.md`.
- **Trang Quản lý (đủ 7 chức năng, bản 22/10/2026):** `/manager/customers` (tìm kiếm, lọc, phân trang), `/manager/customers/new` (CN1 thêm khách, tùy chọn cấp tài khoản với mật khẩu tạm), `/manager/customers/:maKH` (hồ sơ 360°, CN2 xóa mềm có lý do, CN3 khóa/mở khóa có lý do, sửa, cấp tài khoản), `/manager/feedback` (CN4 tiếp nhận, phân loại lại, trả lời), `/manager/reports` (CN5 tỷ lệ độ tuổi, giới tính, hạng, tỉnh; sở thích theo loại SP và theo nhóm tuổi; tải CSV), `/manager/surveys`, `/manager/surveys/new`, `/manager/surveys/:maKS` (CN6 tạo khảo sát, thêm/xóa câu hỏi, xem trước số người nhận, gửi tới tài khoản khách, đóng), `/manager/surveys/:maKS/stats` (CN7 thống kê). Nút thao tác ẩn theo quyền; CSDL vẫn kiểm quyền. Hướng dẫn test: `../HUONG_DAN_TEST_TRANG_QUAN_LY.md`.
- **Các trang nghiệp vụ khác của Admin** (tài khoản, vai trò…) đã có route, guard và menu theo quyền, nội dung hiện "đang xây dựng".

## 6. Kiểm thử

`tests/e2e/dang-nhap-phan-quyen.cjs` (Playwright) chạy 50 ca trên giao diện thật + API thật + CSDL dữ liệu mẫu: trang chung không còn ô tài khoản demo và không nhận Admin; trang Admin riêng không nhận Khách hàng/Quản lý; Admin và Quản lý đăng nhập cùng trình duyệt giữ 2 phiên độc lập; sai mật khẩu, tên không tồn tại, tài khoản khóa, hồ sơ đã xóa; điều hướng 4 vai trò; gõ URL khu vực khác (403/404); menu theo quyền; đăng xuất + Back; `quay-lai` sau đăng nhập ở cả 2 trang; khóa tài khoản đang đăng nhập → hết phiên; mật khẩu tạm → bắt buộc đổi (428); đăng ký; cảnh báo và hết phiên do không thao tác; quên mật khẩu → email → đặt lại → đăng nhập bằng mật khẩu mới, dùng lại liên kết bị từ chối; sản phẩm đã mua (lịch sử mua hàng) trong form phản hồi. Kết quả lần chạy gần nhất: **50/50 PASS**, không có lỗi JavaScript. Backend: 92/92 kiểm thử đạt (thêm các ca đăng nhập sai trang, cookie riêng, đặt lại mật khẩu Admin chỉ qua cổng 5001). Kịch bản có ghi dữ liệu nên chỉ chạy trên CSDL thử nghiệm.

`tests/e2e/trang-quan-ly.cjs` (Playwright) chạy 39 ca cho trang Quản lý: 7 chức năng từ đầu đến cuối (thêm khách → khách đăng nhập bằng mật khẩu tạm; khóa kh.binh → kh.binh không đăng nhập được → mở khóa; xóa mềm; tiếp nhận và trả lời phản hồi; báo cáo + CSV; tạo khảo sát 3 loại câu hỏi → gửi khách VIP → kh.an nộp bài → thống kê; đóng khảo sát) và phân quyền NV CSKH (ẩn nút, URL bị chặn, API trả 403). Kết quả: `docs/KetQua_E2E_QuanLy.txt` (**39/39 PASS**), ảnh chụp ở `docs/anh-chup/quan-ly/`.

`tests/e2e/trang-khach-hang.cjs` (Playwright) chạy 42 ca cho trang Khách hàng: đăng ký (lỗi trống, mật khẩu không khớp, SĐT trùng, thành công → tự đăng nhập), đăng nhập (sai mật khẩu, đúng, chặn URL /manager), chỉnh sửa thông tin (SĐT sai, trùng, lưu và tải lại, sở thích), gửi phản hồi → quản lý trả lời → khách thấy câu trả lời, nhận khảo sát do quản lý gửi → làm 4 loại câu hỏi → nhận voucher → không nộp lại được → thống kê phía quản lý, khảo sát đã đóng, khảo sát của người khác trả 404, giao diện điện thoại. Kết quả: `docs/KetQua_E2E_KhachHang.txt` (**42/42 PASS**), ảnh chụp ở `docs/anh-chup/khach-hang/`.

## 7. Cấu trúc

```
frontend/
├─ package.json, tsconfig.base.json, .env.development, .env.production
├─ shared/
│  ├─ vite.shared.ts            Cấu hình Vite chung (proxy /api, alias @shared, tách chunk)
│  └─ src/
│     ├─ api/                   client.ts (fetch + CSRF + sự kiện 401/428), errors.ts (ProblemDetails)
│     ├─ auth/                  AuthProvider, guards, redirect (đích sau đăng nhập, chống open redirect), sessionClock, SessionWatcher
│     ├─ forms/                 Lược đồ Zod khớp ràng buộc API/CSDL, form đổi mật khẩu
│     ├─ layouts/PortalLayout   Topbar + sidebar 240px theo quyền, drawer dưới 1024px, xác nhận đăng xuất
│     ├─ pages/                 Trang 403/404/lỗi, trạng thái rỗng, Tài khoản của tôi
│     │  └─ auth/               AuthLayout (2 biến thể web-crm / web-admin), Login, ForgotPassword, ResetPassword, ChangePassword
│     ├─ ui/                    Button, Field, PasswordInput, Alert, Modal (<dialog>), Toast, KpiCard, Wordmark
│     └─ styles/theme.css       Design tokens (đặc tả 6.1), focus 2px, reduced-motion
├─ web-crm/src/                 router.tsx, pages/auth/Register, pages/manager, pages/customer (trang chủ, thông tin cá nhân, phản hồi, khảo sát)
├─ web-admin/src/               router.tsx (có trang đăng nhập riêng), pages/AdminHome
├─ scripts/copy-dist.mjs        Chép bản build vào wwwroot của API
└─ tests/e2e/                   Kiểm thử đầu cuối
```
