/* =====================================================================
   Script 05c: Thủ tục cổng Admin (api_admin)
   ---------------------------------------------------------------------
   Đáp ứng yêu cầu đề (II.2 – Giao diện ADMIN):
     - Admin xem, tìm kiếm, tìm kiếm nâng cao, sắp xếp, lọc sản phẩm, nhà cung cấp...
         -> usp_TimSanPham, usp_TimNhaCungCap, usp_DanhSachNhanVien,
            usp_DanhSachTaiKhoan, usp_DanhSachDanhMucPhu, usp_TraCuuKhachHang
     - Admin thêm, xóa, phân quyền cho account
         -> usp_TaoTaiKhoanNhanVien, usp_XoaTaiKhoan, usp_KhoaMoTaiKhoan,
            usp_DoiVaiTro, usp_TaoVaiTro, usp_CapNhatQuyenVaiTro, usp_DanhSachVaiTroQuyen
   Bổ sung theo thiết kế (File B, mục 6): quản lý danh mục (usp_Luu*),
   nạp dữ liệu giao dịch từ POS (usp_NhapHoaDon, usp_NhapDoiTra), nhật ký.
   Admin là vai trò KỸ THUẬT: không xem đầy đủ SĐT/email khách hàng, không
   xử lý nghiệp vụ CRM (không có quyền EXECUTE trên api_ql).
   Tìm kiếm dùng SQL tĩnh có tham số + danh sách trắng cho cột sắp xếp
   (không ghép chuỗi SQL động) để loại trừ SQL injection.
   ===================================================================== */
USE CRM_Uniqlo;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

/* Số tài khoản Admin còn khả năng phân quyền (để chống tự khóa hệ thống). */
CREATE OR ALTER FUNCTION sec.fn_SoAdminConLai(@TruMaTK INT, @TruMaVT VARCHAR(20))
RETURNS INT
AS
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM crm.TAI_KHOAN tk
        JOIN crm.VAI_TRO vt        ON vt.MaVT = tk.MaVT AND vt.CongTruyCap = 'ADMIN'
        JOIN crm.VAI_TRO_QUYEN vq  ON vq.MaVT = tk.MaVT AND vq.MaQuyen = 'AD_PHAN_QUYEN'
        JOIN crm.NHAN_VIEN nv      ON nv.MaTK = tk.MaTK AND nv.TrangThai = 'DANG_LAM'
        WHERE tk.TrangThai = 'HOAT_DONG'
          AND (@TruMaTK IS NULL OR tk.MaTK <> @TruMaTK)
          AND (@TruMaVT IS NULL OR tk.MaVT <> @TruMaVT));
END;
GO

/* ===================== TRA CỨU / TÌM KIẾM ===================== */

CREATE OR ALTER PROCEDURE api_admin.usp_TimSanPham
    @TuKhoa    NVARCHAR(100)  = NULL,   -- tên, mã SKU, chất liệu
    @MaSP      INT            = NULL,   -- lấy đúng 1 sản phẩm (form sửa)
    @MaLoai    INT            = NULL,
    @MaNCC     INT            = NULL,
    @TrangThai VARCHAR(12)    = NULL,
    @GiaTu     DECIMAL(14, 2) = NULL,
    @GiaDen    DECIMAL(14, 2) = NULL,
    @SapXep    VARCHAR(10)    = 'TEN_TANG', -- TEN_TANG|TEN_GIAM|GIA_TANG|GIA_GIAM|MOI_NHAT
    @Trang     INT            = 1,
    @SoDong    INT            = 20
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_TRA_CUU';
    IF @Trang < 1 OR @SoDong NOT BETWEEN 1 AND 200
       OR @SapXep NOT IN ('TEN_TANG', 'TEN_GIAM', 'GIA_TANG', 'GIA_GIAM', 'MOI_NHAT')
        THROW 52001, N'Tham số phân trang/sắp xếp không hợp lệ.', 1;
    DECLARE @Mau NVARCHAR(102) = N'%' + NULLIF(TRIM(@TuKhoa), N'') + N'%';

    SELECT v.*, COUNT(*) OVER () AS TongSoDong
    FROM api_admin.vw_SanPham v
    WHERE (@Mau IS NULL OR v.TenSP LIKE @Mau OR v.MaSKU LIKE @Mau OR v.ChatLieu LIKE @Mau)
      AND (@MaSP IS NULL OR v.MaSP = @MaSP)
      AND (@MaLoai IS NULL OR v.MaLoai = @MaLoai)
      AND (@MaNCC IS NULL OR v.MaNCC = @MaNCC)
      AND (@TrangThai IS NULL OR v.TrangThai = @TrangThai)
      AND (@GiaTu IS NULL OR v.GiaNiemYet >= @GiaTu)
      AND (@GiaDen IS NULL OR v.GiaNiemYet <= @GiaDen)
    ORDER BY CASE WHEN @SapXep = 'TEN_TANG' THEN v.TenSP END ASC,
             CASE WHEN @SapXep = 'TEN_GIAM' THEN v.TenSP END DESC,
             CASE WHEN @SapXep = 'GIA_TANG' THEN v.GiaNiemYet END ASC,
             CASE WHEN @SapXep = 'GIA_GIAM' THEN v.GiaNiemYet END DESC,
             CASE WHEN @SapXep = 'MOI_NHAT' THEN v.MaSP END DESC,
             v.MaSP
    OFFSET (@Trang - 1) * @SoDong ROWS FETCH NEXT @SoDong ROWS ONLY
    OPTION (RECOMPILE);
END;
GO

CREATE OR ALTER PROCEDURE api_admin.usp_TimNhaCungCap
    @TuKhoa    NVARCHAR(100) = NULL,   -- tên, email, SĐT
    @MaNCC     INT           = NULL,   -- lấy đúng 1 nhà cung cấp (form sửa)
    @QuocGia   NVARCHAR(50)  = NULL,
    @TrangThai VARCHAR(13)   = NULL,
    @SapXep    VARCHAR(10)   = 'TEN_TANG', -- TEN_TANG|TEN_GIAM|SO_SP_GIAM
    @Trang     INT           = 1,
    @SoDong    INT           = 20
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_TRA_CUU';
    IF @Trang < 1 OR @SoDong NOT BETWEEN 1 AND 200 OR @SapXep NOT IN ('TEN_TANG', 'TEN_GIAM', 'SO_SP_GIAM')
        THROW 52001, N'Tham số phân trang/sắp xếp không hợp lệ.', 1;
    DECLARE @Mau NVARCHAR(102) = N'%' + NULLIF(TRIM(@TuKhoa), N'') + N'%';

    SELECT v.*, COUNT(*) OVER () AS TongSoDong
    FROM api_admin.vw_NhaCungCap v
    WHERE (@Mau IS NULL OR v.TenNCC LIKE @Mau OR v.Email LIKE @Mau OR v.SDT LIKE @Mau)
      AND (@MaNCC IS NULL OR v.MaNCC = @MaNCC)
      AND (@QuocGia IS NULL OR v.QuocGia = @QuocGia)
      AND (@TrangThai IS NULL OR v.TrangThai = @TrangThai)
    ORDER BY CASE WHEN @SapXep = 'TEN_TANG' THEN v.TenNCC END ASC,
             CASE WHEN @SapXep = 'TEN_GIAM' THEN v.TenNCC END DESC,
             CASE WHEN @SapXep = 'SO_SP_GIAM' THEN v.SoSanPham END DESC,
             v.MaNCC
    OFFSET (@Trang - 1) * @SoDong ROWS FETCH NEXT @SoDong ROWS ONLY
    OPTION (RECOMPILE);
END;
GO

CREATE OR ALTER PROCEDURE api_admin.usp_DanhSachNhanVien
    @TuKhoa    NVARCHAR(100) = NULL,
    @MaCV      VARCHAR(20)   = NULL,
    @MaCH      INT           = NULL,
    @TrangThai VARCHAR(10)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_TRA_CUU';
    DECLARE @Mau NVARCHAR(102) = N'%' + NULLIF(TRIM(@TuKhoa), N'') + N'%';
    SELECT v.*
    FROM api_admin.vw_NhanVien v
    WHERE (@Mau IS NULL OR v.HoTen LIKE @Mau OR v.Email LIKE @Mau OR v.SDT LIKE @Mau)
      AND (@MaCV IS NULL OR v.MaCV = @MaCV)
      AND (@MaCH IS NULL OR v.MaCH = @MaCH)
      AND (@TrangThai IS NULL OR v.TrangThai = @TrangThai)
    ORDER BY v.HoTen
    OPTION (RECOMPILE);
END;
GO

CREATE OR ALTER PROCEDURE api_admin.usp_DanhSachTaiKhoan
    @TuKhoa    NVARCHAR(100) = NULL,   -- tên đăng nhập / tên chủ tài khoản
    @LoaiTK    CHAR(2)       = NULL,
    @MaVT      VARCHAR(20)   = NULL,
    @TrangThai VARCHAR(10)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_TAI_KHOAN';
    DECLARE @Mau NVARCHAR(102) = N'%' + NULLIF(TRIM(@TuKhoa), N'') + N'%';
    SELECT v.*                               -- view không có cột MatKhauHash
    FROM api_admin.vw_TaiKhoan v
    WHERE (@Mau IS NULL OR v.TenDangNhap LIKE @Mau OR v.ChuTaiKhoan LIKE @Mau)
      AND (@LoaiTK IS NULL OR v.LoaiTK = @LoaiTK)
      AND (@MaVT IS NULL OR v.MaVT = @MaVT)
      AND (@TrangThai IS NULL OR v.TrangThai = @TrangThai)
    ORDER BY v.LoaiTK DESC, v.TenDangNhap
    OPTION (RECOMPILE);
END;
GO

CREATE OR ALTER PROCEDURE api_admin.usp_DanhSachVaiTroQuyen
    @MaVT VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_PHAN_QUYEN';
    SELECT MaVT, TenVT, LoaiTK, CongTruyCap, MoTa,
           (SELECT COUNT(*) FROM crm.TAI_KHOAN tk WHERE tk.MaVT = vt.MaVT) AS SoTaiKhoan
    FROM crm.VAI_TRO vt WHERE (@MaVT IS NULL OR vt.MaVT = @MaVT) ORDER BY CongTruyCap, MaVT;

    SELECT * FROM api_admin.vw_VaiTroQuyen
    WHERE (@MaVT IS NULL OR MaVT = @MaVT) ORDER BY MaVT, MaQuyen;
END;
GO

/* Danh mục phụ dùng cho các ô chọn của giao diện Admin. */
CREATE OR ALTER PROCEDURE api_admin.usp_DanhSachDanhMucPhu
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_TRA_CUU';
    SELECT * FROM api_admin.vw_LoaiSP ORDER BY TenLoai;
    SELECT * FROM api_admin.vw_CuaHang ORDER BY TenCH;
    SELECT MaCV, TenCV, MoTa FROM crm.CHUC_VU ORDER BY TenCV;
    SELECT MaTinh, TenTinh FROM crm.TINH_THANH ORDER BY TenTinh;
END;
GO

/* Admin chỉ tra cứu khách hàng ở mức kỹ thuật (SĐT/Email đã che). */
CREATE OR ALTER PROCEDURE api_admin.usp_TraCuuKhachHang
    @TuKhoa NVARCHAR(100) = NULL,   -- họ tên
    @MaHang VARCHAR(10)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_TRA_CUU';
    DECLARE @Mau NVARCHAR(102) = N'%' + NULLIF(TRIM(@TuKhoa), N'') + N'%';
    SELECT v.*
    FROM api_admin.vw_KhachHang_TraCuu v
    WHERE (@Mau IS NULL OR v.HoTen LIKE @Mau)
      AND (@MaHang IS NULL OR v.MaHang = @MaHang)
    ORDER BY v.HoTen
    OPTION (RECOMPILE);
END;
GO

CREATE OR ALTER PROCEDURE api_admin.usp_XemNhatKy
    @TuNgay   DATE        = NULL,
    @DenNgay  DATE        = NULL,
    @HanhDong VARCHAR(40) = NULL,
    @MaTK     INT         = NULL,
    @Trang    INT         = 1,
    @SoDong   INT         = 50
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_NHAT_KY';
    IF @Trang < 1 OR @SoDong NOT BETWEEN 1 AND 500
        THROW 52001, N'Tham số phân trang không hợp lệ.', 1;
    SELECT v.*, COUNT(*) OVER () AS TongSoDong
    FROM api_admin.vw_NhatKy v
    WHERE (@TuNgay IS NULL OR v.ThoiGian >= @TuNgay)
      AND (@DenNgay IS NULL OR v.ThoiGian < DATEADD(DAY, 1, @DenNgay))
      AND (@HanhDong IS NULL OR v.HanhDong = @HanhDong)
      AND (@MaTK IS NULL OR v.MaTK = @MaTK)
    ORDER BY v.ThoiGian DESC, v.MaNK DESC
    OFFSET (@Trang - 1) * @SoDong ROWS FETCH NEXT @SoDong ROWS ONLY
    OPTION (RECOMPILE);
END;
GO

/* ===================== QUẢN LÝ DANH MỤC ===================== */
/* Quy ước: @Ma... NULL = thêm mới; có giá trị = cập nhật. Không xóa cứng
   danh mục đã phát sinh dữ liệu (dùng TrangThai NGUNG_BAN / NGUNG_HOP_TAC / DA_DONG). */

CREATE OR ALTER PROCEDURE api_admin.usp_LuuSanPham
    @MaSP       INT            = NULL,
    @MaSKU      VARCHAR(20),
    @TenSP      NVARCHAR(150),
    @MaLoai     INT,
    @MaNCC      INT,
    @GiaNiemYet DECIMAL(14, 2),
    @TrangThai  VARCHAR(12)    = 'DANG_BAN',
    @NgayRaMat  DATE           = NULL,
    @ChatLieu   NVARCHAR(100)  = NULL,
    @MoTa       NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_DANH_MUC';
    BEGIN TRY
        BEGIN TRAN;
        IF @MaSP IS NULL
        BEGIN
            INSERT crm.SAN_PHAM (MaSKU, TenSP, MaLoai, MaNCC, ChatLieu, MoTa, GiaNiemYet, TrangThai, NgayRaMat)
            VALUES (@MaSKU, @TenSP, @MaLoai, @MaNCC, @ChatLieu, @MoTa, @GiaNiemYet, @TrangThai, @NgayRaMat);
            SET @MaSP = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE crm.SAN_PHAM
               SET MaSKU = @MaSKU, TenSP = @TenSP, MaLoai = @MaLoai, MaNCC = @MaNCC, ChatLieu = @ChatLieu,
                   MoTa = @MoTa, GiaNiemYet = @GiaNiemYet, TrangThai = @TrangThai, NgayRaMat = @NgayRaMat
             WHERE MaSP = @MaSP;
            IF @@ROWCOUNT = 0 THROW 52080, N'Không tìm thấy sản phẩm.', 1;
        END
        EXEC sec.usp_GhiNhatKy @HanhDong = 'LUU_DANH_MUC', @DoiTuong = 'SAN_PHAM', @MaDoiTuong = @MaSP;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF ERROR_NUMBER() IN (2601, 2627) THROW 52081, N'Mã SKU đã tồn tại.', 1;
        IF ERROR_NUMBER() = 547 THROW 52082, N'Dữ liệu sản phẩm vi phạm ràng buộc (loại, NCC, giá, trạng thái, ngày ra mắt).', 1;
        THROW;
    END CATCH;
    SELECT @MaSP AS MaSP;
END;
GO

CREATE OR ALTER PROCEDURE api_admin.usp_LuuNhaCungCap
    @MaNCC     INT           = NULL,
    @TenNCC    NVARCHAR(150),
    @QuocGia   NVARCHAR(50)  = NULL,
    @DiaChi    NVARCHAR(200) = NULL,
    @SDT       VARCHAR(20)   = NULL,
    @Email     VARCHAR(100)  = NULL,
    @TrangThai VARCHAR(13)   = 'DANG_HOP_TAC'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_DANH_MUC';
    BEGIN TRY
        BEGIN TRAN;
        IF @MaNCC IS NULL
        BEGIN
            INSERT crm.NHA_CUNG_CAP (TenNCC, QuocGia, DiaChi, SDT, Email, TrangThai)
            VALUES (@TenNCC, @QuocGia, @DiaChi, @SDT, @Email, @TrangThai);
            SET @MaNCC = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE crm.NHA_CUNG_CAP
               SET TenNCC = @TenNCC, QuocGia = @QuocGia, DiaChi = @DiaChi, SDT = @SDT, Email = @Email, TrangThai = @TrangThai
             WHERE MaNCC = @MaNCC;
            IF @@ROWCOUNT = 0 THROW 52080, N'Không tìm thấy nhà cung cấp.', 1;
        END
        EXEC sec.usp_GhiNhatKy @HanhDong = 'LUU_DANH_MUC', @DoiTuong = 'NHA_CUNG_CAP', @MaDoiTuong = @MaNCC;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF ERROR_NUMBER() IN (2601, 2627) THROW 52081, N'Tên nhà cung cấp đã tồn tại.', 1;
        THROW;
    END CATCH;
    SELECT @MaNCC AS MaNCC;
END;
GO

CREATE OR ALTER PROCEDURE api_admin.usp_LuuLoaiSP
    @MaLoai  INT           = NULL,
    @TenLoai NVARCHAR(50),
    @MoTa    NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_DANH_MUC';
    BEGIN TRY
        BEGIN TRAN;
        IF @MaLoai IS NULL
        BEGIN
            INSERT crm.LOAI_SP (TenLoai, MoTa) VALUES (@TenLoai, @MoTa);
            SET @MaLoai = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE crm.LOAI_SP SET TenLoai = @TenLoai, MoTa = @MoTa WHERE MaLoai = @MaLoai;
            IF @@ROWCOUNT = 0 THROW 52080, N'Không tìm thấy loại sản phẩm.', 1;
        END
        EXEC sec.usp_GhiNhatKy @HanhDong = 'LUU_DANH_MUC', @DoiTuong = 'LOAI_SP', @MaDoiTuong = @MaLoai;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF ERROR_NUMBER() IN (2601, 2627) THROW 52081, N'Tên loại sản phẩm đã tồn tại.', 1;
        THROW;
    END CATCH;
    SELECT @MaLoai AS MaLoai;
END;
GO

CREATE OR ALTER PROCEDURE api_admin.usp_LuuCuaHang
    @MaCH      INT           = NULL,
    @TenCH     NVARCHAR(100),
    @DiaChi    NVARCHAR(200),
    @MaTinh    VARCHAR(10),
    @SDT       VARCHAR(15)   = NULL,
    @TrangThai VARCHAR(10)   = 'HOAT_DONG'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_DANH_MUC';
    BEGIN TRY
        BEGIN TRAN;
        IF @MaCH IS NULL
        BEGIN
            INSERT crm.CUA_HANG (TenCH, DiaChi, MaTinh, SDT, TrangThai) VALUES (@TenCH, @DiaChi, @MaTinh, @SDT, @TrangThai);
            SET @MaCH = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE crm.CUA_HANG SET TenCH = @TenCH, DiaChi = @DiaChi, MaTinh = @MaTinh, SDT = @SDT, TrangThai = @TrangThai
             WHERE MaCH = @MaCH;
            IF @@ROWCOUNT = 0 THROW 52080, N'Không tìm thấy cửa hàng.', 1;
        END
        EXEC sec.usp_GhiNhatKy @HanhDong = 'LUU_DANH_MUC', @DoiTuong = 'CUA_HANG', @MaDoiTuong = @MaCH;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF ERROR_NUMBER() IN (2601, 2627) THROW 52081, N'Tên cửa hàng đã tồn tại.', 1;
        THROW;
    END CATCH;
    SELECT @MaCH AS MaCH;
END;
GO

/* Hồ sơ nhân viên. Chức vụ chỉ Admin sửa được; chức vụ KHÔNG tự sinh quyền.
   Nhân viên nghỉ việc -> tài khoản (nếu có) bị khóa trong cùng giao dịch. */
CREATE OR ALTER PROCEDURE api_admin.usp_LuuNhanVien
    @MaNV       INT           = NULL,
    @HoTen      NVARCHAR(100),
    @MaCV       VARCHAR(20),
    @SDT        VARCHAR(10),
    @Email      VARCHAR(100),
    @NgayVaoLam DATE,
    @MaCH       INT           = NULL,
    @TrangThai  VARCHAR(10)   = 'DANG_LAM'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_DANH_MUC';
    IF @MaNV IS NOT NULL AND @MaNV = sec.fn_MaNV() AND @TrangThai <> 'DANG_LAM'
        THROW 52090, N'Không thể tự chuyển hồ sơ của chính mình sang nghỉ việc.', 1;

    BEGIN TRY
        BEGIN TRAN;
        IF @MaNV IS NULL
        BEGIN
            INSERT crm.NHAN_VIEN (HoTen, MaCV, MaCH, SDT, Email, NgayVaoLam, TrangThai)
            VALUES (@HoTen, @MaCV, @MaCH, @SDT, @Email, @NgayVaoLam, @TrangThai);
            SET @MaNV = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            DECLARE @MaTK INT;
            SELECT @MaTK = MaTK FROM crm.NHAN_VIEN WITH (UPDLOCK) WHERE MaNV = @MaNV;
            IF @@ROWCOUNT = 0 THROW 52080, N'Không tìm thấy nhân viên.', 1;

            IF @TrangThai = 'DA_NGHI' AND @MaTK IS NOT NULL
               AND EXISTS (SELECT 1 FROM crm.TAI_KHOAN tk JOIN crm.VAI_TRO_QUYEN vq ON vq.MaVT = tk.MaVT
                           WHERE tk.MaTK = @MaTK AND vq.MaQuyen = 'AD_PHAN_QUYEN')
               AND sec.fn_SoAdminConLai(@MaTK, NULL) = 0
                THROW 52091, N'Không thể cho nghỉ việc Admin cuối cùng có quyền phân quyền.', 1;

            UPDATE crm.NHAN_VIEN
               SET HoTen = @HoTen, MaCV = @MaCV, MaCH = @MaCH, SDT = @SDT, Email = @Email,
                   NgayVaoLam = @NgayVaoLam, TrangThai = @TrangThai
             WHERE MaNV = @MaNV;

            IF @TrangThai = 'DA_NGHI' AND @MaTK IS NOT NULL
                UPDATE crm.TAI_KHOAN
                   SET TrangThai = 'DA_KHOA', NgayKhoa = SYSDATETIME(), LyDoKhoa = N'Nhân viên đã nghỉ việc'
                 WHERE MaTK = @MaTK AND TrangThai = 'HOAT_DONG';
        END
        EXEC sec.usp_GhiNhatKy @HanhDong = 'LUU_DANH_MUC', @DoiTuong = 'NHAN_VIEN', @MaDoiTuong = @MaNV;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF ERROR_NUMBER() IN (2601, 2627) THROW 52081, N'SĐT hoặc email nhân viên đã tồn tại.', 1;
        IF ERROR_NUMBER() = 547 THROW 52082, N'Dữ liệu nhân viên vi phạm ràng buộc (chức vụ, cửa hàng, SĐT, email, trạng thái).', 1;
        THROW;
    END CATCH;
    SELECT @MaNV AS MaNV;
END;
GO

/* ===================== TÀI KHOẢN VÀ PHÂN QUYỀN ===================== */

/* Thêm account cho nhân viên (tài khoản khách hàng do khách tự đăng ký
   hoặc Quản lý cấp). Mật khẩu tạm đã băm; bắt buộc đổi ở lần đăng nhập đầu. */
CREATE OR ALTER PROCEDURE api_admin.usp_TaoTaiKhoanNhanVien
    @MaNV           INT,
    @TenDangNhap    VARCHAR(50),
    @MatKhauHashTam VARCHAR(255),
    @MaVT           VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_TAI_KHOAN';
    /* Tạo tài khoản kèm vai trò = cấp quyền => bắt buộc có thêm AD_PHAN_QUYEN.
       Nếu không, người chỉ có AD_TAI_KHOAN có thể tạo tài khoản ADMIN/QUAN_LY
       cho một hồ sơ nhân viên, biết mật khẩu tạm và leo thang đặc quyền. */
    EXEC sec.usp_KiemTraQuyen 'AD_PHAN_QUYEN';
    IF @TenDangNhap IS NULL OR @MatKhauHashTam IS NULL OR LEN(@MatKhauHashTam) < 50
        THROW 52001, N'Cần tên đăng nhập và chuỗi băm mật khẩu tạm hợp lệ.', 1;
    IF NOT EXISTS (SELECT 1 FROM crm.VAI_TRO WHERE MaVT = @MaVT AND LoaiTK = 'NV')
        THROW 52092, N'Vai trò không tồn tại hoặc không dành cho nhân viên.', 1;

    BEGIN TRY
        BEGIN TRAN;
        IF NOT EXISTS (SELECT 1 FROM crm.NHAN_VIEN WITH (UPDLOCK) WHERE MaNV = @MaNV AND TrangThai = 'DANG_LAM' AND MaTK IS NULL)
            THROW 52093, N'Nhân viên không tồn tại, đã nghỉ việc hoặc đã có tài khoản.', 1;
        IF EXISTS (SELECT 1 FROM crm.TAI_KHOAN WHERE TenDangNhap = @TenDangNhap)
            THROW 52004, N'Tên đăng nhập đã tồn tại.', 1;

        DECLARE @MaTK INT;
        INSERT crm.TAI_KHOAN (TenDangNhap, MatKhauHash, MaVT, LoaiTK, PhaiDoiMatKhau)
        VALUES (@TenDangNhap, @MatKhauHashTam, @MaVT, 'NV', 1);
        SET @MaTK = SCOPE_IDENTITY();
        UPDATE crm.NHAN_VIEN SET MaTK = @MaTK WHERE MaNV = @MaNV;

        DECLARE @ChiTiet NVARCHAR(1000) = CONCAT(N'Tạo tài khoản ', @TenDangNhap, N' cho NV ', @MaNV, N', vai trò ', @MaVT);
        EXEC sec.usp_GhiNhatKy @HanhDong = 'TAO_TK', @DoiTuong = 'TAI_KHOAN', @MaDoiTuong = @MaTK, @ChiTiet = @ChiTiet;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
    SELECT @MaTK AS MaTK;
END;
GO

/* Phân quyền cho account = đổi vai trò. Không tự đổi vai trò của chính mình;
   không để hệ thống mất Admin cuối cùng. Tài khoản KH chỉ nhận vai trò loại KH
   (khóa ngoại (MaVT, LoaiTK) chặn ở mức dữ liệu). */
CREATE OR ALTER PROCEDURE api_admin.usp_DoiVaiTro
    @MaTK    INT,
    @MaVTMoi VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_PHAN_QUYEN';
    IF @MaTK = sec.fn_MaTK()
        THROW 52094, N'Không được tự thay đổi vai trò của chính mình.', 1;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @MaVTCu VARCHAR(20), @LoaiTK CHAR(2);
        SELECT @MaVTCu = MaVT, @LoaiTK = LoaiTK FROM crm.TAI_KHOAN WITH (UPDLOCK) WHERE MaTK = @MaTK;
        IF @MaVTCu IS NULL
            THROW 52095, N'Không tìm thấy tài khoản.', 1;
        IF NOT EXISTS (SELECT 1 FROM crm.VAI_TRO WHERE MaVT = @MaVTMoi AND LoaiTK = @LoaiTK)
            THROW 52092, N'Vai trò mới không tồn tại hoặc không phù hợp loại tài khoản (KH/NV).', 1;
        IF EXISTS (SELECT 1 FROM crm.VAI_TRO_QUYEN WHERE MaVT = @MaVTCu AND MaQuyen = 'AD_PHAN_QUYEN')
           AND NOT EXISTS (SELECT 1 FROM crm.VAI_TRO_QUYEN WHERE MaVT = @MaVTMoi AND MaQuyen = 'AD_PHAN_QUYEN')
           AND sec.fn_SoAdminConLai(@MaTK, NULL) = 0
            THROW 52091, N'Không thể hạ quyền Admin cuối cùng có quyền phân quyền.', 1;

        UPDATE crm.TAI_KHOAN SET MaVT = @MaVTMoi WHERE MaTK = @MaTK;
        DECLARE @ChiTiet NVARCHAR(1000) = CONCAT(N'Đổi vai trò ', @MaVTCu, N' -> ', @MaVTMoi);
        EXEC sec.usp_GhiNhatKy @HanhDong = 'DOI_VAI_TRO', @DoiTuong = 'TAI_KHOAN', @MaDoiTuong = @MaTK, @ChiTiet = @ChiTiet;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE api_admin.usp_KhoaMoTaiKhoan
    @MaTK INT,
    @Khoa BIT,
    @LyDo NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_TAI_KHOAN';
    IF @MaTK = sec.fn_MaTK()
        THROW 52094, N'Không được tự khóa/mở khóa tài khoản của chính mình.', 1;
    IF @Khoa IS NULL OR (@Khoa = 1 AND NULLIF(TRIM(@LyDo), N'') IS NULL)
        THROW 52001, N'Khóa tài khoản cần có lý do.', 1;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @TrangThai VARCHAR(10), @MaVT VARCHAR(20);
        SELECT @TrangThai = TrangThai, @MaVT = MaVT FROM crm.TAI_KHOAN WITH (UPDLOCK) WHERE MaTK = @MaTK;
        IF @TrangThai IS NULL
            THROW 52095, N'Không tìm thấy tài khoản.', 1;
        IF (@Khoa = 1 AND @TrangThai = 'DA_KHOA') OR (@Khoa = 0 AND @TrangThai = 'HOAT_DONG')
            THROW 52043, N'Tài khoản đã ở trạng thái yêu cầu.', 1;
        IF @Khoa = 1
           AND EXISTS (SELECT 1 FROM crm.VAI_TRO_QUYEN WHERE MaVT = @MaVT AND MaQuyen = 'AD_PHAN_QUYEN')
           AND sec.fn_SoAdminConLai(@MaTK, NULL) = 0
            THROW 52091, N'Không thể khóa Admin cuối cùng có quyền phân quyền.', 1;
        IF @Khoa = 0
           AND (EXISTS (SELECT 1 FROM crm.KHACH_HANG WHERE MaTK = @MaTK AND TrangThaiHoSo <> 'HOAT_DONG')
             OR EXISTS (SELECT 1 FROM crm.NHAN_VIEN WHERE MaTK = @MaTK AND TrangThai <> 'DANG_LAM'))
            THROW 52043, N'Không mở khóa tài khoản của hồ sơ đã xóa hoặc nhân viên đã nghỉ.', 1;

        UPDATE crm.TAI_KHOAN
           SET TrangThai = CASE WHEN @Khoa = 1 THEN 'DA_KHOA' ELSE 'HOAT_DONG' END,
               NgayKhoa  = CASE WHEN @Khoa = 1 THEN SYSDATETIME() END,
               LyDoKhoa  = CASE WHEN @Khoa = 1 THEN @LyDo END
         WHERE MaTK = @MaTK;

        DECLARE @HanhDong VARCHAR(40) = CASE WHEN @Khoa = 1 THEN 'KHOA_TK' ELSE 'MO_KHOA_TK' END;
        EXEC sec.usp_GhiNhatKy @HanhDong = @HanhDong, @DoiTuong = 'TAI_KHOAN', @MaDoiTuong = @MaTK, @ChiTiet = @LyDo;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

/* Xóa account: gỡ liên kết khỏi hồ sơ (hồ sơ và lịch sử nghiệp vụ được giữ,
   vì lịch sử tham chiếu MaKH/MaNV chứ không tham chiếu MaTK) rồi xóa tài khoản. */
CREATE OR ALTER PROCEDURE api_admin.usp_XoaTaiKhoan
    @MaTK INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_TAI_KHOAN';
    IF @MaTK = sec.fn_MaTK()
        THROW 52094, N'Không được tự xóa tài khoản của chính mình.', 1;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @TenDangNhap VARCHAR(50), @MaVT VARCHAR(20);
        SELECT @TenDangNhap = TenDangNhap, @MaVT = MaVT FROM crm.TAI_KHOAN WITH (UPDLOCK) WHERE MaTK = @MaTK;
        IF @TenDangNhap IS NULL
            THROW 52095, N'Không tìm thấy tài khoản.', 1;
        IF EXISTS (SELECT 1 FROM crm.VAI_TRO_QUYEN WHERE MaVT = @MaVT AND MaQuyen = 'AD_PHAN_QUYEN')
           AND sec.fn_SoAdminConLai(@MaTK, NULL) = 0
            THROW 52091, N'Không thể xóa Admin cuối cùng có quyền phân quyền.', 1;

        UPDATE crm.NHAN_VIEN  SET MaTK = NULL WHERE MaTK = @MaTK;
        UPDATE crm.KHACH_HANG SET MaTK = NULL WHERE MaTK = @MaTK;
        DELETE crm.TAI_KHOAN WHERE MaTK = @MaTK;

        DECLARE @ChiTiet NVARCHAR(1000) = CONCAT(N'Xóa tài khoản ', @TenDangNhap, N' (vai trò ', @MaVT, N')');
        EXEC sec.usp_GhiNhatKy @HanhDong = 'XOA_TK', @DoiTuong = 'TAI_KHOAN', @MaDoiTuong = @MaTK, @ChiTiet = @ChiTiet;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

/* Tạo vai trò nội bộ mới (vd. "Nhân viên CSKH" dùng cổng Quản lý nhưng ít quyền hơn). */
CREATE OR ALTER PROCEDURE api_admin.usp_TaoVaiTro
    @MaVT        VARCHAR(20),
    @TenVT       NVARCHAR(50),
    @CongTruyCap VARCHAR(10),
    @MoTa        NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_PHAN_QUYEN';
    IF @CongTruyCap NOT IN ('ADMIN', 'QUAN_LY')
        THROW 52096, N'Chỉ tạo được vai trò nội bộ cho cổng ADMIN hoặc QUAN_LY.', 1;
    BEGIN TRY
        INSERT crm.VAI_TRO (MaVT, TenVT, LoaiTK, CongTruyCap, MoTa) VALUES (@MaVT, @TenVT, 'NV', @CongTruyCap, @MoTa);
        EXEC sec.usp_GhiNhatKy @HanhDong = 'TAO_VAI_TRO', @DoiTuong = 'VAI_TRO', @MaDoiTuong = @MaVT;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627) THROW 52081, N'Mã hoặc tên vai trò đã tồn tại.', 1;
        THROW;
    END CATCH;
END;
GO

/* Thay toàn bộ danh sách quyền của một vai trò. Quyền phải cùng cổng với vai trò
   (khóa ngoại kép chặn ở mức dữ liệu). Chặn tự khóa: không gỡ AD_PHAN_QUYEN khỏi
   vai trò của chính mình, và luôn còn ít nhất một Admin có AD_PHAN_QUYEN. */
CREATE OR ALTER PROCEDURE api_admin.usp_CapNhatQuyenVaiTro
    @MaVT    VARCHAR(20),
    @DsQuyen api_admin.DanhSachMaQuyen READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_PHAN_QUYEN';

    DECLARE @Cong VARCHAR(10) = (SELECT CongTruyCap FROM crm.VAI_TRO WHERE MaVT = @MaVT);
    IF @Cong IS NULL
        THROW 52092, N'Vai trò không tồn tại.', 1;
    IF EXISTS (SELECT 1 FROM @DsQuyen d
               WHERE NOT EXISTS (SELECT 1 FROM crm.QUYEN q WHERE q.MaQuyen = d.MaQuyen AND q.CongTruyCap = @Cong))
        THROW 52097, N'Có quyền không tồn tại hoặc không thuộc cổng của vai trò.', 1;

    DECLARE @GoAdmin BIT = CASE WHEN @Cong = 'ADMIN'
                                 AND NOT EXISTS (SELECT 1 FROM @DsQuyen WHERE MaQuyen = 'AD_PHAN_QUYEN') THEN 1 ELSE 0 END;
    IF @GoAdmin = 1 AND @MaVT = (SELECT MaVT FROM crm.TAI_KHOAN WHERE MaTK = sec.fn_MaTK())
        THROW 52094, N'Không được gỡ quyền phân quyền khỏi vai trò của chính mình.', 1;
    IF @GoAdmin = 1 AND sec.fn_SoAdminConLai(NULL, @MaVT) = 0
        THROW 52091, N'Thay đổi này làm hệ thống không còn Admin có quyền phân quyền.', 1;

    BEGIN TRY
        BEGIN TRAN;
        DELETE crm.VAI_TRO_QUYEN WHERE MaVT = @MaVT;
        INSERT crm.VAI_TRO_QUYEN (MaVT, MaQuyen, CongTruyCap) SELECT @MaVT, d.MaQuyen, @Cong FROM @DsQuyen d;
        DECLARE @ChiTiet NVARCHAR(1000) =
            (SELECT STRING_AGG(MaQuyen, ',') WITHIN GROUP (ORDER BY MaQuyen) FROM @DsQuyen);
        EXEC sec.usp_GhiNhatKy @HanhDong = 'CAP_NHAT_QUYEN', @DoiTuong = 'VAI_TRO', @MaDoiTuong = @MaVT, @ChiTiet = @ChiTiet;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

/* Đặt lại mật khẩu (người dùng quên mật khẩu). Ứng dụng sinh mật khẩu tạm, băm,
   gửi chuỗi băm; người dùng bắt buộc đổi ở lần đăng nhập tới.
   Chống leo thang: đặt lại mật khẩu tài khoản NỘI BỘ (NV) cần thêm AD_PHAN_QUYEN,
   nếu không người chỉ có AD_TAI_KHOAN có thể chiếm tài khoản Quản lý/Admin. */
CREATE OR ALTER PROCEDURE api_admin.usp_DatLaiMatKhau
    @MaTK           INT,
    @MatKhauHashTam VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_TAI_KHOAN';
    IF @MaTK = sec.fn_MaTK()
        THROW 52094, N'Tự đổi mật khẩu của mình bằng chức năng Đổi mật khẩu.', 1;
    IF @MatKhauHashTam IS NULL OR LEN(@MatKhauHashTam) < 50
        THROW 52001, N'Chuỗi băm mật khẩu tạm không hợp lệ.', 1;

    DECLARE @LoaiTK CHAR(2) = (SELECT LoaiTK FROM crm.TAI_KHOAN WHERE MaTK = @MaTK);
    IF @LoaiTK IS NULL
        THROW 52095, N'Không tìm thấy tài khoản.', 1;
    IF @LoaiTK = 'NV'
        EXEC sec.usp_KiemTraQuyen 'AD_PHAN_QUYEN';

    UPDATE crm.TAI_KHOAN SET MatKhauHash = @MatKhauHashTam, PhaiDoiMatKhau = 1 WHERE MaTK = @MaTK;
    EXEC sec.usp_GhiNhatKy @HanhDong = 'DAT_LAI_MK', @DoiTuong = 'TAI_KHOAN', @MaDoiTuong = @MaTK;
END;
GO

/* Danh sách hóa đơn đã nạp (kiểm tra sau khi nạp, tìm số hóa đơn để nạp đổi trả). */
CREATE OR ALTER PROCEDURE api_admin.usp_DanhSachHoaDon
    @SoHoaDon VARCHAR(20) = NULL,
    @MaKH     INT         = NULL,
    @TuNgay   DATE        = NULL,
    @DenNgay  DATE        = NULL,
    @Trang    INT         = 1,
    @SoDong   INT         = 50
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_NAP_GIAO_DICH';
    IF @Trang < 1 OR @SoDong NOT BETWEEN 1 AND 500
        THROW 52001, N'Tham số phân trang không hợp lệ.', 1;

    SELECT g.MaHD, g.SoHoaDon, g.NgayLap, g.KenhBan, ch.TenCH, nv.HoTen AS NhanVienBan,
           g.MaKH, k.HoTen AS TenKhachHang, g.TongTienHang, g.PhanTramGiam, g.ThanhTien,
           (SELECT ISNULL(SUM(d.SoLuong), 0) FROM crm.DOI_TRA d WHERE d.MaHD = g.MaHD) AS SoLuongDaDoiTra,
           COUNT(*) OVER () AS TongSoDong
    FROM crm.vw_GiaTriHoaDon g
    JOIN crm.KHACH_HANG k     ON k.MaKH = g.MaKH
    LEFT JOIN crm.CUA_HANG ch ON ch.MaCH = g.MaCH
    LEFT JOIN crm.NHAN_VIEN nv ON nv.MaNV = g.MaNV
    WHERE (@SoHoaDon IS NULL OR g.SoHoaDon = @SoHoaDon)
      AND (@MaKH IS NULL OR g.MaKH = @MaKH)
      AND (@TuNgay IS NULL OR g.NgayLap >= @TuNgay)
      AND (@DenNgay IS NULL OR g.NgayLap < DATEADD(DAY, 1, @DenNgay))
    ORDER BY g.NgayLap DESC, g.MaHD DESC
    OFFSET (@Trang - 1) * @SoDong ROWS FETCH NEXT @SoDong ROWS ONLY
    OPTION (RECOMPILE);

    -- Chi tiết dòng hàng khi lọc đúng 1 số hóa đơn
    IF @SoHoaDon IS NOT NULL
        SELECT sp.MaSKU, sp.TenSP, ct.SoLuong, ct.DonGiaBan,
               (SELECT ISNULL(SUM(d.SoLuong), 0) FROM crm.DOI_TRA d WHERE d.MaHD = ct.MaHD AND d.MaSP = ct.MaSP) AS DaDoiTra
        FROM crm.CHI_TIET_HOA_DON ct
        JOIN crm.HOA_DON h  ON h.MaHD = ct.MaHD
        JOIN crm.SAN_PHAM sp ON sp.MaSP = ct.MaSP
        WHERE h.SoHoaDon = @SoHoaDon;
END;
GO

/* ===================== NẠP DỮ LIỆU GIAO DỊCH (từ POS) ===================== */

CREATE OR ALTER PROCEDURE api_admin.usp_NhapHoaDon
    @SoHoaDon      VARCHAR(20),
    @MaKH          INT,
    @KenhBan       VARCHAR(8),
    @NgayLap       DATETIME2(0),
    @MaCH          INT         = NULL,
    @MaNV          INT         = NULL,
    @MaCodeVoucher VARCHAR(20) = NULL,
    @ChiTiet       api_admin.BangChiTietHoaDon READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_NAP_GIAO_DICH';

    IF NOT EXISTS (SELECT 1 FROM @ChiTiet)
        THROW 52070, N'Hóa đơn phải có ít nhất một dòng chi tiết.', 1;
    IF EXISTS (SELECT 1 FROM @ChiTiet WHERE SoLuong <= 0 OR DonGiaBan < 0)
        THROW 52070, N'Số lượng phải > 0 và đơn giá >= 0.', 1;
    IF @NgayLap IS NULL OR @NgayLap > SYSDATETIME()
        THROW 52070, N'Ngày lập hóa đơn không hợp lệ.', 1;

    DECLARE @SkuLoi NVARCHAR(1000) =
        (SELECT STRING_AGG(c.MaSKU, ', ') FROM @ChiTiet c
         WHERE NOT EXISTS (SELECT 1 FROM crm.SAN_PHAM sp WHERE sp.MaSKU = c.MaSKU AND sp.TrangThai <> 'SAP_RA_MAT'));
    IF @SkuLoi IS NOT NULL
    BEGIN
        SET @SkuLoi = N'Mã SKU không tồn tại hoặc chưa mở bán: ' + @SkuLoi;
        THROW 52071, @SkuLoi, 1;
    END

    BEGIN TRY
        BEGIN TRAN;
        IF NOT EXISTS (SELECT 1 FROM crm.KHACH_HANG WHERE MaKH = @MaKH AND TrangThaiHoSo = 'HOAT_DONG')
            THROW 52040, N'Khách hàng không tồn tại hoặc đã bị xóa.', 1;
        IF EXISTS (SELECT 1 FROM crm.HOA_DON WHERE SoHoaDon = @SoHoaDon)
            THROW 52072, N'Số hóa đơn đã được nạp trước đó.', 1;

        DECLARE @MaVoucher INT = NULL;
        IF @MaCodeVoucher IS NOT NULL
        BEGIN
            DECLARE @VcKH INT, @VcPhat DATETIME2(0), @VcHan DATETIME2(0);
            SELECT @MaVoucher = MaVoucher, @VcKH = MaKH, @VcPhat = NgayPhat, @VcHan = HanDung
            FROM crm.VOUCHER WITH (UPDLOCK) WHERE MaCode = @MaCodeVoucher;
            IF @MaVoucher IS NULL OR @VcKH <> @MaKH
                THROW 52073, N'Voucher không tồn tại hoặc không thuộc khách hàng này.', 1;
            IF EXISTS (SELECT 1 FROM crm.HOA_DON WHERE MaVoucher = @MaVoucher)
                THROW 52073, N'Voucher đã được sử dụng.', 1;
            IF @NgayLap < @VcPhat OR @NgayLap > @VcHan
                THROW 52073, N'Voucher không còn hiệu lực tại ngày lập hóa đơn.', 1;
        END

        DECLARE @MaHD INT;
        INSERT crm.HOA_DON (SoHoaDon, MaKH, KenhBan, MaCH, MaNV, NgayLap, MaVoucher)
        VALUES (@SoHoaDon, @MaKH, @KenhBan, @MaCH, @MaNV, @NgayLap, @MaVoucher);
        SET @MaHD = SCOPE_IDENTITY();

        INSERT crm.CHI_TIET_HOA_DON (MaHD, MaSP, SoLuong, DonGiaBan)
        SELECT @MaHD, sp.MaSP, c.SoLuong, c.DonGiaBan
        FROM @ChiTiet c JOIN crm.SAN_PHAM sp ON sp.MaSKU = c.MaSKU;

        DECLARE @LyDo NVARCHAR(200) = N'Tự xét hạng sau khi nạp hóa đơn ' + @SoHoaDon;
        EXEC crm.usp_XetHang_NoiBo @MaKH = @MaKH, @LyDo = @LyDo;
        EXEC sec.usp_GhiNhatKy @HanhDong = 'NAP_HOA_DON', @DoiTuong = 'HOA_DON', @MaDoiTuong = @MaHD, @ChiTiet = @SoHoaDon;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF ERROR_NUMBER() = 547
            THROW 52074, N'Dữ liệu hóa đơn vi phạm ràng buộc (kênh bán, cửa hàng, nhân viên).', 1;
        THROW;
    END CATCH;

    SELECT g.MaHD, g.SoHoaDon, g.TongTienHang, g.PhanTramGiam, g.ThanhTien, k.MaHang AS HangSauKhiNap
    FROM crm.vw_GiaTriHoaDon g JOIN crm.KHACH_HANG k ON k.MaKH = g.MaKH
    WHERE g.MaHD = @MaHD;
END;
GO

CREATE OR ALTER PROCEDURE api_admin.usp_NhapDoiTra
    @SoHoaDon   VARCHAR(20),
    @MaSKU      VARCHAR(20),
    @SoLuong    INT,
    @LyDo       VARCHAR(10),
    @NgayDoiTra DATETIME2(0),
    @GhiChu     NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_NAP_GIAO_DICH';
    IF @NgayDoiTra IS NULL OR @NgayDoiTra > SYSDATETIME()
        THROW 52075, N'Ngày đổi trả không hợp lệ.', 1;

    DECLARE @MaHD INT, @MaKH INT, @MaSP INT;
    SELECT @MaHD = h.MaHD, @MaKH = h.MaKH, @MaSP = ct.MaSP
    FROM crm.HOA_DON h
    JOIN crm.CHI_TIET_HOA_DON ct ON ct.MaHD = h.MaHD
    JOIN crm.SAN_PHAM sp         ON sp.MaSP = ct.MaSP
    WHERE h.SoHoaDon = @SoHoaDon AND sp.MaSKU = @MaSKU;
    IF @MaHD IS NULL
        THROW 52075, N'Không tìm thấy sản phẩm này trong hóa đơn.', 1;

    BEGIN TRY
        BEGIN TRAN;
        INSERT crm.DOI_TRA (MaHD, MaSP, SoLuong, LyDo, GhiChu, NgayDoiTra)
        VALUES (@MaHD, @MaSP, @SoLuong, @LyDo, @GhiChu, @NgayDoiTra);   -- trigger kiểm tra số lượng/ngày
        DECLARE @MaDT INT = SCOPE_IDENTITY();
        DECLARE @LyDoXet NVARCHAR(200) = N'Tự xét hạng sau đổi trả hóa đơn ' + @SoHoaDon;
        EXEC crm.usp_XetHang_NoiBo @MaKH = @MaKH, @LyDo = @LyDoXet;
        EXEC sec.usp_GhiNhatKy @HanhDong = 'NAP_DOI_TRA', @DoiTuong = 'DOI_TRA', @MaDoiTuong = @MaDT, @ChiTiet = @SoHoaDon;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF ERROR_NUMBER() = 547 THROW 52076, N'Dữ liệu đổi trả vi phạm ràng buộc (số lượng, lý do).', 1;
        THROW;
    END CATCH;
    SELECT @MaDT AS MaDT;
END;
GO

CREATE OR ALTER PROCEDURE api_admin.usp_XetHangToanBo
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'AD_NAP_GIAO_DICH';
    DECLARE @SoThayDoi INT;
    BEGIN TRY
        BEGIN TRAN;
        EXEC crm.usp_XetHang_NoiBo @MaKH = NULL, @LyDo = N'Xét hạng định kỳ toàn bộ khách hàng',
             @SoThayDoi = @SoThayDoi OUTPUT;
        DECLARE @ChiTiet NVARCHAR(1000) = CONCAT(N'Số khách đổi hạng: ', @SoThayDoi);
        EXEC sec.usp_GhiNhatKy @HanhDong = 'XET_HANG', @DoiTuong = 'KHACH_HANG', @ChiTiet = @ChiTiet;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
    SELECT @SoThayDoi AS SoKhachDoiHang;
END;
GO

PRINT N'Script 05c hoàn tất.';
GO
