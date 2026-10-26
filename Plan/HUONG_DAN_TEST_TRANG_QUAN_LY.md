# Hướng dẫn test trang Quản lý (web-crm, khu vực `/manager`)

Bản 22/10/2026. Tài liệu này dùng để tự kiểm tra 7 chức năng của người quản lý theo đề (III.4) trên giao diện thật, API thật và CSDL dữ liệu mẫu.

## 1. Kết quả đối chiếu 7 chức năng

| # | Chức năng theo đề | CSDL (thủ tục) | API | Giao diện | Trạng thái |
|---|---|---|---|---|---|
| 1 | Thêm khách hàng mới | `usp_ThemKhachHang`, `usp_CapTaiKhoanKhachHang` | `POST /api/manager/customers`, `POST /customers/{maKH}/account` | Khách hàng → **Thêm khách hàng** | Đã có DB/API, **mới làm giao diện** |
| 2 | Xóa khách hàng | `usp_XoaKhachHang` (xóa mềm, khóa tài khoản, giữ lịch sử) | `DELETE /customers/{maKH}` | Hồ sơ khách → **Xóa khách hàng** | Đã có DB/API, **mới làm giao diện** |
| 3 | Khóa tài khoản khách hàng | `usp_KhoaTaiKhoanKhachHang` (khóa / mở khóa) | `PATCH /customers/{maKH}/lock` | Hồ sơ khách → **Khóa / Mở khóa tài khoản** | Đã có DB/API, **mới làm giao diện** |
| 4 | Tiếp nhận phản hồi | `usp_DanhSachPhanHoi`, `usp_TiepNhanPhanHoi`, `usp_TraLoiPhanHoi` | `GET /feedback`, `POST /feedback/{maPH}/accept`, `/reply` | **Phản hồi** | Đã có DB/API, **mới làm giao diện** |
| 5 | Báo cáo khách hàng: tỷ lệ độ tuổi, sở thích | `usp_BaoCaoCoCauKhachHang`, `usp_BaoCaoSoThich` | `GET /reports/demographics`, `/reports/interests` (+ `?format=csv`) | **Báo cáo** (2 tab) | Đã có DB/API, **mới làm giao diện** |
| 6 | Tạo bảng khảo sát và gửi đến tài khoản khách hàng | `usp_TaoKhaoSat`, `usp_ThemCauHoi`, `usp_XoaCauHoi`, `usp_GuiKhaoSat`, `usp_DongKhaoSat` | `POST /surveys`, `/questions`, `/send-preview`, `/send`, `/close` | **Khảo sát** → Tạo khảo sát → trang chi tiết | Đã có DB/API, **mới làm giao diện** |
| 7 | Thống kê kết quả khảo sát | `usp_ThongKeKhaoSat` | `GET /surveys/{maKS}/stats` | Khảo sát → **Thống kê** | Đã có DB/API, **mới làm giao diện** |

**Thiếu:** cả 7 chức năng chỉ thiếu giao diện (trước đây là trang "đang xây dựng"). Đã làm đủ, xem mục 4.

**Thừa, đã chỉnh:** báo cáo *mức độ hài lòng* (`GET /api/manager/reports/satisfaction`) và khối `haiLong` trong trang Tổng quan không thuộc 7 chức năng, nên đã bỏ khỏi API và giao diện (kiểm thử backend được sửa theo, giờ kiểm tra endpoint này trả 404). Thủ tục `usp_BaoCaoHaiLong` vẫn nằm trong CSDL vì gỡ nó cần thêm script và sửa bộ kiểm thử SQL; API không gọi tới nó nữa.

**Giữ lại vì chức năng chính cần:** tìm kiếm khách và hồ sơ 360° (để chọn khách trước khi xóa/khóa), sửa hồ sơ, cấp tài khoản cho khách chưa có (khảo sát chỉ gửi được tới khách *có tài khoản*), xem trước số người nhận và đóng khảo sát.

**CSDL không thay đổi** trong đợt này, nên không có script mới; bộ script `CRM_Uniqlo_SQL` (01→08, 18) dùng nguyên như cũ.

## 2. Chuẩn bị

1. CSDL `CRM_Uniqlo` đã cài (script 01→08 và 18, hoặc `chay_trien_khai_va_kiem_thu.ps1`), Mixed Mode đã bật, User Secrets đã có chuỗi kết nối (README backend mục 2–3). Nếu `08b` vẫn 79/79 PASS là đủ.
2. Lấy mã mới nhất của `backend` và `frontend` trong thư mục dự án.
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

| Tài khoản | Vai trò | Dùng để |
|---|---|---|
| `ql.lan` | Quản lý, đủ quyền | Test cả 7 chức năng |
| `cskh.hoa` | NV CSKH | Test phân quyền: xem khách, xử lý phản hồi, xem khảo sát; không thêm/xóa/khóa khách, không có Báo cáo |
| `kh.an`, `kh.binh` | Khách hàng VIP | Kiểm tra tác động phía khách (bị khóa, nhận khảo sát) |

Lưu ý: test thủ công **ghi vào CSDL `CRM_Uniqlo`** (thêm/xóa khách, khóa, trả lời phản hồi, gửi khảo sát). Muốn về lại dữ liệu mẫu ban đầu, chạy lại `chay_trien_khai_va_kiem_thu.ps1`.

## 3. Các bước test thủ công

Đăng nhập `ql.lan`. Trang **Tổng quan** có 7 ô lối tắt đánh số 1–7 đúng thứ tự chức năng.

### CN1. Thêm khách hàng mới
1. Menu **Khách hàng** → nút **Thêm khách hàng**.
2. Bấm **Thêm khách hàng** khi để trống → báo lỗi ngay dưới ô Họ tên, Số điện thoại.
3. Nhập SĐT đã có (`0901000001`) → báo "Số điện thoại đã thuộc hồ sơ khác" ở ô SĐT.
4. Nhập đủ: họ tên, SĐT mới (10 số, bắt đầu bằng 0), giới tính, ngày sinh, tỉnh, chọn vài sở thích; giữ tick **Cấp tài khoản ngay**, tên đăng nhập ví dụ `kh.test01` → **Thêm khách hàng**.
5. **Mong đợi:** hiện hộp "Đã cấp tài khoản" với tên đăng nhập và **mật khẩu tạm** (chỉ hiện một lần). Bấm **Xem hồ sơ** thấy đúng thông tin.
6. Mở cửa sổ ẩn danh, đăng nhập `kh.test01` bằng mật khẩu tạm → bị chuyển sang trang **bắt buộc đổi mật khẩu**.
7. Bỏ tick "Cấp tài khoản" khi thêm khách khác → chỉ tạo hồ sơ; vào hồ sơ có nút **Cấp tài khoản** để cấp sau.

### CN2. Xóa khách hàng
1. Mở hồ sơ khách vừa tạo → **Xóa khách hàng**.
2. Nút xác nhận bị khóa khi chưa nhập lý do. Nhập lý do → **Xóa khách hàng**.
3. **Mong đợi:** hồ sơ hiện "Hồ sơ đã bị xóa", các nút thao tác biến mất; khách không còn trong danh sách mặc định; chọn bộ lọc **Trạng thái hồ sơ = Đã xóa** thì thấy lại. Tài khoản của khách bị khóa (đăng nhập báo "Tài khoản đã bị khóa"). Đây là xóa mềm: lịch sử mua hàng, phản hồi, khảo sát vẫn được giữ cho báo cáo.

### CN3. Khóa tài khoản khách hàng
1. **Khách hàng** → tìm "Bình" → mở hồ sơ **Trần Văn Bình** → **Khóa tài khoản**.
2. Nhập lý do → **Khóa tài khoản**. **Mong đợi:** huy hiệu chuyển "Đã khóa", có dòng cảnh báo, nút đổi thành **Mở khóa tài khoản**.
3. Cửa sổ ẩn danh: đăng nhập `kh.binh` → "Tài khoản đã bị khóa". (Nếu `kh.binh` đang đăng nhập ở nơi khác, lần gọi kế tiếp sẽ bị đẩy về trang đăng nhập.)
4. Quay lại → **Mở khóa tài khoản** → `kh.binh` đăng nhập lại được.

### CN4. Tiếp nhận phản hồi
1. Menu **Phản hồi**, tab **Mới** (dữ liệu mẫu có 5 phản hồi mới).
2. Ở một phản hồi: đổi **Phân loại** (ví dụ Góp ý → Khiếu nại) → **Tiếp nhận**. **Mong đợi:** phản hồi rời tab Mới, sang tab **Đang xử lý** với tên người tiếp nhận.
3. Tab **Đang xử lý** → **Trả lời** → nhập nội dung → **Gửi trả lời**. **Mong đợi:** chuyển sang tab **Đã xử lý**, hiện khung nội dung trả lời.
4. Có thể trả lời thẳng từ tab Mới (hệ thống tự ghi nhận tiếp nhận). Lọc theo loại và khoảng ngày hoạt động; "Đến ngày" trước "Từ ngày" thì báo lỗi.

### CN5. Báo cáo độ tuổi, sở thích
1. Menu **Báo cáo**, tab **Độ tuổi và cơ cấu khách hàng**: thẻ tổng số khách, nhóm tuổi đông nhất; biểu đồ **tỷ lệ theo nhóm tuổi** (Dưới 18, 18-24, 25-34, 35-44, 45-54, 55 trở lên, Không rõ), kèm giới tính, hạng, tỉnh/thành. Rê chuột lên thanh để xem số khách.
2. Tab **Sở thích**: tỷ lệ khách quan tâm từng loại sản phẩm; bảng so sánh *quan tâm* với *đã mua* (tỷ lệ chuyển đổi); bảng **sở thích theo nhóm tuổi** (% khách trong nhóm, ô đậm hơn = tỷ lệ cao hơn).
3. Bấm **CSV** ở từng khối → tải tệp mở được bằng Excel (UTF-8 có BOM).
4. Đối chiếu: sau khi thêm khách ở CN1 (có ngày sinh, sở thích), số liệu nhóm tuổi tương ứng tăng; sau khi xóa ở CN2 thì giảm (báo cáo chỉ tính khách đang hoạt động).

### CN6. Tạo khảo sát và gửi tới tài khoản khách hàng
1. Menu **Khảo sát** → **Tạo khảo sát**. Nhập tiêu đề, mục đích *Đo mức độ hài lòng*, hạn trả lời (mặc định 14 ngày tới), voucher 10% → **Tạo khảo sát nháp**.
   - Chọn mục đích *Thăm dò sản phẩm mới* thì bắt buộc chọn một sản phẩm **Sắp ra mắt** (danh sách tự lọc).
2. Trang chi tiết (trạng thái **Nháp**): thêm câu hỏi
   - *Thang điểm 1–5*: "Bạn hài lòng với chất lượng sản phẩm ở mức nào?"
   - *Một lựa chọn*: "Bạn thường mua sắm qua kênh nào?" với 3 lựa chọn (nút **Thêm lựa chọn**; dưới 2 lựa chọn thì nút Thêm câu hỏi bị khóa)
   - *Tự luận*: "Góp ý thêm cho Uniqlo"
   - Thử xóa một câu bằng biểu tượng thùng rác (chỉ được khi còn Nháp).
3. Khối **Chọn đối tượng và gửi**: chọn **Hạng = VIP** → **Xem trước số người nhận** (dữ liệu mẫu: 2 khách) → **Gửi khảo sát**. **Mong đợi:** thông báo "Đã gửi khảo sát tới 2 tài khoản khách hàng", trạng thái **Đã gửi**, không còn thêm/xóa câu hỏi. Gửi lại cùng tiêu chí → 0 người (không gửi trùng). Có thể gửi bổ sung cho nhóm khác.
4. **Kiểm tra phía khách:** cửa sổ ẩn danh đăng nhập `kh.an`, mở `http://localhost:5173/api/customer/surveys` → thấy khảo sát vừa gửi trong danh sách JSON.
5. **Cho khách trả lời** (trang khảo sát phía khách chưa có giao diện): vẫn ở cửa sổ `kh.an`, mở trang `/customer`, nhấn F12 → Console, dán đoạn sau (đổi `MA_KS` thành mã khảo sát, xem trên thanh địa chỉ trang chi tiết):
   ```js
   const MA_KS = 5;
   const t = (await (await fetch("/api/auth/antiforgery")).json()).xsrfToken;
   const ks = await (await fetch(`/api/customer/surveys/${MA_KS}`)).json();
   const traLoi = ks.cauHoi.map((c) =>
     c.loaiCauHoi === "THANG_DIEM" ? { maCauHoi: c.maCauHoi, diemSo: 4 }
     : c.loaiCauHoi === "TU_LUAN" ? { maCauHoi: c.maCauHoi, noiDungTuLuan: "Mong có thêm size lớn." }
     : { maCauHoi: c.maCauHoi, maLC: ks.luaChon.find((l) => l.maCauHoi === c.maCauHoi).maLC });
   const r = await fetch(`/api/customer/surveys/${MA_KS}/submit`, { method: "POST", headers: { "Content-Type": "application/json", "X-XSRF-TOKEN": t }, body: JSON.stringify({ traLoi }) });
   console.log(r.status, await r.json());
   ```
   **Mong đợi:** `200` kèm mã voucher 10%.
6. Quay lại tài khoản `ql.lan` → **Đóng khảo sát** (xác nhận) → trạng thái **Đã đóng**.

### CN7. Thống kê kết quả khảo sát
1. **Khảo sát** → ở khảo sát đã gửi bấm **Thống kê** (hoặc nút **Thống kê kết quả** trong trang chi tiết).
2. **Mong đợi** với khảo sát vừa làm: Đã gửi 2, Đã hoàn thành 1, Tỷ lệ phản hồi 50%, Điểm hài lòng TB 4 / 5; câu thang điểm có phân bố 1–5 điểm; câu một lựa chọn có số lượt và % từng lựa chọn; câu tự luận liệt kê nội dung (ẩn danh khách).
3. Không cần tự trả lời cũng xem được: khảo sát mẫu số 1, 2, 3 đã có sẵn câu trả lời (ví dụ `/manager/surveys/1/stats`: 7 người nhận, 5 hoàn thành).

### Phân quyền (đăng nhập `cskh.hoa`)
- Danh sách khách không có nút **Thêm khách hàng**; hồ sơ không có **Xóa**, **Khóa**, **Sửa**.
- Menu không có **Báo cáo**; gõ `/manager/reports` hoặc `/manager/customers/new` → "Không có quyền truy cập".
- **Phản hồi** vẫn tiếp nhận và trả lời được; **Khảo sát** chỉ xem danh sách và thống kê (không tạo, gửi, đóng).
- Nút chỉ ẩn để tiện dùng: nếu gọi thẳng API (ví dụ `DELETE /api/manager/customers/1`) CSDL vẫn chặn và trả 403.

## 4. Các trang đã làm

| Đường dẫn | Nội dung |
|---|---|
| `/manager` | Tổng quan: số khách, phản hồi mới, khảo sát đang mở, khách VIP; 7 lối tắt chức năng |
| `/manager/customers` | Tìm theo từ khóa, hạng, tỉnh, giới tính, tuổi, sở thích, trạng thái hồ sơ; sắp xếp; phân trang 20 dòng |
| `/manager/customers/new`, `/:maKH/edit` | Thêm (CN1) / sửa hồ sơ, chọn sở thích, cấp tài khoản |
| `/manager/customers/:maKH` | Hồ sơ 360°: thông tin, phản hồi, khảo sát đã nhận, hóa đơn, voucher; nút Xóa (CN2), Khóa/Mở khóa (CN3), Sửa, Cấp tài khoản |
| `/manager/feedback` | CN4: tab theo trạng thái, lọc loại/ngày, tiếp nhận + phân loại lại, trả lời |
| `/manager/reports` | CN5: độ tuổi và cơ cấu; sở thích; tải CSV |
| `/manager/surveys`, `/new`, `/:maKS` | CN6: danh sách, tạo, soạn câu hỏi, xem trước và gửi, đóng |
| `/manager/surveys/:maKS/stats` | CN7: thống kê |

Mã nguồn: `frontend/web-crm/src/pages/manager/`. Thay đổi backend: `ManagerReportsController.cs`, `ManagerDashboardController.cs`, `ManagerModels.cs`, `ManagerTests.cs`, `docs/02_DacTa_API.md`, `requests/CrmUniqlo.http`.

## 5. Kết quả kiểm thử tự động (đã chạy 22/10/2026)

Chạy trên SQL Server 2025 với dữ liệu mẫu (bản sao `CRM_Uniqlo_Test`):

| Bộ kiểm thử | Kết quả |
|---|---|
| `08b_KiemTra_SauTrienKhai.sql` | 79/79 PASS |
| Backend `dotnet test` | 92/92 PASS |
| E2E trang Quản lý `frontend/tests/e2e/trang-quan-ly.cjs` (mới) | 39/39 PASS, không lỗi JavaScript — `frontend/docs/KetQua_E2E_QuanLy.txt` |
| E2E đăng nhập và phân quyền `dang-nhap-phan-quyen.cjs` (cũ, chạy lại để kiểm tra hồi quy) | 50/50 PASS |

Ảnh chụp các màn hình: `frontend/docs/anh-chup/quan-ly/`.

Tự chạy lại E2E trang Quản lý (ghi dữ liệu nên dùng CSDL thử nghiệm: trỏ User Secrets sang `CRM_Uniqlo_Test` hoặc chạy lại script 11 sau đó):
```powershell
cd frontend
npm i --no-save playwright
npx playwright install chromium
npm run dev:crm                       # cửa sổ riêng, backend đang chạy
node tests/e2e/trang-quan-ly.cjs
```
