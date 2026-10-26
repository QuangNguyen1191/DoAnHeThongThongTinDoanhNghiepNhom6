# Hướng dẫn test trang Admin (web-admin, khu vực `/admin`)

Bản 22/10/2026. Tài liệu này dùng để tự kiểm tra trang Quản trị trên giao diện thật, API thật và CSDL dữ liệu mẫu.

## 1. Phạm vi chức năng (đề xuất, vì đề chỉ ghi chung)

Đề II.2 yêu cầu: *giao diện Admin tách biệt* và *Admin thêm, xóa, phân quyền cho account*. Mục "tìm kiếm, lọc sản phẩm, nhà cung cấp" đã được giáo viên gạch **(bỏ chức năng này)**. Trang Admin vì vậy gồm 2 nhóm:

**Nhóm A: đúng câu chữ của đề (chấm chính)**

| # | Chức năng | CSDL (thủ tục) | API | Giao diện |
|---|---|---|---|---|
| A1 | Thêm account cho nhân viên | `usp_TaoTaiKhoanNhanVien` | `POST /api/admin/accounts` | Tài khoản → **Tạo tài khoản nhân viên** |
| A2 | Xóa account (giữ hồ sơ, lịch sử) | `usp_XoaTaiKhoan` | `DELETE /accounts/{maTK}` | Tài khoản → **Xóa** |
| A3 | Khóa / mở khóa account | `usp_KhoaMoTaiKhoan` | `PATCH /accounts/{maTK}/lock` | Tài khoản → **Khóa / Mở khóa** |
| A4 | Đặt lại mật khẩu (mật khẩu tạm) | `usp_DatLaiMatKhau` | `POST /accounts/{maTK}/reset-password` | Tài khoản → **Đặt lại MK** |
| A5 | Phân quyền cho account (đổi vai trò) | `usp_DoiVaiTro` | `PUT /accounts/{maTK}/role` | Tài khoản → **Vai trò** |
| A6 | Vai trò và ma trận quyền, tạo vai trò | `usp_DanhSachVaiTroQuyen`, `usp_CapNhatQuyenVaiTro`, `usp_TaoVaiTro` | `GET/POST /roles`, `PUT /roles/{maVT}/permissions` | **Vai trò và quyền** |

**Nhóm B: quản lý tổng bộ (dựa trên những gì CSDL đã có, phục vụ 2 trang Quản lý và Khách hàng)**

| # | Chức năng | Vì sao cần |
|---|---|---|
| B1 | **Nhân viên**: thêm/sửa hồ sơ; chuyển "Đã nghỉ" thì tài khoản tự khóa | Muốn tạo account cho người mới thì phải có hồ sơ nhân viên trước |
| B2 | **Tra cứu khách hàng** (chỉ xem, SĐT/email đã che) | Hỗ trợ kỹ thuật (khách đã có tài khoản chưa, có bị khóa không) mà không lấn việc của Quản lý |
| B3 | **Hóa đơn và đổi trả**: nạp hóa đơn, nạp đổi trả, xét lại hạng | Nguồn điểm và hạng VIP mà trang Quản lý dùng để báo cáo, gửi khảo sát; trang Khách hàng hiển thị hạng |
| B4 | **Nhật ký hệ thống** | Ai làm gì, lúc nào trên cả 3 cổng |
| B5 | **Tổng quan** + **Trạng thái hệ thống** | Số tài khoản theo trạng thái, hoạt động gần đây; kiểm tra 3 kết nối CSDL |

**Không làm (có lý do):**
- *Sản phẩm, nhà cung cấp*: giáo viên đã bỏ. API cũ (`/api/admin/products`, `/suppliers`) vẫn giữ nguyên trong backend nhưng không có giao diện.
- *Nút sao lưu trên web*: login của ứng dụng không có quyền BACKUP (nguyên tắc quyền tối thiểu). Sao lưu/phục hồi làm bằng script `10_SaoLuu.sql`, `10b_PhucHoi.sql` và trình bày trong báo cáo (đề II.1). Trang Trạng thái hệ thống có ghi chú phần này.
- *Nghiệp vụ khách hàng, phản hồi, khảo sát*: thuộc trang Quản lý; Admin là vai trò kỹ thuật.

**Thay đổi so với trước:** trang Admin trước đây chỉ có Tổng quan, các mục khác là trang "đang xây dựng". Đợt này:
- Làm toàn bộ giao diện ở trên.
- Thêm API `POST /api/admin/employees` và `PUT /api/admin/employees/{maNV}`. API này gọi thủ tục `usp_LuuNhanVien` đã có sẵn trong CSDL.
- Thêm 1 ca kiểm thử backend.

**CSDL không thay đổi**, không có script mới.

## 2. Chuẩn bị

1. CSDL `CRM_Uniqlo` đã cài (01→08 và 18), Mixed Mode đã bật, User Secrets có chuỗi kết nối (README backend mục 2–3). Chạy `08b` thấy 79/79 PASS là đủ.
2. Giải nén `backend.zip` và `frontend.zip` mới nhất.
3. Chạy backend (PowerShell 1):
   ```powershell
   cd backend
   dotnet run --project src/CrmUniqlo.Api
   ```
4. Chạy giao diện Admin (PowerShell 2) và giao diện chung (PowerShell 3, để xem tác động sang trang Quản lý/Khách hàng):
   ```powershell
   cd frontend
   npm install
   npm run dev:admin      # http://localhost:5174/login
   ```
   ```powershell
   cd frontend
   npm run dev:crm        # http://localhost:5173/login
   ```
   (Hoặc `npm run build` + `npm run publish:api` rồi mở `http://localhost:5001/login` và `http://localhost:5000/login`.)

Mật khẩu mọi tài khoản demo: **`Demo@2026`**.

| Tài khoản | Trang đăng nhập | Vai trò | Dùng để |
|---|---|---|---|
| `admin.it` | Admin (5174) | Quản trị hệ thống, đủ 6 quyền AD_* | Test tất cả |
| `it.mai` | Admin (5174) | Quản trị viên tài khoản (AD_TAI_KHOAN, AD_TRA_CUU) | Test phân quyền, chống leo thang |
| `cskh.hoa` | Chung (5173) | NV CSKH | Xem quyền đổi có hiệu lực ngay ở trang Quản lý |
| `kh.ha` | Chung (5173) | Khách hàng, hạng Thường | Nạp hóa đơn → lên VIP |

Lưu ý: test thủ công **ghi vào CSDL `CRM_Uniqlo`** (thêm nhân viên, tài khoản, vai trò, hóa đơn). Muốn về lại dữ liệu mẫu, chạy lại `chay_trien_khai_va_kiem_thu.ps1`.

## 3. Các bước test thủ công

Mở `http://localhost:5174/login`, đăng nhập `admin.it`. **Tổng quan** có 4 thẻ số liệu tài khoản, 8 ô lối tắt chức năng đánh số và danh sách hoạt động gần đây.

### Trang đăng nhập riêng
- Ở trang Admin, đăng nhập `ql.lan` hoặc `kh.an` → "Sai tên đăng nhập hoặc mật khẩu" (không lộ tài khoản có tồn tại).
- Ở trang chung (5173), đăng nhập `admin.it` → cũng bị từ chối như vậy.

### B1. Thêm nhân viên (chuẩn bị cho A1)
1. Menu **Nhân viên** → **Thêm nhân viên**. Bấm lưu khi để trống → báo lỗi dưới ô Họ tên, Chức vụ...
2. Nhập Họ tên, Chức vụ *Nhân viên CSKH*, Nơi làm việc *Cửa hàng Quận 1*, SĐT `0912000001` (đã thuộc gd.minh), email mới → báo "SĐT hoặc email nhân viên đã tồn tại".
3. Đổi SĐT mới (10 số, đầu 0) → lưu. **Mong đợi:** nhân viên mới có trong danh sách, cột Tài khoản có liên kết **Tạo tài khoản**.

### A1. Thêm account cho nhân viên
1. Bấm **Tạo tài khoản** ở dòng nhân viên vừa thêm (hoặc menu **Tài khoản** → **Tạo tài khoản nhân viên**). Hộp thoại đã chọn sẵn nhân viên. Danh sách chỉ có nhân viên đang làm và chưa có tài khoản (dữ liệu mẫu có Võ Thanh Tùng, Đặng Mỹ Linh, Hồ Gia Huy).
2. Nhập tên đăng nhập `admin.it` → lỗi "Tên đăng nhập đã tồn tại." ngay dưới ô.
3. Nhập `nv.test01`, vai trò *Nhân viên CSKH (cổng Quản lý)* → **Tạo tài khoản**. **Mong đợi:** hiện **mật khẩu tạm** một lần, có nút Chép.
4. Cửa sổ ẩn danh, trang chung 5173: đăng nhập `nv.test01` bằng mật khẩu tạm → bị chuyển sang trang **bắt buộc đổi mật khẩu**.

### A5. Phân quyền cho account (đổi vai trò)
1. **Tài khoản** → dòng `nv.test01` → **Vai trò** → chọn *Quản lý* → **Lưu vai trò**. **Mong đợi:** cột Vai trò thành *Quản lý / QUAN_LY*.
2. Dòng tài khoản khách hàng (`kh.*`) không có nút Vai trò (khách chỉ có vai trò Khách hàng).
3. Dòng của chính mình (`admin.it`) ghi "Tài khoản của bạn", không có nút nào (không tự khóa, tự xóa, tự hạ quyền).

### A3. Khóa / mở khóa
1. Dòng `nv.test01` → **Khóa**. Nút xác nhận bị khóa khi chưa nhập lý do. Nhập lý do → **Khóa tài khoản**. **Mong đợi:** huy hiệu *Đã khóa* kèm lý do.
2. Đăng nhập `nv.test01` ở trang chung → "Tài khoản đã bị khóa".
3. **Mở khóa** → đăng nhập lại được.

### A4. Đặt lại mật khẩu
1. Dòng `nv.test01` → **Đặt lại MK** → **Đặt lại mật khẩu**. **Mong đợi:** hiện mật khẩu tạm mới.
2. Mật khẩu cũ không đăng nhập được nữa; mật khẩu tạm mới đăng nhập được và phải đổi mật khẩu.

### B1 (tiếp). Nhân viên nghỉ việc → khóa tài khoản
1. **Nhân viên** → **Sửa** nhân viên vừa thêm → Trạng thái *Đã nghỉ*. **Mong đợi:** trước khi lưu hiện cảnh báo "tài khoản nv.test01 sẽ tự động bị khóa".
2. Lưu → vào **Tài khoản**: `nv.test01` *Đã khóa*, lý do "Nhân viên đã nghỉ việc".
3. Thử **Mở khóa** → báo lỗi "Không mở khóa tài khoản của hồ sơ đã xóa hoặc nhân viên đã nghỉ."

### A2. Xóa account
1. Dòng `nv.test01` → **Xóa**. Hộp xác nhận ghi rõ chỉ xóa tài khoản đăng nhập, **hồ sơ và lịch sử vẫn được giữ**.
2. Xác nhận → tài khoản biến khỏi danh sách; ở **Nhân viên**, hồ sơ vẫn còn, cột Tài khoản về "Chưa có".

### A6. Vai trò và ma trận quyền
1. Menu **Vai trò và quyền**: 2 bảng *Cổng Quản trị* và *Cổng Quản lý*, mỗi cột là một vai trò (kèm số tài khoản), mỗi dòng là một quyền. Ô *Phân quyền* của vai trò *Quản trị hệ thống* bị mờ: không tự gỡ quyền phân quyền khỏi vai trò của chính mình.
2. Tick **Xem báo cáo tổng hợp** cho *Nhân viên CSKH* → cột hiện "Chưa lưu" → **Lưu thay đổi**.
3. Đăng nhập `cskh.hoa` ở trang chung → menu có **Báo cáo**. Bỏ tick, lưu, tải lại trang của cskh.hoa → mất menu **Báo cáo**. (Đúng tiêu chí "sửa ma trận quyền và thấy hiệu lực ngay ở Web Quản lý".)
4. **Tạo vai trò** → mã `NV_KHAO_SAT`, tên, cổng *Quản lý* → vai trò mới thành một cột (0 quyền) để tick. Sau đó có thể gán vai trò này cho tài khoản ở bước A5.

### B2. Tra cứu khách hàng
Menu **Tra cứu khách hàng**: SĐT dạng `090xxxx001`, email dạng `an***@example.com`; lọc theo họ tên, hạng; không có nút sửa/xóa.

### B3. Nạp hóa đơn, đổi trả, xét hạng
1. **Hóa đơn, đổi trả** → **Nạp hóa đơn**. Số hóa đơn `HD-TEST-01`, khách *Hoàng Thu Hà* (đang hạng Thường), kênh *Tại cửa hàng*, cửa hàng *Quận 1*, nhân viên bán bất kỳ.
2. Dòng 1 chọn **AK-001** → đơn giá tự điền 1.290.000 (sửa được). Có thể **Thêm dòng** AT-001. Chọn kênh *Online* thì ô cửa hàng và nhân viên ẩn đi.
3. **Nạp hóa đơn**. **Mong đợi:** khung kết quả có tổng tiền, giảm, thành tiền và **Hạng sau khi nạp: VIP**.
4. Đăng nhập `kh.ha` ở trang chung → trang chủ khách hiện hạng **VIP**.
5. Nạp lại cùng số hóa đơn → lỗi "Số hóa đơn đã được nạp trước đó." ngay dưới ô.
6. Danh sách hóa đơn → bấm số hóa đơn → hộp chi tiết có các dòng hàng. Ở **Nạp đổi trả**, chọn dòng, số lượng (nhập lớn hơn phần còn lại thì nút bị khóa), lý do → **Nạp đổi trả** → cột *Đã đổi trả* tăng.
7. **Xét lại hạng** → xác nhận → báo số khách đổi hạng.

### B4. Nhật ký
Menu **Nhật ký**: lọc *Hành động = Tạo tài khoản nhân viên* thấy dòng "Tạo tài khoản nv.test01 ...". Bỏ lọc thấy đủ các thao tác vừa làm: đổi vai trò, khóa, xóa tài khoản, cập nhật quyền, nạp hóa đơn... kèm login CSDL đã dùng (`crm_app_admin`, `crm_app_quanly`...). Lọc theo khoảng ngày và theo tài khoản.

### B5. Trạng thái hệ thống
3 thẻ *Cổng Quản trị / Quản lý / Khách hàng* đều "Kết nối tốt", kèm login SQL, thời gian phản hồi, phiên bản SQL Server. Nút **Kiểm tra lại**.

### Phân quyền: đăng nhập `it.mai`
- Menu chỉ có Tổng quan, **Tài khoản**, Nhân viên (chỉ xem), **Tra cứu khách hàng**, Trạng thái hệ thống, Tài khoản của tôi. Không có Vai trò và quyền, Hóa đơn, Nhật ký.
- Trang Tài khoản không có nút **Tạo tài khoản nhân viên**. Dòng tài khoản nhân viên không có **Vai trò**, **Đặt lại MK**. Dòng khách hàng vẫn có **Đặt lại MK**, **Khóa**, **Xóa**. Đây là chủ ý chống leo thang đặc quyền: nếu it.mai đặt lại được mật khẩu của Quản lý/Admin thì sẽ chiếm được tài khoản đó.
- Gõ `/admin/roles` → "Không có quyền truy cập".
- Nút chỉ ẩn để gọn. Gọi thẳng API đổi vai trò `ql.lan` thành ADMIN thì CSDL vẫn chặn và trả 403.

## 4. Các trang đã làm

| Đường dẫn | Quyền | Nội dung |
|---|---|---|
| `/admin` | — | Tổng quan: số tài khoản, 8 lối tắt, hoạt động gần đây |
| `/admin/accounts` | AD_TAI_KHOAN | A1–A5: danh sách + lọc (từ khóa, loại, vai trò, trạng thái); tạo, khóa/mở, đặt lại MK, đổi vai trò, xóa |
| `/admin/roles` | AD_PHAN_QUYEN | A6: ma trận quyền theo cổng, lưu nhiều vai trò một lần, tạo vai trò |
| `/admin/employees` | AD_TRA_CUU (sửa: AD_DANH_MUC) | B1: danh sách + lọc, thêm/sửa, nghỉ việc |
| `/admin/customers` | AD_TRA_CUU | B2: tra cứu khách (đã che) |
| `/admin/invoices`, `/admin/invoices/new` | AD_NAP_GIAO_DICH | B3: danh sách, chi tiết + đổi trả, nạp hóa đơn, xét hạng |
| `/admin/audit-log` | AD_NHAT_KY | B4: nhật ký, phân trang 50 dòng |
| `/admin/system` | — | B5: 3 kết nối CSDL, ghi chú sao lưu |
| `/admin/account` | — | Đổi mật khẩu của chính mình |

Mã nguồn:
- Giao diện: `frontend/web-admin/src/pages/`. Các thành phần bảng, khối, nhãn, phân trang dùng chung với trang Quản lý được chuyển sang `frontend/shared/src/ui/data.tsx`.
- Backend: `AdminAccountsController.cs`, `AdminModels.cs`, `AdminTests.cs`, `docs/02_DacTa_API.md`, `requests/CrmUniqlo.http`.

## 5. Kết quả kiểm thử tự động (đã chạy 22/10/2026)

Chạy trên SQL Server 2025, CSDL cài mới từ `00_TronBo_TrienKhai.sql`:

| Bộ kiểm thử | Kết quả |
|---|---|
| `08b_KiemTra_SauTrienKhai.sql` | 79/79 PASS |
| Backend `dotnet test` (thêm ca *Employee_create_update_and_quit_locks_account*) | 93/93 PASS |
| E2E trang Admin `frontend/tests/e2e/trang-admin.cjs` (mới) | 54/54 PASS, không lỗi JavaScript — `frontend/docs/KetQua_E2E_Admin.txt` |
| E2E đăng nhập và phân quyền (chạy lại kiểm tra hồi quy) | 50/50 PASS |
| E2E trang Quản lý (chạy lại) | 39/39 PASS |
| E2E trang Khách hàng (chạy lại) | 42/42 PASS |

Ảnh chụp các màn hình: `frontend/docs/anh-chup/admin/` (19 ảnh, dùng được cho báo cáo mục "Thiết kế giao diện").

Tự chạy lại E2E trang Admin. Bộ này ghi dữ liệu nên chạy trên CSDL thử nghiệm: trỏ User Secrets sang `CRM_Uniqlo_Test`, hoặc chạy lại script 11 sau đó. Cần cả 2 máy chủ Vite.
```powershell
cd frontend
npm i --no-save playwright
npx playwright install chromium
npm run dev:admin                     # cửa sổ riêng
npm run dev:crm                       # cửa sổ riêng, backend đang chạy
node tests/e2e/trang-admin.cjs
```
API giới hạn 30 lần đăng nhập mỗi IP trong 15 phút. Nếu chạy liên tiếp nhiều bộ E2E mà gặp lỗi chờ thông báo đăng nhập, hãy khởi động lại backend rồi chạy lại.
