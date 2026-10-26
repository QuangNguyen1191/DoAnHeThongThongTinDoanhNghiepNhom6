/* =====================================================================
   Script 18: BỔ SUNG – Quên mật khẩu (L5) và Lịch sử mua hàng của khách
   ---------------------------------------------------------------------
   Chạy SAU script 08 (trước 08b). Chỉ THÊM đối tượng mới, không xóa/sửa
   bảng cũ, không đụng dữ liệu cũ. Chạy lại nhiều lần được (idempotent).
     - Bảng crm.YEU_CAU_DAT_LAI_MK : mã đặt lại mật khẩu dùng một lần.
       CSDL chỉ lưu SHA-256 của mã (ứng dụng giữ mã gốc và gửi qua email),
       nên người đọc được bảng cũng không dùng được mã.
     - sec.usp_TimTaiKhoanQuenMK_NoiBo   : tra tài khoản theo tên ĐN + email
       hồ sơ (EXECUTE AS OWNER vì phiên chưa đăng nhập bị RLS chặn đọc KHACH_HANG).
     - api_chung.usp_YeuCauDatLaiMatKhau : bước 1, ghi mã đặt lại.
     - api_chung.usp_DatLaiMatKhauBangMa : bước 2, đặt mật khẩu mới bằng mã.
     - api_kh.usp_LichSuGiaoDich         : hóa đơn, chi tiết, đổi trả của
       chính khách đang đăng nhập.
   Quyền: các schema api_chung/api_kh đã được GRANT EXECUTE ở script 06 nên
   thủ tục mới tự có quyền; sec/crm vẫn bị DENY như cũ.
   ===================================================================== */
USE CRM_Uniqlo;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

/* ============================ BẢNG ============================ */

/* ON DELETE CASCADE: api_admin.usp_XoaTaiKhoan xóa hẳn tài khoản, mã đặt lại
   của tài khoản đó không còn ý nghĩa. */
IF OBJECT_ID(N'crm.YEU_CAU_DAT_LAI_MK', N'U') IS NULL
CREATE TABLE crm.YEU_CAU_DAT_LAI_MK (
    MaYC       INT IDENTITY(1, 1) NOT NULL,
    MaTK       INT           NOT NULL,
    TokenHash  CHAR(64)      NOT NULL,      -- SHA-256 dạng hex của mã gửi qua email
    NgayTao    DATETIME2(0)  NOT NULL CONSTRAINT DF_YEU_CAU_DAT_LAI_MK_NgayTao DEFAULT (SYSDATETIME()),
    HetHan     DATETIME2(0)  NOT NULL,
    TrangThai  VARCHAR(10)   NOT NULL CONSTRAINT DF_YEU_CAU_DAT_LAI_MK_TrangThai DEFAULT ('CHO'),
    NgaySuDung DATETIME2(0)  NULL,
    CONSTRAINT PK_YEU_CAU_DAT_LAI_MK PRIMARY KEY (MaYC),
    CONSTRAINT UQ_YEU_CAU_DAT_LAI_MK_Token UNIQUE (TokenHash),
    CONSTRAINT FK_YEU_CAU_DAT_LAI_MK_TAI_KHOAN FOREIGN KEY (MaTK)
        REFERENCES crm.TAI_KHOAN (MaTK) ON DELETE CASCADE,
    CONSTRAINT CK_YEU_CAU_DAT_LAI_MK_Token CHECK (TokenHash NOT LIKE '%[^0-9a-f]%'),
    CONSTRAINT CK_YEU_CAU_DAT_LAI_MK_HetHan CHECK (HetHan > NgayTao),
    CONSTRAINT CK_YEU_CAU_DAT_LAI_MK_TrangThai CHECK (
        (TrangThai = 'CHO'     AND NgaySuDung IS NULL)
     OR (TrangThai = 'DA_DUNG' AND NgaySuDung IS NOT NULL)
     OR (TrangThai = 'DA_HUY'))
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_YEU_CAU_DAT_LAI_MK_MaTK'
                 AND object_id = OBJECT_ID(N'crm.YEU_CAU_DAT_LAI_MK'))
    CREATE INDEX IX_YEU_CAU_DAT_LAI_MK_MaTK ON crm.YEU_CAU_DAT_LAI_MK (MaTK, NgayTao);
GO

/* ======================= THỦ TỤC NỘI BỘ (sec) ======================= */

/* Tra tài khoản để đặt lại mật khẩu: đúng tên đăng nhập, đang hoạt động,
   thuộc cổng @Cong, hồ sơ còn hoạt động và email hồ sơ trùng @Email.
   @Cong do thủ tục gọi truyền vào (dưới EXECUTE AS OWNER, fn_CongNguoiGoi
   sẽ trả 'DBO'). Không khớp -> @MaTK = NULL. */
CREATE OR ALTER PROCEDURE sec.usp_TimTaiKhoanQuenMK_NoiBo
    @TenDangNhap VARCHAR(50),
    @Email       VARCHAR(100),
    @Cong        VARCHAR(10),
    @MaTK        INT           OUTPUT,
    @HoTen       NVARCHAR(100) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @MaTK = NULL, @HoTen = NULL;

    SELECT @MaTK = tk.MaTK, @HoTen = COALESCE(k.HoTen, n.HoTen)
    FROM crm.TAI_KHOAN tk
    JOIN crm.VAI_TRO vt        ON vt.MaVT = tk.MaVT
    LEFT JOIN crm.KHACH_HANG k ON k.MaTK = tk.MaTK AND k.TrangThaiHoSo = 'HOAT_DONG'
    LEFT JOIN crm.NHAN_VIEN n  ON n.MaTK = tk.MaTK AND n.TrangThai = 'DANG_LAM'
    WHERE tk.TenDangNhap = @TenDangNhap
      AND tk.TrangThai = 'HOAT_DONG'
      AND (@Cong = 'DBO' OR vt.CongTruyCap = @Cong)
      AND LOWER(COALESCE(k.Email, n.Email)) = @Email;
END;
GO

/* ============================ api_chung ============================ */

/* L5 bước 1 – Quên mật khẩu (phiên CHƯA đăng nhập).
   Ứng dụng sinh mã ngẫu nhiên, gửi SHA-256 của mã vào đây; nếu có dòng trả về
   thì gửi email chứa mã gốc tới Email đó. Không khớp hoặc gửi quá nhiều lần
   -> tập rỗng, KHÔNG báo lỗi (ứng dụng luôn trả lời chung để không lộ việc
   tài khoản có tồn tại hay không). Mỗi tài khoản tối đa 3 yêu cầu / 15 phút;
   yêu cầu mới hủy các mã cũ còn chờ. */
CREATE OR ALTER PROCEDURE api_chung.usp_YeuCauDatLaiMatKhau
    @TenDangNhap   VARCHAR(50),
    @Email         VARCHAR(100),
    @TokenHash     CHAR(64),
    @SoPhutHieuLuc INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF SESSION_CONTEXT(N'MaTK') IS NOT NULL
        THROW 52001, N'Phiên đã đăng nhập; dùng chức năng đổi mật khẩu.', 1;
    DECLARE @Cong VARCHAR(10) = sec.fn_CongNguoiGoi();
    IF @Cong IS NULL
        THROW 50011, N'Người dùng CSDL hiện tại không thuộc cổng ứng dụng nào.', 1;

    SELECT @TenDangNhap = NULLIF(TRIM(@TenDangNhap), ''),
           @Email       = NULLIF(LOWER(TRIM(@Email)), ''),
           @TokenHash   = LOWER(@TokenHash);
    IF @TenDangNhap IS NULL OR @Email IS NULL
        THROW 52001, N'Phải nhập tên đăng nhập và email.', 1;
    IF @TokenHash IS NULL OR LEN(@TokenHash) <> 64 OR @TokenHash LIKE '%[^0-9a-f]%'
        THROW 52001, N'Mã đặt lại không hợp lệ (CSDL chỉ nhận SHA-256 dạng hex).', 1;
    IF @SoPhutHieuLuc IS NULL OR @SoPhutHieuLuc NOT BETWEEN 5 AND 1440
        THROW 52001, N'Thời hạn mã đặt lại phải từ 5 đến 1440 phút.', 1;

    DECLARE @MaTK INT, @HoTen NVARCHAR(100);
    EXEC sec.usp_TimTaiKhoanQuenMK_NoiBo @TenDangNhap = @TenDangNhap, @Email = @Email, @Cong = @Cong,
         @MaTK = @MaTK OUTPUT, @HoTen = @HoTen OUTPUT;
    IF @MaTK IS NULL
        RETURN;

    IF (SELECT COUNT(*) FROM crm.YEU_CAU_DAT_LAI_MK
        WHERE MaTK = @MaTK AND NgayTao > DATEADD(MINUTE, -15, SYSDATETIME())) >= 3
    BEGIN
        EXEC sec.usp_GhiNhatKy @HanhDong = 'QUEN_MAT_KHAU_BI_CHAN', @DoiTuong = 'TAI_KHOAN',
             @MaDoiTuong = @MaTK, @ChiTiet = N'Quá 3 yêu cầu trong 15 phút.', @MaTK = @MaTK;
        RETURN;
    END

    BEGIN TRAN;
        UPDATE crm.YEU_CAU_DAT_LAI_MK SET TrangThai = 'DA_HUY'
        WHERE MaTK = @MaTK AND TrangThai = 'CHO';

        INSERT crm.YEU_CAU_DAT_LAI_MK (MaTK, TokenHash, NgayTao, HetHan)
        VALUES (@MaTK, @TokenHash, SYSDATETIME(), DATEADD(MINUTE, @SoPhutHieuLuc, SYSDATETIME()));

        EXEC sec.usp_GhiNhatKy @HanhDong = 'QUEN_MAT_KHAU', @DoiTuong = 'TAI_KHOAN',
             @MaDoiTuong = @MaTK, @MaTK = @MaTK;
    COMMIT;

    SELECT @HoTen AS HoTen, @Email AS Email,
           DATEADD(MINUTE, @SoPhutHieuLuc, SYSDATETIME()) AS HetHan;
END;
GO

/* L5 bước 2 – Đặt mật khẩu mới bằng mã trong email (phiên CHƯA đăng nhập).
   Mã phải đang chờ, chưa hết hạn và thuộc tài khoản của đúng cổng gọi.
   Thành công: đổi chuỗi băm, bỏ cờ "phải đổi mật khẩu", đánh dấu mã đã dùng
   và hủy các mã khác của tài khoản. */
CREATE OR ALTER PROCEDURE api_chung.usp_DatLaiMatKhauBangMa
    @TokenHash      CHAR(64),
    @MatKhauHashMoi VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF SESSION_CONTEXT(N'MaTK') IS NOT NULL
        THROW 52001, N'Phiên đã đăng nhập; dùng chức năng đổi mật khẩu.', 1;
    DECLARE @Cong VARCHAR(10) = sec.fn_CongNguoiGoi();
    IF @Cong IS NULL
        THROW 50011, N'Người dùng CSDL hiện tại không thuộc cổng ứng dụng nào.', 1;
    IF @MatKhauHashMoi IS NULL OR LEN(@MatKhauHashMoi) < 50
        THROW 52001, N'Chuỗi băm mật khẩu không hợp lệ (CSDL không nhận mật khẩu thô).', 1;
    SET @TokenHash = LOWER(@TokenHash);

    DECLARE @MaYC INT, @MaTK INT;
    BEGIN TRAN;
        SELECT @MaYC = y.MaYC, @MaTK = y.MaTK
        FROM crm.YEU_CAU_DAT_LAI_MK y WITH (UPDLOCK, HOLDLOCK)
        JOIN crm.TAI_KHOAN tk ON tk.MaTK = y.MaTK
        JOIN crm.VAI_TRO vt   ON vt.MaVT = tk.MaVT
        WHERE y.TokenHash = @TokenHash
          AND y.TrangThai = 'CHO'
          AND y.HetHan > SYSDATETIME()
          AND tk.TrangThai = 'HOAT_DONG'
          AND (@Cong = 'DBO' OR vt.CongTruyCap = @Cong);

        IF @MaYC IS NULL
            THROW 52098, N'Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn.', 1;

        UPDATE crm.TAI_KHOAN SET MatKhauHash = @MatKhauHashMoi, PhaiDoiMatKhau = 0
        WHERE MaTK = @MaTK;

        UPDATE crm.YEU_CAU_DAT_LAI_MK SET TrangThai = 'DA_DUNG', NgaySuDung = SYSDATETIME()
        WHERE MaYC = @MaYC;
        UPDATE crm.YEU_CAU_DAT_LAI_MK SET TrangThai = 'DA_HUY'
        WHERE MaTK = @MaTK AND TrangThai = 'CHO';

        EXEC sec.usp_GhiNhatKy @HanhDong = 'DAT_LAI_MAT_KHAU_BANG_MA', @DoiTuong = 'TAI_KHOAN',
             @MaDoiTuong = @MaTK, @MaTK = @MaTK;
    COMMIT;
END;
GO

/* ============================ api_kh ============================ */

/* Lịch sử mua hàng của chính khách đang đăng nhập.
   HOA_DON/CHI_TIET_HOA_DON/DOI_TRA không có RLS nên lọc tường minh theo
   sec.fn_MaKH(). @TuNgay/@DenNgay lọc theo ngày lập hóa đơn (bao gồm hai đầu).
   RS1: hóa đơn  RS2: chi tiết từng hóa đơn  RS3: đổi trả của các hóa đơn đó. */
CREATE OR ALTER PROCEDURE api_kh.usp_LichSuGiaoDich
    @TuNgay  DATE = NULL,
    @DenNgay DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'KH_HO_SO';
    DECLARE @MaKH INT = sec.fn_MaKH();
    IF ISNULL(@MaKH, 0) = 0
        THROW 50012, N'Tài khoản không gắn với hồ sơ khách hàng.', 1;
    IF @TuNgay IS NOT NULL AND @DenNgay IS NOT NULL AND @TuNgay > @DenNgay
        THROW 52001, N'Từ ngày phải trước hoặc bằng đến ngày.', 1;

    DECLARE @HD TABLE (MaHD INT PRIMARY KEY);
    INSERT @HD
    SELECT h.MaHD FROM crm.HOA_DON h
    WHERE h.MaKH = @MaKH
      AND (@TuNgay  IS NULL OR h.NgayLap >= @TuNgay)
      AND (@DenNgay IS NULL OR h.NgayLap <  DATEADD(DAY, 1, @DenNgay));

    SELECT g.MaHD, g.SoHoaDon, g.NgayLap, g.KenhBan, ch.TenCH,
           (SELECT SUM(ct.SoLuong) FROM crm.CHI_TIET_HOA_DON ct WHERE ct.MaHD = g.MaHD) AS SoLuongSP,
           g.TongTienHang, g.PhanTramGiam, g.ThanhTien,
           ISNULL((SELECT SUM(d.SoLuong) FROM crm.DOI_TRA d WHERE d.MaHD = g.MaHD), 0) AS SoLuongDaDoiTra,
           ISNULL((SELECT SUM(dt.GiaTriHoan) FROM crm.vw_GiaTriDoiTra dt WHERE dt.MaHD = g.MaHD), 0) AS GiaTriHoan
    FROM crm.vw_GiaTriHoaDon g
    JOIN @HD x               ON x.MaHD = g.MaHD
    LEFT JOIN crm.CUA_HANG ch ON ch.MaCH = g.MaCH
    ORDER BY g.NgayLap DESC, g.MaHD DESC;

    SELECT ct.MaHD, h.SoHoaDon, sp.MaSP, sp.MaSKU, sp.TenSP, ct.SoLuong, ct.DonGiaBan,
           CAST(ct.SoLuong * ct.DonGiaBan AS DECIMAL(16, 2)) AS ThanhTien,
           ISNULL((SELECT SUM(d.SoLuong) FROM crm.DOI_TRA d
                   WHERE d.MaHD = ct.MaHD AND d.MaSP = ct.MaSP), 0) AS SoLuongDaDoiTra
    FROM crm.CHI_TIET_HOA_DON ct
    JOIN @HD x           ON x.MaHD = ct.MaHD
    JOIN crm.HOA_DON h   ON h.MaHD = ct.MaHD
    JOIN crm.SAN_PHAM sp ON sp.MaSP = ct.MaSP
    ORDER BY h.NgayLap DESC, ct.MaHD DESC, sp.TenSP;

    SELECT dt.MaDT, dt.MaHD, h.SoHoaDon, sp.MaSP, sp.TenSP, dt.SoLuong, dt.LyDo, dt.NgayDoiTra, dt.GiaTriHoan
    FROM crm.vw_GiaTriDoiTra dt
    JOIN @HD x           ON x.MaHD = dt.MaHD
    JOIN crm.HOA_DON h   ON h.MaHD = dt.MaHD
    JOIN crm.SAN_PHAM sp ON sp.MaSP = dt.MaSP
    ORDER BY dt.NgayDoiTra DESC, dt.MaDT DESC;
END;
GO

PRINT N'Script 18 hoàn tất: bảng YEU_CAU_DAT_LAI_MK + 4 thủ tục (quên mật khẩu, lịch sử mua hàng).';
GO
