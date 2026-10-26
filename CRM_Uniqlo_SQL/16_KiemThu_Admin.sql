/* =====================================================================
   Script 16: Kiểm thử cổng Admin (chức năng + bảo mật)
   ---------------------------------------------------------------------
   Chạy trên CRM_Uniqlo_Test, MỘT kết nối mới, SAU script 15.
   Đóng vai admin.it (MaTK 1, MaNV 4, vai trò ADMIN) qua EXECUTE AS USER = 'u_app_admin'.
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
DECLARE @Quyen api_admin.DanhSachMaQuyen;
DECLARE @CT api_admin.BangChiTietHoaDon;
DECLARE @KHA TABLE (MaKH INT, HoTen NVARCHAR(100), SDT_Che VARCHAR(20), Email_Che VARCHAR(110), MaHang VARCHAR(10),
                    TrangThaiHoSo VARCHAR(10), NgayDangKy DATETIME2(0), MaTK INT, TrangThaiTaiKhoan VARCHAR(10));
DECLARE @SP TABLE (MaSP INT, MaSKU VARCHAR(20), TenSP NVARCHAR(150), MaLoai INT, TenLoai NVARCHAR(50), MaNCC INT, TenNCC NVARCHAR(150),
                   ChatLieu NVARCHAR(100), MoTa NVARCHAR(1000), GiaNiemYet DECIMAL(14, 2), TrangThai VARCHAR(12), NgayRaMat DATE, TongSoDong INT, STT INT IDENTITY);
DECLARE @HD TABLE (MaHD INT, SoHoaDon VARCHAR(20), TongTienHang DECIMAL(16, 2), PhanTramGiam TINYINT, ThanhTien DECIMAL(16, 2), HangSauKhiNap VARCHAR(10));
EXECUTE AS USER = 'u_app_admin';   -- đóng vai kết nối của cổng Admin

/* AD-01: Cổng Admin không đăng nhập được bằng tài khoản Quản lý */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC sec.usp_DatNguCanh @MaTK = 3;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-01', N'Cổng Admin không đăng nhập được bằng tài khoản Quản lý', N'Lỗi 50013',
        CASE WHEN @Loi IN (50013) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-02: Đăng nhập admin.it (vai trò ADMIN) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC sec.usp_DatNguCanh @MaTK = 1;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-02', N'Đăng nhập admin.it (vai trò ADMIN)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-03: Admin không đọc trực tiếp bảng tài khoản (kể cả chuỗi băm) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT TOP (1) @Loi = MaTK FROM crm.TAI_KHOAN;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-03', N'Admin không đọc trực tiếp bảng tài khoản (kể cả chuỗi băm)', N'Lỗi 229',
        CASE WHEN @Loi IN (229) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-04: Admin không gọi được nghiệp vụ CRM của Quản lý */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_ql.usp_TimKhachHang;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-04', N'Admin không gọi được nghiệp vụ CRM của Quản lý', N'Lỗi 229',
        CASE WHEN @Loi IN (229) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-05: Tra cứu khách hàng: SĐT bị che */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    INSERT @KHA EXEC api_admin.usp_TraCuuKhachHang;
    IF NOT (EXISTS (SELECT 1 FROM @KHA) AND NOT EXISTS (SELECT 1 FROM @KHA WHERE SDT_Che NOT LIKE '%xxxx%')) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-05', N'Tra cứu khách hàng: SĐT bị che', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-06: Tìm kiếm nâng cao + sắp xếp giá giảm dần */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    INSERT @SP (MaSP, MaSKU, TenSP, MaLoai, TenLoai, MaNCC, TenNCC, ChatLieu, MoTa, GiaNiemYet, TrangThai, NgayRaMat, TongSoDong)
    EXEC api_admin.usp_TimSanPham @TuKhoa = N'Áo', @TrangThai = 'DANG_BAN', @SapXep = 'GIA_GIAM';
    IF NOT (EXISTS (SELECT 1 FROM @SP) AND (SELECT GiaNiemYet FROM @SP WHERE STT = 1) = (SELECT MAX(GiaNiemYet) FROM @SP) AND NOT EXISTS (SELECT 1 FROM @SP WHERE TrangThai <> 'DANG_BAN')) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-06', N'Tìm kiếm nâng cao + sắp xếp giá giảm dần', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-07: Cột sắp xếp ngoài danh sách trắng bị từ chối (chống injection) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_TimSanPham @SapXep = 'GiaNiemYet; DROP TABLE x';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-07', N'Cột sắp xếp ngoài danh sách trắng bị từ chối (chống injection)', N'Lỗi 52001',
        CASE WHEN @Loi IN (52001) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-08: Tìm và lọc nhà cung cấp */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_TimNhaCungCap @TrangThai = 'DANG_HOP_TAC', @SapXep = 'SO_SP_GIAM';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-08', N'Tìm và lọc nhà cung cấp', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-09: Không tự đổi vai trò của chính mình */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_DoiVaiTro @MaTK = 1, @MaVTMoi = 'QUAN_LY';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-09', N'Không tự đổi vai trò của chính mình', N'Lỗi 52094',
        CASE WHEN @Loi IN (52094) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-10: Không gán vai trò ADMIN cho tài khoản khách hàng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_DoiVaiTro @MaTK = 6, @MaVTMoi = 'ADMIN';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-10', N'Không gán vai trò ADMIN cho tài khoản khách hàng', N'Lỗi 52092',
        CASE WHEN @Loi IN (52092) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-11: Không tạo 'vai trò VIP' cho khách (VIP là hạng, không phải quyền) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_TaoVaiTro @MaVT = 'KH_VIP', @TenVT = N'Khách VIP', @CongTruyCap = 'KHACH_HANG';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-11', N'Không tạo ''vai trò VIP'' cho khách (VIP là hạng, không phải quyền)', N'Lỗi 52096',
        CASE WHEN @Loi IN (52096) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-12: Không gán quyền Admin cho vai trò khách hàng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @Quyen; INSERT @Quyen VALUES ('KH_HO_SO'), ('AD_PHAN_QUYEN');
    EXEC api_admin.usp_CapNhatQuyenVaiTro @MaVT = 'KHACH_HANG', @DsQuyen = @Quyen;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-12', N'Không gán quyền Admin cho vai trò khách hàng', N'Lỗi 52097',
        CASE WHEN @Loi IN (52097) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-13: Không tự gỡ quyền phân quyền khỏi vai trò của mình */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @Quyen; INSERT @Quyen VALUES ('AD_TRA_CUU');
    EXEC api_admin.usp_CapNhatQuyenVaiTro @MaVT = 'ADMIN', @DsQuyen = @Quyen;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-13', N'Không tự gỡ quyền phân quyền khỏi vai trò của mình', N'Lỗi 52094',
        CASE WHEN @Loi IN (52094) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-14: Thăng chức: đổi vai trò cskh.hoa NV_CSKH -> QUAN_LY (quyền thay đổi theo vai trò) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_DoiVaiTro @MaTK = 4, @MaVTMoi = 'QUAN_LY';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-14', N'Thăng chức: đổi vai trò cskh.hoa NV_CSKH -> QUAN_LY (quyền thay đổi theo vai trò)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-15: Thêm account cho nhân viên NV5 với vai trò QUAN_LY */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_TaoTaiKhoanNhanVien @MaNV = 5, @TenDangNhap = 'nv.tung', @MatKhauHashTam = '$2b$10$xWcj7ts/xbO83TtC4rGMn.Ucpo1QynUTWjfh3QS1S3.3TYspWgif.', @MaVT = 'QUAN_LY';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-15', N'Thêm account cho nhân viên NV5 với vai trò QUAN_LY', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-16: Không tạo account thứ 2 cho cùng nhân viên */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_TaoTaiKhoanNhanVien @MaNV = 5, @TenDangNhap = 'nv.tung2', @MatKhauHashTam = '$2b$10$xWcj7ts/xbO83TtC4rGMn.Ucpo1QynUTWjfh3QS1S3.3TYspWgif.', @MaVT = 'QUAN_LY';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-16', N'Không tạo account thứ 2 cho cùng nhân viên', N'Lỗi 52093',
        CASE WHEN @Loi IN (52093) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-17: Không tự khóa tài khoản của mình */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_KhoaMoTaiKhoan @MaTK = 1, @Khoa = 1, @LyDo = N'x';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-17', N'Không tự khóa tài khoản của mình', N'Lỗi 52094',
        CASE WHEN @Loi IN (52094) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-18: Nạp hóa đơn cho Hoàng Thu Hà -> tự lên VIP */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @CT; INSERT @CT VALUES ('AK-001', 1, 1290000);
    INSERT @HD EXEC api_admin.usp_NhapHoaDon @SoHoaDon = 'HD-KT-0001', @MaKH = 5, @KenhBan = 'CUA_HANG', @MaCH = 1, @MaNV = 5,
         @NgayLap = '20261005 10:00', @ChiTiet = @CT;
    IF NOT ((SELECT HangSauKhiNap FROM @HD) = 'VIP') SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-18', N'Nạp hóa đơn cho Hoàng Thu Hà -> tự lên VIP', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-19: Không bán sản phẩm 'Sắp ra mắt' */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @CT; INSERT @CT VALUES ('AK-003', 1, 990000);
    EXEC api_admin.usp_NhapHoaDon @SoHoaDon = 'HD-KT-0002', @MaKH = 3, @KenhBan = 'ONLINE', @NgayLap = '20261005 10:00', @ChiTiet = @CT;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-19', N'Không bán sản phẩm ''Sắp ra mắt''', N'Lỗi 52071',
        CASE WHEN @Loi IN (52071) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-20: Không dùng voucher của khách khác */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @CT; INSERT @CT VALUES ('AT-001', 1, 249000);
    EXEC api_admin.usp_NhapHoaDon @SoHoaDon = 'HD-KT-0003', @MaKH = 3, @KenhBan = 'ONLINE', @NgayLap = '20260920 10:00', @MaCodeVoucher = 'V1-B5C6D7E8', @ChiTiet = @CT;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-20', N'Không dùng voucher của khách khác', N'Lỗi 52073',
        CASE WHEN @Loi IN (52073) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-21: Không dùng lại voucher đã dùng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @CT; INSERT @CT VALUES ('AT-001', 1, 249000);
    EXEC api_admin.usp_NhapHoaDon @SoHoaDon = 'HD-KT-0004', @MaKH = 1, @KenhBan = 'ONLINE', @NgayLap = '20260930 10:00', @MaCodeVoucher = 'V1-A1B2C3D4', @ChiTiet = @CT;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-21', N'Không dùng lại voucher đã dùng', N'Lỗi 52073',
        CASE WHEN @Loi IN (52073) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-22: Không nạp trùng số hóa đơn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    DELETE @CT; INSERT @CT VALUES ('AT-001', 1, 249000);
    EXEC api_admin.usp_NhapHoaDon @SoHoaDon = 'HD0001', @MaKH = 1, @KenhBan = 'ONLINE', @NgayLap = '20260930 10:00', @ChiTiet = @CT;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-22', N'Không nạp trùng số hóa đơn', N'Lỗi 52072',
        CASE WHEN @Loi IN (52072) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-23: Đổi trả vượt số lượng bị chặn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_NhapDoiTra @SoHoaDon = 'HD0016', @MaSKU = 'AT-003', @SoLuong = 3, @LyDo = 'KHAC', @NgayDoiTra = '20260601';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-23', N'Đổi trả vượt số lượng bị chặn', N'Lỗi 51001',
        CASE WHEN @Loi IN (51001) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-24: Xóa account của khách đã xóa (giữ hồ sơ và lịch sử) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_XoaTaiKhoan @MaTK = 15;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-24', N'Xóa account của khách đã xóa (giữ hồ sơ và lịch sử)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-25: Xem nhật ký kiểm toán */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_XemNhatKy @SoDong = 20;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-25', N'Xem nhật ký kiểm toán', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-26: Thêm sản phẩm trùng SKU bị từ chối */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_LuuSanPham @MaSKU = 'AT-001', @TenSP = N'Trùng', @MaLoai = 1, @MaNCC = 1, @GiaNiemYet = 100000;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-26', N'Thêm sản phẩm trùng SKU bị từ chối', N'Lỗi 52081',
        CASE WHEN @Loi IN (52081) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-27: Không tự chuyển hồ sơ của mình sang nghỉ việc */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_LuuNhanVien @MaNV = 4, @HoTen = N'Trần Quốc Bảo', @MaCV = 'NV_IT', @SDT = '0912000004',
         @Email = 'bao.tran@nv.example.com', @NgayVaoLam = '20220910', @TrangThai = 'DA_NGHI';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-27', N'Không tự chuyển hồ sơ của mình sang nghỉ việc', N'Lỗi 52090',
        CASE WHEN @Loi IN (52090) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-31: Đặt lại mật khẩu cho khách quên mật khẩu (kh.binh) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_DatLaiMatKhau @MaTK = 7, @MatKhauHashTam = '$2b$10$xWcj7ts/xbO83TtC4rGMn.Ucpo1QynUTWjfh3QS1S3.3TYspWgif.';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-31', N'Đặt lại mật khẩu cho khách quên mật khẩu (kh.binh)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-32: Xem hóa đơn đã nạp kèm dòng hàng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    EXEC api_admin.usp_DanhSachHoaDon @SoHoaDon = 'HD0002';
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-32', N'Xem hóa đơn đã nạp kèm dòng hàng', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

REVERT;

/* AD-28: Hậu kiểm: Hà lên VIP, có lịch sử hạng, vai trò tài khoản vẫn KHACH_HANG */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT ((SELECT MaHang FROM crm.KHACH_HANG WHERE MaKH = 5) = 'VIP' AND (SELECT MaVT FROM crm.TAI_KHOAN WHERE MaTK = 10) = 'KHACH_HANG' AND EXISTS (SELECT 1 FROM crm.LICH_SU_HANG WHERE MaKH = 5 AND MaHangMoi = 'VIP')) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-28', N'Hậu kiểm: Hà lên VIP, có lịch sử hạng, vai trò tài khoản vẫn KHACH_HANG', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-29: Hậu kiểm: xóa account kh.nam -> hồ sơ còn, MaTK NULL, hóa đơn còn, nhật ký còn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT (NOT EXISTS (SELECT 1 FROM crm.TAI_KHOAN WHERE MaTK = 15) AND (SELECT MaTK FROM crm.KHACH_HANG WHERE MaKH = 11) IS NULL AND EXISTS (SELECT 1 FROM crm.HOA_DON WHERE MaKH = 11) AND EXISTS (SELECT 1 FROM audit.NHAT_KY WHERE HanhDong = 'XOA_TK' AND MaDoiTuong = N'15')) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-29', N'Hậu kiểm: xóa account kh.nam -> hồ sơ còn, MaTK NULL, hóa đơn còn, nhật ký còn', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-30: Hậu kiểm: account mới của NV5 là loại NV, bắt đổi mật khẩu */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT (EXISTS (SELECT 1 FROM crm.NHAN_VIEN n JOIN crm.TAI_KHOAN tk ON tk.MaTK = n.MaTK WHERE n.MaNV = 5 AND tk.LoaiTK = 'NV' AND tk.PhaiDoiMatKhau = 1 AND tk.MaVT = 'QUAN_LY')) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-30', N'Hậu kiểm: account mới của NV5 là loại NV, bắt đổi mật khẩu', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* AD-33: Hậu kiểm: đặt lại mật khẩu bật cờ bắt đổi mật khẩu và ghi nhật ký */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT ((SELECT PhaiDoiMatKhau FROM crm.TAI_KHOAN WHERE MaTK = 7) = 1 AND EXISTS (SELECT 1 FROM audit.NHAT_KY WHERE HanhDong = 'DAT_LAI_MK' AND MaDoiTuong = N'7')) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('AD-33', N'Hậu kiểm: đặt lại mật khẩu bật cờ bắt đổi mật khẩu và ghi nhật ký', N'Thành công',
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
DECLARE @KT_DuKien INT = 33,
        @KT_Pass INT = (SELECT COUNT(*) FROM @KQ WHERE KetQua = 'PASS'),
        @KT_Fail INT = (SELECT COUNT(*) FROM @KQ WHERE KetQua = 'FAIL');
PRINT N'------------------------------------------------------------';
PRINT CONCAT(N'TONG KET ', DB_NAME(), N': ', @KT_Pass, N'/', @KT_n, N' PASS, ', @KT_Fail, N' FAIL (du kien ', @KT_DuKien, N' ca)');
PRINT CASE WHEN @KT_Fail = 0 AND @KT_n = @KT_DuKien THEN N'KET LUAN: DAT' ELSE N'KET LUAN: KHONG DAT' END;
SELECT MaKT AS CA_FAIL, ChiTiet FROM @KQ WHERE KetQua = 'FAIL';
GO
SET NOEXEC OFF;
GO
