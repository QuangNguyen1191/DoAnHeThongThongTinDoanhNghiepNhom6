# Đặc tả API – CRM Uniqlo Backend

Phiên bản 1.0 (17/10/2026). Tài liệu này mô tả hợp đồng HTTP giữa front-end và backend. Tên thủ tục, tham số và quyền khớp với bộ script CSDL bản 14/10/2026. Khi chạy ở môi trường Development có thêm tài liệu tương tác tại `http://localhost:5000/docs` (Scalar) và OpenAPI JSON tại `/openapi/v1.json`.

## 1. Quy ước chung

| Mục | Quy ước |
|---|---|
| Cổng | `5000` phục vụ web-crm (`/api/auth`, `/api/catalog`, `/api/manager/*`, `/api/customer/*`); `5001` phục vụ web-admin (`/api/auth`, `/api/catalog`, `/api/admin/*`). Gọi sai cổng trả **404**. |
| Định dạng | JSON UTF-8. Khóa camelCase giữ nguyên tên cột CSDL: `MaKH` → `maKH`, `SDT_Che` → `sdt_Che`. |
| Ngày, giờ | Ngày `yyyy-MM-dd`. Thời điểm ISO 8601 có múi giờ, ví dụ `2026-10-17T18:31:27+07:00`. Khi gửi lên có thể kèm múi giờ bất kỳ; API đổi về giờ máy chủ SQL (+07:00). |
| Phân trang | Query `trang` (≥ 1) và `soDong` (1–200; nhật ký và hóa đơn 1–500). Phản hồi `{ items, trang, soDong, tongSoDong }`. |
| Xác thực | Cookie `crm.auth` (HttpOnly, SameSite=Lax, Secure khi triển khai). Hết hạn trượt 30 phút, tối đa 8 giờ kể từ khi đăng nhập. JavaScript không đọc được cookie. |
| Chống CSRF | Mọi request `POST/PUT/PATCH/DELETE` phải có header `X-XSRF-TOKEN`. Token lấy từ `GET /api/auth/antiforgery`, và được trả lại mới trong phản hồi đăng nhập, đăng ký, đổi mật khẩu (`xsrfToken`). Thiếu hoặc sai → **400** `code: "CSRF"`. |
| Origin | Request ghi có header `Origin` khác máy chủ và không nằm trong `Security:AllowedOrigins` → **403** `code: "ORIGIN"`. |
| Đổi mật khẩu bắt buộc | Phiên có `phaiDoiMatKhau = true` gọi `/api/admin|manager|customer/*` → **428** `code: "PASSWORD_CHANGE_REQUIRED"`. |
| Correlation ID | Mọi phản hồi có header `X-Correlation-ID` (client có thể gửi sẵn). Giá trị này là `traceId` trong thân lỗi. |

### 1.1. Thân lỗi (ProblemDetails, RFC 9457)

```json
{ "status": 409, "code": 52002, "title": "Số điện thoại đã thuộc hồ sơ khác.", "field": "sdt", "traceId": "0HNPC8...", "errors": null, "type": "https://httpstatuses.io/409" }
```

`code` là số khi lỗi đến từ CSDL, là chuỗi khi API tự phát hiện. `field` là ô nhập bị lỗi (camelCase) khi xác định được. Lỗi kiểm tra đầu vào (400) có thêm `errors: { "<truong>": ["thông báo"] }`.

### 1.2. Ánh xạ mã lỗi

| Mã | HTTP | Ý nghĩa / cách giao diện xử lý |
|---|---|---|
| `50001`, `50012`, `UNAUTHENTICATED` | 401 | Hết phiên hoặc tài khoản bị khóa/xóa giữa chừng. API xóa cookie. Chuyển `/login`. |
| `50003`, `229`, `33504`, `50013`, `FORBIDDEN` | 403 | Không có quyền (cổng sai, thiếu quyền chức năng, RLS). 229/33504 được ghi log cảnh báo bảo mật. |
| `52002`, `52003`, `52004`, `52072`, `52081` | 409 | Trùng SĐT / email / tên đăng nhập / số hóa đơn / mã. Có `field`. |
| `52030`, `52040`, `52042`, `52080`, `52095`, `NOT_FOUND` | 404 | Không tìm thấy (kể cả khi khách đổi URL sang khảo sát không gửi cho mình). |
| Các `51xxx`, `52xxx` khác | 422 | Vi phạm quy tắc nghiệp vụ; `title` là câu tiếng Việt của CSDL, hiển thị nguyên văn. |
| `VALIDATION` | 400 | Đầu vào sai định dạng (kiểm tra ở API trước khi gọi CSDL). |
| `LOGIN_FAILED` | 401 | Sai tên đăng nhập hoặc mật khẩu (cùng một thông báo cho cả hai). |
| `ACCOUNT_LOCKED` | 403 | Tài khoản bị khóa hoặc hồ sơ đã xóa / nhân viên nghỉ việc. |
| `RATE_LIMIT` | 429 | Quá 5 lần sai / 15 phút theo (IP, tên đăng nhập) hoặc 30 lần gọi đăng nhập/đăng ký / 15 phút theo IP. |
| `WEAK_PASSWORD`, `WRONG_PASSWORD`, `SAME_PASSWORD` | 422 | Mật khẩu không đạt chính sách (≥ 8 ký tự, có chữ và số), mật khẩu cũ sai, mật khẩu mới trùng cũ. |
| Lỗi SQL khác (207, 208, 1205…) | 500 | `title`: "Hệ thống đang gặp sự cố, vui lòng thử lại." Chi tiết chỉ ghi log, tra bằng `traceId`. |

### 1.3. Mật khẩu tạm

Khi Admin tạo tài khoản nhân viên, đặt lại mật khẩu, hoặc Quản lý cấp tài khoản cho khách, API sinh mật khẩu tạm 12 ký tự (chữ hoa, chữ thường, số), băm bcrypt rồi mới gửi xuống CSDL. Mật khẩu tạm được trả về **một lần duy nhất** trong trường `matKhauTam`; CSDL đặt cờ `PhaiDoiMatKhau = 1`.

## 2. Xác thực và danh mục (cả hai cổng)

| Mã | Phương thức, đường dẫn | Đăng nhập | Thủ tục / view | Thân request | Phản hồi thành công |
|---|---|---|---|---|---|
| L6 | `GET /api/auth/antiforgery` | Không | — | — | `200 { xsrfToken }` |
| L1 | `POST /api/auth/login` | Không | `api_chung.usp_LayThongTinDangNhap` (thử lần lượt cổng KH → QL → Admin), bcrypt, `sec.usp_DatNguCanh`, `usp_GhiNhanDangNhap`, `usp_ThongTinPhien` | `{ tenDangNhap, matKhau }` | `200 SessionResponse` + cookie mới |
| L2 | `POST /api/auth/register` | Không (đang đăng nhập → 422 `52010`) | `api_kh.usp_DangKy` (+ TVP `DanhSachMa`) rồi đăng nhập luôn | `{ tenDangNhap, matKhau, hoTen, sdt, gioiTinh?, ngaySinh?, email?, maTinh?, dsLoaiQuanTam?: int[] }` | `201 SessionResponse` + cookie |
| L6 | `GET /api/auth/me` | Có | `api_chung.usp_ThongTinPhien` | — | `200 SessionResponse` |
| L3 | `POST /api/auth/change-password` | Có (kể cả khi phải đổi) | `usp_LayThongTinDangNhap` + bcrypt, `api_chung.usp_DoiMatKhau` | `{ matKhauCu, matKhauMoi }` | `200 SessionResponse` + cookie mới |
| L4 | `POST /api/auth/logout` | Không bắt buộc | — | — | `204` |
| — | `GET /api/catalog/provinces` | Không | `api_chung.vw_TinhThanh` | — | `200 [{ maTinh, tenTinh }]` |
| — | `GET /api/catalog/categories` | Không | `api_chung.vw_LoaiSP` | — | `200 [{ maLoai, tenLoai, moTa }]` |
| — | `GET /api/catalog/products` | Không | `api_chung.vw_SanPham` | — | `200 [{ maSP, maSKU, tenSP, maLoai, tenLoai, chatLieu, moTa, giaNiemYet, trangThai, ngayRaMat }]` |
| — | `GET /api/catalog/tiers` | Không | `api_chung.vw_HangThanhVien` | — | `200 [{ maHang, tenHang, diemToiThieu, moTa }]` |

`SessionResponse`:

```json
{
  "maTK": 3, "tenDangNhap": "ql.lan", "cong": "QUAN_LY", "maVT": "QUAN_LY", "tenVT": "Quản lý",
  "hoTen": "Lê Thị Lan", "chucVu": "Quản lý CSKH", "maKH": null, "maNV": 2, "phaiDoiMatKhau": false,
  "quyen": ["QL_BAO_CAO", "QL_KH_XEM", "..."],
  "quyenChiTiet": [{ "maQuyen": "QL_BAO_CAO", "tenQuyen": "Xem báo cáo" }],
  "xsrfToken": "CfDJ8..."
}
```

`cong` quyết định ứng dụng mở sau đăng nhập: `ADMIN` → web-admin (cổng 5001), `QUAN_LY` → `/manager`, `KHACH_HANG` → `/customer`. Cookie dùng chung cho cả hai cổng nên Admin không phải đăng nhập lại. `quyen` chỉ dùng để ẩn/hiện chức năng; quyền thật luôn do CSDL kiểm.

Ràng buộc đầu vào: `tenDangNhap` 4–50 ký tự không khoảng trắng; `matKhau` đăng nhập 1–128 ký tự; mật khẩu mới ≥ 8 ký tự có chữ và số; `sdt` đúng 10 chữ số bắt đầu bằng 0; `gioiTinh` ∈ `NAM | NU | KHAC`; `ngaySinh` từ 1900 đến hôm nay.

## 3. Cổng Admin (`/api/admin`, chỉ cổng 5001, cookie cổng ADMIN)

| Mã | Phương thức, đường dẫn | Thủ tục | Quyền CSDL | Request | Phản hồi |
|---|---|---|---|---|---|
| A0 | `GET /dashboard?khoang=7` | `usp_DanhSachTaiKhoan`, `usp_XemNhatKy` (song song) | AD_TAI_KHOAN / AD_NHAT_KY theo từng khối | — | `{ khoang, taiKhoan: { tong, hoatDong, daKhoa, nhanVien, khachHang, phaiDoiMatKhau }, nhatKyGanDay: Paged, loi: { taiKhoan, nhatKy } }` (khối thiếu quyền = `null`, lý do ở `loi`) |
| A1 | `GET /accounts?tuKhoa&loaiTK=NV\|KH&maVT&trangThai` | `usp_DanhSachTaiKhoan` | AD_TAI_KHOAN | — | `[{ maTK, tenDangNhap, loaiTK, maVT, tenVT, congTruyCap, trangThai, phaiDoiMatKhau, ngayTao, lanDangNhapCuoi, ngayKhoa, lyDoKhoa, chuTaiKhoan, maNV, maKH }]` |
| — | `GET /employees?tuKhoa&maCV&maCH&trangThai` | `usp_DanhSachNhanVien` | AD_TRA_CUU | — | `[{ maNV, hoTen, maCV, tenCV, maCH, tenCH, sdt, email, ngayVaoLam, trangThai, maTK, tenDangNhap, maVT }]` |
| A2 | `POST /accounts` | `usp_TaoTaiKhoanNhanVien` | AD_TAI_KHOAN + AD_PHAN_QUYEN | `{ maNV, tenDangNhap, maVT }` | `201 { maTK, tenDangNhap, matKhauTam }` |
| A3 | `PATCH /accounts/{maTK}/lock` | `usp_KhoaMoTaiKhoan` | AD_TAI_KHOAN | `{ khoa: true\|false, lyDo? }` (khóa cần lý do) | `204` |
| A4 | `DELETE /accounts/{maTK}` | `usp_XoaTaiKhoan` | AD_TAI_KHOAN | — | `204` |
| A5 | `POST /accounts/{maTK}/reset-password` | `usp_DatLaiMatKhau` | AD_TAI_KHOAN (+ AD_PHAN_QUYEN với tài khoản NV) | — | `200 { maTK, matKhauTam }` |
| A6 | `PUT /accounts/{maTK}/role` | `usp_DoiVaiTro` | AD_PHAN_QUYEN | `{ maVT }` | `204` |
| A7 | `GET /roles?maVT` | `usp_DanhSachVaiTroQuyen` | AD_PHAN_QUYEN | — | `{ vaiTro: [{ maVT, tenVT, loaiTK, congTruyCap, moTa, soTaiKhoan }], quyen: [{ maVT, tenVT, congTruyCap, maQuyen, tenQuyen, duocCap }] }` |
| A7 | `POST /roles` | `usp_TaoVaiTro` | AD_PHAN_QUYEN | `{ maVT (A-Z0-9_), tenVT, congTruyCap: ADMIN\|QUAN_LY, moTa? }` | `201 { maVT }` |
| A7 | `PUT /roles/{maVT}/permissions` | `usp_CapNhatQuyenVaiTro` (+ TVP `DanhSachMaQuyen`) | AD_PHAN_QUYEN | `{ dsQuyen: string[] }` (thay toàn bộ) | `204` |
| A11 | `GET /customers?tuKhoa&maHang` | `usp_TraCuuKhachHang` | AD_TRA_CUU | — | `[{ maKH, hoTen, sdt_Che, email_Che, maHang, trangThaiHoSo, ngayDangKy, maTK, trangThaiTaiKhoan }]` (SĐT, email đã che) |
| A12 | `GET /invoices?soHoaDon&maKH&tuNgay&denNgay&trang&soDong` | `usp_DanhSachHoaDon` | AD_NAP_GIAO_DICH | — | `Paged<{ maHD, soHoaDon, ngayLap, kenhBan, tenCH, nhanVienBan, maKH, tenKhachHang, tongTienHang, phanTramGiam, thanhTien, soLuongDaDoiTra }>` |
| A12 | `GET /invoices/{soHoaDon}` | `usp_DanhSachHoaDon` | AD_NAP_GIAO_DICH | — | `{ hoaDon, chiTiet: [{ maSKU, tenSP, soLuong, donGiaBan, daDoiTra }] }` |
| A13 | `POST /invoices` | `usp_NhapHoaDon` (+ TVP `BangChiTietHoaDon`) | AD_NAP_GIAO_DICH | `{ soHoaDon, maKH, kenhBan: CUA_HANG\|ONLINE, ngayLap, maCH?, maNV?, maCodeVoucher?, chiTiet: [{ maSKU, soLuong, donGiaBan }] }` (CUA_HANG cần maCH và maNV; ONLINE thì bỏ trống) | `201 { maHD, soHoaDon, tongTienHang, phanTramGiam, thanhTien, hangSauKhiNap }` |
| A14 | `POST /returns` | `usp_NhapDoiTra` | AD_NAP_GIAO_DICH | `{ soHoaDon, maSKU, soLuong, lyDo: LOI_SP\|KHONG_VUA\|KHONG_UNG\|KHAC, ngayDoiTra, ghiChu? }` | `201 { maDT }` |
| A14 | `POST /tiers/recalculate` | `usp_XetHangToanBo` | AD_NAP_GIAO_DICH | — | `200 { soKhachDoiHang }` |
| A15 | `GET /audit-logs?tuNgay&denNgay&hanhDong&maTK&trang&soDong` | `usp_XemNhatKy` | AD_NHAT_KY | — | `Paged<{ maNK, thoiGian, maTK, tenDangNhap, nguoiDungCSDL, hanhDong, doiTuong, maDoiTuong, chiTiet }>` |
| A16 | `GET /system` | `SELECT 1` trên 3 kết nối cổng | — | — | `{ ketNoi: [{ cong, ok, thoiGianMs, loi, phienBan }], thoiGianApi }` |

Lỗi nghiệp vụ hay gặp: `52091` không khóa/xóa/hạ quyền Admin cuối cùng có quyền phân quyền; `52094` không tự khóa, tự xóa, tự đổi vai trò, tự đặt lại mật khẩu (dùng L3); `52093` nhân viên không hợp lệ hoặc đã có tài khoản; `52092` vai trò không hợp lệ; `52096`, `52097` vai trò/quyền sai cổng; `52070`–`52076` hóa đơn, voucher, đổi trả không hợp lệ.

Danh mục sản phẩm, nhà cung cấp, cửa hàng, nhân viên (`usp_Tim*`, `usp_Luu*`, `usp_DanhSachDanhMucPhu`) không có endpoint vì đề cập nhật đã bỏ các chức năng này khỏi Admin.

## 4. Cổng Quản lý (`/api/manager`, cổng 5000, cookie cổng QUAN_LY)

Hai vai trò dùng chung: `QUAN_LY` (đủ quyền QL_*) và `NV_CSKH` (xem khách, xử lý phản hồi, xem khảo sát). Gọi chức năng ngoài quyền → 403 `50003`.

| Mã | Phương thức, đường dẫn | Thủ tục | Quyền CSDL | Request | Phản hồi |
|---|---|---|---|---|---|
| Q0 | `GET /dashboard` | `usp_TimKhachHang`, `usp_DanhSachPhanHoi`, `usp_BaoCaoCoCauKhachHang`, `usp_DanhSachKhaoSat`, `usp_BaoCaoHaiLong` (song song) | theo từng khối | — | `{ khachMoi: Paged, phanHoiMoi: Paged, theoHang, khaoSatDangMo, haiLong, loi: {...} }` |
| Q1 | `GET /customers?tuKhoa&maHang&maTinh&gioiTinh&tuoiTu&tuoiDen&maLoaiQuanTam&trangThaiHoSo=HOAT_DONG\|DA_XOA&sapXep=TEN\|NGAY_DK_MOI\|DIEM_CAO&trang&soDong` | `usp_TimKhachHang` | QL_KH_XEM | — | `Paged<{ maKH, hoTen, gioiTinh, tuoi, nhomTuoi, sdt, email, tenTinh, maHang, tenHang, diem, soThich, ngayDangKy, trangThaiHoSo, tenDangNhap, trangThaiTaiKhoan }>` |
| Q2 | `GET /customers/{maKH}` | `usp_XemHoSoKhachHang` (8 result set) | QL_KH_XEM | — | `{ hoSo, soThich, hoaDon, doiTra, phanHoi, khaoSat, voucher, lichSuHang }` |
| Q3 (QL-1) | `POST /customers` | `usp_ThemKhachHang` (+ TVP `DanhSachMa`) | QL_KH_THEM | `{ hoTen, sdt, gioiTinh?, ngaySinh?, email?, maTinh?, dsLoaiQuanTam?, tenDangNhap? }` (có `tenDangNhap` thì cấp luôn tài khoản) | `201 { maKH, maTK, tenDangNhap?, matKhauTam? }` |
| Q4 | `PUT /customers/{maKH}` | `usp_CapNhatKhachHang` | QL_KH_SUA | như Q3 (không có `tenDangNhap`) + `capNhatSoThich: bool` | `204` |
| Q5 | `POST /customers/{maKH}/account` | `usp_CapTaiKhoanKhachHang` | QL_KH_THEM | `{ tenDangNhap }` | `201 { maTK, maKH, tenDangNhap, matKhauTam }` |
| Q6 (QL-2) | `DELETE /customers/{maKH}` | `usp_XoaKhachHang` (xóa mềm, khóa tài khoản) | QL_KH_XOA | `{ lyDo }` | `204` |
| Q7 (QL-3) | `PATCH /customers/{maKH}/lock` | `usp_KhoaTaiKhoanKhachHang` | QL_KH_KHOA | `{ khoa, lyDo? }` | `204` |
| Q8 (QL-4) | `GET /feedback?trangThai=MOI\|DANG_XU_LY\|DA_XU_LY&loaiPH&maSP&tuNgay&denNgay&trang&soDong` | `usp_DanhSachPhanHoi` | QL_PH_XEM | — | `Paged<{ maPH, maKH, tenKhachHang, maHang, maSP, tenSP, tenLoai, loaiPH, diemDanhGia, noiDung, ngayGui, trangThai, maNV_XuLy, nguoiXuLy, ngayTiepNhan, noiDungTraLoi, ngayTraLoi, daMuaSanPham }>` |
| Q8 | `POST /feedback/{maPH}/accept` | `usp_TiepNhanPhanHoi` | QL_PH_XU_LY | `{ loaiPH? }` (phân loại lại) | `204` |
| Q8 | `POST /feedback/{maPH}/reply` | `usp_TraLoiPhanHoi` | QL_PH_XU_LY | `{ noiDungTraLoi }` | `204` |
| Q9 (QL-5) | `GET /reports/demographics[?format=csv&bang=nhomTuoi\|gioiTinh\|tinhThanh\|hang]` | `usp_BaoCaoCoCauKhachHang` | QL_BAO_CAO | — | `{ nhomTuoi, gioiTinh, tinhThanh, hang }` mỗi dòng `{ ..., soKhach, tyLePhanTram }` |
| Q10 | `GET /reports/interests[?format=csv&bang=theoLoai\|theoNhomTuoi]` | `usp_BaoCaoSoThich` | QL_BAO_CAO | — | `{ theoLoai, theoNhomTuoi }` |
| Q11 | `GET /reports/satisfaction?tuNgay&denNgay[&format=csv&bang=theoLoai\|tongQuan\|lyDoDoiTra]` | `usp_BaoCaoHaiLong` | QL_BAO_CAO | — | `{ theoLoai, tongQuan, lyDoDoiTra }` |
| Q12 | `GET /surveys?trangThai=NHAP\|DA_GUI\|DA_DONG&mucDich` | `usp_DanhSachKhaoSat` | một trong QL_KS_* | — | `[{ maKS, tieuDe, mucDich, maSP, tenSP, nguoiTao, ngayTao, ngayPhatHanh, hanTraLoi, phanTramVoucher, trangThai, soCauHoi, soNguoiNhan, soHoanThanh, tyLePhanHoiPhanTram }]` |
| Q12 | `GET /surveys/{maKS}` | `usp_XemChiTietKhaoSat` | một trong QL_KS_* | — | `{ khaoSat, cauHoi: [{ maCauHoi, thuTu, noiDung, loaiCauHoi, batBuoc }], luaChon: [{ maLC, maCauHoi, thuTu, noiDung }] }` |
| Q13 (QL-6) | `POST /surveys` | `usp_TaoKhaoSat` | QL_KS_QUAN_LY | `{ tieuDe, mucDich: DO_HAI_LONG\|THAM_DO_SP_MOI, hanTraLoi, moTa?, maSP? (bắt buộc với thăm dò), phanTramVoucher: 0–50, soNgayHieuLucVoucher: 1–365 }` | `201 { maKS }` |
| Q13 | `POST /surveys/{maKS}/questions` | `usp_ThemCauHoi` (+ TVP `DanhSachLuaChon`) | QL_KS_QUAN_LY | `{ noiDung, loaiCauHoi: MOT_LUA_CHON\|NHIEU_LUA_CHON\|THANG_DIEM\|TU_LUAN, batBuoc, luaChon?: string[] }` | `201 { maCauHoi }` |
| Q13 | `DELETE /questions/{maCauHoi}` | `usp_XoaCauHoi` | QL_KS_QUAN_LY | — | `204` |
| Q14 | `POST /surveys/{maKS}/send-preview` | `usp_GuiKhaoSat @ChiDem = 1` | QL_KS_GUI | `{ maHang?, maTinh?, gioiTinh?, tuoiTu?, tuoiDen?, maLoaiQuanTam?, maLoaiDaMua?, hanTraLoiMoi? }` | `200 { soNguoiNhanMoi }` |
| Q14 | `POST /surveys/{maKS}/send` | `usp_GuiKhaoSat @ChiDem = 0` | QL_KS_GUI | như trên | `200 { soNguoiNhanMoi }` |
| Q14 | `POST /surveys/{maKS}/close` | `usp_DongKhaoSat` | QL_KS_GUI | — | `204` |
| Q15 (QL-7) | `GET /surveys/{maKS}/stats` | `usp_ThongKeKhaoSat` | QL_KS_THONG_KE | — | `{ tongQuan, luaChon, thangDiem, tuLuan }` |

Lỗi nghiệp vụ hay gặp: `52040` không tìm thấy khách; `52041` khách đã có tài khoản; `52043` trạng thái khóa không đổi được; `52050` phản hồi đã xử lý; `52060` thăm dò cần sản phẩm Sắp ra mắt; `52061` lựa chọn không hợp lệ; `52062` chỉ sửa câu hỏi khi Nháp; `52063` khảo sát chưa có câu hỏi, đã đóng hoặc quá hạn.

CSV: thêm `format=csv` và `bang=<tên bảng>` (mặc định bảng đầu tiên). Tệp UTF-8 có BOM để Excel đọc đúng tiếng Việt.

## 5. Cổng Khách hàng (`/api/customer`, cổng 5000, cookie cổng KHACH_HANG)

Không endpoint nào nhận `maKH`. Thủ tục `api_kh` lấy mã khách từ ngữ cảnh phiên (`sec.usp_DatNguCanh`) và RLS chặn dữ liệu của khách khác. Gửi thêm `maKH` trong thân request không có tác dụng.

| Mã | Phương thức, đường dẫn | Thủ tục | Quyền CSDL | Request | Phản hồi |
|---|---|---|---|---|---|
| K0 | `GET /dashboard` | `usp_XemHoSo`, `usp_DanhSachKhaoSat`, `usp_XemVoucherCuaToi`, `usp_XemPhanHoiCuaToi` (song song) | KH_* | — | `{ hoSo, khaoSatChoLam, voucher, phanHoiGanDay, loi }` |
| K1 (KH-2) | `GET /profile` | `usp_XemHoSo` | KH_HO_SO | — | `{ hoSo: { maKH, hoTen, gioiTinh, ngaySinh, tuoi, sdt, email, maTinh, tenTinh, ngayDangKy, maHang, tenHang, diem, hangKeTiep, diemCanThem }, soThich: [{ maLoai, tenLoai }] }` |
| K2 (KH-2) | `PUT /profile` | `usp_CapNhatHoSo` | KH_HO_SO | `{ hoTen, sdt, gioiTinh?, ngaySinh?, email?, maTinh?, capNhatSoThich, dsLoaiQuanTam? }` | `204` |
| K3 | `GET /vouchers` | `usp_XemVoucherCuaToi` | KH_HO_SO | — | `[{ maCode, phanTramGiam, ngayPhat, hanDung, tuKhaoSat, trangThai }]` |
| K4 | `GET /surveys` | `usp_DanhSachKhaoSat` | KH_KHAO_SAT | — | `[{ maKS, tieuDe, moTa, mucDich, hanTraLoi, phanTramVoucher, ngayGui, ngayHoanThanh, trangThai, coTheThucHien }]` |
| K5 (KH-4) | `GET /surveys/{maKS}` | `usp_XemKhaoSat` | KH_KHAO_SAT | — | `{ khaoSat, cauHoi, luaChon, traLoiCuaToi }`; khảo sát không gửi cho mình → 404 `52030` |
| K5 (KH-4) | `POST /surveys/{maKS}/submit` | `usp_NopKhaoSat` (+ TVP `BangTraLoi`) | KH_KHAO_SAT | `{ traLoi: [{ maCauHoi, maLC? , diemSo? (1–5), noiDungTuLuan? }] }` (câu nhiều lựa chọn gửi nhiều dòng cùng `maCauHoi`) | `200 { hoanThanh: true, thongBao, voucher: { maCode, phanTramGiam, hanDung } \| null }` |
| K6 (KH-3) | `POST /feedback` | `usp_GuiPhanHoi` | KH_PHAN_HOI | `{ maSP, loaiPH: KHEN\|GOP_Y\|KHIEU_NAI, diemDanhGia: 1–5, noiDung }` | `201 { maPH }` |
| K7 (KH-3) | `GET /feedback` | `usp_XemPhanHoiCuaToi` | KH_PHAN_HOI | — | `[{ maPH, maSP, tenSP, loaiPH, diemDanhGia, noiDung, ngayGui, trangThai, noiDungTraLoi, ngayTraLoi }]` |

Lỗi nghiệp vụ hay gặp: `52031` đã hoàn thành / khảo sát đã đóng hoặc hết hạn; `52032` thiếu câu bắt buộc, lựa chọn sai, câu không thuộc khảo sát; `52020` sản phẩm không tồn tại; `52002`/`52003` SĐT/email trùng khi sửa hồ sơ.

## 6. Mẫu request / response

```http
GET /api/auth/antiforgery                          → 200 { "xsrfToken": "CfDJ8..." }

POST /api/auth/login
X-XSRF-TOKEN: CfDJ8...
{ "tenDangNhap": "ql.lan", "matKhau": "Demo@2026" }  → 200 SessionResponse (+ Set-Cookie crm.auth)

POST /api/manager/surveys/12/send-preview
X-XSRF-TOKEN: <xsrfToken từ phản hồi đăng nhập>
{ "maHang": "VIP", "maLoaiQuanTam": 6, "tuoiTu": 25, "tuoiDen": 34 }
→ 200 { "soNguoiNhanMoi": 3 }

POST /api/customer/surveys/2/submit
{ "traLoi": [ { "maCauHoi": 4, "maLC": 9 }, { "maCauHoi": 5, "diemSo": 4 }, { "maCauHoi": 6, "noiDungTuLuan": "Áo mặc mát" } ] }
→ 200 { "hoanThanh": true, "thongBao": "Đã ghi nhận bài khảo sát.", "voucher": { "maCode": "…", "phanTramGiam": 5, "hanDung": "2026-11-15T23:59:59+07:00" } }
→ 422 { "status": 422, "code": 52032, "title": "Chưa trả lời đủ các câu hỏi bắt buộc.", "traceId": "…" }
```

Bộ request đầy đủ để chạy thử: `requests/CrmUniqlo.http`.
