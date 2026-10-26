/* =====================================================================
   Script 17: Kiểm thử chống leo thang đặc quyền trong cổng Admin
   ---------------------------------------------------------------------
   Chạy trên CRM_Uniqlo_Test, MỘT kết nối mới, SAU script 16.
   it.mai chỉ có AD_TAI_KHOAN + AD_TRA_CUU: không được tự cấp/cấp cho người khác vai trò cao hơn.
   Cách đọc kết quả: bảng cuối cùng liệt kê từng ca, cột KetQua = PASS/FAIL;
   tab Messages in từng ca và 2 dòng cuối: TONG KET ... và KET LUAN: DAT / KHONG DAT.
   DAT = mọi ca PASS và chạy đủ số ca dự kiến. Xem HUONG_DAN_KIEM_THU (mục 6).
   ===================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT OFF;
GO
IF DB_NAME() <> N'CRM_Uniqlo_Test'
BEGIN
    RAISERROR (N'Hãy chạy trên CSDL CRM_Uniqlo_Test (tạo bằng script 11). Script này GHI dữ liệu.', 16, 1);
    SET NOEXEC ON;
END
GO
/* Ngữ cảnh phiên là read-only: nếu cửa sổ này đã đăng nhập (đã chạy một script kiểm thử
   hoặc sec.usp_DatNguCanh trước đó) thì mọi ca sẽ sai. Phải mở cửa sổ truy vấn MỚI. */
IF SESSION_CONTEXT(N'MaTK') IS NOT NULL
BEGIN
    RAISERROR (N'Kết nối này đã gắn ngữ cảnh phiên (đã đăng nhập). Mở cửa sổ truy vấn MỚI (Ctrl+N) rồi chạy lại script.', 16, 1);
    SET NOEXEC ON;
END
GO
DECLARE @KQ TABLE (STT INT IDENTITY, MaKT VARCHAR(10), MucTieu NVARCHAR(300), MongDoi NVARCHAR(100),
                   KetQua VARCHAR(4), ChiTiet NVARCHAR(1000));
DECLARE @Loi INT, @ThongBao NVARCHAR(4000), @DatDK BIT;
DECLARE @CT api_admin.BangChiTietHoaDon;
EXECUTE AS USER = 'u_app_admin';   -- cổng Admin, vai trò QTV_TAI_KHOAN (chỉ AD_TAI_KHOAN, AD_TRA_CUU)

/* QT-01: Đăng nhập it.mai (vai trò QTV_TAI_KHOAN) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC sec.usp_DatNguCanh @MaTK = 5;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QT-01', N'Đăng nhập it.mai (vai trò QTV_TAI_KHOAN)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QT-02: Được xem danh sách tài khoản */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_DanhSachTaiKhoan @LoaiTK = 'NV';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QT-02', N'Được xem danh sách tài khoản', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QT-03: Leo thang: tạo account ADMIN cho nhân viên khác bị chặn (thiếu AD_PHAN_QUYEN) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_TaoTaiKhoanNhanVien @MaNV = 6, @TenDangNhap = 'nv.linh', @MatKhauHashTam = '$2b$10$xWcj7ts/xbO83TtC4rGMn.Ucpo1QynUTWjfh3QS1S3.3TYspWgif.', @MaVT = 'ADMIN';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QT-03', N'Leo thang: tạo account ADMIN cho nhân viên khác bị chặn (thiếu AD_PHAN_QUYEN)', N'Lỗi 50003',
        CASE WHEN @Loi IN (50003) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QT-04: Leo thang: tự đổi vai trò của mình lên ADMIN bị chặn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_DoiVaiTro @MaTK = 5, @MaVTMoi = 'ADMIN';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QT-04', N'Leo thang: tự đổi vai trò của mình lên ADMIN bị chặn', N'Lỗi 50003',
        CASE WHEN @Loi IN (50003) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QT-05: Không khóa được Admin cuối cùng có quyền phân quyền */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_KhoaMoTaiKhoan @MaTK = 1, @Khoa = 1, @LyDo = N'Thử khóa admin';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QT-05', N'Không khóa được Admin cuối cùng có quyền phân quyền', N'Lỗi 52091',
        CASE WHEN @Loi IN (52091) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QT-06: Không quản lý danh mục (thiếu AD_DANH_MUC) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_LuuLoaiSP @TenLoai = N'Đồ bơi';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QT-06', N'Không quản lý danh mục (thiếu AD_DANH_MUC)', N'Lỗi 50003',
        CASE WHEN @Loi IN (50003) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QT-07: Không nạp giao dịch (thiếu AD_NAP_GIAO_DICH) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @CT; INSERT @CT VALUES ('AT-001', 1, 249000);
    EXEC api_admin.usp_NhapHoaDon @SoHoaDon = 'HD-KT-0101', @MaKH = 1, @KenhBan = 'ONLINE', @NgayLap = '20261001', @ChiTiet = @CT;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QT-07', N'Không nạp giao dịch (thiếu AD_NAP_GIAO_DICH)', N'Lỗi 50003',
        CASE WHEN @Loi IN (50003) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QT-08: Được khóa tài khoản khách hàng theo nhiệm vụ */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_KhoaMoTaiKhoan @MaTK = 9, @Khoa = 1, @LyDo = N'Yêu cầu từ bộ phận CSKH';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QT-08', N'Được khóa tài khoản khách hàng theo nhiệm vụ', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QT-10: Leo thang: đặt lại mật khẩu tài khoản Admin bị chặn (thiếu AD_PHAN_QUYEN) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_DatLaiMatKhau @MaTK = 1, @MatKhauHashTam = '$2b$10$xWcj7ts/xbO83TtC4rGMn.Ucpo1QynUTWjfh3QS1S3.3TYspWgif.';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QT-10', N'Leo thang: đặt lại mật khẩu tài khoản Admin bị chặn (thiếu AD_PHAN_QUYEN)', N'Lỗi 50003',
        CASE WHEN @Loi IN (50003) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QT-11: Được đặt lại mật khẩu tài khoản khách hàng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_DatLaiMatKhau @MaTK = 12, @MatKhauHashTam = '$2b$10$xWcj7ts/xbO83TtC4rGMn.Ucpo1QynUTWjfh3QS1S3.3TYspWgif.';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QT-11', N'Được đặt lại mật khẩu tài khoản khách hàng', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

REVERT;

/* QT-09: Hậu kiểm: vai trò của it.mai không đổi, NV6 không có account */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT ((SELECT MaVT FROM crm.TAI_KHOAN WHERE MaTK = 5) = 'QTV_TAI_KHOAN' AND (SELECT MaTK FROM crm.NHAN_VIEN WHERE MaNV = 6) IS NULL AND (SELECT TrangThai FROM crm.TAI_KHOAN WHERE MaTK = 1) = 'HOAT_DONG') SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QT-09', N'Hậu kiểm: vai trò của it.mai không đổi, NV6 không có account', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* ===================== TỔNG KẾT ===================== */
SELECT STT, MaKT, KetQua, MucTieu, MongDoi, ChiTiet FROM @KQ ORDER BY STT;
/* In từng ca ra tab Messages (đọc được cả khi chạy bằng sqlcmd) */
DECLARE @KT_i INT = 1, @KT_n INT = (SELECT COUNT(*) FROM @KQ), @KT_Dong NVARCHAR(2000);
WHILE @KT_i <= @KT_n
BEGIN
    SELECT @KT_Dong = CONCAT(KetQua, N' | ', MaKT, N' | ', MucTieu, N' | Mong đợi: ', MongDoi,
                             CASE WHEN KetQua = 'FAIL' THEN CONCAT(N' | THỰC TẾ: ', ChiTiet) ELSE N'' END)
    FROM @KQ WHERE STT = @KT_i;
    PRINT @KT_Dong;
    SET @KT_i += 1;
END
DECLARE @KT_DuKien INT = 11,
        @KT_Pass INT = (SELECT COUNT(*) FROM @KQ WHERE KetQua = 'PASS'),
        @KT_Fail INT = (SELECT COUNT(*) FROM @KQ WHERE KetQua = 'FAIL');
PRINT N'------------------------------------------------------------';
PRINT CONCAT(N'TONG KET ', DB_NAME(), N': ', @KT_Pass, N'/', @KT_n, N' PASS, ', @KT_Fail, N' FAIL (du kien ', @KT_DuKien, N' ca)');
PRINT CASE WHEN @KT_Fail = 0 AND @KT_n = @KT_DuKien THEN N'KET LUAN: DAT' ELSE N'KET LUAN: KHONG DAT' END;
SELECT MaKT AS CA_FAIL, ChiTiet FROM @KQ WHERE KetQua = 'FAIL';
GO
SET NOEXEC OFF;
GO
