# Hướng dẫn test trang Khách hàng (web-crm, khu vực `/customer`)

Bản 22/10/2026. Tài liệu này dùng để tự kiểm tra 5 chức năng của khách hàng theo đề (III.4) trên giao diện thật, API thật và CSDL dữ liệu mẫu.

## 1. Kết quả đối chiếu 5 chức năng

| # | Chức năng theo đề | CSDL (thủ tục) | API | Giao diện | Trạng thái |
|---|---|---|---|---|---|
| 1 | Đăng ký tài khoản khách hàng | `api_kh.usp_DangKy` | `POST /api/auth/register` | `/register` (nút **Đăng ký thành viên** ở trang đăng nhập) | Đã có đủ, giữ nguyên |
| 8 | Đăng nhập | `api_chung.usp_LayThongTinDangNhap`, `usp_GhiNhanDangNhap` | `POST /api/auth/login` | `/login` (trang chung cho Khách hàng và Quản lý) | Đã có đủ, giữ nguyên |
| 2 | Chỉnh sửa thông tin | `api_kh.usp_XemHoSo`, `usp_CapNhatHoSo` | `GET`, `PUT /api/customer/profile` | **Thông tin cá nhân** → **Chỉnh sửa thông tin** | Đã có DB/API, **mới làm giao diện** |
| 3 | Gửi phản hồi về sản phẩm | `api_kh.usp_GuiPhanHoi`, `usp_XemPhanHoiCuaToi` | `POST`, `GET /api/customer/feedback` | **Phản hồi sản phẩm** | Đã có DB/API, **mới làm giao diện** |
| 4 | Nhận được khảo sát và thực hiện | `api_kh.usp_DanhSachKhaoSat`, `usp_XemKhaoSat`, `usp_NopKhaoSat` (tự phát voucher), `usp_XemVoucherCuaToi` | `GET /surveys`, `GET /surveys/{maKS}`, `POST /surveys/{maKS}/submit`, `GET /vouchers` | **Khảo sát** → mở khảo sát → **Gửi bài khảo sát** | Đã có DB/API, **mới làm giao diện** |

**Thiếu:** chức năng 2, 3, 4 trước đây chỉ là trang "đang xây dựng" (CSDL và API đã có). Đã làm đủ giao diện. Đây cũng là phần "khách làm khảo sát" còn thiếu ở hướng dẫn test trang Quản lý (CN6 ở đó phải dán mã vào Console; giờ làm bằng giao diện).

**Thừa, đã chỉnh:**
- Trang **Voucher của tôi** (menu riêng): voucher trong hệ thống chỉ sinh ra khi khách hoàn thành khảo sát, nên đã gộp vào trang **Khảo sát** (khối "Voucher nhận từ khảo sát") và bỏ menu riêng.
- Trang **Lịch sử mua hàng** (`/customer/orders`): không thuộc 5 chức năng, đã gỡ trang và menu. API `GET /api/customer/purchases` và thủ tục `usp_LichSuGiaoDich` (script 18) vẫn giữ vì được dùng lại cho chức năng 3: form phản hồi đưa **sản phẩm khách đã mua** lên đầu danh sách chọn.

**Giữ lại vì cần cho chức năng chính:** trang chủ khách (hạng, điểm, khảo sát đang chờ, 3 lối tắt chức năng), **Đổi mật khẩu** (thuộc đăng nhập; khách được quản lý cấp mật khẩu tạm bắt buộc đổi lần đầu), **Quên mật khẩu** ở trang đăng nhập.

**CSDL và backend không thay đổi** trong đợt này. Bộ script `CRM_Uniqlo_SQL` (01→08, 18) dùng nguyên như cũ, `backend.zip` chỉ đóng gói lại.

## 2. Chuẩn bị

1. CSDL `CRM_Uniqlo` đã cài (script 01→08 và 18, hoặc `chay_trien_khai_va_kiem_thu.ps1`), Mixed Mode đã bật, User Secrets đã có chuỗi kết nối (README backend mục 2–3). Nên cài lại CSDL trước khi test để có đúng dữ liệu mẫu bên dưới.
2. Giải nén `backend.zip` và `frontend.zip` mới nhất.
3. Chạy backend (cửa sổ PowerShell 1):
   ```powershell
   cd backend
   dotnet run --project src/CrmUniqlo.Api
   ```
4. Chạy giao diện (cửa sổ PowerShell 2):
   ```powershell
   cd frontend
   npm install
   npm run dev:crm
   ```
   Mở `http://localhost:5173/login`. (Hoặc `npm run build` + `npm run publish:api` rồi mở `http://localhost:5000/login`.)

Mật khẩu mọi tài khoản demo: **`Demo@2026`**.

| Tài khoản | Vai trò | Dữ liệu mẫu có sẵn |
|---|---|---|
| `kh.an` | Khách hàng VIP | 2 khảo sát **chờ làm**: số 2 "Đánh giá Áo khoác chần bông siêu nhẹ" (voucher 5%), số 3 "Thăm dò: Áo khoác lông cừu nhân tạo 2026" (voucher 15%); khảo sát số 1 đã làm; 1 voucher đã dùng; 2 phản hồi (1 đã được trả lời) |
| `kh.binh` | Khách hàng VIP | Khảo sát số 3 chờ làm |
| `ql.lan` | Quản lý | Dùng để gửi khảo sát mới và trả lời phản hồi của khách |

Lưu ý: test thủ công **ghi vào CSDL `CRM_Uniqlo`** (đăng ký, sửa hồ sơ, gửi phản hồi, nộp khảo sát). Muốn về lại dữ liệu mẫu ban đầu, chạy lại `chay_trien_khai_va_kiem_thu.ps1`.

## 3. Các bước test thủ công

### CN1. Đăng ký tài khoản khách hàng
1. Mở `/login` → bấm **Đăng ký thành viên**.
2. Bấm **Tạo tài khoản** khi để trống → báo lỗi ngay dưới các ô bắt buộc.
3. Nhập SĐT đã có (`0901000001`) cùng thông tin khác → báo lỗi ở ô SĐT, kèm gợi ý liên hệ cửa hàng.
4. Mật khẩu nhập lại khác → "Mật khẩu nhập lại không khớp."; danh sách điều kiện mật khẩu (≥ 8 ký tự, có chữ, có số) tick dần khi gõ.
5. Nhập đủ: họ tên, SĐT mới (10 số, bắt đầu bằng 0), **email**, ngày sinh, tỉnh, chọn vài sở thích, tên đăng nhập ví dụ `kh.test01`, mật khẩu `KiemThu2026` → **Tạo tài khoản**.
6. **Mong đợi:** tự đăng nhập, vào trang chủ khách "Xin chào, …", hạng **Thường**, 0 điểm, "Còn 500 điểm để lên hạng VIP".

### CN8. Đăng nhập
1. Bấm **Đăng xuất** (góc phải) → xác nhận.
2. Đăng nhập `kh.test01` với mật khẩu sai → "Sai tên đăng nhập hoặc mật khẩu", ô mật khẩu bị xóa.
3. Đăng nhập đúng → vào `/customer`. Menu chỉ có: Trang chủ, Thông tin cá nhân, Phản hồi sản phẩm, Khảo sát, Đổi mật khẩu.
4. Gõ `/manager` → "Bạn không có quyền truy cập trang này". Gõ `/customer/orders` → trang 404 (trang thừa đã gỡ).
5. (Tùy chọn) Đăng nhập `ql.lan` ở cùng trang `/login` → vào khu vực Quản lý: cùng một trang đăng nhập, điều hướng theo vai trò.

### CN2. Chỉnh sửa thông tin
1. Menu **Thông tin cá nhân**: thấy đúng thông tin vừa đăng ký, thẻ hạng và điểm bên phải.
2. **Chỉnh sửa thông tin** → đổi SĐT thành `12345` → **Lưu thay đổi** → lỗi "gồm đúng 10 chữ số" tại ô.
3. Đổi SĐT thành `0901000002` (của khách khác) → lỗi từ CSDL "Số điện thoại hoặc email đã được một hồ sơ khác sử dụng" tại ô SĐT. Sửa lại thì lỗi tự mất.
4. Đổi họ tên, email, giới tính, tỉnh; bấm chọn/bỏ chọn sở thích → **Lưu thay đổi**.
5. **Mong đợi:** thông báo "Đã lưu thông tin cá nhân.", trang quay về chế độ xem với thông tin mới; F5 vẫn giữ. Tên mới hiện ở trang chủ và góc phải. **Hủy** thì bỏ mọi thay đổi chưa lưu.
6. Đối chiếu phía quản lý: đăng nhập `ql.lan` ở cửa sổ ẩn danh → Khách hàng → tìm tên mới → hồ sơ 360° hiện đúng thông tin và sở thích vừa sửa.

### CN3. Gửi phản hồi về sản phẩm
1. Menu **Phản hồi sản phẩm**. Tài khoản mới: "Bạn chưa gửi phản hồi nào."
2. Bấm **Gửi phản hồi** khi để trống → báo lỗi ở Sản phẩm, Loại phản hồi, Đánh giá, Nội dung.
3. Ô Sản phẩm không có sản phẩm **Sắp ra mắt** (chưa bán). Với `kh.an`, nhóm **"Sản phẩm bạn đã mua"** nằm đầu danh sách.
4. Chọn sản phẩm, loại **Góp ý**, chấm **4 sao**, nhập nội dung → **Gửi phản hồi**.
5. **Mong đợi:** "Đã gửi phản hồi. Cảm ơn bạn đã góp ý!", form trống lại, phản hồi hiện đầu danh sách **Phản hồi của tôi** với trạng thái **Đã gửi**.
6. Cửa sổ `ql.lan` → **Phản hồi** → tab Mới thấy phản hồi này → **Tiếp nhận** → khách F5 thấy **Đang xử lý** → quản lý **Trả lời** → khách F5 thấy **Đã trả lời** và khung "Uniqlo trả lời" với nội dung trả lời.

### CN4. Nhận được khảo sát và thực hiện
**Cách nhanh (dữ liệu mẫu):** đăng nhập `kh.an`.
1. Trang chủ có khối **Khảo sát dành cho bạn** (2 khảo sát) và ô "Khảo sát chờ bạn: 2". Bấm tên khảo sát số 2 hoặc vào menu **Khảo sát**.
2. Trang **Khảo sát của tôi**: nhóm **Chờ bạn thực hiện** (số 2, số 3, kèm % voucher và hạn), nhóm **Đã hoàn thành hoặc đã đóng** (số 1), khối **Voucher nhận từ khảo sát** (`V1-A1B2C3D4`, Đã dùng).
3. Mở khảo sát số 2 → bấm **Gửi bài khảo sát** khi chưa trả lời → "Còn … câu bắt buộc chưa trả lời", câu thiếu viền đỏ.
4. Trả lời từng câu: thang điểm bấm 1–5; một lựa chọn chọn 1 ô tròn; nhiều lựa chọn tick 1 hoặc nhiều ô; tự luận gõ chữ (câu "không bắt buộc" có thể bỏ trống). Dòng "Đã trả lời x/y câu" tăng dần.
5. **Gửi bài khảo sát** → **Mong đợi:** "Cảm ơn bạn đã hoàn thành khảo sát!" kèm voucher **-5%**, mã dạng `V2-XXXXXXXX`, hạn dùng 30 ngày.
6. F5: trang hiện "Bạn đã hoàn thành khảo sát này", các câu trả lời bị khóa, không còn nút gửi. Về **Khảo sát**: số 2 sang nhóm Đã hoàn thành, voucher mới ở trạng thái **Còn hạn**; trang chủ "Voucher còn dùng được" tăng 1.
7. Khảo sát số 3 (thăm dò sản phẩm mới) làm tương tự → voucher -15%.

**Cách đầy đủ (quản lý gửi → khách nhận):**
1. `ql.lan` → **Khảo sát** → **Tạo khảo sát** (voucher 10%) → thêm câu hỏi đủ 4 loại → **Chọn đối tượng và gửi**: Hạng = **VIP** → **Gửi khảo sát** (gửi tới `kh.an`, `kh.binh`). Chi tiết ở `HUONG_DAN_TEST_TRANG_QUAN_LY.md` CN6.
2. `kh.binh` đăng nhập → trang chủ và **Khảo sát** thấy ngay khảo sát mới → làm và nộp như trên → nhận voucher 10%.
3. `ql.lan` → **Thống kê** của khảo sát đó: Đã hoàn thành tăng 1, có điểm, lựa chọn và nội dung tự luận vừa nộp.
4. `ql.lan` **Đóng khảo sát** → khách mở lại khảo sát (chưa làm) thấy "Khảo sát đã đóng", không gửi được.

**Bảo mật:** khách chỉ xem được khảo sát gửi cho mình. Ví dụ tài khoản mới đăng ký gõ `/customer/surveys/2` → "Không tìm thấy khảo sát" (API trả 404). Nộp lần hai (gọi thẳng API) bị CSDL từ chối "Bạn đã hoàn thành khảo sát này."

### Giao diện điện thoại
F12 → **Toggle device toolbar** (Ctrl+Shift+M) → iPhone. Kiểm tra trang chủ khách, Thông tin cá nhân, Phản hồi sản phẩm, Khảo sát, làm khảo sát: không tràn ngang, menu mở bằng nút ☰, nút chọn điểm đủ lớn để bấm.

## 4. Các trang đã làm

| Đường dẫn | Nội dung |
|---|---|
| `/register` | CN1 (có sẵn): thông tin cá nhân, sở thích, tên đăng nhập, mật khẩu; xong thì tự đăng nhập |
| `/login` | CN8 (có sẵn): đăng nhập chung, quên mật khẩu, liên kết đăng ký |
| `/customer` | Trang chủ: hạng, điểm, 3 lối tắt chức năng, số khảo sát chờ, voucher còn hạn, khảo sát dành cho bạn |
| `/customer/profile` | CN2: xem và chỉnh sửa thông tin liên hệ, sở thích; thẻ hạng và điểm |
| `/customer/feedback` | CN3: gửi phản hồi (sản phẩm, loại, 1–5 sao, nội dung ≤ 2000 ký tự); danh sách phản hồi của tôi với trạng thái và câu trả lời |
| `/customer/surveys` | CN4: khảo sát chờ làm, đã hoàn thành/đã đóng; voucher nhận từ khảo sát |
| `/customer/surveys/:maKS` | CN4: làm khảo sát (thang điểm, một lựa chọn, nhiều lựa chọn, tự luận), nộp và nhận voucher; xem lại bài đã nộp |
| `/customer/account` | Đổi mật khẩu |

Mã nguồn: `frontend/web-crm/src/pages/customer/` (`ProfilePage.tsx`, `FeedbackPage.tsx`, `SurveysPage.tsx`, `SurveyTakePage.tsx` mới; `CustomerHome.tsx` sửa; `PurchasesPage.tsx` đã xóa) và `frontend/web-crm/src/router.tsx` (menu, route).

## 5. Kết quả kiểm thử tự động (đã chạy 22/10/2026)

Chạy trên SQL Server 2025 với CSDL cài mới từ script 01→08, 18:

| Bộ kiểm thử | Kết quả |
|---|---|
| `08b_KiemTra_SauTrienKhai.sql` | 79/79 PASS |
| Backend `dotnet test` (bản sao `CRM_Uniqlo_Test`) | 92/92 PASS |
| E2E trang Khách hàng `frontend/tests/e2e/trang-khach-hang.cjs` (mới) | **42/42 PASS**, không lỗi JavaScript — `frontend/docs/KetQua_E2E_KhachHang.txt` |
| E2E đăng nhập và phân quyền `dang-nhap-phan-quyen.cjs` (ca lịch sử mua hàng đổi sang form phản hồi) | 50/50 PASS |
| E2E trang Quản lý `trang-quan-ly.cjs` (chạy lại kiểm tra hồi quy) | 39/39 PASS |

Kịch bản E2E trang Khách hàng: đăng ký khách mới (sinh năm 1931 để quản lý gửi khảo sát riêng theo độ tuổi) → đăng xuất, đăng nhập lại → sửa thông tin → gửi phản hồi → quản lý trả lời → khách thấy câu trả lời → quản lý tạo khảo sát 4 loại câu hỏi và gửi → khách làm, nhận voucher 12% → thống kê phía quản lý ghi nhận → khảo sát bị đóng thì không làm được → `kh.an` làm khảo sát mẫu trên màn hình điện thoại. Chạy lại:
```powershell
cd frontend
npm i --no-save playwright
npx playwright install chromium
node tests/e2e/trang-khach-hang.cjs
```
(cần backend và `npm run dev:crm` đang chạy; kịch bản ghi dữ liệu nên chỉ chạy trên CSDL thử nghiệm.)

Ảnh chụp các màn hình: `frontend/docs/anh-chup/khach-hang/`.
