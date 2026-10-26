# CRM Uniqlo – Front-end (đăng nhập và phân quyền)

Nền tảng giao diện cho cả hệ thống: trang đăng nhập chung, đăng ký khách hàng, quên mật khẩu, đổi mật khẩu, bảo vệ route theo cổng và quyền, đăng xuất, hết phiên, xử lý `401 / 403 / 428`. Gọi **backend thật** (`../backend`), không dùng dữ liệu giả.

- **Công nghệ:** React 19 + TypeScript + Vite 7, React Router 7, TanStack Query 5, React Hook Form + Zod, Tailwind CSS 4, lucide-react, font Inter (tự host, có bộ chữ tiếng Việt).
- **Hai ứng dụng** theo đặc tả FrontEnd v1.2 mục 4.5:
  - `web-crm` (dev `:5173`, API `:5000`): `/login`, `/register`, `/forgot-password`, `/change-password`, `/manager/*`, `/customer/*`.
  - `web-admin` (dev `:5174`, API `:5001`): chỉ `/admin/*`. Không có trang đăng nhập riêng, chưa đăng nhập thì chuyển sang `/login` của web-crm.
- `shared/` chứa mã dùng chung (không có trang nghiệp vụ): API client, xác thực, guard, khung trang, thành phần giao diện, design tokens.

## 1. Chạy thử (dev)

Yêu cầu: Node.js 20+ và backend đang chạy (`dotnet run --project src/CrmUniqlo.Api` trong `../backend`, xem README backend).

```powershell
cd frontend
npm install
npm run dev:crm      # http://localhost:5173  (proxy /api → http://localhost:5000)
npm run dev:admin    # http://localhost:5174  (proxy /api → http://localhost:5001), mở cửa sổ terminal thứ 2
```

Mở `http://localhost:5173`. Ở chế độ dev, trang đăng nhập có ô **Tài khoản demo** để điền sẵn (mật khẩu chung `Demo@2026`):

| Tài khoản | Vai trò | Sau đăng nhập |
|---|---|---|
| `kh.an`, `kh.binh` | Khách hàng (VIP) | `/customer` |
| `ql.lan` | Quản lý (đủ quyền QL_*) | `/manager` |
| `cskh.hoa` | NV CSKH (không có Báo cáo, Thêm/Xóa/Khóa khách) | `/manager`, ẩn menu Báo cáo |
| `admin.it` | Admin | chuyển sang web-admin `:5174/admin`, không phải đăng nhập lại |
| `it.mai` | QTV tài khoản (không có Phân quyền) | web-admin, ẩn menu Vai trò và quyền |
| `kh.quyen` | Tài khoản bị khóa | thông báo khóa |

Proxy Vite đổi header `Origin` thành địa chỉ API vì API chặn request ghi có `Origin` khác máy chủ (403 `ORIGIN`). Không cần mở CORS ở backend.

## 2. Build và để API phục vụ

```powershell
npm run build                 # kiểm kiểu TypeScript + build 2 ứng dụng (web-crm/dist, web-admin/dist)
npm run publish:api           # chép dist vào ../backend/src/CrmUniqlo.Api/wwwroot/web-crm và /web-admin
# hoặc: npm run publish:api -- "D:\duong-dan\backend"
```

Sau đó chạy API: `http://localhost:5000` là web-crm, `http://localhost:5001` là web-admin (API tự phục vụ theo cổng, đã có fallback cho SPA). Bản build dùng `.env.production` (địa chỉ 5000/5001, ẩn tài khoản demo). Lưu ý: ngoài môi trường Development, backend đặt cookie `Secure` nên phải chạy qua HTTPS; khi demo trên máy cá nhân bằng HTTP hãy chạy API ở Development.

## 3. Biến môi trường

| Biến | Dev (`.env.development`) | Build (`.env.production`) | Ý nghĩa |
|---|---|---|---|
| `VITE_CRM_URL` | `http://localhost:5173` | `http://localhost:5000` | Gốc web-crm (trang đăng nhập chung) |
| `VITE_ADMIN_URL` | `http://localhost:5174` | `http://localhost:5001` | Gốc web-admin |
| `VITE_SHOW_DEMO_ACCOUNTS` | `true` | `false` | Hiện ô tài khoản demo trên trang đăng nhập |

Đổi địa chỉ API khi dev: `CRM_API=http://localhost:5000 npm run dev:crm`, `ADMIN_API=... npm run dev:admin`.

## 4. Luồng xác thực và phân quyền

```
GET /api/auth/me khi tải trang ──► 200: có phiên │ 401: chưa đăng nhập
POST /api/auth/login (X-XSRF-TOKEN) ──► SessionResponse { cong, phaiDoiMatKhau, quyen[] } + cookie HttpOnly
   phaiDoiMatKhau = true → /change-password?batbuoc=1
   cong = QUAN_LY → /manager · KHACH_HANG → /customer · ADMIN → web-admin /admin
   ?quay-lai=… chỉ được dùng nếu là đường dẫn nội bộ thuộc đúng cổng của phiên (chống open redirect)
```

| Lớp | Cách làm | Tệp |
|---|---|---|
| Phiên | Cookie `crm.auth` HttpOnly do API quản lý; giao diện không lưu token, mật khẩu hay quyền vào localStorage. Thông tin phiên lấy từ `/api/auth/me` (cache 60 giây, tải lại khi quay lại tab). | `shared/src/auth/AuthProvider.tsx` |
| CSRF | Lấy token ở `GET /api/auth/antiforgery`, gửi `X-XSRF-TOKEN` ở mọi request ghi, thay token mới sau đăng nhập/đăng ký/đổi mật khẩu; gặp 400 `CSRF` thì lấy token mới và thử lại 1 lần. | `shared/src/api/client.ts` |
| Route theo cổng | `RequirePortal`: chưa đăng nhập → `/login?quay-lai=…`; khác cổng → trang 403; đang phải đổi mật khẩu → `/change-password`. Gõ URL khu vực khác chỉ thấy trang 403. | `shared/src/auth/guards.tsx` |
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

Đăng xuất: `POST /api/auth/logout` → xóa toàn bộ cache → `/login?da-dang-xuat=1`; các tab khác cùng ứng dụng cũng đăng xuất (BroadcastChannel); trang được khôi phục bằng nút Back sẽ tải lại để kiểm phiên.

Hết phiên do không thao tác: API dùng cookie trượt 30 phút (tối đa 8 giờ). Giao diện mô phỏng cách gia hạn của ASP.NET Core, hiện hộp thoại cảnh báo trước 2 phút (Tiếp tục làm việc / Đăng xuất), hết giờ thì gọi đăng xuất và về `/login?het-phien=1`.

## 5. Phạm vi đã làm và chưa làm

- **Hoạt động đầy đủ với API thật:** đăng nhập, đăng ký khách (kèm tỉnh/thành và sở thích từ `/api/catalog`), đổi mật khẩu (tự nguyện và bắt buộc), đăng xuất, hết phiên, trang 403/404, menu và route theo quyền, trang Tổng quan của 3 khu vực (đọc `/api/manager/dashboard`, `/api/customer/dashboard`, `/api/admin/dashboard`), trang Tài khoản của tôi.
- **Quên mật khẩu:** CSDL chưa có cơ chế token/email (đặc tả L5, G1) nên trang chỉ hướng dẫn liên hệ cửa hàng/quản trị viên, ghi rõ "chưa hỗ trợ", không có nút gửi email giả.
- **Lịch sử mua hàng (khách):** chưa có API, hiện "Chưa hỗ trợ".
- **Các trang nghiệp vụ khác** (khách hàng, phản hồi, khảo sát, báo cáo, tài khoản, vai trò…) đã có route, guard và menu theo quyền, nội dung hiện "đang xây dựng" để các giai đoạn sau làm tiếp.

## 6. Kiểm thử

`tests/e2e/dang-nhap-phan-quyen.cjs` (Playwright) chạy 39 ca trên giao diện thật + API thật + CSDL dữ liệu mẫu: sai mật khẩu, tên không tồn tại, tài khoản khóa, hồ sơ đã xóa, điều hướng 4 vai trò, gõ URL khu vực khác (403), menu theo quyền, đăng xuất + Back, Admin chuyển cổng không đăng nhập lại, `quay-lai` sau đăng nhập, khóa tài khoản đang đăng nhập → hết phiên, mật khẩu tạm → bắt buộc đổi (428), đăng ký (trùng SĐT, thành công), cảnh báo và hết phiên do không thao tác. Kết quả lần chạy gần nhất: **39/39 PASS**, không có lỗi JavaScript. Kịch bản có ghi dữ liệu nên chỉ chạy trên CSDL thử nghiệm.

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
│     ├─ pages/                 Trang 403/404/lỗi, trạng thái rỗng/chưa hỗ trợ, Tài khoản của tôi
│     ├─ ui/                    Button, Field, PasswordInput, Alert, Modal (<dialog>), Toast, KpiCard, Wordmark
│     └─ styles/theme.css       Design tokens (đặc tả 6.1), focus 2px, reduced-motion
├─ web-crm/src/                 router.tsx, pages/auth (Login, Register, ForgotPassword, ChangePassword), pages/manager, pages/customer
├─ web-admin/src/               router.tsx, pages/AdminHome
├─ scripts/copy-dist.mjs        Chép bản build vào wwwroot của API
└─ tests/e2e/                   Kiểm thử đầu cuối
```
