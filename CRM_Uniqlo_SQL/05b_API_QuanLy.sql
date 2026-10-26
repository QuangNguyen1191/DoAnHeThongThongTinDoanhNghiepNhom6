/* =====================================================================
   Script 05b: Thủ tục cổng Quản lý (api_ql)
   ---------------------------------------------------------------------
   Đáp ứng yêu cầu đề (III.4 – Người quản lý):
     1. Thêm khách hàng mới           -> usp_ThemKhachHang, usp_CapTaiKhoanKhachHang
     2. Xóa khách hàng (xóa mềm)      -> usp_XoaKhachHang
     3. Khóa tài khoản khách hàng     -> usp_KhoaTaiKhoanKhachHang
     4. Tiếp nhận phản hồi            -> usp_DanhSachPhanHoi, usp_TiepNhanPhanHoi, usp_TraLoiPhanHoi
     5. Báo cáo độ tuổi, sở thích     -> usp_BaoCaoCoCauKhachHang, usp_BaoCaoSoThich (+ usp_BaoCaoHaiLong)
     6. Tạo khảo sát, gửi tới TK KH   -> usp_TaoKhaoSat, usp_ThemCauHoi, usp_XoaCauHoi, usp_GuiKhaoSat, usp_DongKhaoSat
                                          + usp_DanhSachKhaoSat, usp_XemChiTietKhaoSat
     7. Thống kê kết quả khảo sát     -> usp_ThongKeKhaoSat
   Tra cứu: usp_TimKhachHang, usp_XemHoSoKhachHang, usp_CapNhatKhachHang
   Mỗi thủ tục kiểm tra một quyền chức năng (QL_*) trong VAI_TRO_QUYEN.
   ===================================================================== */
USE CRM_Uniqlo;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

/* ------------------------- KHÁCH HÀNG ------------------------- */

CREATE OR ALTER PROCEDURE api_ql.usp_TimKhachHang
    @TuKhoa        NVARCHAR(100) = NULL,   -- tìm trong họ tên / SĐT / email
    @MaHang        VARCHAR(10)   = NULL,
    @MaTinh        VARCHAR(10)   = NULL,
    @GioiTinh      VARCHAR(4)    = NULL,
    @TuoiTu        INT           = NULL,
    @TuoiDen       INT           = NULL,
    @MaLoaiQuanTam INT           = NULL,
    @TrangThaiHoSo VARCHAR(10)   = 'HOAT_DONG',   -- NULL = tất cả
    @SapXep        VARCHAR(20)   = 'TEN',         -- TEN | NGAY_DK_MOI | DIEM_CAO
    @Trang         INT           = 1,
    @SoDong        INT           = 20
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_KH_XEM';
    IF @Trang < 1 OR @SoDong NOT BETWEEN 1 AND 200 OR @SapXep NOT IN ('TEN', 'NGAY_DK_MOI', 'DIEM_CAO')
        THROW 52001, N'Tham số phân trang/sắp xếp không hợp lệ.', 1;

    DECLARE @Mau NVARCHAR(102) = N'%' + NULLIF(TRIM(@TuKhoa), N'') + N'%';

    SELECT v.MaKH, v.HoTen, v.GioiTinh, v.Tuoi, v.NhomTuoi, v.SDT, v.Email, v.TenTinh,
           v.MaHang, v.TenHang, v.Diem, v.SoThich, v.NgayDangKy, v.TrangThaiHoSo,
           v.TenDangNhap, v.TrangThaiTaiKhoan,
           COUNT(*) OVER () AS TongSoDong
    FROM api_ql.vw_KhachHang v
    WHERE (@Mau IS NULL OR v.HoTen LIKE @Mau OR v.SDT LIKE @Mau OR v.Email LIKE @Mau)
      AND (@MaHang IS NULL OR v.MaHang = @MaHang)
      AND (@MaTinh IS NULL OR v.MaTinh = @MaTinh)
      AND (@GioiTinh IS NULL OR v.GioiTinh = @GioiTinh)
      AND (@TuoiTu IS NULL OR v.Tuoi >= @TuoiTu)
      AND (@TuoiDen IS NULL OR v.Tuoi <= @TuoiDen)
      AND (@TrangThaiHoSo IS NULL OR v.TrangThaiHoSo = @TrangThaiHoSo)
      AND (@MaLoaiQuanTam IS NULL
           OR EXISTS (SELECT 1 FROM crm.KH_QUAN_TAM q WHERE q.MaKH = v.MaKH AND q.MaLoai = @MaLoaiQuanTam))
    ORDER BY CASE WHEN @SapXep = 'TEN' THEN v.HoTen END,
             CASE WHEN @SapXep = 'NGAY_DK_MOI' THEN v.NgayDangKy END DESC,
             CASE WHEN @SapXep = 'DIEM_CAO' THEN v.Diem END DESC,
             v.MaKH
    OFFSET (@Trang - 1) * @SoDong ROWS FETCH NEXT @SoDong ROWS ONLY
    OPTION (RECOMPILE);
END;
GO

/* Hồ sơ 360°: thông tin, sở thích, hóa đơn, đổi trả, phản hồi, khảo sát, voucher, lịch sử hạng. */
CREATE OR ALTER PROCEDURE api_ql.usp_XemHoSoKhachHang
    @MaKH INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_KH_XEM';
    IF NOT EXISTS (SELECT 1 FROM crm.KHACH_HANG WHERE MaKH = @MaKH)
        THROW 52040, N'Không tìm thấy khách hàng.', 1;

    SELECT * FROM api_ql.vw_KhachHang WHERE MaKH = @MaKH;

    SELECT l.MaLoai, l.TenLoai FROM crm.KH_QUAN_TAM q JOIN crm.LOAI_SP l ON l.MaLoai = q.MaLoai
    WHERE q.MaKH = @MaKH ORDER BY l.TenLoai;

    SELECT g.MaHD, g.SoHoaDon, g.NgayLap, g.KenhBan, ch.TenCH, g.TongTienHang, g.PhanTramGiam, g.ThanhTien
    FROM crm.vw_GiaTriHoaDon g LEFT JOIN crm.CUA_HANG ch ON ch.MaCH = g.MaCH
    WHERE g.MaKH = @MaKH ORDER BY g.NgayLap DESC;

    SELECT d.MaDT, h.SoHoaDon, sp.TenSP, d.SoLuong, d.LyDo, d.NgayDoiTra, d.GiaTriHoan
    FROM crm.vw_GiaTriDoiTra d
    JOIN crm.HOA_DON h  ON h.MaHD = d.MaHD
    JOIN crm.SAN_PHAM sp ON sp.MaSP = d.MaSP
    WHERE d.MaKH = @MaKH ORDER BY d.NgayDoiTra DESC;

    SELECT MaPH, TenSP, LoaiPH, DiemDanhGia, NoiDung, NgayGui, TrangThai, NguoiXuLy, NoiDungTraLoi, NgayTraLoi
    FROM api_ql.vw_PhanHoi WHERE MaKH = @MaKH ORDER BY NgayGui DESC;

    SELECT g.MaKS, ks.TieuDe, ks.MucDich, g.NgayGui, g.NgayHoanThanh, g.TrangThai
    FROM crm.KHAO_SAT_GUI g JOIN crm.KHAO_SAT ks ON ks.MaKS = g.MaKS
    WHERE g.MaKH = @MaKH ORDER BY g.NgayGui DESC;

    SELECT v.MaCode, v.PhanTramGiam, v.NgayPhat, v.HanDung,
           CASE WHEN h.MaHD IS NOT NULL THEN 'DA_DUNG' WHEN v.HanDung < SYSDATETIME() THEN 'HET_HAN' ELSE 'CON_HAN' END AS TrangThai
    FROM crm.VOUCHER v LEFT JOIN crm.HOA_DON h ON h.MaVoucher = v.MaVoucher
    WHERE v.MaKH = @MaKH ORDER BY v.NgayPhat DESC;

    SELECT ls.ThoiGian, ls.MaHangCu, ls.MaHangMoi, ls.DiemTaiThoiDiem, ls.LyDo, nv.HoTen AS NguoiThucHien
    FROM crm.LICH_SU_HANG ls LEFT JOIN crm.NHAN_VIEN nv ON nv.MaNV = ls.MaNV_ThucHien
    WHERE ls.MaKH = @MaKH ORDER BY ls.ThoiGian DESC;
END;
GO

/* (1) Thêm khách hàng mới. Tài khoản là TÙY CHỌN: nếu có, ứng dụng sinh mật
   khẩu tạm, băm rồi gửi chuỗi băm; khách phải đổi mật khẩu ở lần đăng nhập đầu. */
CREATE OR ALTER PROCEDURE api_ql.usp_ThemKhachHang
    @HoTen          NVARCHAR(100),
    @SDT            VARCHAR(10),
    @GioiTinh       VARCHAR(4)   = NULL,
    @NgaySinh       DATE         = NULL,
    @Email          VARCHAR(100) = NULL,
    @MaTinh         VARCHAR(10)  = NULL,
    @TenDangNhap    VARCHAR(50)  = NULL,
    @MatKhauHashTam VARCHAR(255) = NULL,
    @DsLoaiQuanTam  api_chung.DanhSachMa READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_KH_THEM';
    IF @MatKhauHashTam IS NOT NULL AND LEN(@MatKhauHashTam) < 50
        THROW 52001, N'Chuỗi băm mật khẩu không hợp lệ.', 1;

    DECLARE @MaKH INT, @MaTK INT;
    BEGIN TRY
        BEGIN TRAN;
        EXEC crm.usp_TaoKhachHang_NoiBo
             @HoTen = @HoTen, @GioiTinh = @GioiTinh, @NgaySinh = @NgaySinh, @SDT = @SDT,
             @Email = @Email, @MaTinh = @MaTinh, @DsLoaiQuanTam = @DsLoaiQuanTam,
             @TenDangNhap = @TenDangNhap, @MatKhauHash = @MatKhauHashTam, @PhaiDoiMatKhau = 1,
             @MaKH = @MaKH OUTPUT, @MaTK = @MaTK OUTPUT;
        EXEC sec.usp_GhiNhatKy @HanhDong = 'THEM_KH', @DoiTuong = 'KHACH_HANG', @MaDoiTuong = @MaKH,
             @ChiTiet = N'Quản lý thêm khách hàng';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;

    SELECT @MaKH AS MaKH, @MaTK AS MaTK;
END;
GO

/* Cấp tài khoản cho hồ sơ chưa có tài khoản (vd. khách do quản lý tạo tại cửa hàng). */
CREATE OR ALTER PROCEDURE api_ql.usp_CapTaiKhoanKhachHang
    @MaKH           INT,
    @TenDangNhap    VARCHAR(50),
    @MatKhauHashTam VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_KH_THEM';
    IF @TenDangNhap IS NULL OR @MatKhauHashTam IS NULL OR LEN(@MatKhauHashTam) < 50
        THROW 52001, N'Cần tên đăng nhập và chuỗi băm mật khẩu tạm hợp lệ.', 1;

    BEGIN TRY
        BEGIN TRAN;
        IF NOT EXISTS (SELECT 1 FROM crm.KHACH_HANG WITH (UPDLOCK)
                       WHERE MaKH = @MaKH AND TrangThaiHoSo = 'HOAT_DONG' AND MaTK IS NULL)
            THROW 52041, N'Khách hàng không tồn tại, đã bị xóa hoặc đã có tài khoản.', 1;
        IF EXISTS (SELECT 1 FROM crm.TAI_KHOAN WHERE TenDangNhap = @TenDangNhap)
            THROW 52004, N'Tên đăng nhập đã tồn tại.', 1;

        DECLARE @MaTK INT;
        INSERT crm.TAI_KHOAN (TenDangNhap, MatKhauHash, MaVT, LoaiTK, PhaiDoiMatKhau)
        VALUES (@TenDangNhap, @MatKhauHashTam, 'KHACH_HANG', 'KH', 1);
        SET @MaTK = SCOPE_IDENTITY();
        UPDATE crm.KHACH_HANG SET MaTK = @MaTK WHERE MaKH = @MaKH;

        EXEC sec.usp_GhiNhatKy @HanhDong = 'CAP_TK_KH', @DoiTuong = 'KHACH_HANG', @MaDoiTuong = @MaKH;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;

    SELECT @MaTK AS MaTK;
END;
GO

CREATE OR ALTER PROCEDURE api_ql.usp_CapNhatKhachHang
    @MaKH           INT,
    @HoTen          NVARCHAR(100),
    @SDT            VARCHAR(10),
    @GioiTinh       VARCHAR(4)   = NULL,
    @NgaySinh       DATE         = NULL,
    @Email          VARCHAR(100) = NULL,
    @MaTinh         VARCHAR(10)  = NULL,
    @CapNhatSoThich BIT          = 0,
    @DsLoaiQuanTam  api_chung.DanhSachMa READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_KH_SUA';
    SELECT @HoTen = NULLIF(TRIM(@HoTen), N''), @SDT = TRIM(@SDT), @Email = NULLIF(LOWER(TRIM(@Email)), '');
    IF @HoTen IS NULL OR @SDT IS NULL
        THROW 52001, N'Họ tên và số điện thoại là bắt buộc.', 1;

    BEGIN TRY
        BEGIN TRAN;
        IF NOT EXISTS (SELECT 1 FROM crm.KHACH_HANG WITH (UPDLOCK) WHERE MaKH = @MaKH AND TrangThaiHoSo = 'HOAT_DONG')
            THROW 52040, N'Không tìm thấy khách hàng đang hoạt động.', 1;
        IF EXISTS (SELECT 1 FROM crm.KHACH_HANG WHERE SDT = @SDT AND TrangThaiHoSo = 'HOAT_DONG' AND MaKH <> @MaKH)
            THROW 52002, N'Số điện thoại đã thuộc hồ sơ khác.', 1;
        IF @Email IS NOT NULL
           AND EXISTS (SELECT 1 FROM crm.KHACH_HANG WHERE Email = @Email AND TrangThaiHoSo = 'HOAT_DONG' AND MaKH <> @MaKH)
            THROW 52003, N'Email đã thuộc hồ sơ khác.', 1;

        UPDATE crm.KHACH_HANG
           SET HoTen = @HoTen, SDT = @SDT, GioiTinh = @GioiTinh, NgaySinh = @NgaySinh,
               Email = @Email, MaTinh = @MaTinh
         WHERE MaKH = @MaKH;

        IF @CapNhatSoThich = 1
        BEGIN
            DELETE crm.KH_QUAN_TAM WHERE MaKH = @MaKH;
            INSERT crm.KH_QUAN_TAM (MaKH, MaLoai) SELECT @MaKH, d.Ma FROM @DsLoaiQuanTam d;
        END

        EXEC sec.usp_GhiNhatKy @HanhDong = 'SUA_KH', @DoiTuong = 'KHACH_HANG', @MaDoiTuong = @MaKH;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

/* (2) Xóa khách hàng = xóa mềm + khóa tài khoản. Lịch sử mua, phản hồi,
   kết quả khảo sát được giữ nguyên cho báo cáo. */
CREATE OR ALTER PROCEDURE api_ql.usp_XoaKhachHang
    @MaKH INT,
    @LyDo NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_KH_XOA';
    IF NULLIF(TRIM(@LyDo), N'') IS NULL
        THROW 52001, N'Cần nhập lý do xóa.', 1;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @MaTK INT, @TonTai BIT = 0;
        SELECT @TonTai = 1, @MaTK = MaTK
        FROM crm.KHACH_HANG WITH (UPDLOCK)
        WHERE MaKH = @MaKH AND TrangThaiHoSo = 'HOAT_DONG';
        IF @TonTai = 0
            THROW 52040, N'Không tìm thấy khách hàng đang hoạt động.', 1;

        UPDATE crm.KHACH_HANG SET TrangThaiHoSo = 'DA_XOA', NgayXoa = SYSDATETIME() WHERE MaKH = @MaKH;

        IF @MaTK IS NOT NULL
            UPDATE crm.TAI_KHOAN
               SET TrangThai = 'DA_KHOA', NgayKhoa = SYSDATETIME(), LyDoKhoa = N'Hồ sơ khách hàng đã bị xóa'
             WHERE MaTK = @MaTK AND TrangThai = 'HOAT_DONG';

        EXEC sec.usp_GhiNhatKy @HanhDong = 'XOA_KH', @DoiTuong = 'KHACH_HANG', @MaDoiTuong = @MaKH, @ChiTiet = @LyDo;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

/* (3) Khóa / mở khóa tài khoản khách hàng. Chỉ tác động tài khoản loại KH. */
CREATE OR ALTER PROCEDURE api_ql.usp_KhoaTaiKhoanKhachHang
    @MaKH INT,
    @Khoa BIT,
    @LyDo NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_KH_KHOA';
    IF @Khoa IS NULL OR (@Khoa = 1 AND NULLIF(TRIM(@LyDo), N'') IS NULL)
        THROW 52001, N'Khóa tài khoản cần có lý do.', 1;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @MaTK INT, @TrangThaiHS VARCHAR(10), @TrangThaiTK VARCHAR(10);
        SELECT @MaTK = k.MaTK, @TrangThaiHS = k.TrangThaiHoSo, @TrangThaiTK = tk.TrangThai
        FROM crm.KHACH_HANG k
        JOIN crm.TAI_KHOAN tk WITH (UPDLOCK) ON tk.MaTK = k.MaTK AND tk.LoaiTK = 'KH'
        WHERE k.MaKH = @MaKH;

        IF @MaTK IS NULL
            THROW 52042, N'Khách hàng không tồn tại hoặc chưa có tài khoản.', 1;
        IF @Khoa = 0 AND @TrangThaiHS <> 'HOAT_DONG'
            THROW 52043, N'Không thể mở khóa tài khoản của hồ sơ đã bị xóa.', 1;
        IF (@Khoa = 1 AND @TrangThaiTK = 'DA_KHOA') OR (@Khoa = 0 AND @TrangThaiTK = 'HOAT_DONG')
            THROW 52043, N'Tài khoản đã ở trạng thái yêu cầu.', 1;

        UPDATE crm.TAI_KHOAN
           SET TrangThai = CASE WHEN @Khoa = 1 THEN 'DA_KHOA' ELSE 'HOAT_DONG' END,
               NgayKhoa  = CASE WHEN @Khoa = 1 THEN SYSDATETIME() END,
               LyDoKhoa  = CASE WHEN @Khoa = 1 THEN @LyDo END
         WHERE MaTK = @MaTK;

        DECLARE @HanhDong VARCHAR(40) = CASE WHEN @Khoa = 1 THEN 'KHOA_TK_KH' ELSE 'MO_KHOA_TK_KH' END;
        EXEC sec.usp_GhiNhatKy @HanhDong = @HanhDong, @DoiTuong = 'TAI_KHOAN', @MaDoiTuong = @MaTK, @ChiTiet = @LyDo;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

/* ------------------------- PHẢN HỒI ------------------------- */

CREATE OR ALTER PROCEDURE api_ql.usp_DanhSachPhanHoi
    @TrangThai VARCHAR(10) = NULL,
    @LoaiPH    VARCHAR(10) = NULL,
    @MaSP      INT         = NULL,
    @TuNgay    DATE        = NULL,
    @DenNgay   DATE        = NULL,
    @Trang     INT         = 1,
    @SoDong    INT         = 20
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_PH_XEM';
    IF @Trang < 1 OR @SoDong NOT BETWEEN 1 AND 200
        THROW 52001, N'Tham số phân trang không hợp lệ.', 1;

    SELECT p.*, COUNT(*) OVER () AS TongSoDong
    FROM api_ql.vw_PhanHoi p
    WHERE (@TrangThai IS NULL OR p.TrangThai = @TrangThai)
      AND (@LoaiPH IS NULL OR p.LoaiPH = @LoaiPH)
      AND (@MaSP IS NULL OR p.MaSP = @MaSP)
      AND (@TuNgay IS NULL OR p.NgayGui >= @TuNgay)
      AND (@DenNgay IS NULL OR p.NgayGui < DATEADD(DAY, 1, @DenNgay))
    ORDER BY CASE p.TrangThai WHEN 'MOI' THEN 0 WHEN 'DANG_XU_LY' THEN 1 ELSE 2 END, p.NgayGui
    OFFSET (@Trang - 1) * @SoDong ROWS FETCH NEXT @SoDong ROWS ONLY
    OPTION (RECOMPILE);
END;
GO

/* (4) Tiếp nhận (MOI -> DANG_XU_LY), có thể phân loại lại. */
CREATE OR ALTER PROCEDURE api_ql.usp_TiepNhanPhanHoi
    @MaPH   INT,
    @LoaiPH VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_PH_XU_LY';
    IF @LoaiPH IS NOT NULL AND @LoaiPH NOT IN ('KHEN', 'GOP_Y', 'KHIEU_NAI')
        THROW 52001, N'Loại phản hồi không hợp lệ.', 1;

    BEGIN TRY
        BEGIN TRAN;
        UPDATE crm.PHAN_HOI
           SET TrangThai = 'DANG_XU_LY', MaNV_XuLy = sec.fn_MaNV(), NgayTiepNhan = SYSDATETIME(),
               LoaiPH = ISNULL(@LoaiPH, LoaiPH)
         WHERE MaPH = @MaPH AND TrangThai = 'MOI';
        IF @@ROWCOUNT = 0
            THROW 52050, N'Phản hồi không tồn tại hoặc đã được tiếp nhận.', 1;
        EXEC sec.usp_GhiNhatKy @HanhDong = 'TIEP_NHAN_PH', @DoiTuong = 'PHAN_HOI', @MaDoiTuong = @MaPH;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

/* Trả lời và đóng phản hồi (MOI/DANG_XU_LY -> DA_XU_LY). */
CREATE OR ALTER PROCEDURE api_ql.usp_TraLoiPhanHoi
    @MaPH          INT,
    @NoiDungTraLoi NVARCHAR(2000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_PH_XU_LY';
    SET @NoiDungTraLoi = NULLIF(TRIM(@NoiDungTraLoi), N'');
    IF @NoiDungTraLoi IS NULL
        THROW 52001, N'Nội dung trả lời là bắt buộc.', 1;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @MaNV INT = sec.fn_MaNV(), @BayGio DATETIME2(0) = SYSDATETIME();
        UPDATE crm.PHAN_HOI
           SET TrangThai     = 'DA_XU_LY',
               MaNV_XuLy     = ISNULL(MaNV_XuLy, @MaNV),
               NgayTiepNhan  = ISNULL(NgayTiepNhan, @BayGio),
               NoiDungTraLoi = @NoiDungTraLoi,
               NgayTraLoi    = @BayGio
         WHERE MaPH = @MaPH AND TrangThai IN ('MOI', 'DANG_XU_LY');
        IF @@ROWCOUNT = 0
            THROW 52050, N'Phản hồi không tồn tại hoặc đã xử lý xong.', 1;
        EXEC sec.usp_GhiNhatKy @HanhDong = 'TRA_LOI_PH', @DoiTuong = 'PHAN_HOI', @MaDoiTuong = @MaPH;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

/* ------------------------- KHẢO SÁT ------------------------- */

/* (6a) Tạo khảo sát (trạng thái NHAP). Thăm dò SP mới bắt buộc SP "Sắp ra mắt". */
CREATE OR ALTER PROCEDURE api_ql.usp_TaoKhaoSat
    @TieuDe               NVARCHAR(200),
    @MucDich              VARCHAR(15),
    @HanTraLoi            DATETIME2(0),
    @MoTa                 NVARCHAR(1000) = NULL,
    @MaSP                 INT            = NULL,
    @PhanTramVoucher      TINYINT        = 0,
    @SoNgayHieuLucVoucher SMALLINT       = 30
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_KS_QUAN_LY';
    SET @TieuDe = NULLIF(TRIM(@TieuDe), N'');

    IF @TieuDe IS NULL OR @MucDich IS NULL OR @MucDich NOT IN ('DO_HAI_LONG', 'THAM_DO_SP_MOI')
        THROW 52001, N'Cần tiêu đề và mục đích hợp lệ (DO_HAI_LONG / THAM_DO_SP_MOI).', 1;
    IF @HanTraLoi IS NULL OR @HanTraLoi <= SYSDATETIME()
        THROW 52001, N'Hạn trả lời phải ở tương lai.', 1;
    IF @MucDich = 'THAM_DO_SP_MOI'
       AND NOT EXISTS (SELECT 1 FROM crm.SAN_PHAM WHERE MaSP = @MaSP AND TrangThai = 'SAP_RA_MAT')
        THROW 52060, N'Khảo sát thăm dò phải gắn với một sản phẩm đang ở trạng thái Sắp ra mắt.', 1;
    IF @MaSP IS NOT NULL AND NOT EXISTS (SELECT 1 FROM crm.SAN_PHAM WHERE MaSP = @MaSP)
        THROW 52020, N'Sản phẩm không tồn tại.', 1;

    INSERT crm.KHAO_SAT (TieuDe, MoTa, MucDich, MaSP, MaNV_Tao, HanTraLoi, PhanTramVoucher, SoNgayHieuLucVoucher)
    VALUES (@TieuDe, @MoTa, @MucDich, @MaSP, sec.fn_MaNV(), @HanTraLoi, @PhanTramVoucher, @SoNgayHieuLucVoucher);

    DECLARE @MaKS INT = SCOPE_IDENTITY();
    EXEC sec.usp_GhiNhatKy @HanhDong = 'TAO_KS', @DoiTuong = 'KHAO_SAT', @MaDoiTuong = @MaKS;
    SELECT @MaKS AS MaKS;
END;
GO

/* (6b) Thêm câu hỏi (chỉ khi khảo sát còn NHAP). Câu trắc nghiệm cần >= 2 lựa chọn. */
CREATE OR ALTER PROCEDURE api_ql.usp_ThemCauHoi
    @MaKS       INT,
    @NoiDung    NVARCHAR(500),
    @LoaiCauHoi VARCHAR(15),
    @BatBuoc    BIT = 1,
    @DsLuaChon  api_ql.DanhSachLuaChon READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_KS_QUAN_LY';
    SET @NoiDung = NULLIF(TRIM(@NoiDung), N'');
    DECLARE @SoLuaChon INT = (SELECT COUNT(*) FROM @DsLuaChon WHERE NULLIF(TRIM(NoiDung), N'') IS NOT NULL);

    IF @NoiDung IS NULL OR @LoaiCauHoi IS NULL
       OR @LoaiCauHoi NOT IN ('MOT_LUA_CHON', 'NHIEU_LUA_CHON', 'THANG_DIEM', 'TU_LUAN')
        THROW 52001, N'Nội dung hoặc loại câu hỏi không hợp lệ.', 1;
    IF @LoaiCauHoi IN ('MOT_LUA_CHON', 'NHIEU_LUA_CHON') AND @SoLuaChon < 2
        THROW 52061, N'Câu trắc nghiệm cần ít nhất 2 lựa chọn có nội dung.', 1;
    IF @LoaiCauHoi IN ('THANG_DIEM', 'TU_LUAN') AND EXISTS (SELECT 1 FROM @DsLuaChon)
        THROW 52061, N'Câu thang điểm/tự luận không có danh sách lựa chọn.', 1;

    BEGIN TRY
        BEGIN TRAN;
        IF NOT EXISTS (SELECT 1 FROM crm.KHAO_SAT WITH (UPDLOCK) WHERE MaKS = @MaKS AND TrangThai = 'NHAP')
            THROW 52062, N'Chỉ thêm/sửa câu hỏi khi khảo sát còn ở trạng thái Nháp.', 1;

        DECLARE @ThuTu SMALLINT = (SELECT ISNULL(MAX(ThuTu), 0) + 1 FROM crm.CAU_HOI WHERE MaKS = @MaKS);
        INSERT crm.CAU_HOI (MaKS, ThuTu, NoiDung, LoaiCauHoi, BatBuoc)
        VALUES (@MaKS, @ThuTu, @NoiDung, @LoaiCauHoi, ISNULL(@BatBuoc, 1));
        DECLARE @MaCauHoi INT = SCOPE_IDENTITY();

        INSERT crm.LUA_CHON (MaCauHoi, ThuTu, NoiDung)
        SELECT @MaCauHoi, ROW_NUMBER() OVER (ORDER BY d.ThuTu), TRIM(d.NoiDung)
        FROM @DsLuaChon d WHERE NULLIF(TRIM(d.NoiDung), N'') IS NOT NULL;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;

    SELECT @MaCauHoi AS MaCauHoi;
END;
GO

CREATE OR ALTER PROCEDURE api_ql.usp_XoaCauHoi
    @MaCauHoi INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_KS_QUAN_LY';
    BEGIN TRY
        BEGIN TRAN;
        IF NOT EXISTS (SELECT 1 FROM crm.CAU_HOI c JOIN crm.KHAO_SAT ks WITH (UPDLOCK) ON ks.MaKS = c.MaKS
                       WHERE c.MaCauHoi = @MaCauHoi AND ks.TrangThai = 'NHAP')
            THROW 52062, N'Câu hỏi không tồn tại hoặc khảo sát không còn ở trạng thái Nháp.', 1;
        DELETE crm.CAU_HOI WHERE MaCauHoi = @MaCauHoi;   -- LUA_CHON xóa theo (ON DELETE CASCADE)
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

/* (6c) Chọn đối tượng và gửi khảo sát tới TÀI KHOẢN khách hàng.
   Chỉ gửi cho khách có hồ sơ HOAT_DONG và tài khoản HOAT_DONG; không gửi trùng.
   Gọi lại được nhiều lần để gửi thêm nhóm đối tượng khác khi khảo sát đang DA_GUI. */
CREATE OR ALTER PROCEDURE api_ql.usp_GuiKhaoSat
    @MaKS          INT,
    @MaHang        VARCHAR(10)  = NULL,
    @MaTinh        VARCHAR(10)  = NULL,
    @GioiTinh      VARCHAR(4)   = NULL,
    @TuoiTu        INT          = NULL,
    @TuoiDen       INT          = NULL,
    @MaLoaiQuanTam INT          = NULL,   -- khách có quan tâm loại này
    @MaLoaiDaMua   INT          = NULL,   -- khách đã từng mua loại này
    @HanTraLoiMoi  DATETIME2(0) = NULL,   -- gia hạn (tùy chọn)
    @ChiDem        BIT          = 0       -- 1 = chỉ đếm số người sẽ nhận (xem trước), không gửi
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_KS_GUI';
    DECLARE @SoNguoiNhan INT = 0;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @TrangThai VARCHAR(8), @HanTraLoi DATETIME2(0), @MucDich VARCHAR(15), @MaSP INT;
        SELECT @TrangThai = TrangThai, @HanTraLoi = COALESCE(@HanTraLoiMoi, HanTraLoi), @MucDich = MucDich, @MaSP = MaSP
        FROM crm.KHAO_SAT WITH (UPDLOCK) WHERE MaKS = @MaKS;

        IF @TrangThai IS NULL
            THROW 52030, N'Không tìm thấy khảo sát.', 1;
        IF @TrangThai = 'DA_DONG'
            THROW 52063, N'Khảo sát đã đóng.', 1;
        IF @HanTraLoi IS NULL OR @HanTraLoi <= SYSDATETIME()
            THROW 52063, N'Hạn trả lời đã qua; hãy gia hạn bằng @HanTraLoiMoi.', 1;
        IF NOT EXISTS (SELECT 1 FROM crm.CAU_HOI WHERE MaKS = @MaKS)
            THROW 52063, N'Khảo sát chưa có câu hỏi.', 1;
        IF @MucDich = 'THAM_DO_SP_MOI'
           AND NOT EXISTS (SELECT 1 FROM crm.SAN_PHAM WHERE MaSP = @MaSP AND TrangThai = 'SAP_RA_MAT')
            THROW 52060, N'Sản phẩm thăm dò không còn ở trạng thái Sắp ra mắt.', 1;

        DECLARE @DoiTuong TABLE (MaKH INT PRIMARY KEY);
        INSERT @DoiTuong (MaKH)
        SELECT k.MaKH
        FROM crm.vw_KhachHang_MoRong k
        JOIN crm.TAI_KHOAN tk ON tk.MaTK = k.MaTK AND tk.TrangThai = 'HOAT_DONG'
        WHERE k.TrangThaiHoSo = 'HOAT_DONG'
          AND (@MaHang   IS NULL OR k.MaHang = @MaHang)
          AND (@MaTinh   IS NULL OR k.MaTinh = @MaTinh)
          AND (@GioiTinh IS NULL OR k.GioiTinh = @GioiTinh)
          AND (@TuoiTu   IS NULL OR k.Tuoi >= @TuoiTu)
          AND (@TuoiDen  IS NULL OR k.Tuoi <= @TuoiDen)
          AND (@MaLoaiQuanTam IS NULL
               OR EXISTS (SELECT 1 FROM crm.KH_QUAN_TAM q WHERE q.MaKH = k.MaKH AND q.MaLoai = @MaLoaiQuanTam))
          AND (@MaLoaiDaMua IS NULL
               OR EXISTS (SELECT 1 FROM crm.HOA_DON h
                          JOIN crm.CHI_TIET_HOA_DON ct ON ct.MaHD = h.MaHD
                          JOIN crm.SAN_PHAM sp ON sp.MaSP = ct.MaSP
                          WHERE h.MaKH = k.MaKH AND sp.MaLoai = @MaLoaiDaMua))
          AND NOT EXISTS (SELECT 1 FROM crm.KHAO_SAT_GUI g WHERE g.MaKS = @MaKS AND g.MaKH = k.MaKH);

        IF @ChiDem = 1
        BEGIN
            SET @SoNguoiNhan = (SELECT COUNT(*) FROM @DoiTuong);
            COMMIT;
            SELECT @SoNguoiNhan AS SoNguoiNhanMoi;
            RETURN;
        END

        INSERT crm.KHAO_SAT_GUI (MaKS, MaKH) SELECT @MaKS, MaKH FROM @DoiTuong;
        SET @SoNguoiNhan = @@ROWCOUNT;

        IF @SoNguoiNhan > 0
        BEGIN
            UPDATE crm.KHAO_SAT
               SET TrangThai = 'DA_GUI',
                   NgayPhatHanh = ISNULL(NgayPhatHanh, SYSDATETIME()),
                   HanTraLoi = @HanTraLoi
             WHERE MaKS = @MaKS;
            DECLARE @ChiTiet NVARCHAR(1000) = CONCAT(N'Gửi tới ', @SoNguoiNhan, N' khách hàng');
            EXEC sec.usp_GhiNhatKy @HanhDong = 'GUI_KS', @DoiTuong = 'KHAO_SAT', @MaDoiTuong = @MaKS, @ChiTiet = @ChiTiet;
        END
        ELSE IF @HanTraLoiMoi IS NOT NULL AND @TrangThai = 'DA_GUI'
            UPDATE crm.KHAO_SAT SET HanTraLoi = @HanTraLoi WHERE MaKS = @MaKS;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;

    SELECT @SoNguoiNhan AS SoNguoiNhanMoi;
END;
GO

CREATE OR ALTER PROCEDURE api_ql.usp_DongKhaoSat
    @MaKS INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_KS_GUI';
    UPDATE crm.KHAO_SAT SET TrangThai = 'DA_DONG' WHERE MaKS = @MaKS AND TrangThai = 'DA_GUI';
    IF @@ROWCOUNT = 0
        THROW 52063, N'Chỉ đóng được khảo sát đang ở trạng thái Đã gửi.', 1;
    EXEC sec.usp_GhiNhatKy @HanhDong = 'DONG_KS', @DoiTuong = 'KHAO_SAT', @MaDoiTuong = @MaKS;
END;
GO

/* Danh sách khảo sát (mọi trạng thái) cho màn hình quản lý khảo sát.
   Ai có ít nhất một quyền khảo sát (tạo / gửi / thống kê) đều xem được. */
CREATE OR ALTER PROCEDURE sec.usp_KiemTraMotTrongCacQuyen
    @Quyen1 VARCHAR(30), @Quyen2 VARCHAR(30) = NULL, @Quyen3 VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF SESSION_CONTEXT(N'MaTK') IS NULL
        THROW 50001, N'Chưa đăng nhập: phiên chưa được thiết lập ngữ cảnh.', 1;
    IF sec.fn_CoQuyen(@Quyen1) = 0
       AND (@Quyen2 IS NULL OR sec.fn_CoQuyen(@Quyen2) = 0)
       AND (@Quyen3 IS NULL OR sec.fn_CoQuyen(@Quyen3) = 0)
        THROW 50003, N'Không có quyền thực hiện chức năng này.', 1;
END;
GO

CREATE OR ALTER PROCEDURE api_ql.usp_DanhSachKhaoSat
    @TrangThai VARCHAR(8)  = NULL,   -- NHAP | DA_GUI | DA_DONG
    @MucDich   VARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraMotTrongCacQuyen 'QL_KS_QUAN_LY', 'QL_KS_GUI', 'QL_KS_THONG_KE';
    SELECT MaKS, TieuDe, MucDich, MaSP, TenSP, NguoiTao, NgayTao, NgayPhatHanh, HanTraLoi,
           PhanTramVoucher, TrangThai, SoCauHoi, SoNguoiNhan, SoHoanThanh,
           CAST(100.0 * SoHoanThanh / NULLIF(SoNguoiNhan, 0) AS DECIMAL(5, 2)) AS TyLePhanHoiPhanTram
    FROM api_ql.vw_KhaoSat
    WHERE (@TrangThai IS NULL OR TrangThai = @TrangThai)
      AND (@MucDich IS NULL OR MucDich = @MucDich)
    ORDER BY CASE TrangThai WHEN 'NHAP' THEN 0 WHEN 'DA_GUI' THEN 1 ELSE 2 END, NgayTao DESC;
END;
GO

/* Chi tiết một khảo sát: thông tin chung, câu hỏi, lựa chọn (để sửa bản nháp / xem trước). */
CREATE OR ALTER PROCEDURE api_ql.usp_XemChiTietKhaoSat
    @MaKS INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraMotTrongCacQuyen 'QL_KS_QUAN_LY', 'QL_KS_GUI', 'QL_KS_THONG_KE';
    IF NOT EXISTS (SELECT 1 FROM crm.KHAO_SAT WHERE MaKS = @MaKS)
        THROW 52030, N'Không tìm thấy khảo sát.', 1;

    SELECT ks.MaKS, ks.TieuDe, ks.MoTa, ks.MucDich, ks.MaSP, v.TenSP, ks.MaNV_Tao, v.NguoiTao,
           ks.NgayTao, ks.NgayPhatHanh, ks.HanTraLoi, ks.PhanTramVoucher, ks.SoNgayHieuLucVoucher,
           ks.TrangThai, v.SoNguoiNhan, v.SoHoanThanh
    FROM crm.KHAO_SAT ks JOIN api_ql.vw_KhaoSat v ON v.MaKS = ks.MaKS
    WHERE ks.MaKS = @MaKS;

    SELECT MaCauHoi, ThuTu, NoiDung, LoaiCauHoi, BatBuoc
    FROM crm.CAU_HOI WHERE MaKS = @MaKS ORDER BY ThuTu;

    SELECT l.MaLC, l.MaCauHoi, l.ThuTu, l.NoiDung
    FROM crm.LUA_CHON l JOIN crm.CAU_HOI c ON c.MaCauHoi = l.MaCauHoi
    WHERE c.MaKS = @MaKS ORDER BY c.ThuTu, l.ThuTu;
END;
GO

/* (7) Thống kê kết quả một khảo sát. */
CREATE OR ALTER PROCEDURE api_ql.usp_ThongKeKhaoSat
    @MaKS INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_KS_THONG_KE';
    IF NOT EXISTS (SELECT 1 FROM crm.KHAO_SAT WHERE MaKS = @MaKS)
        THROW 52030, N'Không tìm thấy khảo sát.', 1;

    -- 1. Tổng quan và tỷ lệ phản hồi
    SELECT MaKS, TieuDe, MucDich, TenSP, TrangThai, NgayPhatHanh, HanTraLoi, SoNguoiNhan, SoHoanThanh,
           CAST(100.0 * SoHoanThanh / NULLIF(SoNguoiNhan, 0) AS DECIMAL(5, 2)) AS TyLePhanHoiPhanTram
    FROM api_ql.vw_KhaoSat WHERE MaKS = @MaKS;

    -- 2. Câu trắc nghiệm: số lượt chọn, % trên số người trả lời câu đó
    SELECT c.ThuTu AS CauSo, c.NoiDung AS CauHoi, c.LoaiCauHoi, l.ThuTu AS LuaChonSo, l.NoiDung AS LuaChon,
           COUNT(t.MaLC) AS SoLuotChon,
           CAST(100.0 * COUNT(t.MaLC) / NULLIF(n.SoNguoiTraLoi, 0) AS DECIMAL(5, 2)) AS TyLePhanTram
    FROM crm.CAU_HOI c
    JOIN crm.LUA_CHON l ON l.MaCauHoi = c.MaCauHoi
    LEFT JOIN crm.TRA_LOI_LUA_CHON t ON t.MaCauHoi = c.MaCauHoi AND t.MaLC = l.MaLC
    CROSS APPLY (SELECT COUNT(*) AS SoNguoiTraLoi FROM crm.TRA_LOI r WHERE r.MaCauHoi = c.MaCauHoi) n
    WHERE c.MaKS = @MaKS
    GROUP BY c.ThuTu, c.NoiDung, c.LoaiCauHoi, l.ThuTu, l.NoiDung, n.SoNguoiTraLoi
    ORDER BY c.ThuTu, l.ThuTu;

    -- 3. Câu thang điểm 1-5: điểm trung bình và phân bố
    SELECT c.ThuTu AS CauSo, c.NoiDung AS CauHoi,
           COUNT(r.DiemSo) AS SoNguoiTraLoi,
           CAST(AVG(CAST(r.DiemSo AS DECIMAL(5, 2))) AS DECIMAL(4, 2)) AS DiemTrungBinh,
           SUM(CASE WHEN r.DiemSo = 1 THEN 1 ELSE 0 END) AS Diem1,
           SUM(CASE WHEN r.DiemSo = 2 THEN 1 ELSE 0 END) AS Diem2,
           SUM(CASE WHEN r.DiemSo = 3 THEN 1 ELSE 0 END) AS Diem3,
           SUM(CASE WHEN r.DiemSo = 4 THEN 1 ELSE 0 END) AS Diem4,
           SUM(CASE WHEN r.DiemSo = 5 THEN 1 ELSE 0 END) AS Diem5
    FROM crm.CAU_HOI c
    LEFT JOIN crm.TRA_LOI r ON r.MaCauHoi = c.MaCauHoi
    WHERE c.MaKS = @MaKS AND c.LoaiCauHoi = 'THANG_DIEM'
    GROUP BY c.ThuTu, c.NoiDung
    ORDER BY c.ThuTu;

    -- 4. Câu tự luận (không hiển thị danh tính khách)
    SELECT c.ThuTu AS CauSo, c.NoiDung AS CauHoi, r.NoiDungTuLuan
    FROM crm.CAU_HOI c
    JOIN crm.TRA_LOI r ON r.MaCauHoi = c.MaCauHoi
    WHERE c.MaKS = @MaKS AND c.LoaiCauHoi = 'TU_LUAN'
    ORDER BY c.ThuTu;
END;
GO

/* ------------------------- BÁO CÁO ------------------------- */

/* (5a) Cơ cấu khách hàng: tỷ lệ độ tuổi, giới tính, khu vực, hạng. */
CREATE OR ALTER PROCEDURE api_ql.usp_BaoCaoCoCauKhachHang
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_BAO_CAO';
    DECLARE @Tong INT = (SELECT COUNT(*) FROM crm.KHACH_HANG WHERE TrangThaiHoSo = 'HOAT_DONG');

    SELECT NhomTuoi, COUNT(*) AS SoKhach,
           CAST(100.0 * COUNT(*) / NULLIF(@Tong, 0) AS DECIMAL(5, 2)) AS TyLePhanTram
    FROM crm.vw_KhachHang_MoRong
    WHERE TrangThaiHoSo = 'HOAT_DONG'
    GROUP BY NhomTuoi
    ORDER BY MIN(ISNULL(Tuoi, 999));

    SELECT CASE GioiTinh WHEN 'NAM' THEN N'Nam' WHEN 'NU' THEN N'Nữ' WHEN 'KHAC' THEN N'Khác' ELSE N'Không rõ' END AS GioiTinh,
           COUNT(*) AS SoKhach,
           CAST(100.0 * COUNT(*) / NULLIF(@Tong, 0) AS DECIMAL(5, 2)) AS TyLePhanTram
    FROM crm.KHACH_HANG WHERE TrangThaiHoSo = 'HOAT_DONG'
    GROUP BY GioiTinh ORDER BY SoKhach DESC;

    SELECT ISNULL(t.TenTinh, N'Không rõ') AS TinhThanh, COUNT(*) AS SoKhach,
           CAST(100.0 * COUNT(*) / NULLIF(@Tong, 0) AS DECIMAL(5, 2)) AS TyLePhanTram
    FROM crm.KHACH_HANG k LEFT JOIN crm.TINH_THANH t ON t.MaTinh = k.MaTinh
    WHERE k.TrangThaiHoSo = 'HOAT_DONG'
    GROUP BY t.TenTinh ORDER BY SoKhach DESC;

    SELECT h.TenHang, COUNT(k.MaKH) AS SoKhach,
           CAST(100.0 * COUNT(k.MaKH) / NULLIF(@Tong, 0) AS DECIMAL(5, 2)) AS TyLePhanTram
    FROM crm.HANG_THANH_VIEN h
    LEFT JOIN crm.KHACH_HANG k ON k.MaHang = h.MaHang AND k.TrangThaiHoSo = 'HOAT_DONG'
    GROUP BY h.TenHang, h.DiemToiThieu ORDER BY h.DiemToiThieu;
END;
GO

/* (5b) Sở thích: loại SP quan tâm so với loại SP đã mua; sở thích theo nhóm tuổi. */
CREATE OR ALTER PROCEDURE api_ql.usp_BaoCaoSoThich
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_BAO_CAO';
    DECLARE @Tong INT = (SELECT COUNT(*) FROM crm.KHACH_HANG WHERE TrangThaiHoSo = 'HOAT_DONG');

    WITH QuanTam AS (
        SELECT q.MaLoai, q.MaKH
        FROM crm.KH_QUAN_TAM q JOIN crm.KHACH_HANG k ON k.MaKH = q.MaKH
        WHERE k.TrangThaiHoSo = 'HOAT_DONG'
    ), DaMua AS (
        SELECT DISTINCT sp.MaLoai, h.MaKH
        FROM crm.HOA_DON h
        JOIN crm.CHI_TIET_HOA_DON ct ON ct.MaHD = h.MaHD
        JOIN crm.SAN_PHAM sp         ON sp.MaSP = ct.MaSP
        JOIN crm.KHACH_HANG k        ON k.MaKH = h.MaKH
        WHERE k.TrangThaiHoSo = 'HOAT_DONG'
    )
    SELECT l.TenLoai,
           (SELECT COUNT(*) FROM QuanTam x WHERE x.MaLoai = l.MaLoai) AS SoKhachQuanTam,
           CAST(100.0 * (SELECT COUNT(*) FROM QuanTam x WHERE x.MaLoai = l.MaLoai) / NULLIF(@Tong, 0)
                AS DECIMAL(5, 2)) AS TyLeQuanTamPhanTram,
           (SELECT COUNT(*) FROM DaMua m WHERE m.MaLoai = l.MaLoai) AS SoKhachDaMua,
           (SELECT COUNT(*) FROM QuanTam x JOIN DaMua m ON m.MaLoai = x.MaLoai AND m.MaKH = x.MaKH
            WHERE x.MaLoai = l.MaLoai) AS SoKhachQuanTamVaDaMua,
           CAST(100.0 * (SELECT COUNT(*) FROM QuanTam x JOIN DaMua m ON m.MaLoai = x.MaLoai AND m.MaKH = x.MaKH
                         WHERE x.MaLoai = l.MaLoai)
                / NULLIF((SELECT COUNT(*) FROM QuanTam x WHERE x.MaLoai = l.MaLoai), 0)
                AS DECIMAL(5, 2)) AS TyLeChuyenDoiPhanTram
    FROM crm.LOAI_SP l
    ORDER BY SoKhachQuanTam DESC, l.TenLoai;

    -- Sở thích theo nhóm tuổi (% trong mỗi nhóm tuổi)
    SELECT k.NhomTuoi, l.TenLoai, COUNT(*) AS SoKhach,
           CAST(100.0 * COUNT(*) / NULLIF(n.SoKhachNhom, 0) AS DECIMAL(5, 2)) AS TyLeTrongNhomPhanTram
    FROM crm.vw_KhachHang_MoRong k
    JOIN crm.KH_QUAN_TAM q ON q.MaKH = k.MaKH
    JOIN crm.LOAI_SP l     ON l.MaLoai = q.MaLoai
    CROSS APPLY (SELECT COUNT(*) AS SoKhachNhom FROM crm.vw_KhachHang_MoRong x
                 WHERE x.NhomTuoi = k.NhomTuoi AND x.TrangThaiHoSo = 'HOAT_DONG') n
    WHERE k.TrangThaiHoSo = 'HOAT_DONG'
    GROUP BY k.NhomTuoi, l.TenLoai, n.SoKhachNhom
    ORDER BY k.NhomTuoi, SoKhach DESC;
END;
GO

/* (5c) Mức độ hài lòng theo loại sản phẩm: điểm phản hồi, tỷ lệ đổi trả,
   điểm khảo sát hài lòng (câu thang điểm của khảo sát DO_HAI_LONG). */
CREATE OR ALTER PROCEDURE api_ql.usp_BaoCaoHaiLong
    @TuNgay  DATE = NULL,
    @DenNgay DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'QL_BAO_CAO';
    DECLARE @Tu DATETIME2(0) = ISNULL(CAST(@TuNgay AS DATETIME2(0)), '19000101'),
            @Den DATETIME2(0) = ISNULL(DATEADD(DAY, 1, CAST(@DenNgay AS DATETIME2(0))), '99991231');

    WITH PH AS (
        SELECT sp.MaLoai, COUNT(*) AS SoPhanHoi, AVG(CAST(ph.DiemDanhGia AS DECIMAL(5, 2))) AS DiemTB,
               SUM(CASE WHEN ph.LoaiPH = 'KHIEU_NAI' THEN 1 ELSE 0 END) AS SoKhieuNai
        FROM crm.PHAN_HOI ph JOIN crm.SAN_PHAM sp ON sp.MaSP = ph.MaSP
        WHERE ph.NgayGui >= @Tu AND ph.NgayGui < @Den
        GROUP BY sp.MaLoai
    ), Ban AS (
        SELECT sp.MaLoai, SUM(ct.SoLuong) AS SoLuongBan
        FROM crm.HOA_DON h JOIN crm.CHI_TIET_HOA_DON ct ON ct.MaHD = h.MaHD
        JOIN crm.SAN_PHAM sp ON sp.MaSP = ct.MaSP
        WHERE h.NgayLap >= @Tu AND h.NgayLap < @Den
        GROUP BY sp.MaLoai
    ), Tra AS (
        SELECT sp.MaLoai, SUM(d.SoLuong) AS SoLuongTra
        FROM crm.DOI_TRA d JOIN crm.SAN_PHAM sp ON sp.MaSP = d.MaSP
        WHERE d.NgayDoiTra >= @Tu AND d.NgayDoiTra < @Den
        GROUP BY sp.MaLoai
    ), KS AS (
        SELECT sp.MaLoai, AVG(CAST(r.DiemSo AS DECIMAL(5, 2))) AS DiemKS, COUNT(*) AS SoLuotChamDiem
        FROM crm.TRA_LOI r
        JOIN crm.KHAO_SAT ks    ON ks.MaKS = r.MaKS AND ks.MucDich = 'DO_HAI_LONG'
        JOIN crm.SAN_PHAM sp    ON sp.MaSP = ks.MaSP
        JOIN crm.KHAO_SAT_GUI g ON g.MaKS = r.MaKS AND g.MaKH = r.MaKH
        WHERE r.LoaiCauHoi = 'THANG_DIEM' AND g.NgayHoanThanh >= @Tu AND g.NgayHoanThanh < @Den
        GROUP BY sp.MaLoai
    )
    SELECT l.TenLoai,
           ISNULL(PH.SoPhanHoi, 0) AS SoPhanHoi,
           CAST(PH.DiemTB AS DECIMAL(4, 2)) AS DiemPhanHoiTB,
           ISNULL(PH.SoKhieuNai, 0) AS SoKhieuNai,
           ISNULL(Ban.SoLuongBan, 0) AS SoLuongBan,
           ISNULL(Tra.SoLuongTra, 0) AS SoLuongDoiTra,
           CAST(100.0 * ISNULL(Tra.SoLuongTra, 0) / NULLIF(Ban.SoLuongBan, 0) AS DECIMAL(5, 2)) AS TyLeDoiTraPhanTram,
           CAST(KS.DiemKS AS DECIMAL(4, 2)) AS DiemKhaoSatHaiLongTB,
           ISNULL(KS.SoLuotChamDiem, 0) AS SoLuotChamDiemKhaoSat
    FROM crm.LOAI_SP l
    LEFT JOIN PH  ON PH.MaLoai = l.MaLoai
    LEFT JOIN Ban ON Ban.MaLoai = l.MaLoai
    LEFT JOIN Tra ON Tra.MaLoai = l.MaLoai
    LEFT JOIN KS  ON KS.MaLoai = l.MaLoai
    ORDER BY l.TenLoai;

    -- Tổng hợp toàn doanh nghiệp
    SELECT
        (SELECT CAST(AVG(CAST(DiemDanhGia AS DECIMAL(5, 2))) AS DECIMAL(4, 2)) FROM crm.PHAN_HOI
          WHERE NgayGui >= @Tu AND NgayGui < @Den) AS DiemPhanHoiTB,
        (SELECT COUNT(*) FROM crm.PHAN_HOI WHERE NgayGui >= @Tu AND NgayGui < @Den AND TrangThai <> 'DA_XU_LY') AS PhanHoiChuaXuLy,
        CAST(100.0 * (SELECT ISNULL(SUM(SoLuong), 0) FROM crm.DOI_TRA WHERE NgayDoiTra >= @Tu AND NgayDoiTra < @Den)
             / NULLIF((SELECT SUM(ct.SoLuong) FROM crm.CHI_TIET_HOA_DON ct JOIN crm.HOA_DON h ON h.MaHD = ct.MaHD
                       WHERE h.NgayLap >= @Tu AND h.NgayLap < @Den), 0) AS DECIMAL(5, 2)) AS TyLeDoiTraPhanTram,
        (SELECT CAST(AVG(CAST(r.DiemSo AS DECIMAL(5, 2))) AS DECIMAL(4, 2))
           FROM crm.TRA_LOI r JOIN crm.KHAO_SAT ks ON ks.MaKS = r.MaKS AND ks.MucDich = 'DO_HAI_LONG'
           JOIN crm.KHAO_SAT_GUI g ON g.MaKS = r.MaKS AND g.MaKH = r.MaKH
          WHERE r.LoaiCauHoi = 'THANG_DIEM' AND g.NgayHoanThanh >= @Tu AND g.NgayHoanThanh < @Den) AS DiemKhaoSatHaiLongTB;

    -- Lý do đổi trả
    SELECT d.LyDo, COUNT(*) AS SoLan, SUM(d.SoLuong) AS SoLuong
    FROM crm.DOI_TRA d WHERE d.NgayDoiTra >= @Tu AND d.NgayDoiTra < @Den
    GROUP BY d.LyDo ORDER BY SoLuong DESC;
END;
GO

PRINT N'Script 05b hoàn tất.';
GO
