/* =====================================================================
   Script 19: Kiểm thử phần BỔ SUNG (script 18) – quên mật khẩu, lịch sử mua hàng
   ---------------------------------------------------------------------
   Chạy trên CRM_Uniqlo_Test (tạo bằng 11 SAU khi đã chạy 18), MỘT kết nối mới.
   Có thể chạy trước hoặc sau 12–17 (script 13, ca KH-27, đổi email của kh.an; script
   này tạm đặt lại email gốc rồi trả lại như cũ ở cuối). Ca BS-19 gắn ngữ cảnh phiên (chỉ đọc)
   nên các ca sau nó là "đã đăng nhập"; không đổi thứ tự các ca.
   Cách đọc kết quả giống 12–17: bảng KetQua PASS/FAIL, tab Messages có
   TONG KET ... và KET LUAN: DAT / KHONG DAT.
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
IF OBJECT_ID(N'crm.YEU_CAU_DAT_LAI_MK', N'U') IS NULL
BEGIN
    RAISERROR (N'CSDL chưa có phần bổ sung: chạy 18 trên CRM_Uniqlo rồi tạo lại bản sao bằng 10 + 11.', 16, 1);
    SET NOEXEC ON;
END
GO
DECLARE @KQ TABLE (STT INT IDENTITY, MaKT VARCHAR(10), MucTieu NVARCHAR(300), MongDoi NVARCHAR(100),
                   KetQua VARCHAR(4), ChiTiet NVARCHAR(1000));
DECLARE @Loi INT, @ThongBao NVARCHAR(4000), @DatDK BIT, @Dem INT;
DECLARE @R TABLE (HoTen NVARCHAR(100), Email VARCHAR(100), HetHan DATETIME2(0));
DECLARE @HashCu VARCHAR(255) = (SELECT MatKhauHash FROM crm.TAI_KHOAN WHERE MaTK = 6);   -- trả lại sau BS-10
DECLARE @EmailCu VARCHAR(100) = (SELECT Email FROM crm.KHACH_HANG WHERE MaTK = 6);     -- 13 (KH-27) có thể đã đổi

/* Chuẩn bị (dbo): dọn mã của các lần chạy trước; tạo sẵn một mã đã hết hạn cho kh.binh. */
DELETE crm.YEU_CAU_DAT_LAI_MK WHERE MaTK IN (1, 6, 7);
UPDATE crm.KHACH_HANG SET Email = 'an.nguyen@example.com' WHERE MaTK = 6;   -- email gốc của script 08
INSERT crm.YEU_CAU_DAT_LAI_MK (MaTK, TokenHash, NgayTao, HetHan)
VALUES (7, '5555555555555555555555555555555555555555555555555555555555555555', DATEADD(HOUR, -2, SYSDATETIME()), DATEADD(HOUR, -1, SYSDATETIME()));


/* BS-01: Quên MK kh.an: đúng tên ĐN + email (khác hoa thường) -> tạo mã chờ */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    DELETE @R; INSERT @R EXEC api_chung.usp_YeuCauDatLaiMatKhau @TenDangNhap = 'kh.an', @Email = ' AN.Nguyen@Example.com ', @TokenHash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
IF @Loi IS NULL
    IF (SELECT COUNT(*) FROM @R WHERE Email = 'an.nguyen@example.com') <> 1 OR NOT EXISTS (SELECT 1 FROM crm.YEU_CAU_DAT_LAI_MK WHERE TokenHash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' AND MaTK = 6 AND TrangThai = 'CHO') SET @DatDK = 0;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-01', N'Quên MK kh.an: đúng tên ĐN + email (khác hoa thường) -> tạo mã chờ', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-02: Quên MK: email không khớp hồ sơ -> không trả dòng, không tạo mã */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    DELETE @R; INSERT @R EXEC api_chung.usp_YeuCauDatLaiMatKhau @TenDangNhap = 'kh.an', @Email = 'sai@example.com', @TokenHash = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
IF @Loi IS NULL
    IF EXISTS (SELECT 1 FROM @R) OR EXISTS (SELECT 1 FROM crm.YEU_CAU_DAT_LAI_MK WHERE TokenHash = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb') SET @DatDK = 0;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-02', N'Quên MK: email không khớp hồ sơ -> không trả dòng, không tạo mã', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-03: Quên MK: tài khoản Admin gọi từ cổng Khách hàng -> không trả dòng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    DELETE @R; INSERT @R EXEC api_chung.usp_YeuCauDatLaiMatKhau @TenDangNhap = 'admin.it', @Email = 'bao.tran@nv.example.com', @TokenHash = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
IF @Loi IS NULL
    IF EXISTS (SELECT 1 FROM @R) OR EXISTS (SELECT 1 FROM crm.YEU_CAU_DAT_LAI_MK WHERE TokenHash = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc') SET @DatDK = 0;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-03', N'Quên MK: tài khoản Admin gọi từ cổng Khách hàng -> không trả dòng', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-04: Quên MK: tài khoản đang bị khóa (kh.quyen) -> không trả dòng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    DELETE @R; INSERT @R EXEC api_chung.usp_YeuCauDatLaiMatKhau @TenDangNhap = 'kh.quyen', @Email = 'quyen.phan@example.com', @TokenHash = 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
IF @Loi IS NULL
    IF EXISTS (SELECT 1 FROM @R) SET @DatDK = 0;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-04', N'Quên MK: tài khoản đang bị khóa (kh.quyen) -> không trả dòng', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-05: Quên MK: mã không phải SHA-256 hex bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    EXEC api_chung.usp_YeuCauDatLaiMatKhau @TenDangNhap = 'kh.an', @Email = 'an.nguyen@example.com', @TokenHash = 'mat-khau-tho';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-05', N'Quên MK: mã không phải SHA-256 hex bị từ chối', N'Lỗi 52001',
        CASE WHEN @Loi IN (52001) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-06: Quên MK Admin: admin.it từ cổng Admin -> tạo mã */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_admin';
BEGIN TRY
    DELETE @R; INSERT @R EXEC api_chung.usp_YeuCauDatLaiMatKhau @TenDangNhap = 'admin.it', @Email = 'bao.tran@nv.example.com', @TokenHash = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
IF @Loi IS NULL
    IF (SELECT COUNT(*) FROM @R) <> 1 SET @DatDK = 0;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-06', N'Quên MK Admin: admin.it từ cổng Admin -> tạo mã', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-07: Đặt lại MK: mã không tồn tại */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    EXEC api_chung.usp_DatLaiMatKhauBangMa @TokenHash = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', @MatKhauHashMoi = '$2b$10$xWcj7ts/xbO83TtC4rGMn.Ucpo1QynUTWjfh3QS1S3.3TYspWgif.';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-07', N'Đặt lại MK: mã không tồn tại', N'Lỗi 52098',
        CASE WHEN @Loi IN (52098) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-08: Đặt lại MK: mã của khách dùng từ cổng Admin bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_admin';
BEGIN TRY
    EXEC api_chung.usp_DatLaiMatKhauBangMa @TokenHash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', @MatKhauHashMoi = '$2b$10$xWcj7ts/xbO83TtC4rGMn.Ucpo1QynUTWjfh3QS1S3.3TYspWgif.';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-08', N'Đặt lại MK: mã của khách dùng từ cổng Admin bị từ chối', N'Lỗi 52098',
        CASE WHEN @Loi IN (52098) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-09: Đặt lại MK: chuỗi băm quá ngắn (mật khẩu thô) bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    EXEC api_chung.usp_DatLaiMatKhauBangMa @TokenHash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', @MatKhauHashMoi = 'Demo@2026';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-09', N'Đặt lại MK: chuỗi băm quá ngắn (mật khẩu thô) bị từ chối', N'Lỗi 52001',
        CASE WHEN @Loi IN (52001) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-10: Đặt lại MK kh.an bằng mã hợp lệ: đổi băm, mã thành DA_DUNG */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    EXEC api_chung.usp_DatLaiMatKhauBangMa @TokenHash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', @MatKhauHashMoi = '$2b$10$xWcj7ts/xbO83TtC4rGMn.Ucpo1QynUTWjfh3QS1S3.3TYspWgif.';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
IF @Loi IS NULL
    IF (SELECT MatKhauHash FROM crm.TAI_KHOAN WHERE MaTK = 6) <> '$2b$10$xWcj7ts/xbO83TtC4rGMn.Ucpo1QynUTWjfh3QS1S3.3TYspWgif.' OR (SELECT TrangThai FROM crm.YEU_CAU_DAT_LAI_MK WHERE TokenHash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa') <> 'DA_DUNG' SET @DatDK = 0;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-10', N'Đặt lại MK kh.an bằng mã hợp lệ: đổi băm, mã thành DA_DUNG', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-11: Đặt lại MK: mã đã dùng không dùng lại được */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    EXEC api_chung.usp_DatLaiMatKhauBangMa @TokenHash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', @MatKhauHashMoi = '$2b$10$xWcj7ts/xbO83TtC4rGMn.Ucpo1QynUTWjfh3QS1S3.3TYspWgif.';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-11', N'Đặt lại MK: mã đã dùng không dùng lại được', N'Lỗi 52098',
        CASE WHEN @Loi IN (52098) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-12: Yêu cầu mới hủy mã cũ còn chờ (kh.binh: mã 1 -> DA_HUY) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    INSERT @R EXEC api_chung.usp_YeuCauDatLaiMatKhau @TenDangNhap = 'kh.binh', @Email = 'binh.tran@example.com', @TokenHash = '1111111111111111111111111111111111111111111111111111111111111111'; INSERT @R EXEC api_chung.usp_YeuCauDatLaiMatKhau @TenDangNhap = 'kh.binh', @Email = 'binh.tran@example.com', @TokenHash = '2222222222222222222222222222222222222222222222222222222222222222';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
IF @Loi IS NULL
    IF (SELECT TrangThai FROM crm.YEU_CAU_DAT_LAI_MK WHERE TokenHash = '1111111111111111111111111111111111111111111111111111111111111111') <> 'DA_HUY' OR (SELECT TrangThai FROM crm.YEU_CAU_DAT_LAI_MK WHERE TokenHash = '2222222222222222222222222222222222222222222222222222222222222222') <> 'CHO' SET @DatDK = 0;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-12', N'Yêu cầu mới hủy mã cũ còn chờ (kh.binh: mã 1 -> DA_HUY)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-13: Mã đã bị hủy không dùng được */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    EXEC api_chung.usp_DatLaiMatKhauBangMa @TokenHash = '1111111111111111111111111111111111111111111111111111111111111111', @MatKhauHashMoi = '$2b$10$xWcj7ts/xbO83TtC4rGMn.Ucpo1QynUTWjfh3QS1S3.3TYspWgif.';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-13', N'Mã đã bị hủy không dùng được', N'Lỗi 52098',
        CASE WHEN @Loi IN (52098) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-14: Giới hạn 3 yêu cầu / 15 phút: yêu cầu thứ 4 không tạo mã */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    INSERT @R EXEC api_chung.usp_YeuCauDatLaiMatKhau @TenDangNhap = 'kh.binh', @Email = 'binh.tran@example.com', @TokenHash = '3333333333333333333333333333333333333333333333333333333333333333'; DELETE @R; INSERT @R EXEC api_chung.usp_YeuCauDatLaiMatKhau @TenDangNhap = 'kh.binh', @Email = 'binh.tran@example.com', @TokenHash = '4444444444444444444444444444444444444444444444444444444444444444';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
IF @Loi IS NULL
    IF EXISTS (SELECT 1 FROM @R) OR EXISTS (SELECT 1 FROM crm.YEU_CAU_DAT_LAI_MK WHERE TokenHash = '4444444444444444444444444444444444444444444444444444444444444444') SET @DatDK = 0;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-14', N'Giới hạn 3 yêu cầu / 15 phút: yêu cầu thứ 4 không tạo mã', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-15: Mã hết hạn không dùng được */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    EXEC api_chung.usp_DatLaiMatKhauBangMa @TokenHash = '5555555555555555555555555555555555555555555555555555555555555555', @MatKhauHashMoi = '$2b$10$xWcj7ts/xbO83TtC4rGMn.Ucpo1QynUTWjfh3QS1S3.3TYspWgif.';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-15', N'Mã hết hạn không dùng được', N'Lỗi 52098',
        CASE WHEN @Loi IN (52098) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-16: Cổng Khách hàng không đọc trực tiếp bảng mã đặt lại */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    SELECT TOP (1) @Dem = MaYC FROM crm.YEU_CAU_DAT_LAI_MK;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-16', N'Cổng Khách hàng không đọc trực tiếp bảng mã đặt lại', N'Lỗi 229',
        CASE WHEN @Loi IN (229) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-17: Cổng Quản lý không gọi được lịch sử mua hàng của cổng Khách */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_quanly';
BEGIN TRY
    EXEC api_kh.usp_LichSuGiaoDich;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-17', N'Cổng Quản lý không gọi được lịch sử mua hàng của cổng Khách', N'Lỗi 229',
        CASE WHEN @Loi IN (229) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-18: Lịch sử mua hàng khi chưa đăng nhập bị chặn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    EXEC api_kh.usp_LichSuGiaoDich;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-18', N'Lịch sử mua hàng khi chưa đăng nhập bị chặn', N'Lỗi 50001',
        CASE WHEN @Loi IN (50001) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-19: Đăng nhập kh.an (cổng Khách hàng) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    EXEC sec.usp_DatNguCanh @MaTK = 6;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-19', N'Đăng nhập kh.an (cổng Khách hàng)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-20: Lịch sử mua hàng kh.an chạy được */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    EXEC api_kh.usp_LichSuGiaoDich;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-20', N'Lịch sử mua hàng kh.an chạy được', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-21: Lịch sử mua hàng: từ ngày sau đến ngày bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    EXEC api_kh.usp_LichSuGiaoDich @TuNgay = '2026-12-31', @DenNgay = '2026-01-01';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-21', N'Lịch sử mua hàng: từ ngày sau đến ngày bị từ chối', N'Lỗi 52001',
        CASE WHEN @Loi IN (52001) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* BS-22: Phiên đã đăng nhập không dùng được quên mật khẩu */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
EXECUTE AS USER = 'u_app_khachhang';
BEGIN TRY
    EXEC api_chung.usp_YeuCauDatLaiMatKhau @TenDangNhap = 'kh.an', @Email = 'an.nguyen@example.com', @TokenHash = '9999999999999999999999999999999999999999999999999999999999999999';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
REVERT;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('BS-22', N'Phiên đã đăng nhập không dùng được quên mật khẩu', N'Lỗi 52001',
        CASE WHEN @Loi IN (52001) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* Dọn (dbo): trả mật khẩu cũ (Demo@2026) cho kh.an để các kiểm thử khác vẫn đăng nhập được. */
UPDATE crm.TAI_KHOAN SET MatKhauHash = @HashCu WHERE MaTK = 6;
UPDATE crm.KHACH_HANG SET Email = @EmailCu WHERE MaTK = 6;

/* ===================== TỔNG KẾT ===================== */
SELECT STT, MaKT, KetQua, MucTieu, MongDoi, ChiTiet FROM @KQ ORDER BY STT;
DECLARE @KT_i INT = 1, @KT_n INT = (SELECT COUNT(*) FROM @KQ), @KT_Dong NVARCHAR(2000);
WHILE @KT_i <= @KT_n
BEGIN
    SELECT @KT_Dong = CONCAT(KetQua, N' | ', MaKT, N' | ', MucTieu, N' | Mong đợi: ', MongDoi,
                             CASE WHEN KetQua = 'FAIL' THEN CONCAT(N' | THỰC TẾ: ', ChiTiet) ELSE N'' END)
    FROM @KQ WHERE STT = @KT_i;
    PRINT @KT_Dong;
    SET @KT_i += 1;
END
DECLARE @KT_DuKien INT = 22,
        @KT_Pass INT = (SELECT COUNT(*) FROM @KQ WHERE KetQua = 'PASS'),
        @KT_Fail INT = (SELECT COUNT(*) FROM @KQ WHERE KetQua = 'FAIL');
PRINT N'------------------------------------------------------------';
PRINT CONCAT(N'TONG KET ', DB_NAME(), N': ', @KT_Pass, N'/', @KT_n, N' PASS, ', @KT_Fail, N' FAIL (du kien ', @KT_DuKien, N' ca)');
PRINT CASE WHEN @KT_Fail = 0 AND @KT_n = @KT_DuKien THEN N'KET LUAN: DAT' ELSE N'KET LUAN: KHONG DAT' END;
SELECT MaKT AS CA_FAIL, ChiTiet FROM @KQ WHERE KetQua = 'FAIL';
GO
SET NOEXEC OFF;
GO
