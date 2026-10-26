/* =====================================================================
   Script 14: Kiểm thử cổng Quản lý (chức năng + bảo mật)
   ---------------------------------------------------------------------
   Chạy trên CRM_Uniqlo_Test, trong MỘT kết nối mới, SAU script 13.
   Đóng vai ql.lan (MaTK 3, MaNV 2, vai trò QUAN_LY) qua EXECUTE AS USER = 'u_app_quanly'.
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
DECLARE @DsLoai api_chung.DanhSachMa; INSERT @DsLoai VALUES (6);
DECLARE @DsLC api_ql.DanhSachLuaChon;
DECLARE @MaKHMoi INT, @MaKSMoi INT;
DECLARE @KH TABLE (MaKH INT, HoTen NVARCHAR(100), GioiTinh VARCHAR(4), Tuoi INT, NhomTuoi NVARCHAR(20), SDT VARCHAR(10), Email VARCHAR(100),
                   TenTinh NVARCHAR(50), MaHang VARCHAR(10), TenHang NVARCHAR(30), Diem INT, SoThich NVARCHAR(4000), NgayDangKy DATETIME2(0),
                   TrangThaiHoSo VARCHAR(10), TenDangNhap VARCHAR(50), TrangThaiTaiKhoan VARCHAR(10), TongSoDong INT);
DECLARE @So TABLE (SoNguoiNhanMoi INT);
EXECUTE AS USER = 'u_app_quanly';   -- đóng vai kết nối của cổng Quản lý

/* QL-01: Cổng Quản lý không đăng nhập được bằng tài khoản khách */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC sec.usp_DatNguCanh @MaTK = 6;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-01', N'Cổng Quản lý không đăng nhập được bằng tài khoản khách', N'Lỗi 50013',
        CASE WHEN @Loi IN (50013) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-02: Đăng nhập ql.lan (Quản lý CSKH, vai trò QUAN_LY) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC sec.usp_DatNguCanh @MaTK = 3;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-02', N'Đăng nhập ql.lan (Quản lý CSKH, vai trò QUAN_LY)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-03: Không đọc trực tiếp bảng khách hàng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT TOP (1) @Loi = MaKH FROM crm.KHACH_HANG;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-03', N'Không đọc trực tiếp bảng khách hàng', N'Lỗi 229',
        CASE WHEN @Loi IN (229) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-04: Không tự cấp quyền (không gọi được thủ tục Admin đổi vai trò) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_DoiVaiTro @MaTK = 3, @MaVTMoi = 'ADMIN';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-04', N'Không tự cấp quyền (không gọi được thủ tục Admin đổi vai trò)', N'Lỗi 229',
        CASE WHEN @Loi IN (229) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-05: Không gọi thủ tục của cổng Khách hàng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_kh.usp_XemHoSo;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-05', N'Không gọi thủ tục của cổng Khách hàng', N'Lỗi 229',
        CASE WHEN @Loi IN (229) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-06: Lọc khách VIP: đúng An và Bình */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    INSERT @KH EXEC api_ql.usp_TimKhachHang @MaHang = 'VIP';
    IF NOT ((SELECT STRING_AGG(CAST(MaKH AS VARCHAR(5)), ',') WITHIN GROUP (ORDER BY MaKH) FROM @KH) = '1,2') SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-06', N'Lọc khách VIP: đúng An và Bình', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-07: Lọc nâng cao: nữ, 25-34 tuổi, quan tâm Đầm/váy */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @KH; INSERT @KH EXEC api_ql.usp_TimKhachHang @GioiTinh = 'NU', @TuoiTu = 25, @TuoiDen = 34, @MaLoaiQuanTam = 5;
    IF NOT (EXISTS (SELECT 1 FROM @KH) AND NOT EXISTS (SELECT 1 FROM @KH WHERE GioiTinh <> 'NU' OR Tuoi NOT BETWEEN 25 AND 34)) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-07', N'Lọc nâng cao: nữ, 25-34 tuổi, quan tâm Đầm/váy', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-08: Thêm khách hàng mới tại cửa hàng (chưa có tài khoản) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_ThemKhachHang @HoTen = N'Khách Tại Quầy', @SDT = '0909999101', @GioiTinh = 'NAM', @MaTinh = 'HN', @DsLoaiQuanTam = @DsLoai;
    DELETE @KH; INSERT @KH EXEC api_ql.usp_TimKhachHang @TuKhoa = N'0909999101';
    SELECT @MaKHMoi = MaKH FROM @KH;
    IF NOT (@MaKHMoi IS NOT NULL AND (SELECT TenDangNhap FROM @KH) IS NULL) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-08', N'Thêm khách hàng mới tại cửa hàng (chưa có tài khoản)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-09: Thêm khách trùng SĐT bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_ThemKhachHang @HoTen = N'Trùng', @SDT = '0901000003', @DsLoaiQuanTam = @DsLoai;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-09', N'Thêm khách trùng SĐT bị từ chối', N'Lỗi 52002',
        CASE WHEN @Loi IN (52002) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-10: Cấp tài khoản cho khách vừa thêm (bắt đổi mật khẩu lần đầu) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_CapTaiKhoanKhachHang @MaKH = @MaKHMoi, @TenDangNhap = 'kh.taiquay', @MatKhauHashTam = '$2b$10$xWcj7ts/xbO83TtC4rGMn.Ucpo1QynUTWjfh3QS1S3.3TYspWgif.';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-10', N'Cấp tài khoản cho khách vừa thêm (bắt đổi mật khẩu lần đầu)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-11: Cấp tài khoản lần 2 cho cùng khách bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_CapTaiKhoanKhachHang @MaKH = @MaKHMoi, @TenDangNhap = 'kh.taiquay2', @MatKhauHashTam = '$2b$10$xWcj7ts/xbO83TtC4rGMn.Ucpo1QynUTWjfh3QS1S3.3TYspWgif.';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-11', N'Cấp tài khoản lần 2 cho cùng khách bị từ chối', N'Lỗi 52041',
        CASE WHEN @Loi IN (52041) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-12: Khóa tài khoản khách hàng (Lê Minh Châu) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_KhoaTaiKhoanKhachHang @MaKH = 3, @Khoa = 1, @LyDo = N'Kiểm thử khóa';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-12', N'Khóa tài khoản khách hàng (Lê Minh Châu)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-13: Khóa lại tài khoản đã khóa bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_KhoaTaiKhoanKhachHang @MaKH = 3, @Khoa = 1, @LyDo = N'Lần 2';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-13', N'Khóa lại tài khoản đã khóa bị từ chối', N'Lỗi 52043',
        CASE WHEN @Loi IN (52043) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-14: Khóa không ghi lý do bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_KhoaTaiKhoanKhachHang @MaKH = 4, @Khoa = 1;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-14', N'Khóa không ghi lý do bị từ chối', N'Lỗi 52001',
        CASE WHEN @Loi IN (52001) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-15: Khóa tài khoản của khách chưa có tài khoản bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_KhoaTaiKhoanKhachHang @MaKH = 10, @Khoa = 1, @LyDo = N'x';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-15', N'Khóa tài khoản của khách chưa có tài khoản bị từ chối', N'Lỗi 52042',
        CASE WHEN @Loi IN (52042) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-16: Xóa khách hàng (xóa mềm, khóa tài khoản) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_XoaKhachHang @MaKH = 6, @LyDo = N'Khách yêu cầu (kiểm thử)';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-16', N'Xóa khách hàng (xóa mềm, khóa tài khoản)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-17: Xóa lại khách đã xóa bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_XoaKhachHang @MaKH = 6, @LyDo = N'Lần 2';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-17', N'Xóa lại khách đã xóa bị từ chối', N'Lỗi 52040',
        CASE WHEN @Loi IN (52040) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-18: Tiếp nhận phản hồi mới (MaPH 6) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_TiepNhanPhanHoi @MaPH = 6, @LoaiPH = 'KHIEU_NAI';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-18', N'Tiếp nhận phản hồi mới (MaPH 6)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-19: Tiếp nhận lại phản hồi đã tiếp nhận bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_TiepNhanPhanHoi @MaPH = 6;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-19', N'Tiếp nhận lại phản hồi đã tiếp nhận bị từ chối', N'Lỗi 52050',
        CASE WHEN @Loi IN (52050) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-20: Trả lời phản hồi rỗng bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_TraLoiPhanHoi @MaPH = 6, @NoiDungTraLoi = N'   ';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-20', N'Trả lời phản hồi rỗng bị từ chối', N'Lỗi 52001',
        CASE WHEN @Loi IN (52001) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-21: Trả lời và đóng phản hồi */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_TraLoiPhanHoi @MaPH = 6, @NoiDungTraLoi = N'Cửa hàng sẽ liên hệ đổi sản phẩm cho chị.';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-21', N'Trả lời và đóng phản hồi', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-22: Khảo sát thăm dò gắn SP đang bán bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_TaoKhaoSat @TieuDe = N'Sai', @MucDich = 'THAM_DO_SP_MOI', @MaSP = 1, @HanTraLoi = '20991231';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-22', N'Khảo sát thăm dò gắn SP đang bán bị từ chối', N'Lỗi 52060',
        CASE WHEN @Loi IN (52060) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-23: Tạo khảo sát đo hài lòng mới */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DECLARE @Ks TABLE (MaKS INT);
    INSERT @Ks EXEC api_ql.usp_TaoKhaoSat @TieuDe = N'Hài lòng về đồ mặc nhà', @MucDich = 'DO_HAI_LONG', @MaSP = 10,
         @HanTraLoi = '20991231', @PhanTramVoucher = 5;
    SELECT @MaKSMoi = MaKS FROM @Ks;
    IF NOT (@MaKSMoi IS NOT NULL) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-23', N'Tạo khảo sát đo hài lòng mới', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-24: Câu trắc nghiệm chỉ 1 lựa chọn bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @DsLC; INSERT @DsLC VALUES (1, N'Có');
    EXEC api_ql.usp_ThemCauHoi @MaKS = @MaKSMoi, @NoiDung = N'Bạn có mua lại?', @LoaiCauHoi = 'MOT_LUA_CHON', @DsLuaChon = @DsLC;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-24', N'Câu trắc nghiệm chỉ 1 lựa chọn bị từ chối', N'Lỗi 52061',
        CASE WHEN @Loi IN (52061) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-25: Thêm câu trắc nghiệm 3 lựa chọn và câu thang điểm */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @DsLC; INSERT @DsLC VALUES (1, N'Có'), (2, N'Có thể'), (3, N'Không');
    EXEC api_ql.usp_ThemCauHoi @MaKS = @MaKSMoi, @NoiDung = N'Bạn có mua lại?', @LoaiCauHoi = 'MOT_LUA_CHON', @DsLuaChon = @DsLC;
    DELETE @DsLC;
    EXEC api_ql.usp_ThemCauHoi @MaKS = @MaKSMoi, @NoiDung = N'Độ mát của vải (1-5)?', @LoaiCauHoi = 'THANG_DIEM', @DsLuaChon = @DsLC;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-25', N'Thêm câu trắc nghiệm 3 lựa chọn và câu thang điểm', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-26: Không thêm câu hỏi vào khảo sát đã đóng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @DsLC;
    EXEC api_ql.usp_ThemCauHoi @MaKS = 1, @NoiDung = N'x', @LoaiCauHoi = 'TU_LUAN', @DsLuaChon = @DsLC;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-26', N'Không thêm câu hỏi vào khảo sát đã đóng', N'Lỗi 52062',
        CASE WHEN @Loi IN (52062) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-27: Gửi khảo sát tới khách quan tâm Đồ mặc nhà */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    INSERT @So EXEC api_ql.usp_GuiKhaoSat @MaKS = @MaKSMoi, @MaLoaiQuanTam = 6;
    IF NOT ((SELECT SoNguoiNhanMoi FROM @So) >= 1) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-27', N'Gửi khảo sát tới khách quan tâm Đồ mặc nhà', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-28: Gửi lại cùng tiêu chí không tạo bản gửi trùng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @So; INSERT @So EXEC api_ql.usp_GuiKhaoSat @MaKS = @MaKSMoi, @MaLoaiQuanTam = 6;
    IF NOT ((SELECT SoNguoiNhanMoi FROM @So) = 0) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-28', N'Gửi lại cùng tiêu chí không tạo bản gửi trùng', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-29: Thống kê kết quả khảo sát KS1 */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_ThongKeKhaoSat @MaKS = 1;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-29', N'Thống kê kết quả khảo sát KS1', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-30: Báo cáo cơ cấu khách hàng (độ tuổi, giới tính, tỉnh, hạng) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_BaoCaoCoCauKhachHang;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-30', N'Báo cáo cơ cấu khách hàng (độ tuổi, giới tính, tỉnh, hạng)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-31: Báo cáo sở thích */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_BaoCaoSoThich;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-31', N'Báo cáo sở thích', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-32: Báo cáo mức độ hài lòng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_BaoCaoHaiLong;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-32', N'Báo cáo mức độ hài lòng', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-38: Xem trước số người nhận (không gửi thật) cho bản nháp KS4 */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @So; INSERT @So EXEC api_ql.usp_GuiKhaoSat @MaKS = 4, @MaLoaiQuanTam = 1, @ChiDem = 1;
    IF NOT ((SELECT SoNguoiNhanMoi FROM @So) >= 1) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-38', N'Xem trước số người nhận (không gửi thật) cho bản nháp KS4', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-39: Danh sách khảo sát cho màn hình quản lý */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_DanhSachKhaoSat;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-39', N'Danh sách khảo sát cho màn hình quản lý', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-40: Xem chi tiết khảo sát (câu hỏi + lựa chọn) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_XemChiTietKhaoSat @MaKS = 3;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-40', N'Xem chi tiết khảo sát (câu hỏi + lựa chọn)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-33: Đóng khảo sát KS2 */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_DongKhaoSat @MaKS = 2;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-33', N'Đóng khảo sát KS2', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

REVERT;   -- hậu kiểm bằng dbo

/* QL-34: Hậu kiểm: xóa mềm giữ lịch sử hóa đơn, tài khoản bị khóa */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT ((SELECT TrangThaiHoSo FROM crm.KHACH_HANG WHERE MaKH = 6) = 'DA_XOA' AND (SELECT TrangThai FROM crm.TAI_KHOAN WHERE MaTK = 11) = 'DA_KHOA' AND EXISTS (SELECT 1 FROM crm.HOA_DON WHERE MaKH = 6)) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-34', N'Hậu kiểm: xóa mềm giữ lịch sử hóa đơn, tài khoản bị khóa', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-35: Hậu kiểm: mọi người nhận khảo sát mới đều có hồ sơ + tài khoản hoạt động và quan tâm Đồ mặc nhà */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT (NOT EXISTS (SELECT 1 FROM crm.KHAO_SAT_GUI g JOIN crm.KHACH_HANG k ON k.MaKH = g.MaKH LEFT JOIN crm.TAI_KHOAN tk ON tk.MaTK = k.MaTK WHERE g.MaKS = @MaKSMoi AND (k.TrangThaiHoSo <> 'HOAT_DONG' OR tk.TrangThai IS NULL OR tk.TrangThai <> 'HOAT_DONG' OR NOT EXISTS (SELECT 1 FROM crm.KH_QUAN_TAM q WHERE q.MaKH = g.MaKH AND q.MaLoai = 6))) AND (SELECT TrangThai FROM crm.KHAO_SAT WHERE MaKS = @MaKSMoi) = 'DA_GUI') SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-35', N'Hậu kiểm: mọi người nhận khảo sát mới đều có hồ sơ + tài khoản hoạt động và quan tâm Đồ mặc nhà', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-36: Hậu kiểm: phản hồi 6 đã xử lý bởi đúng nhân viên đăng nhập (MaNV 2) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT (EXISTS (SELECT 1 FROM crm.PHAN_HOI WHERE MaPH = 6 AND TrangThai = 'DA_XU_LY' AND MaNV_XuLy = 2 AND LoaiPH = 'KHIEU_NAI')) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-36', N'Hậu kiểm: phản hồi 6 đã xử lý bởi đúng nhân viên đăng nhập (MaNV 2)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-41: Hậu kiểm: xem trước không tạo bản gửi, KS4 vẫn là bản nháp */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT ((SELECT TrangThai FROM crm.KHAO_SAT WHERE MaKS = 4) = 'NHAP' AND NOT EXISTS (SELECT 1 FROM crm.KHAO_SAT_GUI WHERE MaKS = 4)) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-41', N'Hậu kiểm: xem trước không tạo bản gửi, KS4 vẫn là bản nháp', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* QL-37: Hậu kiểm: tài khoản cấp bởi Quản lý là loại KH, bắt đổi mật khẩu */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT (EXISTS (SELECT 1 FROM crm.TAI_KHOAN tk JOIN crm.KHACH_HANG k ON k.MaTK = tk.MaTK WHERE tk.TenDangNhap = 'kh.taiquay' AND tk.LoaiTK = 'KH' AND tk.PhaiDoiMatKhau = 1 AND k.MaKH = @MaKHMoi)) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('QL-37', N'Hậu kiểm: tài khoản cấp bởi Quản lý là loại KH, bắt đổi mật khẩu', N'Thành công',
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
DECLARE @KT_DuKien INT = 41,
        @KT_Pass INT = (SELECT COUNT(*) FROM @KQ WHERE KetQua = 'PASS'),
        @KT_Fail INT = (SELECT COUNT(*) FROM @KQ WHERE KetQua = 'FAIL');
PRINT N'------------------------------------------------------------';
PRINT CONCAT(N'TONG KET ', DB_NAME(), N': ', @KT_Pass, N'/', @KT_n, N' PASS, ', @KT_Fail, N' FAIL (du kien ', @KT_DuKien, N' ca)');
PRINT CASE WHEN @KT_Fail = 0 AND @KT_n = @KT_DuKien THEN N'KET LUAN: DAT' ELSE N'KET LUAN: KHONG DAT' END;
SELECT MaKT AS CA_FAIL, ChiTiet FROM @KQ WHERE KetQua = 'FAIL';
GO
SET NOEXEC OFF;
GO
