/* =====================================================================
   Script 08: Dữ liệu mẫu (demo)
   ---------------------------------------------------------------------
   - Toàn bộ là dữ liệu GIẢ (tên, SĐT 0901xxxxxx/0912xxxxxx, email @example.com).
   - Mật khẩu demo của MỌI tài khoản: Demo@2026 (đã băm bcrypt cost 10; CSDL
     chỉ lưu chuỗi băm). Đổi/ xóa trước khi triển khai thật.
   - Chỉ chạy khi CSDL chưa có tài khoản nào (tránh chèn trùng).
   - Ngày của khảo sát đang mở và voucher còn hạn được tính TƯƠNG ĐỐI theo
     thời điểm chạy script để demo luôn hợp lệ; dữ liệu lịch sử dùng ngày cố định 2026.
   ===================================================================== */
USE CRM_Uniqlo;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
IF EXISTS (SELECT 1 FROM crm.TAI_KHOAN)
BEGIN
    PRINT N'CSDL đã có dữ liệu tài khoản – bỏ qua script dữ liệu mẫu.';
    SET NOEXEC ON;
END
GO

BEGIN TRAN;
DECLARE @Nay DATETIME2(0) = SYSDATETIME();

/* ---------- Vai trò demo do Admin tạo (minh họa phân quyền theo account) ---------- */
INSERT crm.VAI_TRO (MaVT, TenVT, LoaiTK, CongTruyCap, MoTa) VALUES
 ('NV_CSKH',       N'Nhân viên CSKH',          'NV', 'QUAN_LY', N'Cổng Quản lý nhưng chỉ xem KH và xử lý phản hồi'),
 ('QTV_TAI_KHOAN', N'Quản trị viên tài khoản', 'NV', 'ADMIN',   N'Cổng Admin nhưng chỉ quản lý tài khoản và tra cứu');
INSERT crm.VAI_TRO_QUYEN (MaVT, MaQuyen, CongTruyCap) VALUES
 ('NV_CSKH', 'QL_KH_XEM', 'QUAN_LY'), ('NV_CSKH', 'QL_PH_XEM', 'QUAN_LY'),
 ('NV_CSKH', 'QL_PH_XU_LY', 'QUAN_LY'), ('NV_CSKH', 'QL_KS_THONG_KE', 'QUAN_LY'),
 ('QTV_TAI_KHOAN', 'AD_TAI_KHOAN', 'ADMIN'), ('QTV_TAI_KHOAN', 'AD_TRA_CUU', 'ADMIN');

/* ---------- Tài khoản (mật khẩu demo Demo@2026, lưu dạng bcrypt) ---------- */
SET IDENTITY_INSERT crm.TAI_KHOAN ON;
INSERT crm.TAI_KHOAN (MaTK, TenDangNhap, MatKhauHash, MaVT, LoaiTK, TrangThai, PhaiDoiMatKhau, NgayTao, NgayKhoa, LyDoKhoa) VALUES
 (1, 'admin.it', '$2b$10$Mt1cv.f2n700Js7Wlag.qeqYb/5KzW1c8cFcQBeGFy5DVu1/WIOae', 'ADMIN', 'NV', 'HOAT_DONG', 0, '2025-06-01 08:00', NULL, NULL),
 (2, 'gd.minh', '$2b$10$RKMe3N3rw4oJkdYxz/5suuom9.8oasuxxRNqUzjnWTNt2pDZIDHiu', 'QUAN_LY', 'NV', 'HOAT_DONG', 0, '2025-06-01 08:05', NULL, NULL),
 (3, 'ql.lan', '$2b$10$/SLZ2eJQOGoX6WN9Hfs77Odzv7RXEi5zMz7pIPIEnB.lSkF7K6zKa', 'QUAN_LY', 'NV', 'HOAT_DONG', 0, '2025-06-01 08:10', NULL, NULL),
 (4, 'cskh.hoa', '$2b$10$uXC20TGLBGzAbDTMKPKARuNoBmNrHLtAb.sgSgVlTHt8N3qP6HgxK', 'NV_CSKH', 'NV', 'HOAT_DONG', 0, '2025-06-02 09:00', NULL, NULL),
 (5, 'it.mai', '$2b$10$Xg69r5cIM9kJFmw5Rj2r/uF2dbQowOOlD0PE17lwVOHBleHITzP26', 'QTV_TAI_KHOAN', 'NV', 'HOAT_DONG', 0, '2025-07-01 09:00', NULL, NULL),
 (6, 'kh.an', '$2b$10$eWVBe5JjKzcJ3s5c5Dp.qONhinFmd.WUOt4pxxo21gSz3pOEDaWr.', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2025-11-02 10:00', NULL, NULL),
 (7, 'kh.binh', '$2b$10$jOLmg4cTMASkM9Tg4Zf1DurXlnKqVhk5syDZIPL2uuWb398uPWjtC', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2025-12-15 11:00', NULL, NULL),
 (8, 'kh.chau', '$2b$10$S9YpmhYkMcJ7lHNTXx9VDO.Cg4NSKQXxjpBMiTNfbeuTAYzNoNTdW', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2026-01-20 12:00', NULL, NULL),
 (9, 'kh.dung', '$2b$10$A/RlSAn4Uul/flCT1OMq2e4YN6Tkmrhjci.k0Sxh.3EbO7bZ0Qyq2', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2026-02-03 13:00', NULL, NULL),
 (10, 'kh.ha', '$2b$10$SzvyiKE.kiVzAm7r/tIO9OvLkH273LLBM98bejsPy9JzT.o.UntPa', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2026-02-10 14:00', NULL, NULL),
 (11, 'kh.khanh', '$2b$10$NPQYZSFk4rwVJhtupUlzfOS5vNJO0r6rGs4KJnzgFScnjIxhJx6u.', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2026-03-01 15:00', NULL, NULL),
 (12, 'kh.lananh', '$2b$10$/aEJAbYgP/HsSgt7PniHHeJJAyXaiFPYtYElmjCSJBaL5a1XUy/N2', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2026-04-05 16:00', NULL, NULL),
 (13, 'kh.phong', '$2b$10$74vfMdcY3lDY3wdh5TJH3eC4kt5V6bSNXVe.pmBFw5B6vK//3GnsS', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2026-04-18 17:00', NULL, NULL),
 (14, 'kh.quyen', '$2b$10$raX85zd8/PsHe0OUzC1sIu/NLwdKkaXU5BZLXDAR76.WVRyVEaf0.', 'KHACH_HANG', 'KH', 'DA_KHOA', 0, '2026-03-20 18:00', '2026-09-01 09:30', N'Đăng nhập bất thường nhiều lần, chờ xác minh'),
 (15, 'kh.nam', '$2b$10$q9tU8HEP80oGR7YXc1QedevbI4izV6omYjSZ6JUAfI6drMrUqqzNG', 'KHACH_HANG', 'KH', 'DA_KHOA', 0, '2026-01-05 19:00', '2026-06-30 10:00', N'Hồ sơ khách hàng đã bị xóa'),
 (16, 'kh.thao', '$2b$10$eqV9Z55t2Qo9FZ2.Fw/mvO7r0kMUYtwtL4XGldduTtCCWHY3aBFl.', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2026-05-22 20:00', NULL, NULL);
SET IDENTITY_INSERT crm.TAI_KHOAN OFF;

/* ---------- Cửa hàng, nhân viên ---------- */
SET IDENTITY_INSERT crm.CUA_HANG ON;
INSERT crm.CUA_HANG (MaCH, TenCH, DiaChi, MaTinh, SDT) VALUES
 (1, N'Cửa hàng Quận 1',    N'Số 10 Đường A, Quận 1',       'HCM', '02800000001'),
 (2, N'Cửa hàng Hoàn Kiếm', N'Số 20 Phố B, Quận Hoàn Kiếm', 'HN',  '02400000002'),
 (3, N'Cửa hàng Hải Châu',  N'Số 30 Đường C, Quận Hải Châu', 'DN', '02360000003');
SET IDENTITY_INSERT crm.CUA_HANG OFF;

/* Giám đốc là một nhân viên có chức vụ GIAM_DOC (không có bảng riêng).
   Chức vụ và vai trò hệ thống độc lập: NV4 (IT) mang vai trò ADMIN, GĐ mang vai trò QUAN_LY. */
SET IDENTITY_INSERT crm.NHAN_VIEN ON;
INSERT crm.NHAN_VIEN (MaNV, HoTen, MaCV, MaCH, SDT, Email, NgayVaoLam, TrangThai, MaTK) VALUES
 (1, N'Nguyễn Văn Minh', 'GIAM_DOC',    NULL, '0912000001', 'minh.nguyen@nv.example.com', '20200102', 'DANG_LAM', 2),
 (2, N'Lê Thị Lan',      'QL_CSKH',     1,    '0912000002', 'lan.le@nv.example.com',      '20210315', 'DANG_LAM', 3),
 (3, N'Phạm Thu Hoa',    'NV_CSKH',     1,    '0912000003', 'hoa.pham@nv.example.com',    '20230601', 'DANG_LAM', 4),
 (4, N'Trần Quốc Bảo',   'NV_IT',       NULL, '0912000004', 'bao.tran@nv.example.com',    '20220910', 'DANG_LAM', 1),
 (5, N'Võ Thanh Tùng',   'NV_BAN_HANG', 1,    '0912000005', 'tung.vo@nv.example.com',     '20240201', 'DANG_LAM', NULL),
 (6, N'Đặng Mỹ Linh',    'NV_BAN_HANG', 2,    '0912000006', 'linh.dang@nv.example.com',   '20240512', 'DANG_LAM', NULL),
 (7, N'Hồ Gia Huy',      'NV_BAN_HANG', 3,    '0912000007', 'huy.ho@nv.example.com',      '20250106', 'DANG_LAM', NULL),
 (8, N'Ngô Thị Mai',     'NV_IT',       NULL, '0912000008', 'mai.ngo@nv.example.com',     '20250701', 'DANG_LAM', 5);
SET IDENTITY_INSERT crm.NHAN_VIEN OFF;

/* ---------- Nhà cung cấp, loại sản phẩm, sản phẩm ---------- */
SET IDENTITY_INSERT crm.NHA_CUNG_CAP ON;
INSERT crm.NHA_CUNG_CAP (MaNCC, TenNCC, QuocGia, DiaChi, SDT, Email, TrangThai) VALUES
 (1, N'Công ty TNHH Dệt May Phương Nam',      N'Việt Nam',   N'KCN Tân Bình, TP. Hồ Chí Minh', '02838000001',    'lienhe@phuongnam.example.com', 'DANG_HOP_TAC'),
 (2, N'Công ty CP May Sông Hồng Xanh',        N'Việt Nam',   N'KCN Phố Nối, Hưng Yên',          '02213000002',    'sales@songhongxanh.example.com', 'DANG_HOP_TAC'),
 (3, N'Dong A Textile Co., Ltd.',              N'Trung Quốc', N'Quảng Châu',                     '+86 20 0000 0003', 'export@donga.example.com',     'DANG_HOP_TAC'),
 (4, N'Công ty TNHH Phụ Kiện Thời Trang Mai Anh', N'Việt Nam', N'Quận 5, TP. Hồ Chí Minh',        '02838000004',    'info@maianh.example.com',       'NGUNG_HOP_TAC');
SET IDENTITY_INSERT crm.NHA_CUNG_CAP OFF;

SET IDENTITY_INSERT crm.LOAI_SP ON;
INSERT crm.LOAI_SP (MaLoai, TenLoai, MoTa) VALUES
 (1, N'Áo thun', NULL), (2, N'Áo khoác', NULL), (3, N'Quần jeans', NULL), (4, N'Quần âu/kaki', NULL),
 (5, N'Đầm/váy', NULL), (6, N'Đồ mặc nhà', NULL), (7, N'Phụ kiện', NULL);
SET IDENTITY_INSERT crm.LOAI_SP OFF;

SET IDENTITY_INSERT crm.SAN_PHAM ON;
INSERT crm.SAN_PHAM (MaSP, MaSKU, TenSP, MaLoai, MaNCC, ChatLieu, GiaNiemYet, TrangThai, NgayRaMat) VALUES
 (1,  'AT-001', N'Áo thun cotton cổ tròn nam',        1, 1, N'100% cotton',          249000,  'DANG_BAN',   NULL),
 (2,  'AT-002', N'Áo thun cotton cổ tròn nữ',         1, 1, N'100% cotton',          249000,  'DANG_BAN',   NULL),
 (3,  'AT-003', N'Áo polo vải pique nam',             1, 2, N'Cotton pique',         399000,  'DANG_BAN',   NULL),
 (4,  'AK-001', N'Áo khoác chần bông siêu nhẹ',       2, 2, N'Nylon, lông vũ',       1290000, 'DANG_BAN',   NULL),
 (5,  'AK-002', N'Áo khoác gió chống nước',           2, 3, N'Polyester',            799000,  'DANG_BAN',   NULL),
 (6,  'QJ-001', N'Quần jeans dáng slim nam',          3, 3, N'Denim co giãn',        799000,  'DANG_BAN',   NULL),
 (7,  'QJ-002', N'Quần jeans ống rộng nữ',            3, 3, N'Denim',                899000,  'DANG_BAN',   NULL),
 (8,  'QK-001', N'Quần kaki co giãn',                 4, 1, N'Cotton, spandex',      599000,  'DANG_BAN',   NULL),
 (9,  'DV-001', N'Đầm suông vải lanh',                5, 2, N'Linen',                699000,  'DANG_BAN',   NULL),
 (10, 'DM-001', N'Bộ mặc nhà vải modal',              6, 1, N'Modal',                499000,  'DANG_BAN',   NULL),
 (11, 'PK-001', N'Mũ lưỡi trai cotton',               7, 4, N'Cotton',               199000,  'NGUNG_BAN',  NULL),
 (12, 'PK-002', N'Túi đeo chéo mini',                 7, 3, N'Polyester',            299000,  'DANG_BAN',   NULL),
 (13, 'AK-003', N'Áo khoác lông cừu nhân tạo 2026',   2, 2, N'Polyester fleece',     990000,  'SAP_RA_MAT', '20261120'),
 (14, 'AT-004', N'Áo thun làm mát thế hệ mới',        1, 1, N'Sợi làm mát',          299000,  'SAP_RA_MAT', '20261201');
SET IDENTITY_INSERT crm.SAN_PHAM OFF;

/* ---------- Khách hàng: một bảng cho cả thường và VIP; hạng do hệ thống xét ở cuối script ---------- */
SET IDENTITY_INSERT crm.KHACH_HANG ON;
INSERT crm.KHACH_HANG (MaKH, HoTen, GioiTinh, NgaySinh, SDT, Email, MaTinh, NgayDangKy, MaTK, TrangThaiHoSo, NgayXoa) VALUES
 (1, N'Nguyễn Thị An', 'NU', '19980412', '0901000001', 'an.nguyen@example.com', 'HCM', '2025-11-02 10:00', 6, 'HOAT_DONG', NULL),
 (2, N'Trần Văn Bình', 'NAM', '19900923', '0901000002', 'binh.tran@example.com', 'HN', '2025-12-15 11:00', 7, 'HOAT_DONG', NULL),
 (3, N'Lê Minh Châu', 'NU', '20030130', '0901000003', 'chau.le@example.com', 'HCM', '2026-01-20 12:00', 8, 'HOAT_DONG', NULL),
 (4, N'Phạm Quốc Dũng', 'NAM', '19850605', '0901000004', 'dung.pham@example.com', 'DN', '2026-02-03 13:00', 9, 'HOAT_DONG', NULL),
 (5, N'Hoàng Thu Hà', 'NU', '19951111', '0901000005', 'ha.hoang@example.com', 'HCM', '2026-02-10 14:00', 10, 'HOAT_DONG', NULL),
 (6, N'Vũ Đức Khánh', 'NAM', '19780317', '0901000006', NULL, 'HN', '2026-03-01 15:00', 11, 'HOAT_DONG', NULL),
 (7, N'Đỗ Ngọc Lan Anh', 'NU', '20060721', '0901000007', 'lananh.do@example.com', 'CT', '2026-04-05 16:00', 12, 'HOAT_DONG', NULL),
 (8, N'Bùi Thanh Phong', 'NAM', '19681202', '0901000008', 'phong.bui@example.com', 'HP', '2026-04-18 17:00', 13, 'HOAT_DONG', NULL),
 (9, N'Phan Mỹ Quyên', 'NU', '20000228', '0901000009', 'quyen.phan@example.com', 'HCM', '2026-03-20 18:00', 14, 'HOAT_DONG', NULL),
 (10, N'Đinh Gia Bảo', 'NAM', NULL, '0901000010', NULL, 'DN', '2026-08-08 15:30', NULL, 'HOAT_DONG', NULL),
 (11, N'Lý Hoài Nam', 'NAM', '19930509', '0901000011', 'nam.ly@example.com', 'HN', '2026-01-05 19:00', 15, 'DA_XOA', '2026-06-30 10:00'),
 (12, N'Mai Phương Thảo', 'NU', '19921014', '0901000012', 'thao.mai@example.com', 'DN', '2026-05-22 20:00', 16, 'HOAT_DONG', NULL);
SET IDENTITY_INSERT crm.KHACH_HANG OFF;

/* Sở thích = loại sản phẩm quan tâm */
INSERT crm.KH_QUAN_TAM (MaKH, MaLoai) VALUES
 (1, 2), (1, 5), (1, 1),
 (2, 2), (2, 3), (2, 1),
 (3, 1), (3, 3), (3, 7),
 (4, 1), (4, 4), (4, 2),
 (5, 5), (5, 2),
 (6, 4),
 (7, 1), (7, 7),
 (8, 1), (8, 6),
 (9, 5),
 (11, 1),
 (12, 6), (12, 2);

/* ---------- Khảo sát ----------
   KS1: đo hài lòng chung (đã đóng, có kết quả, tặng voucher 10%)
   KS2: đo hài lòng SP Áo khoác chần bông (đang mở, voucher 5%)
   KS3: thăm dò SP sắp ra mắt Áo khoác lông cừu 2026 (đang mở, voucher 15%)
   KS4: bản nháp thăm dò Áo thun làm mát (chưa gửi)                       */
SET IDENTITY_INSERT crm.KHAO_SAT ON;
INSERT crm.KHAO_SAT (MaKS, TieuDe, MoTa, MucDich, MaSP, MaNV_Tao, NgayTao, NgayPhatHanh, HanTraLoi, PhanTramVoucher, SoNgayHieuLucVoucher, TrangThai) VALUES
 (1, N'Khảo sát mức độ hài lòng khi mua sắm – Quý 3/2026', N'Đánh giá chất lượng sản phẩm và dịch vụ', 'DO_HAI_LONG', NULL, 2,
     '2026-08-20 09:00', '2026-08-25 09:00', '2026-09-15 23:59', 10, 30, 'DA_DONG'),
 (2, N'Đánh giá Áo khoác chần bông siêu nhẹ', NULL, 'DO_HAI_LONG', 4, 2,
     DATEADD(DAY, -15, @Nay), DATEADD(DAY, -12, @Nay), DATEADD(DAY, 20, @Nay), 5, 30, 'DA_GUI'),
 (3, N'Thăm dò: Áo khoác lông cừu nhân tạo 2026', N'Sản phẩm dự kiến ra mắt 20/11/2026', 'THAM_DO_SP_MOI', 13, 2,
     DATEADD(DAY, -10, @Nay), DATEADD(DAY, -8, @Nay), DATEADD(DAY, 30, @Nay), 15, 30, 'DA_GUI'),
 (4, N'Thăm dò: Áo thun làm mát thế hệ mới', NULL, 'THAM_DO_SP_MOI', 14, 2,
     DATEADD(DAY, -1, @Nay), NULL, DATEADD(DAY, 45, @Nay), 10, 30, 'NHAP');
SET IDENTITY_INSERT crm.KHAO_SAT OFF;

SET IDENTITY_INSERT crm.CAU_HOI ON;
INSERT crm.CAU_HOI (MaCauHoi, MaKS, ThuTu, NoiDung, LoaiCauHoi, BatBuoc) VALUES
 (1,  1, 1, N'Mức độ hài lòng chung với chất lượng sản phẩm (1-5)?', 'THANG_DIEM', 1),
 (2,  1, 2, N'Mức độ hài lòng với thái độ phục vụ của nhân viên (1-5)?', 'THANG_DIEM', 1),
 (3,  1, 3, N'Bạn thường mua sắm qua kênh nào?', 'MOT_LUA_CHON', 1),
 (4,  1, 4, N'Bạn muốn chúng tôi cải thiện điều gì? (chọn nhiều)', 'NHIEU_LUA_CHON', 1),
 (5,  1, 5, N'Góp ý khác', 'TU_LUAN', 0),
 (6,  2, 1, N'Độ ấm của sản phẩm (1-5)?', 'THANG_DIEM', 1),
 (7,  2, 2, N'Độ vừa vặn, thoải mái (1-5)?', 'THANG_DIEM', 1),
 (8,  2, 3, N'Bạn có giới thiệu sản phẩm cho người khác?', 'MOT_LUA_CHON', 1),
 (9,  3, 1, N'Bạn có dự định mua sản phẩm này khi ra mắt?', 'MOT_LUA_CHON', 1),
 (10, 3, 2, N'Mức giá bạn thấy hợp lý?', 'MOT_LUA_CHON', 1),
 (11, 3, 3, N'Màu sắc bạn quan tâm (chọn nhiều)', 'NHIEU_LUA_CHON', 1),
 (12, 3, 4, N'Bạn mong muốn gì thêm ở sản phẩm?', 'TU_LUAN', 0),
 (13, 4, 1, N'Bạn có quan tâm đến áo thun làm mát?', 'MOT_LUA_CHON', 1);
SET IDENTITY_INSERT crm.CAU_HOI OFF;

SET IDENTITY_INSERT crm.LUA_CHON ON;
INSERT crm.LUA_CHON (MaLC, MaCauHoi, ThuTu, NoiDung) VALUES
 (1, 3, 1, N'Tại cửa hàng'), (2, 3, 2, N'Online'), (3, 3, 3, N'Cả hai'),
 (4, 4, 1, N'Thêm size'), (5, 4, 2, N'Thêm màu sắc'), (6, 4, 3, N'Giao hàng nhanh hơn'), (7, 4, 4, N'Ưu đãi thành viên'),
 (8, 8, 1, N'Có'), (9, 8, 2, N'Có thể'), (10, 8, 3, N'Không'),
 (11, 9, 1, N'Chắc chắn mua'), (12, 9, 2, N'Có thể'), (13, 9, 3, N'Không'),
 (14, 10, 1, N'Dưới 800.000đ'), (15, 10, 2, N'800.000đ - 1.000.000đ'), (16, 10, 3, N'Trên 1.000.000đ'),
 (17, 11, 1, N'Đen'), (18, 11, 2, N'Be'), (19, 11, 3, N'Xanh navy'), (20, 11, 4, N'Xám'),
 (21, 13, 1, N'Rất quan tâm'), (22, 13, 2, N'Bình thường'), (23, 13, 3, N'Không quan tâm');
SET IDENTITY_INSERT crm.LUA_CHON OFF;

/* Gửi khảo sát tới TÀI KHOẢN khách hàng */
INSERT crm.KHAO_SAT_GUI (MaKS, MaKH, NgayGui, NgayHoanThanh) VALUES
 (1, 1, '2026-08-25 09:00', '2026-09-02 10:00'),
 (1, 2, '2026-08-25 09:00', '2026-09-14 20:00'),
 (1, 3, '2026-08-25 09:00', '2026-08-27 08:30'),
 (1, 4, '2026-08-25 09:00', '2026-08-30 19:15'),
 (1, 5, '2026-08-25 09:00', '2026-09-10 12:00'),
 (1, 6, '2026-08-25 09:00', NULL),
 (1, 7, '2026-08-25 09:00', NULL),
 (2, 1, DATEADD(DAY, -12, @Nay), NULL),
 (2, 2, DATEADD(DAY, -12, @Nay), DATEADD(DAY, -5, @Nay)),
 (2, 5, DATEADD(DAY, -12, @Nay), DATEADD(DAY, -3, @Nay)),
 (3, 1,  DATEADD(DAY, -8, @Nay), NULL),
 (3, 2,  DATEADD(DAY, -8, @Nay), NULL),
 (3, 4,  DATEADD(DAY, -8, @Nay), DATEADD(DAY, -4, @Nay)),
 (3, 5,  DATEADD(DAY, -8, @Nay), NULL),
 (3, 12, DATEADD(DAY, -8, @Nay), DATEADD(DAY, -2, @Nay));

/* Câu trả lời (TRA_LOI: 1 dòng/câu; TRA_LOI_LUA_CHON: lựa chọn đã chọn) */
INSERT crm.TRA_LOI (MaKS, MaKH, MaCauHoi, LoaiCauHoi, DiemSo, NoiDungTuLuan) VALUES
 (1, 1, 1, 'THANG_DIEM', 5, NULL), (1, 1, 2, 'THANG_DIEM', 4, NULL), (1, 1, 3, 'MOT_LUA_CHON', NULL, NULL),
 (1, 1, 4, 'NHIEU_LUA_CHON', NULL, NULL), (1, 1, 5, 'TU_LUAN', NULL, N'Mong có thêm size XS cho áo khoác'),
 (1, 2, 1, 'THANG_DIEM', 4, NULL), (1, 2, 2, 'THANG_DIEM', 5, NULL), (1, 2, 3, 'MOT_LUA_CHON', NULL, NULL),
 (1, 2, 4, 'NHIEU_LUA_CHON', NULL, NULL),
 (1, 3, 1, 'THANG_DIEM', 4, NULL), (1, 3, 2, 'THANG_DIEM', 3, NULL), (1, 3, 3, 'MOT_LUA_CHON', NULL, NULL),
 (1, 3, 4, 'NHIEU_LUA_CHON', NULL, NULL), (1, 3, 5, 'TU_LUAN', NULL, N'Giao hàng online còn chậm'),
 (1, 4, 1, 'THANG_DIEM', 2, NULL), (1, 4, 2, 'THANG_DIEM', 3, NULL), (1, 4, 3, 'MOT_LUA_CHON', NULL, NULL),
 (1, 4, 4, 'NHIEU_LUA_CHON', NULL, NULL),
 (1, 5, 1, 'THANG_DIEM', 4, NULL), (1, 5, 2, 'THANG_DIEM', 4, NULL), (1, 5, 3, 'MOT_LUA_CHON', NULL, NULL),
 (1, 5, 4, 'NHIEU_LUA_CHON', NULL, NULL),
 (2, 2, 6, 'THANG_DIEM', 5, NULL), (2, 2, 7, 'THANG_DIEM', 4, NULL), (2, 2, 8, 'MOT_LUA_CHON', NULL, NULL),
 (2, 5, 6, 'THANG_DIEM', 4, NULL), (2, 5, 7, 'THANG_DIEM', 3, NULL), (2, 5, 8, 'MOT_LUA_CHON', NULL, NULL),
 (3, 4, 9, 'MOT_LUA_CHON', NULL, NULL), (3, 4, 10, 'MOT_LUA_CHON', NULL, NULL), (3, 4, 11, 'NHIEU_LUA_CHON', NULL, NULL),
 (3, 4, 12, 'TU_LUAN', NULL, N'Nên có mũ trùm đầu tháo rời'),
 (3, 12, 9, 'MOT_LUA_CHON', NULL, NULL), (3, 12, 10, 'MOT_LUA_CHON', NULL, NULL), (3, 12, 11, 'NHIEU_LUA_CHON', NULL, NULL);

INSERT crm.TRA_LOI_LUA_CHON (MaKS, MaKH, MaCauHoi, MaLC) VALUES
 (1, 1, 3, 3), (1, 1, 4, 4), (1, 1, 4, 7),
 (1, 2, 3, 1), (1, 2, 4, 4),
 (1, 3, 3, 2), (1, 3, 4, 5), (1, 3, 4, 6),
 (1, 4, 3, 1), (1, 4, 4, 4),
 (1, 5, 3, 3), (1, 5, 4, 7),
 (2, 2, 8, 8), (2, 5, 8, 9),
 (3, 4, 9, 12), (3, 4, 10, 15), (3, 4, 11, 17), (3, 4, 11, 20),
 (3, 12, 9, 11), (3, 12, 10, 14), (3, 12, 11, 18);

/* Voucher phát khi hoàn thành khảo sát có PhanTramVoucher > 0 */
SET IDENTITY_INSERT crm.VOUCHER ON;
INSERT crm.VOUCHER (MaVoucher, MaCode, MaKH, MaKS, PhanTramGiam, NgayPhat, HanDung) VALUES
 (1, 'V1-A1B2C3D4', 1, 1, 10, '2026-09-02 10:00', '2026-10-02 10:00'),
 (2, 'V1-B5C6D7E8', 2, 1, 10, '2026-09-14 20:00', '2026-10-14 20:00'),
 (3, 'V1-C9D0E1F2', 3, 1, 10, '2026-08-27 08:30', '2026-09-26 08:30'),
 (4, 'V1-D3E4F5A6', 4, 1, 10, '2026-08-30 19:15', '2026-09-29 19:15'),
 (5, 'V1-E7F8A9B0', 5, 1, 10, '2026-09-10 12:00', '2026-10-10 12:00'),
 (6, 'V2-1A2B3C4D', 2, 2, 5,  DATEADD(DAY, -5, @Nay), DATEADD(DAY, 25, @Nay)),
 (7, 'V2-5E6F7A8B', 5, 2, 5,  DATEADD(DAY, -3, @Nay), DATEADD(DAY, 27, @Nay)),
 (8, 'V3-9C0D1E2F', 4, 3, 15, DATEADD(DAY, -4, @Nay), DATEADD(DAY, 26, @Nay)),
 (9, 'V3-3A4B5C6D', 12, 3, 15, DATEADD(DAY, -2, @Nay), DATEADD(DAY, 28, @Nay));
SET IDENTITY_INSERT crm.VOUCHER OFF;

/* ---------- Giao dịch (Admin nạp từ POS) ---------- */
SET IDENTITY_INSERT crm.HOA_DON ON;
INSERT crm.HOA_DON (MaHD, SoHoaDon, MaKH, KenhBan, MaCH, MaNV, NgayLap, MaVoucher, NgayNhap) VALUES
 (1, 'HD0001', 1, 'CUA_HANG', 1, 5, '2026-03-05 10:15', NULL, '2026-03-05 10:15'),
 (2, 'HD0002', 1, 'CUA_HANG', 1, 5, '2026-05-12 17:40', NULL, '2026-05-12 17:40'),
 (3, 'HD0003', 1, 'ONLINE', NULL, NULL, '2026-07-20 21:05', NULL, '2026-07-20 21:05'),
 (4, 'HD0004', 1, 'CUA_HANG', 1, 5, '2026-09-28 18:20', 1, '2026-09-28 18:20'),
 (5, 'HD0005', 2, 'CUA_HANG', 2, 6, '2026-04-02 11:00', NULL, '2026-04-02 11:00'),
 (6, 'HD0006', 2, 'CUA_HANG', 2, 6, '2026-06-15 19:30', NULL, '2026-06-15 19:30'),
 (7, 'HD0007', 2, 'ONLINE', NULL, NULL, '2026-08-30 22:10', NULL, '2026-08-30 22:10'),
 (8, 'HD0008', 3, 'CUA_HANG', 1, 5, '2026-05-03 15:20', NULL, '2026-05-03 15:20'),
 (9, 'HD0009', 3, 'ONLINE', NULL, NULL, '2026-08-11 20:45', NULL, '2026-08-11 20:45'),
 (10, 'HD0010', 4, 'CUA_HANG', 3, 7, '2026-04-20 16:00', NULL, '2026-04-20 16:00'),
 (11, 'HD0011', 5, 'CUA_HANG', 1, 5, '2026-03-15 18:00', NULL, '2026-03-15 18:00'),
 (12, 'HD0012', 5, 'CUA_HANG', 1, 5, '2026-07-07 12:30', NULL, '2026-07-07 12:30'),
 (13, 'HD0013', 5, 'ONLINE', NULL, NULL, '2026-09-19 09:10', NULL, '2026-09-19 09:10'),
 (14, 'HD0014', 6, 'CUA_HANG', 2, 6, '2026-06-01 10:30', NULL, '2026-06-01 10:30'),
 (15, 'HD0015', 7, 'ONLINE', NULL, NULL, '2026-09-05 21:00', NULL, '2026-09-05 21:00'),
 (16, 'HD0016', 8, 'CUA_HANG', 2, 6, '2026-05-25 14:10', NULL, '2026-05-25 14:10'),
 (17, 'HD0017', 9, 'CUA_HANG', 1, 5, '2026-04-11 13:00', NULL, '2026-04-11 13:00'),
 (18, 'HD0018', 10, 'CUA_HANG', 3, 7, '2026-08-08 15:00', NULL, '2026-08-08 15:00'),
 (19, 'HD0019', 11, 'CUA_HANG', 2, 6, '2026-02-14 19:00', NULL, '2026-02-14 19:00'),
 (20, 'HD0020', 12, 'CUA_HANG', 3, 7, '2026-07-30 17:25', NULL, '2026-07-30 17:25');
SET IDENTITY_INSERT crm.HOA_DON OFF;
INSERT crm.CHI_TIET_HOA_DON (MaHD, MaSP, SoLuong, DonGiaBan) VALUES
 (1, 4, 1, 1290000),
 (1, 7, 1, 899000),
 (2, 9, 2, 699000),
 (2, 2, 2, 249000),
 (3, 5, 1, 799000),
 (3, 10, 1, 499000),
 (4, 8, 1, 599000),
 (4, 2, 1, 249000),
 (5, 4, 2, 1290000),
 (5, 6, 1, 799000),
 (6, 3, 3, 399000),
 (6, 8, 1, 599000),
 (7, 5, 1, 799000),
 (7, 12, 1, 299000),
 (8, 2, 2, 249000),
 (8, 7, 1, 899000),
 (9, 10, 1, 499000),
 (10, 1, 3, 249000),
 (10, 8, 1, 599000),
 (11, 4, 1, 1290000),
 (11, 9, 1, 699000),
 (12, 7, 1, 899000),
 (12, 2, 3, 249000),
 (13, 5, 1, 799000),
 (14, 8, 2, 599000),
 (15, 2, 1, 249000),
 (15, 12, 1, 299000),
 (16, 3, 2, 399000),
 (17, 9, 1, 699000),
 (18, 4, 1, 1290000),
 (19, 1, 2, 249000),
 (20, 10, 2, 499000),
 (20, 11, 1, 199000);
SET IDENTITY_INSERT crm.DOI_TRA ON;
INSERT crm.DOI_TRA (MaDT, MaHD, MaSP, SoLuong, LyDo, NgayDoiTra, GhiChu) VALUES
 (1, 2, 9, 1, 'KHONG_VUA', '2026-05-15 10:00', N'Đổi sang size khác không còn hàng'),
 (2, 10, 1, 1, 'LOI_SP', '2026-04-25 09:30', N'Lỗi đường may'),
 (3, 17, 9, 1, 'KHONG_UNG', '2026-04-14 16:00', N'Màu không giống ảnh'),
 (4, 12, 2, 1, 'KHONG_VUA', '2026-07-10 11:15', NULL);
SET IDENTITY_INSERT crm.DOI_TRA OFF;

/* ---------- Phản hồi ở đủ 3 trạng thái ---------- */
SET IDENTITY_INSERT crm.PHAN_HOI ON;
INSERT crm.PHAN_HOI (MaPH, MaKH, MaSP, LoaiPH, DiemDanhGia, NoiDung, NgayGui, TrangThai, MaNV_XuLy, NgayTiepNhan, NoiDungTraLoi, NgayTraLoi) VALUES
 (1, 1, 4, 'KHEN', 5, N'Áo rất nhẹ và ấm, rất đáng tiền.', '2026-03-10 20:00', 'DA_XU_LY', 2, '2026-03-11 09:00', N'Cảm ơn chị đã tin dùng sản phẩm!', '2026-03-11 09:30'),
 (2, 2, 6, 'GOP_Y', 4, N'Mong có thêm size lớn cho quần jeans slim.', '2026-04-10 08:00', 'DA_XU_LY', 3, '2026-04-10 10:00', N'Chúng tôi đã chuyển góp ý tới bộ phận sản phẩm.', '2026-04-11 15:00'),
 (3, 4, 1, 'KHIEU_NAI', 2, N'Áo bị lỗi đường may ở vai.', '2026-04-22 19:00', 'DA_XU_LY', 3, '2026-04-23 08:30', N'Xin lỗi anh, cửa hàng đã hỗ trợ đổi trả và tặng ưu đãi lần sau.', '2026-04-23 14:00'),
 (4, 3, 7, 'KHEN', 5, N'Quần form đẹp, mặc thoải mái.', '2026-05-08 21:00', 'DANG_XU_LY', 3, '2026-05-09 09:00', NULL, NULL),
 (5, 5, 9, 'GOP_Y', 3, N'Vải lanh hơi dễ nhăn.', '2026-07-12 13:00', 'DANG_XU_LY', 2, '2026-07-13 10:00', NULL, NULL),
 (6, 9, 9, 'KHIEU_NAI', 2, N'Màu thực tế không giống ảnh trên web.', '2026-04-13 22:00', 'MOI', NULL, NULL, NULL, NULL),
 (7, 7, 12, 'KHEN', 4, N'Túi nhỏ gọn, đựng vừa điện thoại.', '2026-09-07 18:00', 'MOI', NULL, NULL, NULL, NULL),
 (8, 8, 3, 'GOP_Y', 4, N'Nên có thêm màu xanh rêu.', '2026-06-01 07:30', 'MOI', NULL, NULL, NULL, NULL),
 (9, 12, 10, 'KHEN', 5, N'Đồ mặc nhà rất mát.', '2026-08-05 22:15', 'MOI', NULL, NULL, NULL, NULL),
 (10, 1, 5, 'KHIEU_NAI', 3, N'Khóa kéo hơi kẹt sau vài lần dùng.', '2026-07-25 08:45', 'MOI', NULL, NULL, NULL, NULL);
SET IDENTITY_INSERT crm.PHAN_HOI OFF;

/* ---------- Nhật ký minh họa cho các thao tác quan trọng đã xảy ra ---------- */
INSERT audit.NHAT_KY (ThoiGian, MaTK, NguoiDungCSDL, HanhDong, DoiTuong, MaDoiTuong, ChiTiet) VALUES
 ('2026-06-30 10:00', 3, N'crm_app_quanly', 'XOA_KH',     'KHACH_HANG', N'11', N'Khách yêu cầu ngừng sử dụng dịch vụ'),
 ('2026-09-01 09:30', 3, N'crm_app_quanly', 'KHOA_TK_KH', 'TAI_KHOAN',  N'14', N'Đăng nhập bất thường nhiều lần, chờ xác minh'),
 ('2025-07-01 09:00', 1, N'crm_app_admin',  'TAO_TK',     'TAI_KHOAN',  N'5',  N'Tạo tài khoản it.mai cho NV 8, vai trò QTV_TAI_KHOAN');

/* ---------- Xét hạng lần đầu theo dữ liệu giao dịch (ghi LICH_SU_HANG) ---------- */
EXEC crm.usp_XetHang_NoiBo @MaKH = NULL, @LyDo = N'Xét hạng lần đầu khi nạp dữ liệu mẫu';

COMMIT;
GO
SET NOEXEC OFF;
GO

/* Tóm tắt dữ liệu mẫu */
SELECT 'TAI_KHOAN' AS Bang, COUNT(*) AS SoDong FROM crm.TAI_KHOAN UNION ALL
SELECT 'NHAN_VIEN', COUNT(*) FROM crm.NHAN_VIEN UNION ALL
SELECT 'KHACH_HANG', COUNT(*) FROM crm.KHACH_HANG UNION ALL
SELECT 'KH_QUAN_TAM', COUNT(*) FROM crm.KH_QUAN_TAM UNION ALL
SELECT 'SAN_PHAM', COUNT(*) FROM crm.SAN_PHAM UNION ALL
SELECT 'HOA_DON', COUNT(*) FROM crm.HOA_DON UNION ALL
SELECT 'CHI_TIET_HOA_DON', COUNT(*) FROM crm.CHI_TIET_HOA_DON UNION ALL
SELECT 'DOI_TRA', COUNT(*) FROM crm.DOI_TRA UNION ALL
SELECT 'PHAN_HOI', COUNT(*) FROM crm.PHAN_HOI UNION ALL
SELECT 'KHAO_SAT', COUNT(*) FROM crm.KHAO_SAT UNION ALL
SELECT 'KHAO_SAT_GUI', COUNT(*) FROM crm.KHAO_SAT_GUI UNION ALL
SELECT 'TRA_LOI', COUNT(*) FROM crm.TRA_LOI UNION ALL
SELECT 'VOUCHER', COUNT(*) FROM crm.VOUCHER UNION ALL
SELECT 'LICH_SU_HANG', COUNT(*) FROM crm.LICH_SU_HANG;

SELECT k.MaKH, k.HoTen, k.MaHang, d.Diem, d.ChiTieuRong
FROM crm.KHACH_HANG k JOIN crm.vw_DiemKhachHang d ON d.MaKH = k.MaKH
ORDER BY d.Diem DESC;
GO
PRINT N'Script 08 hoàn tất.';
GO
