/* =====================================================================
   Script 07: Dữ liệu danh mục hệ thống (bắt buộc để hệ thống vận hành)
   ---------------------------------------------------------------------
   Vai trò gốc, quyền chức năng, hạng thành viên, chức vụ, tỉnh/thành.
   Chạy lại an toàn: chỉ thêm dòng chưa có (không ghi đè chỉnh sửa của Admin).
   ===================================================================== */
USE CRM_Uniqlo;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

/* 1. Vai trò gốc. "VIP" KHÔNG phải vai trò: VIP là hạng thành viên. */
INSERT crm.VAI_TRO (MaVT, TenVT, LoaiTK, CongTruyCap, MoTa)
SELECT v.MaVT, v.TenVT, v.LoaiTK, v.CongTruyCap, v.MoTa
FROM (VALUES
    ('ADMIN',      N'Quản trị hệ thống', 'NV', 'ADMIN',      N'Tài khoản, phân quyền, danh mục, nạp giao dịch, nhật ký'),
    ('QUAN_LY',    N'Quản lý',           'NV', 'QUAN_LY',    N'Nghiệp vụ CRM: khách hàng, phản hồi, khảo sát, báo cáo'),
    ('KHACH_HANG', N'Khách hàng',        'KH', 'KHACH_HANG', N'Chỉ thao tác trên dữ liệu của chính mình')
) v (MaVT, TenVT, LoaiTK, CongTruyCap, MoTa)
WHERE NOT EXISTS (SELECT 1 FROM crm.VAI_TRO x WHERE x.MaVT = v.MaVT);
GO

/* 2. Quyền chức năng (mỗi quyền gắn 1 cổng). */
INSERT crm.QUYEN (MaQuyen, TenQuyen, CongTruyCap, MoTa)
SELECT v.MaQuyen, v.TenQuyen, v.CongTruyCap, v.MoTa
FROM (VALUES
    ('AD_TAI_KHOAN',     N'Quản lý tài khoản',              'ADMIN', N'Xem danh sách, khóa/mở khóa, xóa account'),
    ('AD_PHAN_QUYEN',    N'Phân quyền',                     'ADMIN', N'Tạo account kèm vai trò, đổi vai trò, tạo vai trò, gán quyền'),
    ('AD_DANH_MUC',      N'Quản lý danh mục',               'ADMIN', N'Sản phẩm, loại, nhà cung cấp, cửa hàng, nhân viên'),
    ('AD_TRA_CUU',       N'Tra cứu nâng cao',               'ADMIN', N'Tìm kiếm, lọc, sắp xếp danh mục; tra cứu KH (đã che)'),
    ('AD_NAP_GIAO_DICH', N'Nạp dữ liệu giao dịch',          'ADMIN', N'Nạp hóa đơn, đổi trả từ POS; xét hạng'),
    ('AD_NHAT_KY',       N'Xem nhật ký',                    'ADMIN', N'Xem nhật ký kiểm toán'),
    ('QL_KH_XEM',        N'Xem/tra cứu khách hàng',         'QUAN_LY', N'Tìm kiếm, xem hồ sơ 360°'),
    ('QL_KH_THEM',       N'Thêm khách hàng',                'QUAN_LY', N'Thêm hồ sơ, cấp tài khoản KH'),
    ('QL_KH_SUA',        N'Sửa khách hàng',                 'QUAN_LY', N'Cập nhật hồ sơ, sở thích'),
    ('QL_KH_XOA',        N'Xóa khách hàng',                 'QUAN_LY', N'Xóa mềm hồ sơ'),
    ('QL_KH_KHOA',       N'Khóa tài khoản khách hàng',      'QUAN_LY', N'Khóa/mở khóa tài khoản KH'),
    ('QL_PH_XEM',        N'Xem phản hồi',                   'QUAN_LY', NULL),
    ('QL_PH_XU_LY',      N'Tiếp nhận và trả lời phản hồi',  'QUAN_LY', NULL),
    ('QL_KS_QUAN_LY',    N'Tạo/sửa khảo sát',               'QUAN_LY', NULL),
    ('QL_KS_GUI',        N'Gửi/đóng khảo sát',              'QUAN_LY', NULL),
    ('QL_KS_THONG_KE',   N'Thống kê khảo sát',              'QUAN_LY', NULL),
    ('QL_BAO_CAO',       N'Xem báo cáo tổng hợp',           'QUAN_LY', N'Cơ cấu KH, sở thích, hài lòng'),
    ('KH_HO_SO',         N'Hồ sơ cá nhân',                  'KHACH_HANG', N'Xem/sửa hồ sơ, sở thích, voucher của mình'),
    ('KH_PHAN_HOI',      N'Gửi phản hồi',                   'KHACH_HANG', NULL),
    ('KH_KHAO_SAT',      N'Thực hiện khảo sát',             'KHACH_HANG', NULL)
) v (MaQuyen, TenQuyen, CongTruyCap, MoTa)
WHERE NOT EXISTS (SELECT 1 FROM crm.QUYEN x WHERE x.MaQuyen = v.MaQuyen);
GO

/* 3. Gán quyền mặc định: ADMIN, QUAN_LY, KHACH_HANG nhận toàn bộ quyền của cổng mình
      (chỉ khi vai trò chưa có quyền nào – không ghi đè cấu hình Admin đã chỉnh). */
INSERT crm.VAI_TRO_QUYEN (MaVT, MaQuyen, CongTruyCap)
SELECT vt.MaVT, q.MaQuyen, q.CongTruyCap
FROM crm.VAI_TRO vt
JOIN crm.QUYEN q ON q.CongTruyCap = vt.CongTruyCap
WHERE vt.MaVT IN ('ADMIN', 'QUAN_LY', 'KHACH_HANG')
  AND NOT EXISTS (SELECT 1 FROM crm.VAI_TRO_QUYEN x WHERE x.MaVT = vt.MaVT);
GO

/* 4. Hạng thành viên: THUONG (0 điểm), VIP (>= 500 điểm ~ 5.000.000đ chi tiêu ròng).
      Ngưỡng là giả định của nhóm, chỉnh được bằng UPDATE bảng này. */
INSERT crm.HANG_THANH_VIEN (MaHang, TenHang, DiemToiThieu, MoTa)
SELECT v.MaHang, v.TenHang, v.DiemToiThieu, v.MoTa
FROM (VALUES
    ('THUONG', N'Thường', 0,   N'Mặc định khi tạo hồ sơ'),
    ('VIP',    N'VIP',    500, N'Tự động khi điểm tích lũy >= 500 (1 điểm / 10.000đ chi tiêu ròng)')
) v (MaHang, TenHang, DiemToiThieu, MoTa)
WHERE NOT EXISTS (SELECT 1 FROM crm.HANG_THANH_VIEN x WHERE x.MaHang = v.MaHang);
GO

/* 5. Chức vụ (KHÔNG quyết định quyền hệ thống). */
INSERT crm.CHUC_VU (MaCV, TenCV, MoTa)
SELECT v.MaCV, v.TenCV, v.MoTa
FROM (VALUES
    ('GIAM_DOC',    N'Giám đốc',            N'Điều hành chung, xem báo cáo'),
    ('QL_CSKH',     N'Quản lý CSKH',        N'Phụ trách quan hệ khách hàng'),
    ('NV_CSKH',     N'Nhân viên CSKH',      N'Xử lý phản hồi khách hàng'),
    ('NV_BAN_HANG', N'Nhân viên bán hàng',  N'Bán hàng tại cửa hàng (xuất hiện trên hóa đơn POS)'),
    ('NV_IT',       N'Nhân viên IT',        N'Vận hành hệ thống')
) v (MaCV, TenCV, MoTa)
WHERE NOT EXISTS (SELECT 1 FROM crm.CHUC_VU x WHERE x.MaCV = v.MaCV);
GO

/* 6. Tỉnh/thành (rút gọn cho demo; bổ sung đủ danh mục khi triển khai thật). */
INSERT crm.TINH_THANH (MaTinh, TenTinh)
SELECT v.MaTinh, v.TenTinh
FROM (VALUES
    ('HCM', N'TP. Hồ Chí Minh'),
    ('HN',  N'Hà Nội'),
    ('DN',  N'Đà Nẵng'),
    ('HP',  N'Hải Phòng'),
    ('CT',  N'Cần Thơ')
) v (MaTinh, TenTinh)
WHERE NOT EXISTS (SELECT 1 FROM crm.TINH_THANH x WHERE x.MaTinh = v.MaTinh);
GO

PRINT N'Script 07 hoàn tất.';
GO
