/* =====================================================================
   Script 13: Kiểm thử cổng Khách hàng (chức năng + bảo mật)
   ---------------------------------------------------------------------
   Chạy trên CRM_Uniqlo_Test, trong MỘT kết nối mới (ngữ cảnh phiên là read-only).
   Dùng EXECUTE AS USER = 'u_app_khachhang' để đóng vai kết nối của ứng dụng cổng
   Khách hàng (cần quyền IMPERSONATE – dbo/sysadmin có sẵn).
   Giới hạn: EXECUTE AS USER mô phỏng đúng quyền CSDL của role, nhưng không kiểm
   được phần xác thực mật khẩu (do ứng dụng làm) và không thay cho kiểm thử qua
   giao diện thật với login crm_app_khachhang.
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
/* Chuẩn bị (dbo): 2 thủ tục "LỖI CỐ Ý" mô phỏng lập trình viên quên lọc theo MaKH,
   chỉ tồn tại trong CSDL kiểm thử, để chứng minh RLS là lớp phòng thủ thứ hai. */
CREATE OR ALTER PROCEDURE crm.usp_KiemThu_DocTatCaPhanHoi AS
    SELECT MaPH, MaKH FROM crm.PHAN_HOI;               -- cố ý KHÔNG có WHERE MaKH = ...
GO
CREATE OR ALTER PROCEDURE crm.usp_KiemThu_GhiPhanHoiHo @MaKH INT AS
    INSERT crm.PHAN_HOI (MaKH, MaSP, LoaiPH, DiemDanhGia, NoiDung) VALUES (@MaKH, 1, 'GOP_Y', 3, N'Ghi hộ người khác');
GO
GRANT EXECUTE ON crm.usp_KiemThu_DocTatCaPhanHoi TO r_khachhang;
GRANT EXECUTE ON crm.usp_KiemThu_GhiPhanHoiHo TO r_khachhang;
GO
DECLARE @KQ TABLE (STT INT IDENTITY, MaKT VARCHAR(10), MucTieu NVARCHAR(300), MongDoi NVARCHAR(100),
                   KetQua VARCHAR(4), ChiTiet NVARCHAR(1000));
DECLARE @Loi INT, @ThongBao NVARCHAR(4000), @DatDK BIT;
DECLARE @DsLoai api_chung.DanhSachMa; INSERT @DsLoai VALUES (1), (2);
DECLARE @TraLoi api_kh.BangTraLoi;
DECLARE @PH TABLE (MaPH INT, MaSP INT, TenSP NVARCHAR(150), LoaiPH VARCHAR(10), DiemDanhGia TINYINT, NoiDung NVARCHAR(2000),
                   NgayGui DATETIME2(0), TrangThai VARCHAR(10), NoiDungTraLoi NVARCHAR(2000), NgayTraLoi DATETIME2(0));
DECLARE @KS TABLE (MaKS INT, TieuDe NVARCHAR(200), MoTa NVARCHAR(1000), MucDich VARCHAR(15), HanTraLoi DATETIME2(0),
                   PhanTramVoucher TINYINT, NgayGui DATETIME2(0), NgayHoanThanh DATETIME2(0), TrangThai VARCHAR(13), CoTheThucHien BIT);
DECLARE @RLS TABLE (MaPH INT, MaKH INT);
EXECUTE AS USER = 'u_app_khachhang';   -- đóng vai kết nối của cổng Khách hàng

/* KH-01: Chưa đăng nhập thì không xem được hồ sơ */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_kh.usp_XemHoSo;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-01', N'Chưa đăng nhập thì không xem được hồ sơ', N'Lỗi 50001',
        CASE WHEN @Loi IN (50001) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-02: Đăng ký tài khoản khách hàng (kèm sở thích) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_kh.usp_DangKy @TenDangNhap = 'kh.test01', @MatKhauHash = '$2b$10$MLb/KjA8XbVYbdlVIiBbre.rtMSn2YkBLT1E01a.WbM9q4N4LVoi.', @HoTen = N'Khách Thử Nghiệm',
         @SDT = '0909999001', @GioiTinh = 'NU', @NgaySinh = '20010101', @Email = 'test01@example.com', @MaTinh = 'HCM', @DsLoaiQuanTam = @DsLoai;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-02', N'Đăng ký tài khoản khách hàng (kèm sở thích)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-03: Đăng ký trùng SĐT bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_kh.usp_DangKy @TenDangNhap = 'kh.test02', @MatKhauHash = '$2b$10$MLb/KjA8XbVYbdlVIiBbre.rtMSn2YkBLT1E01a.WbM9q4N4LVoi.', @HoTen = N'Trùng', @SDT = '0901000002', @DsLoaiQuanTam = @DsLoai;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-03', N'Đăng ký trùng SĐT bị từ chối', N'Lỗi 52002',
        CASE WHEN @Loi IN (52002) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-04: Đăng ký với mật khẩu thô bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_kh.usp_DangKy @TenDangNhap = 'kh.test03', @MatKhauHash = 'matkhau123', @HoTen = N'Thô', @SDT = '0909999003', @DsLoaiQuanTam = @DsLoai;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-04', N'Đăng ký với mật khẩu thô bị từ chối', N'Lỗi 52001',
        CASE WHEN @Loi IN (52001) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-05: Cổng Khách hàng không đăng nhập được bằng tài khoản Quản lý */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC sec.usp_DatNguCanh @MaTK = 3;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-05', N'Cổng Khách hàng không đăng nhập được bằng tài khoản Quản lý', N'Lỗi 50013',
        CASE WHEN @Loi IN (50013) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-06: Tài khoản bị khóa không đăng nhập được */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC sec.usp_DatNguCanh @MaTK = 14;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-06', N'Tài khoản bị khóa không đăng nhập được', N'Lỗi 50012',
        CASE WHEN @Loi IN (50012) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-07: Đăng nhập kh.an (thiết lập ngữ cảnh read-only) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC sec.usp_DatNguCanh @MaTK = 6;
    EXEC api_chung.usp_GhiNhanDangNhap;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-07', N'Đăng nhập kh.an (thiết lập ngữ cảnh read-only)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-08: Không thể tự đổi MaKH trong ngữ cảnh để giả mạo khách khác */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC sys.sp_set_session_context @key = N'MaKH', @value = 2;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-08', N'Không thể tự đổi MaKH trong ngữ cảnh để giả mạo khách khác', N'Bị từ chối (bất kỳ lỗi)',
        CASE WHEN @Loi IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-09: Không đọc trực tiếp bảng khách hàng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT TOP (1) @Loi = MaKH FROM crm.KHACH_HANG;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-09', N'Không đọc trực tiếp bảng khách hàng', N'Lỗi 229',
        CASE WHEN @Loi IN (229) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-10: Không đọc trực tiếp nhật ký kiểm toán */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT TOP (1) @Loi = MaNK FROM audit.NHAT_KY;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-10', N'Không đọc trực tiếp nhật ký kiểm toán', N'Lỗi 229',
        CASE WHEN @Loi IN (229) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-11: Không gọi được thủ tục của Quản lý */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_TimKhachHang;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-11', N'Không gọi được thủ tục của Quản lý', N'Lỗi 229',
        CASE WHEN @Loi IN (229) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-12: Không gọi được thủ tục của Admin */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_TimSanPham;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-12', N'Không gọi được thủ tục của Admin', N'Lỗi 229',
        CASE WHEN @Loi IN (229) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-13: Chỉ thấy phản hồi của chính mình (MaPH 1, 10) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    INSERT @PH EXEC api_kh.usp_XemPhanHoiCuaToi;
    IF NOT ((SELECT COUNT(*) FROM @PH) = 2 AND NOT EXISTS (SELECT 1 FROM @PH WHERE MaPH NOT IN (1, 10))) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-13', N'Chỉ thấy phản hồi của chính mình (MaPH 1, 10)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-14: Chỉ thấy khảo sát gửi cho mình (KS1, KS2, KS3) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    INSERT @KS EXEC api_kh.usp_DanhSachKhaoSat;
    IF NOT ((SELECT STRING_AGG(CAST(MaKS AS VARCHAR(5)), ',') WITHIN GROUP (ORDER BY MaKS) FROM @KS) = '1,2,3') SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-14', N'Chỉ thấy khảo sát gửi cho mình (KS1, KS2, KS3)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-15: Không xem được khảo sát không gửi cho mình */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_kh.usp_XemKhaoSat @MaKS = 4;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-15', N'Không xem được khảo sát không gửi cho mình', N'Lỗi 52030',
        CASE WHEN @Loi IN (52030) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-16: Nộp khảo sát thiếu câu bắt buộc bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @TraLoi; INSERT @TraLoi (MaCauHoi, DiemSo) VALUES (6, 5);
    EXEC api_kh.usp_NopKhaoSat @MaKS = 2, @TraLoi = @TraLoi;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-16', N'Nộp khảo sát thiếu câu bắt buộc bị từ chối', N'Lỗi 52032',
        CASE WHEN @Loi IN (52032) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-17: Nộp lựa chọn thuộc câu hỏi khác bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @TraLoi; INSERT @TraLoi (MaCauHoi, DiemSo, MaLC) VALUES (6, 5, NULL), (7, 4, NULL), (8, NULL, 11);
    EXEC api_kh.usp_NopKhaoSat @MaKS = 2, @TraLoi = @TraLoi;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-17', N'Nộp lựa chọn thuộc câu hỏi khác bị từ chối', N'Lỗi 52032',
        CASE WHEN @Loi IN (52032) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-18: Câu một lựa chọn chọn 2 đáp án bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @TraLoi; INSERT @TraLoi (MaCauHoi, DiemSo, MaLC) VALUES (6, 5, NULL), (7, 4, NULL), (8, NULL, 8), (8, NULL, 9);
    EXEC api_kh.usp_NopKhaoSat @MaKS = 2, @TraLoi = @TraLoi;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-18', N'Câu một lựa chọn chọn 2 đáp án bị từ chối', N'Lỗi 52032',
        CASE WHEN @Loi IN (52032) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-19: Câu hỏi của khảo sát khác bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @TraLoi; INSERT @TraLoi (MaCauHoi, DiemSo, MaLC) VALUES (6, 5, NULL), (7, 4, NULL), (8, NULL, 8), (1, 5, NULL);
    EXEC api_kh.usp_NopKhaoSat @MaKS = 2, @TraLoi = @TraLoi;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-19', N'Câu hỏi của khảo sát khác bị từ chối', N'Lỗi 52032',
        CASE WHEN @Loi IN (52032) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-20: Nộp khảo sát KS2 hợp lệ (tự phát voucher 5%) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @TraLoi; INSERT @TraLoi (MaCauHoi, DiemSo, MaLC) VALUES (6, 5, NULL), (7, 4, NULL), (8, NULL, 8);
    EXEC api_kh.usp_NopKhaoSat @MaKS = 2, @TraLoi = @TraLoi;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-20', N'Nộp khảo sát KS2 hợp lệ (tự phát voucher 5%)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-21: Không nộp lại khảo sát đã hoàn thành */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_kh.usp_NopKhaoSat @MaKS = 2, @TraLoi = @TraLoi;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-21', N'Không nộp lại khảo sát đã hoàn thành', N'Lỗi 52031',
        CASE WHEN @Loi IN (52031) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-22: Nộp khảo sát thăm dò KS3 (câu nhiều lựa chọn + tự luận) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @TraLoi;
    INSERT @TraLoi (MaCauHoi, MaLC, NoiDungTuLuan) VALUES (9, 11, NULL), (10, 15, NULL), (11, 17, NULL), (11, 19, NULL), (12, NULL, N'Có túi trong');
    EXEC api_kh.usp_NopKhaoSat @MaKS = 3, @TraLoi = @TraLoi;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-22', N'Nộp khảo sát thăm dò KS3 (câu nhiều lựa chọn + tự luận)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-23: Gửi phản hồi hợp lệ */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_kh.usp_GuiPhanHoi @MaSP = 2, @LoaiPH = 'GOP_Y', @DiemDanhGia = 4, @NoiDung = N'Mong có thêm màu pastel';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-23', N'Gửi phản hồi hợp lệ', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-24: Phản hồi điểm 6 bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_kh.usp_GuiPhanHoi @MaSP = 2, @LoaiPH = 'GOP_Y', @DiemDanhGia = 6, @NoiDung = N'x';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-24', N'Phản hồi điểm 6 bị từ chối', N'Lỗi 52001',
        CASE WHEN @Loi IN (52001) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-25: Phản hồi sản phẩm không tồn tại bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_kh.usp_GuiPhanHoi @MaSP = 9999, @LoaiPH = 'KHEN', @DiemDanhGia = 5, @NoiDung = N'x';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-25', N'Phản hồi sản phẩm không tồn tại bị từ chối', N'Lỗi 52020',
        CASE WHEN @Loi IN (52020) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-26: Sửa SĐT trùng hồ sơ khác bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_kh.usp_CapNhatHoSo @HoTen = N'Nguyễn Thị An', @SDT = '0901000002', @GioiTinh = 'NU', @NgaySinh = '19980412', @MaTinh = 'HCM';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-26', N'Sửa SĐT trùng hồ sơ khác bị từ chối', N'Lỗi 52002',
        CASE WHEN @Loi IN (52002) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-27: Sửa thông tin hợp lệ (email mới, sở thích mới) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_kh.usp_CapNhatHoSo @HoTen = N'Nguyễn Thị An', @SDT = '0901000001', @GioiTinh = 'NU', @NgaySinh = '19980412',
         @Email = 'an.nguyen.moi@example.com', @MaTinh = 'HCM', @CapNhatSoThich = 1, @DsLoaiQuanTam = @DsLoai;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-27', N'Sửa thông tin hợp lệ (email mới, sở thích mới)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-28: RLS – thủ tục lỗi quên lọc vẫn chỉ trả dữ liệu của chính mình */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    INSERT @RLS EXEC crm.usp_KiemThu_DocTatCaPhanHoi;
    IF NOT (EXISTS (SELECT 1 FROM @RLS) AND NOT EXISTS (SELECT 1 FROM @RLS WHERE MaKH <> 1)) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-28', N'RLS – thủ tục lỗi quên lọc vẫn chỉ trả dữ liệu của chính mình', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-29: RLS – thủ tục lỗi không ghi được dữ liệu mang MaKH người khác */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC crm.usp_KiemThu_GhiPhanHoiHo @MaKH = 2;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-29', N'RLS – thủ tục lỗi không ghi được dữ liệu mang MaKH người khác', N'Lỗi 33504',
        CASE WHEN @Loi IN (33504) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

REVERT;   -- trở lại dbo để hậu kiểm

/* KH-30: Hậu kiểm: hồ sơ + tài khoản đăng ký đúng loại KH, vai trò KHACH_HANG, hạng THUONG, 2 sở thích */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT (EXISTS (SELECT 1 FROM crm.KHACH_HANG k JOIN crm.TAI_KHOAN tk ON tk.MaTK = k.MaTK WHERE tk.TenDangNhap = 'kh.test01' AND tk.LoaiTK = 'KH' AND tk.MaVT = 'KHACH_HANG' AND k.MaHang = 'THUONG' AND (SELECT COUNT(*) FROM crm.KH_QUAN_TAM q WHERE q.MaKH = k.MaKH) = 2)) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-30', N'Hậu kiểm: hồ sơ + tài khoản đăng ký đúng loại KH, vai trò KHACH_HANG, hạng THUONG, 2 sở thích', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-31: Hậu kiểm: KS2 của An đã hoàn thành, có 3 câu trả lời và đúng 1 voucher 5% */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT ((SELECT COUNT(*) FROM crm.TRA_LOI WHERE MaKS = 2 AND MaKH = 1) = 3 AND (SELECT NgayHoanThanh FROM crm.KHAO_SAT_GUI WHERE MaKS = 2 AND MaKH = 1) IS NOT NULL AND (SELECT COUNT(*) FROM crm.VOUCHER WHERE MaKS = 2 AND MaKH = 1 AND PhanTramGiam = 5) = 1) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-31', N'Hậu kiểm: KS2 của An đã hoàn thành, có 3 câu trả lời và đúng 1 voucher 5%', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-32: Hậu kiểm: câu nhiều lựa chọn KS3 lưu 2 lựa chọn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT ((SELECT COUNT(*) FROM crm.TRA_LOI_LUA_CHON WHERE MaKS = 3 AND MaKH = 1 AND MaCauHoi = 11) = 2) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-32', N'Hậu kiểm: câu nhiều lựa chọn KS3 lưu 2 lựa chọn', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-33: Hậu kiểm: phản hồi ghi đúng MaKH của người đăng nhập, trạng thái MOI */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT (EXISTS (SELECT 1 FROM crm.PHAN_HOI WHERE MaKH = 1 AND NoiDung = N'Mong có thêm màu pastel' AND TrangThai = 'MOI')) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-33', N'Hậu kiểm: phản hồi ghi đúng MaKH của người đăng nhập, trạng thái MOI', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* KH-34: Hậu kiểm: các thao tác được ghi nhật ký (DANG_KY, DANG_NHAP, SUA_HO_SO) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT ((SELECT COUNT(DISTINCT HanhDong) FROM audit.NHAT_KY WHERE HanhDong IN ('DANG_KY', 'DANG_NHAP', 'SUA_HO_SO')) = 3) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('KH-34', N'Hậu kiểm: các thao tác được ghi nhật ký (DANG_KY, DANG_NHAP, SUA_HO_SO)', N'Thành công',
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
DECLARE @KT_DuKien INT = 34,
        @KT_Pass INT = (SELECT COUNT(*) FROM @KQ WHERE KetQua = 'PASS'),
        @KT_Fail INT = (SELECT COUNT(*) FROM @KQ WHERE KetQua = 'FAIL');
PRINT N'------------------------------------------------------------';
PRINT CONCAT(N'TONG KET ', DB_NAME(), N': ', @KT_Pass, N'/', @KT_n, N' PASS, ', @KT_Fail, N' FAIL (du kien ', @KT_DuKien, N' ca)');
PRINT CASE WHEN @KT_Fail = 0 AND @KT_n = @KT_DuKien THEN N'KET LUAN: DAT' ELSE N'KET LUAN: KHONG DAT' END;
SELECT MaKT AS CA_FAIL, ChiTiet FROM @KQ WHERE KetQua = 'FAIL';
GO
/* Dọn thủ tục lỗi cố ý */
DROP PROCEDURE IF EXISTS crm.usp_KiemThu_DocTatCaPhanHoi;
DROP PROCEDURE IF EXISTS crm.usp_KiemThu_GhiPhanHoiHo;
GO
SET NOEXEC OFF;
GO
