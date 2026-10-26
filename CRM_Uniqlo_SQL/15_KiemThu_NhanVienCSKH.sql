/* =====================================================================
   Script 15: Kiểm thử phân quyền chức năng trong cùng cổng (NV_CSKH)
   ---------------------------------------------------------------------
   Chạy trên CRM_Uniqlo_Test, MỘT kết nối mới. Chứng minh lớp quyền thứ 2:
   cùng database role r_quanly nhưng vai trò ứng dụng NV_CSKH chỉ có 4 quyền.
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
DECLARE @DsLoai api_chung.DanhSachMa;
EXECUTE AS USER = 'u_app_quanly';   -- cùng cổng Quản lý, nhưng vai trò NV_CSKH ít quyền hơn

/* CS-01: Đăng nhập cskh.hoa (vai trò NV_CSKH) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC sec.usp_DatNguCanh @MaTK = 4;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('CS-01', N'Đăng nhập cskh.hoa (vai trò NV_CSKH)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* CS-02: Được tra cứu khách hàng (QL_KH_XEM) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_TimKhachHang @TuKhoa = N'An';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('CS-02', N'Được tra cứu khách hàng (QL_KH_XEM)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* CS-03: Được tiếp nhận phản hồi (QL_PH_XU_LY) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_TiepNhanPhanHoi @MaPH = 7;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('CS-03', N'Được tiếp nhận phản hồi (QL_PH_XU_LY)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* CS-04: Không được thêm khách hàng dù DB role cho phép EXECUTE */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_ThemKhachHang @HoTen = N'x', @SDT = '0909999201', @DsLoaiQuanTam = @DsLoai;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('CS-04', N'Không được thêm khách hàng dù DB role cho phép EXECUTE', N'Lỗi 50003',
        CASE WHEN @Loi IN (50003) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* CS-05: Không được xóa khách hàng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_XoaKhachHang @MaKH = 7, @LyDo = N'x';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('CS-05', N'Không được xóa khách hàng', N'Lỗi 50003',
        CASE WHEN @Loi IN (50003) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* CS-06: Không được khóa tài khoản khách hàng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_KhoaTaiKhoanKhachHang @MaKH = 7, @Khoa = 1, @LyDo = N'x';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('CS-06', N'Không được khóa tài khoản khách hàng', N'Lỗi 50003',
        CASE WHEN @Loi IN (50003) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* CS-07: Không được xem báo cáo tổng hợp */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_BaoCaoCoCauKhachHang;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('CS-07', N'Không được xem báo cáo tổng hợp', N'Lỗi 50003',
        CASE WHEN @Loi IN (50003) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* CS-08: Không được tạo khảo sát */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_TaoKhaoSat @TieuDe = N'x', @MucDich = 'DO_HAI_LONG', @HanTraLoi = '20991231';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('CS-08', N'Không được tạo khảo sát', N'Lỗi 50003',
        CASE WHEN @Loi IN (50003) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* CS-10: Được xem danh sách khảo sát (có QL_KS_THONG_KE) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_DanhSachKhaoSat;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('CS-10', N'Được xem danh sách khảo sát (có QL_KS_THONG_KE)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

REVERT;

/* CS-09: Hậu kiểm: các lần từ chối không làm thay đổi dữ liệu */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT (NOT EXISTS (SELECT 1 FROM crm.KHACH_HANG WHERE SDT = '0909999201') AND (SELECT TrangThaiHoSo FROM crm.KHACH_HANG WHERE MaKH = 7) = 'HOAT_DONG') SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('CS-09', N'Hậu kiểm: các lần từ chối không làm thay đổi dữ liệu', N'Thành công',
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
DECLARE @KT_DuKien INT = 10,
        @KT_Pass INT = (SELECT COUNT(*) FROM @KQ WHERE KetQua = 'PASS'),
        @KT_Fail INT = (SELECT COUNT(*) FROM @KQ WHERE KetQua = 'FAIL');
PRINT N'------------------------------------------------------------';
PRINT CONCAT(N'TONG KET ', DB_NAME(), N': ', @KT_Pass, N'/', @KT_n, N' PASS, ', @KT_Fail, N' FAIL (du kien ', @KT_DuKien, N' ca)');
PRINT CASE WHEN @KT_Fail = 0 AND @KT_n = @KT_DuKien THEN N'KET LUAN: DAT' ELSE N'KET LUAN: KHONG DAT' END;
SELECT MaKT AS CA_FAIL, ChiTiet FROM @KQ WHERE KetQua = 'FAIL';
GO
SET NOEXEC OFF;
GO
