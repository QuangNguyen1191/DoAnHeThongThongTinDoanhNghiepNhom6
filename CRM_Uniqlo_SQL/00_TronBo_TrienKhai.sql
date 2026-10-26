/* =====================================================================
   00_TronBo_TrienKhai.sql – GỘP SẴN script 01 -> 08 và 18 (tạo CSDL, bảng, thủ tục,
   phân quyền, RLS, dữ liệu hệ thống, dữ liệu mẫu) để nộp/chạy một lần.
   Nội dung giống hệt các tệp lẻ; khi sửa hãy sửa tệp lẻ rồi gộp lại.
   ĐỔI 3 MẬT KHẨU LOGIN trong phần 06 trước khi chạy.
   ===================================================================== */

/* #################### 01_TaoCSDL_Schema.sql #################### */
/* =====================================================================
   HỆ THỐNG CRM – CHUỖI BÁN LẺ THỜI TRANG UNIQLO (ĐỒ ÁN HTTTDN – SGU)
   Script 01: Kiểm tra điều kiện, tạo database và schema
   ---------------------------------------------------------------------
   Phiên bản mục tiêu : SQL Server 2017 trở lên (compatibility level 140+)
                        Dùng: Row-Level Security, SESSION_CONTEXT,
                        CREATE OR ALTER, STRING_AGG, TRIM, THROW.
   Chạy bằng         : tài khoản có quyền sysadmin hoặc dbcreator.
   An toàn           : Script KHÔNG DROP database/bảng. Chạy lại nhiều lần
                        không làm mất dữ liệu (chỉ tạo khi chưa tồn tại).
   ===================================================================== */
SET NOCOUNT ON;
GO

/* 1. Kiểm tra phiên bản SQL Server */
DECLARE @PhienBanChinh INT =
    CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), 4) AS INT);
IF @PhienBanChinh < 14
BEGIN
    RAISERROR (N'Cần SQL Server 2017 (phiên bản 14.x) trở lên. Phiên bản hiện tại: %d.x', 16, 1, @PhienBanChinh);
    SET NOEXEC ON;   -- dừng toàn bộ phần còn lại của script
END
ELSE
    PRINT N'Phiên bản SQL Server hợp lệ: ' + CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128));
GO

/* 2. Tạo database nếu chưa tồn tại.
      Collation Vietnamese_100_CI_AS: sắp xếp/tìm kiếm tiếng Việt đúng,
      không phân biệt hoa thường (tên đăng nhập 'Kh.An' = 'kh.an'). */
IF DB_ID(N'CRM_Uniqlo') IS NULL
BEGIN
    CREATE DATABASE CRM_Uniqlo COLLATE Vietnamese_100_CI_AS;
    PRINT N'Đã tạo database CRM_Uniqlo.';
END
ELSE
    PRINT N'Database CRM_Uniqlo đã tồn tại – bỏ qua bước tạo.';
GO

/* Recovery model FULL để sao lưu nhật ký giao dịch (xem script 09). */
IF (SELECT recovery_model_desc FROM sys.databases WHERE name = N'CRM_Uniqlo') <> N'FULL'
    ALTER DATABASE CRM_Uniqlo SET RECOVERY FULL;
GO

USE CRM_Uniqlo;
GO

IF (SELECT compatibility_level FROM sys.databases WHERE name = DB_NAME()) < 140
    ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 140;
GO

/* 3. Tạo schema
   crm       : toàn bộ bảng nghiệp vụ, thủ tục nội bộ (không cấp quyền cho ai)
   sec       : hàm/thủ tục bảo mật (ngữ cảnh phiên, kiểm tra quyền, RLS)
   audit     : nhật ký kiểm toán
   api_chung : thủ tục/view dùng chung cho cả 3 cổng (đăng nhập, danh mục)
   api_kh    : thủ tục cho cổng Khách hàng
   api_ql    : thủ tục/báo cáo cho cổng Quản lý
   api_admin : thủ tục/view cho cổng Admin                                */
IF SCHEMA_ID(N'crm')       IS NULL EXEC (N'CREATE SCHEMA crm AUTHORIZATION dbo;');
IF SCHEMA_ID(N'sec')       IS NULL EXEC (N'CREATE SCHEMA sec AUTHORIZATION dbo;');
IF SCHEMA_ID(N'audit')     IS NULL EXEC (N'CREATE SCHEMA audit AUTHORIZATION dbo;');
IF SCHEMA_ID(N'api_chung') IS NULL EXEC (N'CREATE SCHEMA api_chung AUTHORIZATION dbo;');
IF SCHEMA_ID(N'api_kh')    IS NULL EXEC (N'CREATE SCHEMA api_kh AUTHORIZATION dbo;');
IF SCHEMA_ID(N'api_ql')    IS NULL EXEC (N'CREATE SCHEMA api_ql AUTHORIZATION dbo;');
IF SCHEMA_ID(N'api_admin') IS NULL EXEC (N'CREATE SCHEMA api_admin AUTHORIZATION dbo;');
GO
/* Tất cả schema đều do dbo sở hữu => chuỗi sở hữu (ownership chaining) giữa
   thủ tục api_* và bảng crm.* hoạt động: người dùng chỉ cần quyền EXECUTE
   trên thủ tục, không cần quyền trực tiếp trên bảng. */

SET NOEXEC OFF;
GO
PRINT N'Script 01 hoàn tất.';
GO

/* #################### 02_TaoBang.sql #################### */
/* =====================================================================
   Script 02: Tạo bảng, khóa chính, khóa ngoại, UNIQUE, CHECK, DEFAULT
   ---------------------------------------------------------------------
   - Bảng chỉ được tạo khi chưa tồn tại (IF OBJECT_ID ... IS NULL).
   - Không có lệnh DROP. Không xóa dữ liệu.
   - Mã trạng thái/phân loại lưu dạng mã ASCII viết hoa (VARCHAR) để
     tránh lỗi gõ dấu; tên hiển thị tiếng Việt nằm ở view/ứng dụng.
   - Thời gian lưu theo giờ máy chủ (khuyến nghị đặt máy chủ UTC+7),
     kiểu DATETIME2(0) (chính xác tới giây).
   - Tiền lưu bằng DECIMAL(14,2), không dùng FLOAT/REAL.
   ===================================================================== */
USE CRM_Uniqlo;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- bắt buộc cho filtered index / RLS
SET NOCOUNT ON;
GO

/* ==================== A. TÀI KHOẢN VÀ PHÂN QUYỀN ==================== */

/* VAI_TRO: vai trò nghiệp vụ trong ứng dụng (khác chức vụ, khác DB role).
   LoaiTK      : loại tài khoản được phép mang vai trò này (KH/NV).
   CongTruyCap : cổng ứng dụng mà vai trò được đăng nhập, ánh xạ 1-1 với
                 database role (ADMIN->r_admin, QUAN_LY->r_quanly,
                 KHACH_HANG->r_khachhang). Đây là "trần quyền" ở SQL Server. */
IF OBJECT_ID(N'crm.VAI_TRO', N'U') IS NULL
CREATE TABLE crm.VAI_TRO (
    MaVT          VARCHAR(20)   NOT NULL,
    TenVT         NVARCHAR(50)  NOT NULL,
    LoaiTK        CHAR(2)       NOT NULL,
    CongTruyCap   VARCHAR(10)   NOT NULL,
    MoTa          NVARCHAR(200) NULL,
    CONSTRAINT PK_VAI_TRO PRIMARY KEY (MaVT),
    CONSTRAINT UQ_VAI_TRO_TenVT UNIQUE (TenVT),
    CONSTRAINT UQ_VAI_TRO_MaVT_LoaiTK UNIQUE (MaVT, LoaiTK),
    CONSTRAINT UQ_VAI_TRO_MaVT_Cong UNIQUE (MaVT, CongTruyCap),
    CONSTRAINT CK_VAI_TRO_LoaiTK CHECK (LoaiTK IN ('KH', 'NV')),
    CONSTRAINT CK_VAI_TRO_Cong CHECK (CongTruyCap IN ('ADMIN', 'QUAN_LY', 'KHACH_HANG')),
    CONSTRAINT CK_VAI_TRO_LoaiTK_Cong CHECK (
        (LoaiTK = 'KH' AND CongTruyCap = 'KHACH_HANG')
     OR (LoaiTK = 'NV' AND CongTruyCap IN ('ADMIN', 'QUAN_LY')))
);
GO

/* QUYEN: quyền chức năng trong ứng dụng. Mỗi quyền thuộc đúng 1 cổng,
   nên không thể gán nhầm quyền quản trị cho vai trò khách hàng. */
IF OBJECT_ID(N'crm.QUYEN', N'U') IS NULL
CREATE TABLE crm.QUYEN (
    MaQuyen       VARCHAR(30)   NOT NULL,
    TenQuyen      NVARCHAR(100) NOT NULL,
    CongTruyCap   VARCHAR(10)   NOT NULL,
    MoTa          NVARCHAR(200) NULL,
    CONSTRAINT PK_QUYEN PRIMARY KEY (MaQuyen),
    CONSTRAINT UQ_QUYEN_Ma_Cong UNIQUE (MaQuyen, CongTruyCap),
    CONSTRAINT CK_QUYEN_Cong CHECK (CongTruyCap IN ('ADMIN', 'QUAN_LY', 'KHACH_HANG'))
);
GO

/* VAI_TRO_QUYEN: N-N giữa vai trò và quyền. Khóa ngoại kép kèm CongTruyCap
   bảo đảm vai trò và quyền cùng một cổng. */
IF OBJECT_ID(N'crm.VAI_TRO_QUYEN', N'U') IS NULL
CREATE TABLE crm.VAI_TRO_QUYEN (
    MaVT          VARCHAR(20)   NOT NULL,
    MaQuyen       VARCHAR(30)   NOT NULL,
    CongTruyCap   VARCHAR(10)   NOT NULL,
    CONSTRAINT PK_VAI_TRO_QUYEN PRIMARY KEY (MaVT, MaQuyen),
    CONSTRAINT FK_VTQ_VAI_TRO FOREIGN KEY (MaVT, CongTruyCap)
        REFERENCES crm.VAI_TRO (MaVT, CongTruyCap) ON DELETE CASCADE,
    CONSTRAINT FK_VTQ_QUYEN FOREIGN KEY (MaQuyen, CongTruyCap)
        REFERENCES crm.QUYEN (MaQuyen, CongTruyCap) ON DELETE CASCADE
);
GO

/* TAI_KHOAN: thông tin đăng nhập, tách khỏi hồ sơ con người.
   - MatKhauHash: chuỗi băm do ứng dụng sinh (bcrypt/PBKDF2/Argon2, có salt).
     CSDL không bao giờ nhận mật khẩu thô. CHECK độ dài >= 50 ngăn việc
     vô tình lưu mật khẩu dạng văn bản thuần.
   - (MaVT, LoaiTK) -> VAI_TRO: tài khoản KH chỉ mang được vai trò loại KH. */
IF OBJECT_ID(N'crm.TAI_KHOAN', N'U') IS NULL
CREATE TABLE crm.TAI_KHOAN (
    MaTK            INT IDENTITY(1, 1) NOT NULL,
    TenDangNhap     VARCHAR(50)   NOT NULL,
    MatKhauHash     VARCHAR(255)  NOT NULL,
    MaVT            VARCHAR(20)   NOT NULL,
    LoaiTK          CHAR(2)       NOT NULL,
    TrangThai       VARCHAR(10)   NOT NULL CONSTRAINT DF_TAI_KHOAN_TrangThai DEFAULT ('HOAT_DONG'),
    PhaiDoiMatKhau  BIT           NOT NULL CONSTRAINT DF_TAI_KHOAN_PhaiDoiMK DEFAULT (0),
    NgayTao         DATETIME2(0)  NOT NULL CONSTRAINT DF_TAI_KHOAN_NgayTao DEFAULT (SYSDATETIME()),
    LanDangNhapCuoi DATETIME2(0)  NULL,
    NgayKhoa        DATETIME2(0)  NULL,
    LyDoKhoa        NVARCHAR(200) NULL,
    CONSTRAINT PK_TAI_KHOAN PRIMARY KEY (MaTK),
    CONSTRAINT UQ_TAI_KHOAN_TenDangNhap UNIQUE (TenDangNhap),
    CONSTRAINT UQ_TAI_KHOAN_MaTK_LoaiTK UNIQUE (MaTK, LoaiTK),
    CONSTRAINT FK_TAI_KHOAN_VAI_TRO FOREIGN KEY (MaVT, LoaiTK)
        REFERENCES crm.VAI_TRO (MaVT, LoaiTK),
    CONSTRAINT CK_TAI_KHOAN_TenDangNhap CHECK (LEN(TenDangNhap) >= 4 AND TenDangNhap NOT LIKE '% %'),
    CONSTRAINT CK_TAI_KHOAN_Hash CHECK (LEN(MatKhauHash) >= 50),
    CONSTRAINT CK_TAI_KHOAN_TrangThai CHECK (TrangThai IN ('HOAT_DONG', 'DA_KHOA')),
    CONSTRAINT CK_TAI_KHOAN_Khoa CHECK (
        (TrangThai = 'HOAT_DONG' AND NgayKhoa IS NULL AND LyDoKhoa IS NULL)
     OR (TrangThai = 'DA_KHOA'   AND NgayKhoa IS NOT NULL))
);
GO

/* ==================== B. TỔ CHỨC ==================== */

IF OBJECT_ID(N'crm.CHUC_VU', N'U') IS NULL
CREATE TABLE crm.CHUC_VU (
    MaCV   VARCHAR(20)   NOT NULL,
    TenCV  NVARCHAR(50)  NOT NULL,
    MoTa   NVARCHAR(200) NULL,
    CONSTRAINT PK_CHUC_VU PRIMARY KEY (MaCV),
    CONSTRAINT UQ_CHUC_VU_TenCV UNIQUE (TenCV)
);
GO

IF OBJECT_ID(N'crm.TINH_THANH', N'U') IS NULL
CREATE TABLE crm.TINH_THANH (
    MaTinh  VARCHAR(10)  NOT NULL,
    TenTinh NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_TINH_THANH PRIMARY KEY (MaTinh),
    CONSTRAINT UQ_TINH_THANH_TenTinh UNIQUE (TenTinh)
);
GO

IF OBJECT_ID(N'crm.CUA_HANG', N'U') IS NULL
CREATE TABLE crm.CUA_HANG (
    MaCH      INT IDENTITY(1, 1) NOT NULL,
    TenCH     NVARCHAR(100) NOT NULL,
    DiaChi    NVARCHAR(200) NOT NULL,
    MaTinh    VARCHAR(10)   NOT NULL,
    SDT       VARCHAR(15)   NULL,
    TrangThai VARCHAR(10)   NOT NULL CONSTRAINT DF_CUA_HANG_TrangThai DEFAULT ('HOAT_DONG'),
    CONSTRAINT PK_CUA_HANG PRIMARY KEY (MaCH),
    CONSTRAINT UQ_CUA_HANG_TenCH UNIQUE (TenCH),
    CONSTRAINT FK_CUA_HANG_TINH FOREIGN KEY (MaTinh) REFERENCES crm.TINH_THANH (MaTinh),
    CONSTRAINT CK_CUA_HANG_SDT CHECK (SDT IS NULL OR SDT NOT LIKE '%[^0-9]%'),
    CONSTRAINT CK_CUA_HANG_TrangThai CHECK (TrangThai IN ('HOAT_DONG', 'DA_DONG'))
);
GO

/* NHAN_VIEN: hồ sơ nhân sự. Giám đốc/quản lý là nhân viên có chức vụ
   tương ứng (không tạo bảng riêng). MaTK NULL = nhân viên không dùng hệ
   thống (vd. thu ngân chỉ xuất hiện trên hóa đơn nhập từ POS).
   (MaTK, LoaiTK='NV') -> TAI_KHOAN: chỉ gắn được tài khoản loại NV. */
IF OBJECT_ID(N'crm.NHAN_VIEN', N'U') IS NULL
CREATE TABLE crm.NHAN_VIEN (
    MaNV       INT IDENTITY(1, 1) NOT NULL,
    HoTen      NVARCHAR(100) NOT NULL,
    MaCV       VARCHAR(20)   NOT NULL,
    MaCH       INT           NULL,
    SDT        VARCHAR(10)   NOT NULL,
    Email      VARCHAR(100)  NOT NULL,
    NgayVaoLam DATE          NOT NULL,
    TrangThai  VARCHAR(10)   NOT NULL CONSTRAINT DF_NHAN_VIEN_TrangThai DEFAULT ('DANG_LAM'),
    MaTK       INT           NULL,
    LoaiTK     CHAR(2)       NOT NULL CONSTRAINT DF_NHAN_VIEN_LoaiTK DEFAULT ('NV'),
    CONSTRAINT PK_NHAN_VIEN PRIMARY KEY (MaNV),
    CONSTRAINT UQ_NHAN_VIEN_SDT UNIQUE (SDT),
    CONSTRAINT UQ_NHAN_VIEN_Email UNIQUE (Email),
    CONSTRAINT FK_NHAN_VIEN_CHUC_VU FOREIGN KEY (MaCV) REFERENCES crm.CHUC_VU (MaCV),
    CONSTRAINT FK_NHAN_VIEN_CUA_HANG FOREIGN KEY (MaCH) REFERENCES crm.CUA_HANG (MaCH),
    CONSTRAINT FK_NHAN_VIEN_TAI_KHOAN FOREIGN KEY (MaTK, LoaiTK) REFERENCES crm.TAI_KHOAN (MaTK, LoaiTK),
    CONSTRAINT CK_NHAN_VIEN_LoaiTK CHECK (LoaiTK = 'NV'),
    CONSTRAINT CK_NHAN_VIEN_SDT CHECK (SDT LIKE '0[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
    CONSTRAINT CK_NHAN_VIEN_Email CHECK (Email LIKE '_%@_%._%' AND Email NOT LIKE '% %'),
    CONSTRAINT CK_NHAN_VIEN_TrangThai CHECK (TrangThai IN ('DANG_LAM', 'DA_NGHI'))
);
GO
-- Một tài khoản gắn tối đa một nhân viên (cho phép nhiều NULL)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_NHAN_VIEN_MaTK')
    CREATE UNIQUE INDEX UX_NHAN_VIEN_MaTK ON crm.NHAN_VIEN (MaTK) WHERE MaTK IS NOT NULL;
GO

/* ==================== C. DANH MỤC SẢN PHẨM ==================== */

IF OBJECT_ID(N'crm.NHA_CUNG_CAP', N'U') IS NULL
CREATE TABLE crm.NHA_CUNG_CAP (
    MaNCC     INT IDENTITY(1, 1) NOT NULL,
    TenNCC    NVARCHAR(150) NOT NULL,
    QuocGia   NVARCHAR(50)  NULL,
    DiaChi    NVARCHAR(200) NULL,
    SDT       VARCHAR(20)   NULL,
    Email     VARCHAR(100)  NULL,
    TrangThai VARCHAR(13)   NOT NULL CONSTRAINT DF_NCC_TrangThai DEFAULT ('DANG_HOP_TAC'),
    CONSTRAINT PK_NHA_CUNG_CAP PRIMARY KEY (MaNCC),
    CONSTRAINT UQ_NHA_CUNG_CAP_TenNCC UNIQUE (TenNCC),
    CONSTRAINT CK_NCC_SDT CHECK (SDT IS NULL OR SDT NOT LIKE '%[^0-9+ ]%'),
    CONSTRAINT CK_NCC_Email CHECK (Email IS NULL OR (Email LIKE '_%@_%._%' AND Email NOT LIKE '% %')),
    CONSTRAINT CK_NCC_TrangThai CHECK (TrangThai IN ('DANG_HOP_TAC', 'NGUNG_HOP_TAC'))
);
GO

IF OBJECT_ID(N'crm.LOAI_SP', N'U') IS NULL
CREATE TABLE crm.LOAI_SP (
    MaLoai  INT IDENTITY(1, 1) NOT NULL,
    TenLoai NVARCHAR(50)  NOT NULL,
    MoTa    NVARCHAR(200) NULL,
    CONSTRAINT PK_LOAI_SP PRIMARY KEY (MaLoai),
    CONSTRAINT UQ_LOAI_SP_TenLoai UNIQUE (TenLoai)
);
GO

/* SAN_PHAM: danh mục để tra cứu, gắn phản hồi, khảo sát, hóa đơn.
   Không có tồn kho/giỏ hàng (ngoài phạm vi CRM). */
IF OBJECT_ID(N'crm.SAN_PHAM', N'U') IS NULL
CREATE TABLE crm.SAN_PHAM (
    MaSP       INT IDENTITY(1, 1) NOT NULL,
    MaSKU      VARCHAR(20)    NOT NULL,
    TenSP      NVARCHAR(150)  NOT NULL,
    MaLoai     INT            NOT NULL,
    MaNCC      INT            NOT NULL,
    ChatLieu   NVARCHAR(100)  NULL,
    MoTa       NVARCHAR(1000) NULL,
    GiaNiemYet DECIMAL(14, 2) NOT NULL,
    TrangThai  VARCHAR(12)    NOT NULL CONSTRAINT DF_SAN_PHAM_TrangThai DEFAULT ('DANG_BAN'),
    NgayRaMat  DATE           NULL,
    CONSTRAINT PK_SAN_PHAM PRIMARY KEY (MaSP),
    CONSTRAINT UQ_SAN_PHAM_MaSKU UNIQUE (MaSKU),
    CONSTRAINT FK_SAN_PHAM_LOAI FOREIGN KEY (MaLoai) REFERENCES crm.LOAI_SP (MaLoai),
    CONSTRAINT FK_SAN_PHAM_NCC FOREIGN KEY (MaNCC) REFERENCES crm.NHA_CUNG_CAP (MaNCC),
    CONSTRAINT CK_SAN_PHAM_Gia CHECK (GiaNiemYet >= 0),
    CONSTRAINT CK_SAN_PHAM_TrangThai CHECK (TrangThai IN ('DANG_BAN', 'SAP_RA_MAT', 'NGUNG_BAN')),
    CONSTRAINT CK_SAN_PHAM_SapRaMat CHECK (TrangThai <> 'SAP_RA_MAT' OR NgayRaMat IS NOT NULL)
);
GO

/* ==================== D. KHÁCH HÀNG ==================== */

/* HANG_THANH_VIEN: hạng do điều kiện nghiệp vụ quyết định (điểm tích lũy).
   Mặc định 2 hạng THUONG (0 điểm) và VIP. Có thể thêm hạng mà không đổi cấu trúc. */
IF OBJECT_ID(N'crm.HANG_THANH_VIEN', N'U') IS NULL
CREATE TABLE crm.HANG_THANH_VIEN (
    MaHang       VARCHAR(10)   NOT NULL,
    TenHang      NVARCHAR(30)  NOT NULL,
    DiemToiThieu INT           NOT NULL,
    MoTa         NVARCHAR(200) NULL,
    CONSTRAINT PK_HANG_THANH_VIEN PRIMARY KEY (MaHang),
    CONSTRAINT UQ_HANG_TenHang UNIQUE (TenHang),
    CONSTRAINT UQ_HANG_DiemToiThieu UNIQUE (DiemToiThieu),
    CONSTRAINT CK_HANG_Diem CHECK (DiemToiThieu >= 0)
);
GO

/* KHACH_HANG: hồ sơ khách hàng (một bảng duy nhất cho cả thường và VIP).
   - MaTK NULL: khách do Quản lý tạo nhưng chưa có tài khoản đăng nhập.
   - (MaTK, LoaiTK='KH') -> TAI_KHOAN: chỉ gắn được tài khoản loại KH.
   - Không lưu tuổi (tính từ NgaySinh), không lưu điểm (tính từ hóa đơn).
   - Xóa = xóa mềm (TrangThaiHoSo='DA_XOA') để giữ lịch sử. */
IF OBJECT_ID(N'crm.KHACH_HANG', N'U') IS NULL
CREATE TABLE crm.KHACH_HANG (
    MaKH          INT IDENTITY(1, 1) NOT NULL,
    HoTen         NVARCHAR(100) NOT NULL,
    GioiTinh      VARCHAR(4)    NULL,
    NgaySinh      DATE          NULL,
    SDT           VARCHAR(10)   NOT NULL,
    Email         VARCHAR(100)  NULL,
    MaTinh        VARCHAR(10)   NULL,
    NgayDangKy    DATETIME2(0)  NOT NULL CONSTRAINT DF_KHACH_HANG_NgayDangKy DEFAULT (SYSDATETIME()),
    MaHang        VARCHAR(10)   NOT NULL CONSTRAINT DF_KHACH_HANG_MaHang DEFAULT ('THUONG'),
    NgayXetHang   DATETIME2(0)  NULL,
    TrangThaiHoSo VARCHAR(10)   NOT NULL CONSTRAINT DF_KHACH_HANG_TrangThai DEFAULT ('HOAT_DONG'),
    NgayXoa       DATETIME2(0)  NULL,
    MaTK          INT           NULL,
    LoaiTK        CHAR(2)       NOT NULL CONSTRAINT DF_KHACH_HANG_LoaiTK DEFAULT ('KH'),
    CONSTRAINT PK_KHACH_HANG PRIMARY KEY (MaKH),
    CONSTRAINT FK_KHACH_HANG_TINH FOREIGN KEY (MaTinh) REFERENCES crm.TINH_THANH (MaTinh),
    CONSTRAINT FK_KHACH_HANG_HANG FOREIGN KEY (MaHang) REFERENCES crm.HANG_THANH_VIEN (MaHang),
    CONSTRAINT FK_KHACH_HANG_TAI_KHOAN FOREIGN KEY (MaTK, LoaiTK) REFERENCES crm.TAI_KHOAN (MaTK, LoaiTK),
    CONSTRAINT CK_KHACH_HANG_LoaiTK CHECK (LoaiTK = 'KH'),
    CONSTRAINT CK_KHACH_HANG_HoTen CHECK (LEN(HoTen) > 0),
    CONSTRAINT CK_KHACH_HANG_GioiTinh CHECK (GioiTinh IN ('NAM', 'NU', 'KHAC')),
    CONSTRAINT CK_KHACH_HANG_NgaySinh CHECK (NgaySinh >= '19000101' AND NgaySinh <= CAST(NgayDangKy AS DATE)),
    CONSTRAINT CK_KHACH_HANG_SDT CHECK (SDT LIKE '0[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
    CONSTRAINT CK_KHACH_HANG_Email CHECK (Email LIKE '_%@_%._%' AND Email NOT LIKE '% %'),
    CONSTRAINT CK_KHACH_HANG_TrangThai CHECK (
        (TrangThaiHoSo = 'HOAT_DONG' AND NgayXoa IS NULL)
     OR (TrangThaiHoSo = 'DA_XOA'    AND NgayXoa IS NOT NULL))
);
GO
-- 1 tài khoản <-> tối đa 1 hồ sơ khách hàng
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_KHACH_HANG_MaTK')
    CREATE UNIQUE INDEX UX_KHACH_HANG_MaTK ON crm.KHACH_HANG (MaTK) WHERE MaTK IS NOT NULL;
-- SĐT/Email duy nhất trong các hồ sơ còn hoạt động (hồ sơ đã xóa mềm không chặn đăng ký lại)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_KHACH_HANG_SDT')
    CREATE UNIQUE INDEX UX_KHACH_HANG_SDT ON crm.KHACH_HANG (SDT) WHERE TrangThaiHoSo = 'HOAT_DONG';
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_KHACH_HANG_Email')
    CREATE UNIQUE INDEX UX_KHACH_HANG_Email ON crm.KHACH_HANG (Email)
        WHERE Email IS NOT NULL AND TrangThaiHoSo = 'HOAT_DONG';
GO

/* KH_QUAN_TAM: sở thích = loại sản phẩm khách quan tâm (N-N). */
IF OBJECT_ID(N'crm.KH_QUAN_TAM', N'U') IS NULL
CREATE TABLE crm.KH_QUAN_TAM (
    MaKH   INT NOT NULL,
    MaLoai INT NOT NULL,
    CONSTRAINT PK_KH_QUAN_TAM PRIMARY KEY (MaKH, MaLoai),
    CONSTRAINT FK_KHQT_KHACH_HANG FOREIGN KEY (MaKH) REFERENCES crm.KHACH_HANG (MaKH),
    CONSTRAINT FK_KHQT_LOAI_SP FOREIGN KEY (MaLoai) REFERENCES crm.LOAI_SP (MaLoai)
);
GO

/* LICH_SU_HANG: vết thay đổi hạng (thường <-> VIP). MaNV_ThucHien NULL =
   hệ thống tự xét. Lịch sử tham chiếu NHÂN VIÊN, không tham chiếu tài khoản,
   nên xóa tài khoản không làm mất vết. */
IF OBJECT_ID(N'crm.LICH_SU_HANG', N'U') IS NULL
CREATE TABLE crm.LICH_SU_HANG (
    MaLS            INT IDENTITY(1, 1) NOT NULL,
    MaKH            INT           NOT NULL,
    MaHangCu        VARCHAR(10)   NULL,
    MaHangMoi       VARCHAR(10)   NOT NULL,
    DiemTaiThoiDiem INT           NOT NULL,
    ThoiGian        DATETIME2(0)  NOT NULL CONSTRAINT DF_LSH_ThoiGian DEFAULT (SYSDATETIME()),
    LyDo            NVARCHAR(200) NOT NULL,
    MaNV_ThucHien   INT           NULL,
    CONSTRAINT PK_LICH_SU_HANG PRIMARY KEY (MaLS),
    CONSTRAINT FK_LSH_KHACH_HANG FOREIGN KEY (MaKH) REFERENCES crm.KHACH_HANG (MaKH),
    CONSTRAINT FK_LSH_HANG_CU FOREIGN KEY (MaHangCu) REFERENCES crm.HANG_THANH_VIEN (MaHang),
    CONSTRAINT FK_LSH_HANG_MOI FOREIGN KEY (MaHangMoi) REFERENCES crm.HANG_THANH_VIEN (MaHang),
    CONSTRAINT FK_LSH_NHAN_VIEN FOREIGN KEY (MaNV_ThucHien) REFERENCES crm.NHAN_VIEN (MaNV),
    CONSTRAINT CK_LSH_KhacHang CHECK (MaHangCu IS NULL OR MaHangCu <> MaHangMoi),
    CONSTRAINT CK_LSH_Diem CHECK (DiemTaiThoiDiem >= 0)
);
GO

/* ==================== E. KHẢO SÁT ==================== */

IF OBJECT_ID(N'crm.KHAO_SAT', N'U') IS NULL
CREATE TABLE crm.KHAO_SAT (
    MaKS                 INT IDENTITY(1, 1) NOT NULL,
    TieuDe               NVARCHAR(200)  NOT NULL,
    MoTa                 NVARCHAR(1000) NULL,
    MucDich              VARCHAR(15)    NOT NULL,
    MaSP                 INT            NULL,
    MaNV_Tao             INT            NOT NULL,
    NgayTao              DATETIME2(0)   NOT NULL CONSTRAINT DF_KHAO_SAT_NgayTao DEFAULT (SYSDATETIME()),
    NgayPhatHanh         DATETIME2(0)   NULL,
    HanTraLoi            DATETIME2(0)   NULL,
    PhanTramVoucher      TINYINT        NOT NULL CONSTRAINT DF_KHAO_SAT_PTVoucher DEFAULT (0),
    SoNgayHieuLucVoucher SMALLINT       NOT NULL CONSTRAINT DF_KHAO_SAT_NgayHL DEFAULT (30),
    TrangThai            VARCHAR(8)     NOT NULL CONSTRAINT DF_KHAO_SAT_TrangThai DEFAULT ('NHAP'),
    CONSTRAINT PK_KHAO_SAT PRIMARY KEY (MaKS),
    CONSTRAINT FK_KHAO_SAT_SAN_PHAM FOREIGN KEY (MaSP) REFERENCES crm.SAN_PHAM (MaSP),
    CONSTRAINT FK_KHAO_SAT_NHAN_VIEN FOREIGN KEY (MaNV_Tao) REFERENCES crm.NHAN_VIEN (MaNV),
    CONSTRAINT CK_KHAO_SAT_MucDich CHECK (MucDich IN ('DO_HAI_LONG', 'THAM_DO_SP_MOI')),
    CONSTRAINT CK_KHAO_SAT_ThamDo CHECK (MucDich <> 'THAM_DO_SP_MOI' OR MaSP IS NOT NULL),
    CONSTRAINT CK_KHAO_SAT_TrangThai CHECK (TrangThai IN ('NHAP', 'DA_GUI', 'DA_DONG')),
    CONSTRAINT CK_KHAO_SAT_PhatHanh CHECK (
        (TrangThai = 'NHAP' AND NgayPhatHanh IS NULL)
     OR (TrangThai IN ('DA_GUI', 'DA_DONG') AND NgayPhatHanh IS NOT NULL AND HanTraLoi IS NOT NULL)),
    CONSTRAINT CK_KHAO_SAT_Han CHECK (HanTraLoi IS NULL OR HanTraLoi > NgayTao),
    CONSTRAINT CK_KHAO_SAT_Voucher CHECK (PhanTramVoucher BETWEEN 0 AND 50),
    CONSTRAINT CK_KHAO_SAT_NgayHL CHECK (SoNgayHieuLucVoucher BETWEEN 1 AND 365)
);
GO

/* CAU_HOI: UNIQUE (MaCauHoi, MaKS, LoaiCauHoi) là khóa đích cho TRA_LOI,
   bảo đảm câu trả lời thuộc đúng khảo sát và đúng loại câu hỏi. */
IF OBJECT_ID(N'crm.CAU_HOI', N'U') IS NULL
CREATE TABLE crm.CAU_HOI (
    MaCauHoi   INT IDENTITY(1, 1) NOT NULL,
    MaKS       INT           NOT NULL,
    ThuTu      SMALLINT      NOT NULL,
    NoiDung    NVARCHAR(500) NOT NULL,
    LoaiCauHoi VARCHAR(15)   NOT NULL,
    BatBuoc    BIT           NOT NULL CONSTRAINT DF_CAU_HOI_BatBuoc DEFAULT (1),
    CONSTRAINT PK_CAU_HOI PRIMARY KEY (MaCauHoi),
    CONSTRAINT UQ_CAU_HOI_ThuTu UNIQUE (MaKS, ThuTu),
    CONSTRAINT UQ_CAU_HOI_KhoaDich UNIQUE (MaCauHoi, MaKS, LoaiCauHoi),
    CONSTRAINT FK_CAU_HOI_KHAO_SAT FOREIGN KEY (MaKS) REFERENCES crm.KHAO_SAT (MaKS) ON DELETE CASCADE,
    CONSTRAINT CK_CAU_HOI_Loai CHECK (LoaiCauHoi IN ('MOT_LUA_CHON', 'NHIEU_LUA_CHON', 'THANG_DIEM', 'TU_LUAN')),
    CONSTRAINT CK_CAU_HOI_ThuTu CHECK (ThuTu > 0)
);
GO

IF OBJECT_ID(N'crm.LUA_CHON', N'U') IS NULL
CREATE TABLE crm.LUA_CHON (
    MaLC     INT IDENTITY(1, 1) NOT NULL,
    MaCauHoi INT           NOT NULL,
    ThuTu    SMALLINT      NOT NULL,
    NoiDung  NVARCHAR(200) NOT NULL,
    CONSTRAINT PK_LUA_CHON PRIMARY KEY (MaLC),
    CONSTRAINT UQ_LUA_CHON_ThuTu UNIQUE (MaCauHoi, ThuTu),
    CONSTRAINT UQ_LUA_CHON_KhoaDich UNIQUE (MaLC, MaCauHoi),
    CONSTRAINT FK_LUA_CHON_CAU_HOI FOREIGN KEY (MaCauHoi) REFERENCES crm.CAU_HOI (MaCauHoi) ON DELETE CASCADE,
    CONSTRAINT CK_LUA_CHON_ThuTu CHECK (ThuTu > 0)
);
GO

/* KHAO_SAT_GUI: khảo sát đã gửi tới tài khoản khách hàng nào.
   TrangThai là cột tính toán (suy ra từ NgayHoanThanh), không lưu trùng. */
IF OBJECT_ID(N'crm.KHAO_SAT_GUI', N'U') IS NULL
CREATE TABLE crm.KHAO_SAT_GUI (
    MaKS          INT          NOT NULL,
    MaKH          INT          NOT NULL,
    NgayGui       DATETIME2(0) NOT NULL CONSTRAINT DF_KSG_NgayGui DEFAULT (SYSDATETIME()),
    NgayHoanThanh DATETIME2(0) NULL,
    TrangThai AS (CAST(CASE WHEN NgayHoanThanh IS NULL THEN 'CHUA_LAM' ELSE 'DA_HOAN_THANH' END AS VARCHAR(13))),
    CONSTRAINT PK_KHAO_SAT_GUI PRIMARY KEY (MaKS, MaKH),
    CONSTRAINT FK_KSG_KHAO_SAT FOREIGN KEY (MaKS) REFERENCES crm.KHAO_SAT (MaKS),
    CONSTRAINT FK_KSG_KHACH_HANG FOREIGN KEY (MaKH) REFERENCES crm.KHACH_HANG (MaKH),
    CONSTRAINT CK_KSG_HoanThanh CHECK (NgayHoanThanh IS NULL OR NgayHoanThanh >= NgayGui)
);
GO

/* TRA_LOI: một dòng cho mỗi (khảo sát, khách, câu hỏi).
   - (MaKS, MaKH) -> KHAO_SAT_GUI : chỉ trả lời khảo sát đã được gửi cho mình.
   - (MaCauHoi, MaKS, LoaiCauHoi) -> CAU_HOI : câu hỏi thuộc đúng khảo sát; cột
     LoaiCauHoi được sao chép có kiểm soát (FK chặn sai lệch) để CHECK được
     dạng câu trả lời theo loại câu hỏi. */
IF OBJECT_ID(N'crm.TRA_LOI', N'U') IS NULL
CREATE TABLE crm.TRA_LOI (
    MaKS          INT            NOT NULL,
    MaKH          INT            NOT NULL,
    MaCauHoi      INT            NOT NULL,
    LoaiCauHoi    VARCHAR(15)    NOT NULL,
    DiemSo        TINYINT        NULL,
    NoiDungTuLuan NVARCHAR(2000) NULL,
    CONSTRAINT PK_TRA_LOI PRIMARY KEY (MaKS, MaKH, MaCauHoi),
    CONSTRAINT FK_TRA_LOI_KSG FOREIGN KEY (MaKS, MaKH) REFERENCES crm.KHAO_SAT_GUI (MaKS, MaKH),
    CONSTRAINT FK_TRA_LOI_CAU_HOI FOREIGN KEY (MaCauHoi, MaKS, LoaiCauHoi)
        REFERENCES crm.CAU_HOI (MaCauHoi, MaKS, LoaiCauHoi),
    CONSTRAINT CK_TRA_LOI_DangTraLoi CHECK (
        (LoaiCauHoi = 'THANG_DIEM' AND DiemSo BETWEEN 1 AND 5 AND NoiDungTuLuan IS NULL)
     OR (LoaiCauHoi = 'TU_LUAN'    AND DiemSo IS NULL AND NoiDungTuLuan IS NOT NULL)
     OR (LoaiCauHoi IN ('MOT_LUA_CHON', 'NHIEU_LUA_CHON') AND DiemSo IS NULL AND NoiDungTuLuan IS NULL))
);
GO

/* TRA_LOI_LUA_CHON: lựa chọn được chọn (tách riêng vì câu nhiều lựa chọn là
   thuộc tính đa trị). (MaLC, MaCauHoi) -> LUA_CHON: lựa chọn thuộc đúng câu hỏi. */
IF OBJECT_ID(N'crm.TRA_LOI_LUA_CHON', N'U') IS NULL
CREATE TABLE crm.TRA_LOI_LUA_CHON (
    MaKS     INT NOT NULL,
    MaKH     INT NOT NULL,
    MaCauHoi INT NOT NULL,
    MaLC     INT NOT NULL,
    CONSTRAINT PK_TRA_LOI_LUA_CHON PRIMARY KEY (MaKS, MaKH, MaCauHoi, MaLC),
    CONSTRAINT FK_TLLC_TRA_LOI FOREIGN KEY (MaKS, MaKH, MaCauHoi) REFERENCES crm.TRA_LOI (MaKS, MaKH, MaCauHoi),
    CONSTRAINT FK_TLLC_LUA_CHON FOREIGN KEY (MaLC, MaCauHoi) REFERENCES crm.LUA_CHON (MaLC, MaCauHoi)
);
GO

/* ==================== F. VOUCHER ==================== */
/* Voucher là quà tặng khi hoàn thành khảo sát. Trạng thái "đã dùng" suy ra
   từ HOA_DON.MaVoucher, "hết hạn" suy ra từ HanDung => không lưu cột trạng thái. */
IF OBJECT_ID(N'crm.VOUCHER', N'U') IS NULL
CREATE TABLE crm.VOUCHER (
    MaVoucher    INT IDENTITY(1, 1) NOT NULL,
    MaCode       VARCHAR(20)  NOT NULL,
    MaKH         INT          NOT NULL,
    MaKS         INT          NOT NULL,
    PhanTramGiam TINYINT      NOT NULL,
    NgayPhat     DATETIME2(0) NOT NULL CONSTRAINT DF_VOUCHER_NgayPhat DEFAULT (SYSDATETIME()),
    HanDung      DATETIME2(0) NOT NULL,
    CONSTRAINT PK_VOUCHER PRIMARY KEY (MaVoucher),
    CONSTRAINT UQ_VOUCHER_MaCode UNIQUE (MaCode),
    CONSTRAINT UQ_VOUCHER_KS_KH UNIQUE (MaKS, MaKH),           -- 1 voucher / khảo sát / khách
    CONSTRAINT UQ_VOUCHER_KhoaDich UNIQUE (MaVoucher, MaKH),
    CONSTRAINT FK_VOUCHER_KSG FOREIGN KEY (MaKS, MaKH) REFERENCES crm.KHAO_SAT_GUI (MaKS, MaKH),
    CONSTRAINT CK_VOUCHER_PhanTram CHECK (PhanTramGiam BETWEEN 1 AND 50),
    CONSTRAINT CK_VOUCHER_Han CHECK (HanDung > NgayPhat)
);
GO

/* ==================== G. GIAO DỊCH (dữ liệu nguồn từ POS, Admin nạp) ==================== */

/* HOA_DON: không lưu TongTien (suy ra từ chi tiết).
   (MaVoucher, MaKH) -> VOUCHER: chỉ dùng voucher của chính khách đó. */
IF OBJECT_ID(N'crm.HOA_DON', N'U') IS NULL
CREATE TABLE crm.HOA_DON (
    MaHD      INT IDENTITY(1, 1) NOT NULL,
    SoHoaDon  VARCHAR(20)  NOT NULL,
    MaKH      INT          NOT NULL,
    KenhBan   VARCHAR(8)   NOT NULL,
    MaCH      INT          NULL,
    MaNV      INT          NULL,
    NgayLap   DATETIME2(0) NOT NULL,
    MaVoucher INT          NULL,
    NgayNhap  DATETIME2(0) NOT NULL CONSTRAINT DF_HOA_DON_NgayNhap DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_HOA_DON PRIMARY KEY (MaHD),
    CONSTRAINT UQ_HOA_DON_SoHoaDon UNIQUE (SoHoaDon),
    CONSTRAINT FK_HOA_DON_KHACH_HANG FOREIGN KEY (MaKH) REFERENCES crm.KHACH_HANG (MaKH),
    CONSTRAINT FK_HOA_DON_CUA_HANG FOREIGN KEY (MaCH) REFERENCES crm.CUA_HANG (MaCH),
    CONSTRAINT FK_HOA_DON_NHAN_VIEN FOREIGN KEY (MaNV) REFERENCES crm.NHAN_VIEN (MaNV),
    CONSTRAINT FK_HOA_DON_VOUCHER FOREIGN KEY (MaVoucher, MaKH) REFERENCES crm.VOUCHER (MaVoucher, MaKH),
    CONSTRAINT CK_HOA_DON_KenhBan CHECK (
        (KenhBan = 'CUA_HANG' AND MaCH IS NOT NULL AND MaNV IS NOT NULL)
     OR (KenhBan = 'ONLINE'   AND MaCH IS NULL     AND MaNV IS NULL))
);
GO
-- Mỗi voucher dùng tối đa 1 lần
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_HOA_DON_MaVoucher')
    CREATE UNIQUE INDEX UX_HOA_DON_MaVoucher ON crm.HOA_DON (MaVoucher) WHERE MaVoucher IS NOT NULL;
GO

IF OBJECT_ID(N'crm.CHI_TIET_HOA_DON', N'U') IS NULL
CREATE TABLE crm.CHI_TIET_HOA_DON (
    MaHD      INT            NOT NULL,
    MaSP      INT            NOT NULL,
    SoLuong   INT            NOT NULL,
    DonGiaBan DECIMAL(14, 2) NOT NULL,   -- giá tại thời điểm bán (không suy ra được)
    CONSTRAINT PK_CHI_TIET_HOA_DON PRIMARY KEY (MaHD, MaSP),
    CONSTRAINT FK_CTHD_HOA_DON FOREIGN KEY (MaHD) REFERENCES crm.HOA_DON (MaHD),
    CONSTRAINT FK_CTHD_SAN_PHAM FOREIGN KEY (MaSP) REFERENCES crm.SAN_PHAM (MaSP),
    CONSTRAINT CK_CTHD_SoLuong CHECK (SoLuong > 0),
    CONSTRAINT CK_CTHD_DonGia CHECK (DonGiaBan >= 0)
);
GO

IF OBJECT_ID(N'crm.DOI_TRA', N'U') IS NULL
CREATE TABLE crm.DOI_TRA (
    MaDT       INT IDENTITY(1, 1) NOT NULL,
    MaHD       INT           NOT NULL,
    MaSP       INT           NOT NULL,
    SoLuong    INT           NOT NULL,
    LyDo       VARCHAR(10)   NOT NULL,
    GhiChu     NVARCHAR(300) NULL,
    NgayDoiTra DATETIME2(0)  NOT NULL,
    CONSTRAINT PK_DOI_TRA PRIMARY KEY (MaDT),
    CONSTRAINT FK_DOI_TRA_CTHD FOREIGN KEY (MaHD, MaSP) REFERENCES crm.CHI_TIET_HOA_DON (MaHD, MaSP),
    CONSTRAINT CK_DOI_TRA_SoLuong CHECK (SoLuong > 0),
    CONSTRAINT CK_DOI_TRA_LyDo CHECK (LyDo IN ('LOI_SP', 'KHONG_VUA', 'KHONG_UNG', 'KHAC'))
);
GO

/* Trigger: tổng số lượng đổi trả của 1 dòng hóa đơn không vượt số lượng mua,
   và ngày đổi trả không trước ngày lập hóa đơn (ràng buộc liên bảng). */
CREATE OR ALTER TRIGGER crm.TR_DOI_TRA_KiemTra
ON crm.DOI_TRA
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM (SELECT DISTINCT MaHD, MaSP FROM inserted) i
        JOIN crm.CHI_TIET_HOA_DON ct ON ct.MaHD = i.MaHD AND ct.MaSP = i.MaSP
        CROSS APPLY (SELECT SUM(d.SoLuong) AS TongTra
                     FROM crm.DOI_TRA d
                     WHERE d.MaHD = i.MaHD AND d.MaSP = i.MaSP) t
        WHERE t.TongTra > ct.SoLuong)
        THROW 51001, N'Tổng số lượng đổi trả vượt quá số lượng đã mua.', 1;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN crm.HOA_DON h ON h.MaHD = i.MaHD
        WHERE i.NgayDoiTra < h.NgayLap)
        THROW 51002, N'Ngày đổi trả không được trước ngày lập hóa đơn.', 1;
END;
GO

/* ==================== H. PHẢN HỒI ==================== */
/* Một phản hồi có tối đa một lần trả lời; CHECK ràng buộc dữ liệu theo trạng thái:
   MOI -> DANG_XU_LY (đã tiếp nhận, có người xử lý) -> DA_XU_LY (bắt buộc có trả lời). */
IF OBJECT_ID(N'crm.PHAN_HOI', N'U') IS NULL
CREATE TABLE crm.PHAN_HOI (
    MaPH          INT IDENTITY(1, 1) NOT NULL,
    MaKH          INT            NOT NULL,
    MaSP          INT            NOT NULL,
    LoaiPH        VARCHAR(10)    NOT NULL,
    DiemDanhGia   TINYINT        NOT NULL,
    NoiDung       NVARCHAR(2000) NOT NULL,
    NgayGui       DATETIME2(0)   NOT NULL CONSTRAINT DF_PHAN_HOI_NgayGui DEFAULT (SYSDATETIME()),
    TrangThai     VARCHAR(10)    NOT NULL CONSTRAINT DF_PHAN_HOI_TrangThai DEFAULT ('MOI'),
    MaNV_XuLy     INT            NULL,
    NgayTiepNhan  DATETIME2(0)   NULL,
    NoiDungTraLoi NVARCHAR(2000) NULL,
    NgayTraLoi    DATETIME2(0)   NULL,
    CONSTRAINT PK_PHAN_HOI PRIMARY KEY (MaPH),
    CONSTRAINT FK_PHAN_HOI_KHACH_HANG FOREIGN KEY (MaKH) REFERENCES crm.KHACH_HANG (MaKH),
    CONSTRAINT FK_PHAN_HOI_SAN_PHAM FOREIGN KEY (MaSP) REFERENCES crm.SAN_PHAM (MaSP),
    CONSTRAINT FK_PHAN_HOI_NHAN_VIEN FOREIGN KEY (MaNV_XuLy) REFERENCES crm.NHAN_VIEN (MaNV),
    CONSTRAINT CK_PHAN_HOI_Loai CHECK (LoaiPH IN ('KHEN', 'GOP_Y', 'KHIEU_NAI')),
    CONSTRAINT CK_PHAN_HOI_Diem CHECK (DiemDanhGia BETWEEN 1 AND 5),
    CONSTRAINT CK_PHAN_HOI_NoiDung CHECK (LEN(NoiDung) > 0),
    CONSTRAINT CK_PHAN_HOI_TrangThai CHECK (
        (TrangThai = 'MOI'        AND MaNV_XuLy IS NULL     AND NgayTiepNhan IS NULL
                                  AND NoiDungTraLoi IS NULL AND NgayTraLoi IS NULL)
     OR (TrangThai = 'DANG_XU_LY' AND MaNV_XuLy IS NOT NULL AND NgayTiepNhan IS NOT NULL
                                  AND NoiDungTraLoi IS NULL AND NgayTraLoi IS NULL)
     OR (TrangThai = 'DA_XU_LY'   AND MaNV_XuLy IS NOT NULL AND NgayTiepNhan IS NOT NULL
                                  AND NoiDungTraLoi IS NOT NULL AND NgayTraLoi IS NOT NULL)),
    CONSTRAINT CK_PHAN_HOI_ThuTuNgay CHECK (
        (NgayTiepNhan IS NULL OR NgayTiepNhan >= NgayGui)
    AND (NgayTraLoi IS NULL OR NgayTraLoi >= NgayTiepNhan))
);
GO

/* ==================== I. NHẬT KÝ KIỂM TOÁN ==================== */
/* Chỉ thêm (append-only): không cấp quyền UPDATE/DELETE cho vai trò nào.
   Không có FK tới TAI_KHOAN để nhật ký còn nguyên khi tài khoản bị xóa. */
IF OBJECT_ID(N'audit.NHAT_KY', N'U') IS NULL
CREATE TABLE audit.NHAT_KY (
    MaNK          BIGINT IDENTITY(1, 1) NOT NULL,
    ThoiGian      DATETIME2(3)   NOT NULL CONSTRAINT DF_NHAT_KY_ThoiGian DEFAULT (SYSDATETIME()),
    MaTK          INT            NULL,           -- tài khoản ứng dụng (từ SESSION_CONTEXT)
    NguoiDungCSDL NVARCHAR(128)  NOT NULL CONSTRAINT DF_NHAT_KY_NguoiDung DEFAULT (ORIGINAL_LOGIN()),
    HanhDong      VARCHAR(40)    NOT NULL,
    DoiTuong      VARCHAR(40)    NOT NULL,
    MaDoiTuong    NVARCHAR(50)   NULL,
    ChiTiet       NVARCHAR(1000) NULL,
    CONSTRAINT PK_NHAT_KY PRIMARY KEY (MaNK)
);
GO

PRINT N'Script 02 hoàn tất: đã tạo 27 bảng (26 bảng crm + audit.NHAT_KY).';
GO

/* #################### 03_ChiMuc_View.sql #################### */
/* =====================================================================
   Script 03: Chỉ mục và view nghiệp vụ
   ---------------------------------------------------------------------
   - Chỉ mục tạo theo nhu cầu truy vấn thực tế (khóa ngoại hay JOIN,
     lọc báo cáo, sắp xếp theo thời gian). Không tạo chỉ mục trùng với
     PK/UNIQUE sẵn có (VD: PK (MaKH, MaLoai) đã phục vụ tìm theo MaKH).
   - View crm.* là view nội bộ (không cấp quyền trực tiếp).
   - View api_*.* là view được cấp SELECT cho từng cổng (script 06).
   ===================================================================== */
USE CRM_Uniqlo;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

/* ----------------------------- 1. CHỈ MỤC ----------------------------- */
DECLARE @ChiMuc TABLE (Ten SYSNAME, Lenh NVARCHAR(600));
INSERT @ChiMuc (Ten, Lenh) VALUES
 (N'IX_TAI_KHOAN_MaVT',         N'CREATE INDEX IX_TAI_KHOAN_MaVT ON crm.TAI_KHOAN (MaVT);'),
 (N'IX_NHAN_VIEN_MaCH',         N'CREATE INDEX IX_NHAN_VIEN_MaCH ON crm.NHAN_VIEN (MaCH);'),
 (N'IX_NHAN_VIEN_MaCV',         N'CREATE INDEX IX_NHAN_VIEN_MaCV ON crm.NHAN_VIEN (MaCV);'),
 (N'IX_CUA_HANG_MaTinh',        N'CREATE INDEX IX_CUA_HANG_MaTinh ON crm.CUA_HANG (MaTinh);'),
 (N'IX_SAN_PHAM_MaLoai',        N'CREATE INDEX IX_SAN_PHAM_MaLoai ON crm.SAN_PHAM (MaLoai) INCLUDE (TrangThai, GiaNiemYet);'),
 (N'IX_SAN_PHAM_MaNCC',         N'CREATE INDEX IX_SAN_PHAM_MaNCC ON crm.SAN_PHAM (MaNCC);'),
 (N'IX_SAN_PHAM_TrangThai',     N'CREATE INDEX IX_SAN_PHAM_TrangThai ON crm.SAN_PHAM (TrangThai, GiaNiemYet);'),
 (N'IX_KHACH_HANG_MaHang',      N'CREATE INDEX IX_KHACH_HANG_MaHang ON crm.KHACH_HANG (MaHang) INCLUDE (TrangThaiHoSo);'),
 (N'IX_KHACH_HANG_MaTinh',      N'CREATE INDEX IX_KHACH_HANG_MaTinh ON crm.KHACH_HANG (MaTinh);'),
 (N'IX_KHACH_HANG_NgaySinh',    N'CREATE INDEX IX_KHACH_HANG_NgaySinh ON crm.KHACH_HANG (NgaySinh) INCLUDE (GioiTinh, MaHang, TrangThaiHoSo);'),
 (N'IX_KHACH_HANG_HoTen',       N'CREATE INDEX IX_KHACH_HANG_HoTen ON crm.KHACH_HANG (HoTen);'),
 (N'IX_KH_QUAN_TAM_MaLoai',     N'CREATE INDEX IX_KH_QUAN_TAM_MaLoai ON crm.KH_QUAN_TAM (MaLoai);'),
 (N'IX_LICH_SU_HANG_MaKH',      N'CREATE INDEX IX_LICH_SU_HANG_MaKH ON crm.LICH_SU_HANG (MaKH, ThoiGian DESC);'),
 (N'IX_HOA_DON_MaKH',           N'CREATE INDEX IX_HOA_DON_MaKH ON crm.HOA_DON (MaKH, NgayLap DESC);'),
 (N'IX_HOA_DON_MaCH',           N'CREATE INDEX IX_HOA_DON_MaCH ON crm.HOA_DON (MaCH);'),
 (N'IX_HOA_DON_MaNV',           N'CREATE INDEX IX_HOA_DON_MaNV ON crm.HOA_DON (MaNV);'),
 (N'IX_HOA_DON_NgayLap',        N'CREATE INDEX IX_HOA_DON_NgayLap ON crm.HOA_DON (NgayLap);'),
 (N'IX_CTHD_MaSP',              N'CREATE INDEX IX_CTHD_MaSP ON crm.CHI_TIET_HOA_DON (MaSP) INCLUDE (SoLuong, DonGiaBan);'),
 (N'IX_DOI_TRA_MaHD_MaSP',      N'CREATE INDEX IX_DOI_TRA_MaHD_MaSP ON crm.DOI_TRA (MaHD, MaSP) INCLUDE (SoLuong);'),
 (N'IX_PHAN_HOI_MaKH',          N'CREATE INDEX IX_PHAN_HOI_MaKH ON crm.PHAN_HOI (MaKH, NgayGui DESC);'),
 (N'IX_PHAN_HOI_TrangThai',     N'CREATE INDEX IX_PHAN_HOI_TrangThai ON crm.PHAN_HOI (TrangThai, NgayGui);'),
 (N'IX_PHAN_HOI_MaSP',          N'CREATE INDEX IX_PHAN_HOI_MaSP ON crm.PHAN_HOI (MaSP) INCLUDE (DiemDanhGia, LoaiPH);'),
 (N'IX_PHAN_HOI_MaNV_XuLy',     N'CREATE INDEX IX_PHAN_HOI_MaNV_XuLy ON crm.PHAN_HOI (MaNV_XuLy);'),
 (N'IX_KHAO_SAT_TrangThai',     N'CREATE INDEX IX_KHAO_SAT_TrangThai ON crm.KHAO_SAT (TrangThai);'),
 (N'IX_KHAO_SAT_MaNV_Tao',      N'CREATE INDEX IX_KHAO_SAT_MaNV_Tao ON crm.KHAO_SAT (MaNV_Tao);'),
 (N'IX_KHAO_SAT_MaSP',          N'CREATE INDEX IX_KHAO_SAT_MaSP ON crm.KHAO_SAT (MaSP);'),
 (N'IX_KHAO_SAT_GUI_MaKH',      N'CREATE INDEX IX_KHAO_SAT_GUI_MaKH ON crm.KHAO_SAT_GUI (MaKH) INCLUDE (NgayHoanThanh);'),
 (N'IX_TRA_LOI_MaCauHoi',       N'CREATE INDEX IX_TRA_LOI_MaCauHoi ON crm.TRA_LOI (MaCauHoi) INCLUDE (DiemSo);'),
 (N'IX_TLLC_MaLC',              N'CREATE INDEX IX_TLLC_MaLC ON crm.TRA_LOI_LUA_CHON (MaLC);'),
 (N'IX_VOUCHER_MaKH',           N'CREATE INDEX IX_VOUCHER_MaKH ON crm.VOUCHER (MaKH);'),
 (N'IX_NHAT_KY_ThoiGian',       N'CREATE INDEX IX_NHAT_KY_ThoiGian ON audit.NHAT_KY (ThoiGian DESC);'),
 (N'IX_NHAT_KY_DoiTuong',       N'CREATE INDEX IX_NHAT_KY_DoiTuong ON audit.NHAT_KY (DoiTuong, MaDoiTuong);');

DECLARE @Ten SYSNAME, @Lenh NVARCHAR(600);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT Ten, Lenh FROM @ChiMuc;
OPEN cur;
FETCH NEXT FROM cur INTO @Ten, @Lenh;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = @Ten)
        EXEC sys.sp_executesql @Lenh;
    FETCH NEXT FROM cur INTO @Ten, @Lenh;
END
CLOSE cur; DEALLOCATE cur;
GO

/* ----------------------------- 2. VIEW NỘI BỘ ----------------------------- */

/* Giá trị từng hóa đơn (tổng tiền suy ra, không lưu trong bảng). */
CREATE OR ALTER VIEW crm.vw_GiaTriHoaDon
AS
SELECT  h.MaHD, h.SoHoaDon, h.MaKH, h.KenhBan, h.MaCH, h.MaNV, h.NgayLap, h.MaVoucher,
        CAST(SUM(ct.SoLuong * ct.DonGiaBan) AS DECIMAL(16, 2))                       AS TongTienHang,
        CAST(ISNULL(v.PhanTramGiam, 0) AS TINYINT)                                    AS PhanTramGiam,
        CAST(SUM(ct.SoLuong * ct.DonGiaBan) * (100 - ISNULL(v.PhanTramGiam, 0)) / 100.0
             AS DECIMAL(16, 2))                                                       AS ThanhTien
FROM crm.HOA_DON h
JOIN crm.CHI_TIET_HOA_DON ct ON ct.MaHD = h.MaHD
LEFT JOIN crm.VOUCHER v      ON v.MaVoucher = h.MaVoucher
GROUP BY h.MaHD, h.SoHoaDon, h.MaKH, h.KenhBan, h.MaCH, h.MaNV, h.NgayLap, h.MaVoucher, v.PhanTramGiam;
GO

/* Giá trị hoàn lại của từng lần đổi trả (đã trừ % giảm của voucher trên hóa đơn). */
CREATE OR ALTER VIEW crm.vw_GiaTriDoiTra
AS
SELECT  d.MaDT, d.MaHD, d.MaSP, h.MaKH, d.SoLuong, d.LyDo, d.NgayDoiTra,
        CAST(d.SoLuong * ct.DonGiaBan * (100 - ISNULL(v.PhanTramGiam, 0)) / 100.0
             AS DECIMAL(16, 2)) AS GiaTriHoan
FROM crm.DOI_TRA d
JOIN crm.CHI_TIET_HOA_DON ct ON ct.MaHD = d.MaHD AND ct.MaSP = d.MaSP
JOIN crm.HOA_DON h           ON h.MaHD = d.MaHD
LEFT JOIN crm.VOUCHER v      ON v.MaVoucher = h.MaVoucher;
GO

/* Điểm tích lũy (suy ra): 1 điểm cho mỗi 10.000đ chi tiêu ròng
   (= tổng thành tiền hóa đơn - giá trị hàng đổi trả). Đây là quy ước của nhóm.
   HangTheoDiem: hạng cao nhất có DiemToiThieu <= Diem. */
CREATE OR ALTER VIEW crm.vw_DiemKhachHang
AS
WITH Mua AS (
    SELECT MaKH, SUM(ThanhTien) AS TongMua, COUNT(*) AS SoHoaDon, MAX(NgayLap) AS LanMuaCuoi
    FROM crm.vw_GiaTriHoaDon GROUP BY MaKH
), Tra AS (
    SELECT MaKH, SUM(GiaTriHoan) AS TongTra
    FROM crm.vw_GiaTriDoiTra GROUP BY MaKH
), Tinh AS (
    SELECT k.MaKH, k.MaHang,
           ISNULL(m.SoHoaDon, 0) AS SoHoaDon,
           m.LanMuaCuoi,
           CAST(ISNULL(m.TongMua, 0) - ISNULL(t.TongTra, 0) AS DECIMAL(16, 2)) AS ChiTieuRong
    FROM crm.KHACH_HANG k
    LEFT JOIN Mua m ON m.MaKH = k.MaKH
    LEFT JOIN Tra t ON t.MaKH = k.MaKH
)
SELECT  x.MaKH, x.MaHang AS HangHienTai, x.SoHoaDon, x.LanMuaCuoi, x.ChiTieuRong,
        CAST(FLOOR(CASE WHEN x.ChiTieuRong > 0 THEN x.ChiTieuRong ELSE 0 END / 10000) AS INT) AS Diem,
        h.MaHang AS HangTheoDiem
FROM Tinh x
OUTER APPLY (SELECT TOP (1) hg.MaHang
             FROM crm.HANG_THANH_VIEN hg
             WHERE hg.DiemToiThieu <= FLOOR(CASE WHEN x.ChiTieuRong > 0 THEN x.ChiTieuRong ELSE 0 END / 10000)
             ORDER BY hg.DiemToiThieu DESC) h;
GO

/* Hồ sơ khách hàng + thuộc tính suy ra (tuổi, nhóm tuổi). */
CREATE OR ALTER VIEW crm.vw_KhachHang_MoRong
AS
SELECT  k.MaKH, k.HoTen, k.GioiTinh, k.NgaySinh, k.SDT, k.Email, k.MaTinh, k.NgayDangKy,
        k.MaHang, k.NgayXetHang, k.TrangThaiHoSo, k.NgayXoa, k.MaTK,
        a.Tuoi,
        CASE WHEN a.Tuoi IS NULL THEN N'Không rõ'
             WHEN a.Tuoi < 18 THEN N'Dưới 18'
             WHEN a.Tuoi < 25 THEN N'18-24'
             WHEN a.Tuoi < 35 THEN N'25-34'
             WHEN a.Tuoi < 45 THEN N'35-44'
             WHEN a.Tuoi < 55 THEN N'45-54'
             ELSE N'55 trở lên' END AS NhomTuoi
FROM crm.KHACH_HANG k
CROSS APPLY (SELECT CASE WHEN k.NgaySinh IS NULL THEN NULL
                         ELSE DATEDIFF(YEAR, k.NgaySinh, CAST(SYSDATETIME() AS DATE))
                              - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, k.NgaySinh, CAST(SYSDATETIME() AS DATE)), k.NgaySinh)
                                          > CAST(SYSDATETIME() AS DATE) THEN 1 ELSE 0 END
                    END AS Tuoi) a;
GO

/* --------------------- 3. VIEW CẤP CHO CỔNG (api_*) --------------------- */

/* Dùng chung cho cả 3 cổng: danh mục công khai, không chứa dữ liệu cá nhân. */
CREATE OR ALTER VIEW api_chung.vw_LoaiSP
AS SELECT MaLoai, TenLoai, MoTa FROM crm.LOAI_SP;
GO
CREATE OR ALTER VIEW api_chung.vw_TinhThanh
AS SELECT MaTinh, TenTinh FROM crm.TINH_THANH;
GO
CREATE OR ALTER VIEW api_chung.vw_HangThanhVien
AS SELECT MaHang, TenHang, DiemToiThieu, MoTa FROM crm.HANG_THANH_VIEN;
GO
CREATE OR ALTER VIEW api_chung.vw_SanPham
AS
SELECT sp.MaSP, sp.MaSKU, sp.TenSP, sp.MaLoai, l.TenLoai, sp.ChatLieu, sp.MoTa,
       sp.GiaNiemYet, sp.TrangThai, sp.NgayRaMat
FROM crm.SAN_PHAM sp
JOIN crm.LOAI_SP l ON l.MaLoai = sp.MaLoai
WHERE sp.TrangThai IN ('DANG_BAN', 'SAP_RA_MAT');
GO

/* Cổng ADMIN: tra cứu/lọc/sắp xếp danh mục. Không có cột MatKhauHash. */
CREATE OR ALTER VIEW api_admin.vw_SanPham
AS
SELECT sp.MaSP, sp.MaSKU, sp.TenSP, sp.MaLoai, l.TenLoai, sp.MaNCC, n.TenNCC,
       sp.ChatLieu, sp.MoTa, sp.GiaNiemYet, sp.TrangThai, sp.NgayRaMat
FROM crm.SAN_PHAM sp
JOIN crm.LOAI_SP l      ON l.MaLoai = sp.MaLoai
JOIN crm.NHA_CUNG_CAP n ON n.MaNCC = sp.MaNCC;
GO
CREATE OR ALTER VIEW api_admin.vw_NhaCungCap
AS
SELECT n.MaNCC, n.TenNCC, n.QuocGia, n.DiaChi, n.SDT, n.Email, n.TrangThai,
       (SELECT COUNT(*) FROM crm.SAN_PHAM sp WHERE sp.MaNCC = n.MaNCC) AS SoSanPham
FROM crm.NHA_CUNG_CAP n;
GO
CREATE OR ALTER VIEW api_admin.vw_LoaiSP
AS
SELECT l.MaLoai, l.TenLoai, l.MoTa,
       (SELECT COUNT(*) FROM crm.SAN_PHAM sp WHERE sp.MaLoai = l.MaLoai) AS SoSanPham
FROM crm.LOAI_SP l;
GO
CREATE OR ALTER VIEW api_admin.vw_CuaHang
AS
SELECT c.MaCH, c.TenCH, c.DiaChi, c.MaTinh, t.TenTinh, c.SDT, c.TrangThai
FROM crm.CUA_HANG c JOIN crm.TINH_THANH t ON t.MaTinh = c.MaTinh;
GO
CREATE OR ALTER VIEW api_admin.vw_NhanVien
AS
SELECT nv.MaNV, nv.HoTen, nv.MaCV, cv.TenCV, nv.MaCH, ch.TenCH, nv.SDT, nv.Email,
       nv.NgayVaoLam, nv.TrangThai, nv.MaTK, tk.TenDangNhap, tk.MaVT
FROM crm.NHAN_VIEN nv
JOIN crm.CHUC_VU cv        ON cv.MaCV = nv.MaCV
LEFT JOIN crm.CUA_HANG ch  ON ch.MaCH = nv.MaCH
LEFT JOIN crm.TAI_KHOAN tk ON tk.MaTK = nv.MaTK;
GO
CREATE OR ALTER VIEW api_admin.vw_TaiKhoan
AS
SELECT tk.MaTK, tk.TenDangNhap, tk.LoaiTK, tk.MaVT, vt.TenVT, vt.CongTruyCap,
       tk.TrangThai, tk.PhaiDoiMatKhau, tk.NgayTao, tk.LanDangNhapCuoi, tk.NgayKhoa, tk.LyDoKhoa,
       COALESCE(nv.HoTen, kh.HoTen) AS ChuTaiKhoan,
       nv.MaNV, kh.MaKH
FROM crm.TAI_KHOAN tk
JOIN crm.VAI_TRO vt         ON vt.MaVT = tk.MaVT
LEFT JOIN crm.NHAN_VIEN nv  ON nv.MaTK = tk.MaTK
LEFT JOIN crm.KHACH_HANG kh ON kh.MaTK = tk.MaTK;
GO
CREATE OR ALTER VIEW api_admin.vw_VaiTroQuyen
AS
SELECT vt.MaVT, vt.TenVT, vt.CongTruyCap, q.MaQuyen, q.TenQuyen,
       CAST(CASE WHEN vtq.MaQuyen IS NULL THEN 0 ELSE 1 END AS BIT) AS DuocCap
FROM crm.VAI_TRO vt
JOIN crm.QUYEN q ON q.CongTruyCap = vt.CongTruyCap
LEFT JOIN crm.VAI_TRO_QUYEN vtq ON vtq.MaVT = vt.MaVT AND vtq.MaQuyen = q.MaQuyen;
GO
/* Admin chỉ tra cứu khách hàng ở mức kỹ thuật: SĐT/Email bị che bớt. */
CREATE OR ALTER VIEW api_admin.vw_KhachHang_TraCuu
AS
SELECT k.MaKH, k.HoTen,
       LEFT(k.SDT, 3) + 'xxxx' + RIGHT(k.SDT, 3) AS SDT_Che,
       CASE WHEN k.Email IS NULL THEN NULL
            ELSE LEFT(k.Email, 2) + '***' + SUBSTRING(k.Email, CHARINDEX('@', k.Email), 100) END AS Email_Che,
       k.MaHang, k.TrangThaiHoSo, k.NgayDangKy, k.MaTK, tk.TrangThai AS TrangThaiTaiKhoan
FROM crm.KHACH_HANG k
LEFT JOIN crm.TAI_KHOAN tk ON tk.MaTK = k.MaTK;
GO
CREATE OR ALTER VIEW api_admin.vw_NhatKy
AS
SELECT nk.MaNK, nk.ThoiGian, nk.MaTK, tk.TenDangNhap, nk.NguoiDungCSDL,
       nk.HanhDong, nk.DoiTuong, nk.MaDoiTuong, nk.ChiTiet
FROM audit.NHAT_KY nk
LEFT JOIN crm.TAI_KHOAN tk ON tk.MaTK = nk.MaTK;
GO

/* Cổng QUẢN LÝ: hồ sơ khách hàng đầy đủ, phản hồi, khảo sát. */
CREATE OR ALTER VIEW api_ql.vw_KhachHang
AS
SELECT k.MaKH, k.HoTen, k.GioiTinh, k.NgaySinh, k.Tuoi, k.NhomTuoi, k.SDT, k.Email,
       k.MaTinh, t.TenTinh, k.NgayDangKy, k.MaHang, hg.TenHang, d.Diem, d.ChiTieuRong,
       d.SoHoaDon, d.LanMuaCuoi, k.NgayXetHang, k.TrangThaiHoSo, k.NgayXoa,
       k.MaTK, tk.TenDangNhap, tk.TrangThai AS TrangThaiTaiKhoan,
       (SELECT STRING_AGG(l.TenLoai, N', ') WITHIN GROUP (ORDER BY l.TenLoai)
        FROM crm.KH_QUAN_TAM q JOIN crm.LOAI_SP l ON l.MaLoai = q.MaLoai
        WHERE q.MaKH = k.MaKH) AS SoThich
FROM crm.vw_KhachHang_MoRong k
JOIN crm.HANG_THANH_VIEN hg   ON hg.MaHang = k.MaHang
JOIN crm.vw_DiemKhachHang d   ON d.MaKH = k.MaKH
LEFT JOIN crm.TINH_THANH t    ON t.MaTinh = k.MaTinh
LEFT JOIN crm.TAI_KHOAN tk    ON tk.MaTK = k.MaTK;
GO
CREATE OR ALTER VIEW api_ql.vw_PhanHoi
AS
SELECT ph.MaPH, ph.MaKH, k.HoTen AS TenKhachHang, k.MaHang, ph.MaSP, sp.TenSP, l.TenLoai,
       ph.LoaiPH, ph.DiemDanhGia, ph.NoiDung, ph.NgayGui, ph.TrangThai,
       ph.MaNV_XuLy, nv.HoTen AS NguoiXuLy, ph.NgayTiepNhan, ph.NoiDungTraLoi, ph.NgayTraLoi,
       CAST(CASE WHEN EXISTS (SELECT 1 FROM crm.HOA_DON h JOIN crm.CHI_TIET_HOA_DON ct ON ct.MaHD = h.MaHD
                              WHERE h.MaKH = ph.MaKH AND ct.MaSP = ph.MaSP) THEN 1 ELSE 0 END AS BIT) AS DaMuaSanPham
FROM crm.PHAN_HOI ph
JOIN crm.KHACH_HANG k     ON k.MaKH = ph.MaKH
JOIN crm.SAN_PHAM sp      ON sp.MaSP = ph.MaSP
JOIN crm.LOAI_SP l        ON l.MaLoai = sp.MaLoai
LEFT JOIN crm.NHAN_VIEN nv ON nv.MaNV = ph.MaNV_XuLy;
GO
CREATE OR ALTER VIEW api_ql.vw_KhaoSat
AS
SELECT ks.MaKS, ks.TieuDe, ks.MucDich, ks.MaSP, sp.TenSP, ks.MaNV_Tao, nv.HoTen AS NguoiTao,
       ks.NgayTao, ks.NgayPhatHanh, ks.HanTraLoi, ks.PhanTramVoucher, ks.TrangThai,
       (SELECT COUNT(*) FROM crm.CAU_HOI c WHERE c.MaKS = ks.MaKS) AS SoCauHoi,
       (SELECT COUNT(*) FROM crm.KHAO_SAT_GUI g WHERE g.MaKS = ks.MaKS) AS SoNguoiNhan,
       (SELECT COUNT(*) FROM crm.KHAO_SAT_GUI g WHERE g.MaKS = ks.MaKS AND g.NgayHoanThanh IS NOT NULL) AS SoHoanThanh
FROM crm.KHAO_SAT ks
JOIN crm.NHAN_VIEN nv    ON nv.MaNV = ks.MaNV_Tao
LEFT JOIN crm.SAN_PHAM sp ON sp.MaSP = ks.MaSP;
GO

PRINT N'Script 03 hoàn tất.';
GO

/* #################### 04_BaoMat_ThuTucNoiBo.sql #################### */
/* =====================================================================
   Script 04: Kiểu bảng (TVP), hàm/thủ tục bảo mật, thủ tục nội bộ
   ---------------------------------------------------------------------
   MÔ HÌNH NGỮ CẢNH PHIÊN (đọc kỹ trước khi viết ứng dụng)
   1. Mỗi cổng ứng dụng (Admin / Quản lý / Khách hàng) kết nối SQL Server
      bằng MỘT login riêng, ánh xạ vào database role r_admin / r_quanly /
      r_khachhang (script 06). Role này là TRẦN QUYỀN của cổng.
   2. Người dùng cuối đăng nhập vào ứng dụng; ứng dụng gọi
      api_chung.usp_LayThongTinDangNhap để lấy chuỗi băm và tự kiểm tra
      mật khẩu (bcrypt/PBKDF2). CSDL không nhận mật khẩu thô.
   3. Ngay sau khi mở kết nối cho một yêu cầu đã xác thực, ứng dụng gọi
      sec.usp_DatNguCanh @MaTK. Thủ tục kiểm tra tài khoản và cổng rồi ghi
      MaTK/MaKH/MaNV vào SESSION_CONTEXT ở chế độ read_only (không đổi
      được trong suốt phiên).
   4. Mọi thủ tục api_* lấy danh tính từ SESSION_CONTEXT (không nhận MaKH/
      MaTK của "chính mình" từ tham số) và gọi sec.usp_KiemTraQuyen.
   GIỚI HẠN: SQL Server không tự biết người dùng cuối là ai. Nếu kẻ tấn
   công chạy được câu lệnh tùy ý trên kết nối của một cổng (SQL injection)
   TRƯỚC khi ứng dụng gọi sec.usp_DatNguCanh, họ có thể tự đặt ngữ cảnh
   giả. Phạm vi thiệt hại vẫn bị chặn bởi role của cổng đó (ví dụ cổng
   Khách hàng không gọi được thủ tục Quản lý). Vì vậy ứng dụng BẮT BUỘC
   dùng truy vấn tham số hóa và đặt ngữ cảnh ngay khi mở kết nối.
   ===================================================================== */
USE CRM_Uniqlo;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

/* ---------------------- 1. KIỂU BẢNG (table-valued parameter) ---------------------- */
IF TYPE_ID(N'api_chung.DanhSachMa') IS NULL
    CREATE TYPE api_chung.DanhSachMa AS TABLE (Ma INT NOT NULL PRIMARY KEY);
GO
IF TYPE_ID(N'api_kh.BangTraLoi') IS NULL
    CREATE TYPE api_kh.BangTraLoi AS TABLE (
        MaCauHoi      INT            NOT NULL,
        MaLC          INT            NULL,      -- câu chọn: mỗi lựa chọn 1 dòng
        DiemSo        TINYINT        NULL,      -- câu thang điểm 1-5
        NoiDungTuLuan NVARCHAR(2000) NULL       -- câu tự luận
    );
GO
IF TYPE_ID(N'api_ql.DanhSachLuaChon') IS NULL
    CREATE TYPE api_ql.DanhSachLuaChon AS TABLE (
        ThuTu   SMALLINT      NOT NULL PRIMARY KEY,
        NoiDung NVARCHAR(200) NOT NULL
    );
GO
IF TYPE_ID(N'api_admin.DanhSachMaQuyen') IS NULL
    CREATE TYPE api_admin.DanhSachMaQuyen AS TABLE (MaQuyen VARCHAR(30) NOT NULL PRIMARY KEY);
GO
IF TYPE_ID(N'api_admin.BangChiTietHoaDon') IS NULL
    CREATE TYPE api_admin.BangChiTietHoaDon AS TABLE (
        MaSKU     VARCHAR(20)    NOT NULL PRIMARY KEY,
        SoLuong   INT            NOT NULL,
        DonGiaBan DECIMAL(14, 2) NOT NULL
    );
GO

/* ---------------------- 2. HÀM ĐỌC NGỮ CẢNH ---------------------- */
CREATE OR ALTER FUNCTION sec.fn_MaTK()
RETURNS INT
AS
BEGIN
    RETURN CAST(SESSION_CONTEXT(N'MaTK') AS INT);
END;
GO
CREATE OR ALTER FUNCTION sec.fn_MaKH()
RETURNS INT
AS
BEGIN
    RETURN NULLIF(CAST(SESSION_CONTEXT(N'MaKH') AS INT), 0);
END;
GO
CREATE OR ALTER FUNCTION sec.fn_MaNV()
RETURNS INT
AS
BEGIN
    RETURN NULLIF(CAST(SESSION_CONTEXT(N'MaNV') AS INT), 0);
END;
GO

/* Cổng của NGƯỜI GỌI, xác định bằng database role thật (không tin ngữ cảnh). */
CREATE OR ALTER FUNCTION sec.fn_CongNguoiGoi()
RETURNS VARCHAR(10)
AS
BEGIN
    RETURN CASE
        WHEN IS_MEMBER(N'db_owner') = 1    THEN 'DBO'          -- quản trị CSDL / script kiểm thử
        WHEN IS_MEMBER(N'r_admin') = 1     THEN 'ADMIN'
        WHEN IS_MEMBER(N'r_quanly') = 1    THEN 'QUAN_LY'
        WHEN IS_MEMBER(N'r_khachhang') = 1 THEN 'KHACH_HANG'
        ELSE NULL END;
END;
GO

/* Kiểm tra quyền chức năng của tài khoản trong ngữ cảnh:
   - tài khoản đang HOAT_DONG;
   - vai trò của tài khoản thuộc đúng cổng của database role người gọi;
   - vai trò được cấp quyền @MaQuyen (bảng VAI_TRO_QUYEN, Admin chỉnh được);
   - hồ sơ con người còn hoạt động và khớp cặp MaTK/MaKH (hoặc MaTK/MaNV). */
CREATE OR ALTER FUNCTION sec.fn_CoQuyen(@MaQuyen VARCHAR(30))
RETURNS BIT
AS
BEGIN
    DECLARE @MaTK INT = CAST(SESSION_CONTEXT(N'MaTK') AS INT);
    DECLARE @MaKH INT = CAST(SESSION_CONTEXT(N'MaKH') AS INT);
    DECLARE @MaNV INT = CAST(SESSION_CONTEXT(N'MaNV') AS INT);
    DECLARE @CongGoi VARCHAR(10) = sec.fn_CongNguoiGoi();

    IF @MaTK IS NULL OR @CongGoi IS NULL
        RETURN 0;

    IF EXISTS (
        SELECT 1
        FROM crm.TAI_KHOAN tk
        JOIN crm.VAI_TRO vt        ON vt.MaVT = tk.MaVT
        JOIN crm.VAI_TRO_QUYEN vq  ON vq.MaVT = tk.MaVT AND vq.MaQuyen = @MaQuyen
        WHERE tk.MaTK = @MaTK
          AND tk.TrangThai = 'HOAT_DONG'
          AND (@CongGoi = 'DBO' OR vt.CongTruyCap = @CongGoi)
          AND (   (tk.LoaiTK = 'KH' AND EXISTS (SELECT 1 FROM crm.KHACH_HANG k
                                                WHERE k.MaTK = tk.MaTK AND k.MaKH = @MaKH
                                                  AND k.TrangThaiHoSo = 'HOAT_DONG'))
               OR (tk.LoaiTK = 'NV' AND EXISTS (SELECT 1 FROM crm.NHAN_VIEN n
                                                WHERE n.MaTK = tk.MaTK AND n.MaNV = @MaNV
                                                  AND n.TrangThai = 'DANG_LAM'))))
        RETURN 1;
    RETURN 0;
END;
GO

/* ---------------------- 3. THỦ TỤC BẢO MẬT ---------------------- */

/* Nội bộ: tra cứu chủ tài khoản với quyền chủ sở hữu (bỏ qua RLS khi phiên
   chưa có ngữ cảnh). Không cấp quyền EXECUTE cho ai; chỉ gọi qua chuỗi sở hữu. */
CREATE OR ALTER PROCEDURE sec.usp_TraCuuChuTaiKhoan_NoiBo
    @MaTK        INT,
    @CongTK      VARCHAR(10) OUTPUT,
    @TrangThai   VARCHAR(10) OUTPUT,
    @MaKH        INT         OUTPUT,
    @MaNV        INT         OUTPUT,
    @ConHoatDong BIT         OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @CongTK = NULL, @TrangThai = NULL, @MaKH = NULL, @MaNV = NULL, @ConHoatDong = 0;

    SELECT @CongTK = vt.CongTruyCap, @TrangThai = tk.TrangThai
    FROM crm.TAI_KHOAN tk JOIN crm.VAI_TRO vt ON vt.MaVT = tk.MaVT
    WHERE tk.MaTK = @MaTK;

    SELECT @MaKH = k.MaKH,
           @ConHoatDong = CASE WHEN k.TrangThaiHoSo = 'HOAT_DONG' THEN 1 ELSE 0 END
    FROM crm.KHACH_HANG k WHERE k.MaTK = @MaTK;

    IF @MaKH IS NULL
        SELECT @MaNV = n.MaNV,
               @ConHoatDong = CASE WHEN n.TrangThai = 'DANG_LAM' THEN 1 ELSE 0 END
        FROM crm.NHAN_VIEN n WHERE n.MaTK = @MaTK;
END;
GO

/* Ứng dụng gọi NGAY sau khi mở kết nối của một người dùng đã xác thực. */
CREATE OR ALTER PROCEDURE sec.usp_DatNguCanh
    @MaTK INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF SESSION_CONTEXT(N'MaTK') IS NOT NULL
        THROW 50010, N'Phiên đã gắn với một tài khoản. Mở kết nối mới để dùng tài khoản khác.', 1;

    DECLARE @CongGoi VARCHAR(10) = sec.fn_CongNguoiGoi();
    IF @CongGoi IS NULL
        THROW 50011, N'Người dùng CSDL hiện tại không thuộc cổng ứng dụng nào.', 1;

    DECLARE @CongTK VARCHAR(10), @TrangThai VARCHAR(10), @MaKH INT, @MaNV INT, @ConHoatDong BIT;
    EXEC sec.usp_TraCuuChuTaiKhoan_NoiBo
         @MaTK = @MaTK, @CongTK = @CongTK OUTPUT, @TrangThai = @TrangThai OUTPUT,
         @MaKH = @MaKH OUTPUT, @MaNV = @MaNV OUTPUT, @ConHoatDong = @ConHoatDong OUTPUT;

    IF @CongTK IS NULL OR @TrangThai <> 'HOAT_DONG' OR @ConHoatDong = 0
        THROW 50012, N'Tài khoản không tồn tại, đã bị khóa hoặc hồ sơ không còn hoạt động.', 1;
    IF @CongGoi <> 'DBO' AND @CongGoi <> @CongTK
        THROW 50013, N'Tài khoản không được phép sử dụng cổng ứng dụng này.', 1;

    /* Đặt MaKH/MaNV trước, MaTK sau cùng: nếu khóa nào đã bị đặt sẵn (read-only)
       thì lệnh lỗi và MaTK không bao giờ được gán => phiên không dùng được.
       Giá trị 0 = "không có" (IDENTITY bắt đầu từ 1). */
    DECLARE @GiaTriKH INT = ISNULL(@MaKH, 0), @GiaTriNV INT = ISNULL(@MaNV, 0);
    EXEC sys.sp_set_session_context @key = N'MaKH', @value = @GiaTriKH, @read_only = 1;
    EXEC sys.sp_set_session_context @key = N'MaNV', @value = @GiaTriNV, @read_only = 1;
    EXEC sys.sp_set_session_context @key = N'CongTruyCap', @value = @CongTK, @read_only = 1;
    EXEC sys.sp_set_session_context @key = N'MaTK', @value = @MaTK, @read_only = 1;
END;
GO

/* Gọi ở đầu mọi thủ tục api_* (trừ đăng ký/đăng nhập). */
CREATE OR ALTER PROCEDURE sec.usp_KiemTraQuyen
    @MaQuyen VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    IF SESSION_CONTEXT(N'MaTK') IS NULL
        THROW 50001, N'Chưa đăng nhập: phiên chưa được thiết lập ngữ cảnh.', 1;
    IF sec.fn_CoQuyen(@MaQuyen) = 0
    BEGIN
        DECLARE @ThongBao NVARCHAR(200) = N'Không có quyền thực hiện chức năng ' + @MaQuyen + N'.';
        THROW 50003, @ThongBao, 1;
    END
END;
GO

/* Ghi nhật ký kiểm toán. */
CREATE OR ALTER PROCEDURE sec.usp_GhiNhatKy
    @HanhDong   VARCHAR(40),
    @DoiTuong   VARCHAR(40),
    @MaDoiTuong NVARCHAR(50)   = NULL,
    @ChiTiet    NVARCHAR(1000) = NULL,
    @MaTK       INT            = NULL    -- mặc định lấy từ ngữ cảnh
AS
BEGIN
    SET NOCOUNT ON;
    INSERT audit.NHAT_KY (MaTK, HanhDong, DoiTuong, MaDoiTuong, ChiTiet)
    VALUES (COALESCE(@MaTK, sec.fn_MaTK()), @HanhDong, @DoiTuong, @MaDoiTuong, @ChiTiet);
END;
GO

/* ---------------------- 4. THỦ TỤC NỘI BỘ (schema crm, không cấp quyền) ---------------------- */

/* Tạo hồ sơ khách hàng (+ tài khoản nếu có) + sở thích.
   Dùng chung cho Đăng ký (khách) và Thêm khách hàng (quản lý).
   EXECUTE AS OWNER: phiên đăng ký chưa có ngữ cảnh nên RLS sẽ chặn ghi
   KH_QUAN_TAM nếu chạy dưới quyền người gọi. Thủ tục không tự mở giao dịch;
   thủ tục gọi nó chịu trách nhiệm BEGIN/COMMIT/ROLLBACK. */
CREATE OR ALTER PROCEDURE crm.usp_TaoKhachHang_NoiBo
    @HoTen          NVARCHAR(100),
    @GioiTinh       VARCHAR(4),
    @NgaySinh       DATE,
    @SDT            VARCHAR(10),
    @Email          VARCHAR(100),
    @MaTinh         VARCHAR(10),
    @DsLoaiQuanTam  api_chung.DanhSachMa READONLY,
    @TenDangNhap    VARCHAR(50)  = NULL,
    @MatKhauHash    VARCHAR(255) = NULL,
    @PhaiDoiMatKhau BIT          = 0,
    @MaKH           INT OUTPUT,
    @MaTK           INT OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SELECT @MaKH = NULL, @MaTK = NULL,
           @HoTen = NULLIF(TRIM(@HoTen), N''),
           @Email = NULLIF(LOWER(TRIM(@Email)), ''),
           @SDT   = TRIM(@SDT);

    IF @HoTen IS NULL OR @SDT IS NULL
        THROW 52001, N'Họ tên và số điện thoại là bắt buộc.', 1;
    IF (@TenDangNhap IS NULL AND @MatKhauHash IS NOT NULL)
       OR (@TenDangNhap IS NOT NULL AND @MatKhauHash IS NULL)
        THROW 52001, N'Tên đăng nhập và mật khẩu (đã băm) phải đi cùng nhau.', 1;
    IF EXISTS (SELECT 1 FROM crm.KHACH_HANG WHERE SDT = @SDT AND TrangThaiHoSo = 'HOAT_DONG')
        THROW 52002, N'Số điện thoại đã thuộc một hồ sơ khách hàng đang hoạt động.', 1;
    IF @Email IS NOT NULL
       AND EXISTS (SELECT 1 FROM crm.KHACH_HANG WHERE Email = @Email AND TrangThaiHoSo = 'HOAT_DONG')
        THROW 52003, N'Email đã thuộc một hồ sơ khách hàng đang hoạt động.', 1;
    IF @TenDangNhap IS NOT NULL
       AND EXISTS (SELECT 1 FROM crm.TAI_KHOAN WHERE TenDangNhap = @TenDangNhap)
        THROW 52004, N'Tên đăng nhập đã tồn tại.', 1;
    IF EXISTS (SELECT 1 FROM @DsLoaiQuanTam d WHERE NOT EXISTS (SELECT 1 FROM crm.LOAI_SP l WHERE l.MaLoai = d.Ma))
        THROW 52005, N'Có loại sản phẩm quan tâm không tồn tại.', 1;

    IF @TenDangNhap IS NOT NULL
    BEGIN
        INSERT crm.TAI_KHOAN (TenDangNhap, MatKhauHash, MaVT, LoaiTK, PhaiDoiMatKhau)
        VALUES (@TenDangNhap, @MatKhauHash, 'KHACH_HANG', 'KH', @PhaiDoiMatKhau);
        SET @MaTK = SCOPE_IDENTITY();
    END

    INSERT crm.KHACH_HANG (HoTen, GioiTinh, NgaySinh, SDT, Email, MaTinh, MaTK)
    VALUES (@HoTen, @GioiTinh, @NgaySinh, @SDT, @Email, @MaTinh, @MaTK);
    SET @MaKH = SCOPE_IDENTITY();

    INSERT crm.KH_QUAN_TAM (MaKH, MaLoai)
    SELECT @MaKH, d.Ma FROM @DsLoaiQuanTam d;
END;
GO

/* Xét lại hạng thành viên theo điểm suy ra (crm.vw_DiemKhachHang).
   @MaKH NULL = xét toàn bộ khách đang hoạt động. Mọi thay đổi hạng được ghi
   vào LICH_SU_HANG. Đổi hạng KHÔNG đụng tới TAI_KHOAN/VAI_TRO => không thể
   làm thay đổi quyền hệ thống. */
CREATE OR ALTER PROCEDURE crm.usp_XetHang_NoiBo
    @MaKH          INT           = NULL,
    @LyDo          NVARCHAR(200) = N'Hệ thống tự xét hạng theo điểm tích lũy',
    @MaNV_ThucHien INT           = NULL,
    @SoThayDoi     INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @ThayDoi TABLE (MaKH INT PRIMARY KEY, HangCu VARCHAR(10), HangMoi VARCHAR(10), Diem INT);

    UPDATE k
       SET k.MaHang = d.HangTheoDiem,
           k.NgayXetHang = SYSDATETIME()
    OUTPUT inserted.MaKH, deleted.MaHang, inserted.MaHang, d.Diem
      INTO @ThayDoi (MaKH, HangCu, HangMoi, Diem)
    FROM crm.KHACH_HANG k
    JOIN crm.vw_DiemKhachHang d ON d.MaKH = k.MaKH
    WHERE (@MaKH IS NULL OR k.MaKH = @MaKH)
      AND k.TrangThaiHoSo = 'HOAT_DONG'
      AND d.HangTheoDiem IS NOT NULL
      AND d.HangTheoDiem <> k.MaHang;

    INSERT crm.LICH_SU_HANG (MaKH, MaHangCu, MaHangMoi, DiemTaiThoiDiem, LyDo, MaNV_ThucHien)
    SELECT MaKH, HangCu, HangMoi, Diem, @LyDo, @MaNV_ThucHien FROM @ThayDoi;

    SET @SoThayDoi = @@ROWCOUNT;
END;
GO

PRINT N'Script 04 hoàn tất.';
GO

/* #################### 05a_API_Chung_KhachHang.sql #################### */
/* =====================================================================
   Script 05a: Thủ tục dùng chung (api_chung) và cổng Khách hàng (api_kh)
   ---------------------------------------------------------------------
   Đáp ứng yêu cầu đề (III.4 – Khách hàng):
     1. Đăng ký tài khoản khách hàng  -> api_kh.usp_DangKy
     2. Đăng nhập                     -> api_chung.usp_LayThongTinDangNhap
                                          + sec.usp_DatNguCanh + usp_GhiNhanDangNhap
     3. Chỉnh sửa thông tin           -> api_kh.usp_XemHoSo / usp_CapNhatHoSo
     4. Gửi phản hồi về sản phẩm      -> api_kh.usp_GuiPhanHoi / usp_XemPhanHoiCuaToi
     5. Nhận khảo sát và thực hiện    -> api_kh.usp_DanhSachKhaoSat / usp_XemKhaoSat
                                          / usp_NopKhaoSat / usp_XemVoucherCuaToi
   Nguyên tắc: thủ tục cổng Khách hàng KHÔNG nhận MaKH từ tham số; luôn lấy
   từ ngữ cảnh phiên (sec.fn_MaKH()).
   ===================================================================== */
USE CRM_Uniqlo;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

/* ============================ api_chung ============================ */

/* Bước 1 đăng nhập: trả về chuỗi băm để ỨNG DỤNG tự so khớp mật khẩu.
   Chỉ trả tài khoản thuộc đúng cổng của người gọi; không tìm thấy -> tập rỗng
   (ứng dụng báo chung "sai tên đăng nhập hoặc mật khẩu"). */
CREATE OR ALTER PROCEDURE api_chung.usp_LayThongTinDangNhap
    @TenDangNhap VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Cong VARCHAR(10) = sec.fn_CongNguoiGoi();
    IF @Cong IS NULL
        THROW 50011, N'Người dùng CSDL hiện tại không thuộc cổng ứng dụng nào.', 1;

    SELECT tk.MaTK, tk.MatKhauHash, tk.TrangThai, tk.PhaiDoiMatKhau, tk.MaVT, vt.CongTruyCap
    FROM crm.TAI_KHOAN tk
    JOIN crm.VAI_TRO vt ON vt.MaVT = tk.MaVT
    WHERE tk.TenDangNhap = @TenDangNhap
      AND (@Cong = 'DBO' OR vt.CongTruyCap = @Cong);
END;
GO

/* Bước 3 đăng nhập (sau sec.usp_DatNguCanh): ghi thời điểm đăng nhập. */
CREATE OR ALTER PROCEDURE api_chung.usp_GhiNhanDangNhap
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @MaTK INT = sec.fn_MaTK();
    IF @MaTK IS NULL
        THROW 50001, N'Chưa đăng nhập: phiên chưa được thiết lập ngữ cảnh.', 1;

    UPDATE crm.TAI_KHOAN SET LanDangNhapCuoi = SYSDATETIME() WHERE MaTK = @MaTK;
    EXEC sec.usp_GhiNhatKy @HanhDong = 'DANG_NHAP', @DoiTuong = 'TAI_KHOAN', @MaDoiTuong = @MaTK;
END;
GO

/* Thông tin phiên + danh sách quyền để giao diện ẩn/hiện chức năng. */
CREATE OR ALTER PROCEDURE api_chung.usp_ThongTinPhien
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaTK INT = sec.fn_MaTK();
    IF @MaTK IS NULL
        THROW 50001, N'Chưa đăng nhập: phiên chưa được thiết lập ngữ cảnh.', 1;

    SELECT tk.MaTK, tk.TenDangNhap, tk.LoaiTK, tk.MaVT, vt.TenVT, vt.CongTruyCap, tk.PhaiDoiMatKhau,
           sec.fn_MaKH() AS MaKH, sec.fn_MaNV() AS MaNV,
           COALESCE(k.HoTen, n.HoTen) AS HoTen,
           cv.TenCV AS ChucVu
    FROM crm.TAI_KHOAN tk
    JOIN crm.VAI_TRO vt          ON vt.MaVT = tk.MaVT
    LEFT JOIN crm.KHACH_HANG k   ON k.MaKH = sec.fn_MaKH()
    LEFT JOIN crm.NHAN_VIEN n    ON n.MaNV = sec.fn_MaNV()
    LEFT JOIN crm.CHUC_VU cv     ON cv.MaCV = n.MaCV
    WHERE tk.MaTK = @MaTK;

    SELECT q.MaQuyen, q.TenQuyen
    FROM crm.TAI_KHOAN tk
    JOIN crm.VAI_TRO_QUYEN vq ON vq.MaVT = tk.MaVT
    JOIN crm.QUYEN q          ON q.MaQuyen = vq.MaQuyen
    WHERE tk.MaTK = @MaTK
    ORDER BY q.MaQuyen;
END;
GO

/* Đổi mật khẩu: ứng dụng đã xác minh mật khẩu cũ và gửi chuỗi băm mới. */
CREATE OR ALTER PROCEDURE api_chung.usp_DoiMatKhau
    @MatKhauHashMoi VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @MaTK INT = sec.fn_MaTK();
    IF @MaTK IS NULL
        THROW 50001, N'Chưa đăng nhập: phiên chưa được thiết lập ngữ cảnh.', 1;
    IF @MatKhauHashMoi IS NULL OR LEN(@MatKhauHashMoi) < 50
        THROW 52001, N'Chuỗi băm mật khẩu không hợp lệ (CSDL không nhận mật khẩu thô).', 1;

    UPDATE crm.TAI_KHOAN
       SET MatKhauHash = @MatKhauHashMoi, PhaiDoiMatKhau = 0
     WHERE MaTK = @MaTK AND TrangThai = 'HOAT_DONG';
    IF @@ROWCOUNT = 0
        THROW 50012, N'Tài khoản không còn hoạt động.', 1;

    EXEC sec.usp_GhiNhatKy @HanhDong = 'DOI_MAT_KHAU', @DoiTuong = 'TAI_KHOAN', @MaDoiTuong = @MaTK;
END;
GO

/* ============================ api_kh ============================ */

/* 1. Đăng ký tài khoản khách hàng (phiên chưa đăng nhập). */
CREATE OR ALTER PROCEDURE api_kh.usp_DangKy
    @TenDangNhap   VARCHAR(50),
    @MatKhauHash   VARCHAR(255),
    @HoTen         NVARCHAR(100),
    @SDT           VARCHAR(10),
    @GioiTinh      VARCHAR(4)    = NULL,
    @NgaySinh      DATE          = NULL,
    @Email         VARCHAR(100)  = NULL,
    @MaTinh        VARCHAR(10)   = NULL,
    @DsLoaiQuanTam api_chung.DanhSachMa READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF SESSION_CONTEXT(N'MaTK') IS NOT NULL
        THROW 52010, N'Phiên đang đăng nhập, không thể đăng ký tài khoản mới.', 1;
    IF ISNULL(sec.fn_CongNguoiGoi(), '') NOT IN ('KHACH_HANG', 'DBO')
        THROW 50013, N'Chỉ cổng Khách hàng được phép đăng ký.', 1;
    IF @TenDangNhap IS NULL OR @MatKhauHash IS NULL
        THROW 52001, N'Tên đăng nhập và mật khẩu là bắt buộc.', 1;
    IF LEN(@MatKhauHash) < 50
        THROW 52001, N'Chuỗi băm mật khẩu không hợp lệ (CSDL không nhận mật khẩu thô).', 1;

    DECLARE @MaKH INT, @MaTK INT;
    BEGIN TRY
        BEGIN TRAN;
        EXEC crm.usp_TaoKhachHang_NoiBo
             @HoTen = @HoTen, @GioiTinh = @GioiTinh, @NgaySinh = @NgaySinh, @SDT = @SDT,
             @Email = @Email, @MaTinh = @MaTinh, @DsLoaiQuanTam = @DsLoaiQuanTam,
             @TenDangNhap = @TenDangNhap, @MatKhauHash = @MatKhauHash, @PhaiDoiMatKhau = 0,
             @MaKH = @MaKH OUTPUT, @MaTK = @MaTK OUTPUT;
        EXEC sec.usp_GhiNhatKy @HanhDong = 'DANG_KY', @DoiTuong = 'KHACH_HANG',
             @MaDoiTuong = @MaKH, @MaTK = @MaTK;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;

    SELECT @MaKH AS MaKH, @MaTK AS MaTK;
END;
GO

/* 2. Xem hồ sơ của chính mình (kèm hạng, điểm, sở thích). */
CREATE OR ALTER PROCEDURE api_kh.usp_XemHoSo
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'KH_HO_SO';
    DECLARE @MaKH INT = sec.fn_MaKH();

    SELECT k.MaKH, k.HoTen, k.GioiTinh, k.NgaySinh, k.Tuoi, k.SDT, k.Email, k.MaTinh, t.TenTinh,
           k.NgayDangKy, k.MaHang, h.TenHang, d.Diem,
           nx.TenHang AS HangKeTiep,
           CASE WHEN nx.DiemToiThieu IS NULL THEN NULL ELSE nx.DiemToiThieu - d.Diem END AS DiemCanThem
    FROM crm.vw_KhachHang_MoRong k
    JOIN crm.HANG_THANH_VIEN h  ON h.MaHang = k.MaHang
    JOIN crm.vw_DiemKhachHang d ON d.MaKH = k.MaKH
    LEFT JOIN crm.TINH_THANH t  ON t.MaTinh = k.MaTinh
    OUTER APPLY (SELECT TOP (1) x.TenHang, x.DiemToiThieu
                 FROM crm.HANG_THANH_VIEN x
                 WHERE x.DiemToiThieu > d.Diem
                 ORDER BY x.DiemToiThieu) nx
    WHERE k.MaKH = @MaKH;

    SELECT l.MaLoai, l.TenLoai
    FROM crm.KH_QUAN_TAM q JOIN crm.LOAI_SP l ON l.MaLoai = q.MaLoai
    WHERE q.MaKH = @MaKH
    ORDER BY l.TenLoai;
END;
GO

/* 3. Chỉnh sửa thông tin cá nhân và sở thích. */
CREATE OR ALTER PROCEDURE api_kh.usp_CapNhatHoSo
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
    EXEC sec.usp_KiemTraQuyen 'KH_HO_SO';
    DECLARE @MaKH INT = sec.fn_MaKH();

    SELECT @HoTen = NULLIF(TRIM(@HoTen), N''), @SDT = TRIM(@SDT), @Email = NULLIF(LOWER(TRIM(@Email)), '');
    IF @HoTen IS NULL OR @SDT IS NULL
        THROW 52001, N'Họ tên và số điện thoại là bắt buộc.', 1;

    BEGIN TRY
        BEGIN TRAN;
        UPDATE crm.KHACH_HANG
           SET HoTen = @HoTen, SDT = @SDT, GioiTinh = @GioiTinh, NgaySinh = @NgaySinh,
               Email = @Email, MaTinh = @MaTinh
         WHERE MaKH = @MaKH;

        IF @CapNhatSoThich = 1
        BEGIN
            DELETE crm.KH_QUAN_TAM WHERE MaKH = @MaKH;
            INSERT crm.KH_QUAN_TAM (MaKH, MaLoai) SELECT @MaKH, d.Ma FROM @DsLoaiQuanTam d;
        END

        EXEC sec.usp_GhiNhatKy @HanhDong = 'SUA_HO_SO', @DoiTuong = 'KHACH_HANG', @MaDoiTuong = @MaKH,
             @ChiTiet = N'Khách hàng tự cập nhật hồ sơ';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 52002, N'Số điện thoại hoặc email đã được một hồ sơ khác sử dụng.', 1;
        IF ERROR_NUMBER() = 547
            THROW 52001, N'Dữ liệu không hợp lệ (giới tính, ngày sinh, SĐT, email, tỉnh hoặc loại sản phẩm).', 1;
        THROW;
    END CATCH;
END;
GO

/* 4a. Gửi phản hồi về sản phẩm. */
CREATE OR ALTER PROCEDURE api_kh.usp_GuiPhanHoi
    @MaSP        INT,
    @LoaiPH      VARCHAR(10),
    @DiemDanhGia TINYINT,
    @NoiDung     NVARCHAR(2000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'KH_PHAN_HOI';
    DECLARE @MaKH INT = sec.fn_MaKH();

    SET @NoiDung = NULLIF(TRIM(@NoiDung), N'');
    IF @LoaiPH IS NULL OR @LoaiPH NOT IN ('KHEN', 'GOP_Y', 'KHIEU_NAI')
       OR @DiemDanhGia IS NULL OR @DiemDanhGia NOT BETWEEN 1 AND 5
       OR @NoiDung IS NULL
        THROW 52001, N'Phản hồi không hợp lệ: cần loại phản hồi, điểm 1-5 và nội dung.', 1;
    IF NOT EXISTS (SELECT 1 FROM crm.SAN_PHAM WHERE MaSP = @MaSP)
        THROW 52020, N'Sản phẩm không tồn tại.', 1;

    INSERT crm.PHAN_HOI (MaKH, MaSP, LoaiPH, DiemDanhGia, NoiDung)
    VALUES (@MaKH, @MaSP, @LoaiPH, @DiemDanhGia, @NoiDung);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS MaPH;
END;
GO

/* 4b. Xem phản hồi của mình và câu trả lời của doanh nghiệp. */
CREATE OR ALTER PROCEDURE api_kh.usp_XemPhanHoiCuaToi
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'KH_PHAN_HOI';
    DECLARE @MaKH INT = sec.fn_MaKH();

    SELECT ph.MaPH, ph.MaSP, sp.TenSP, ph.LoaiPH, ph.DiemDanhGia, ph.NoiDung, ph.NgayGui,
           ph.TrangThai, ph.NoiDungTraLoi, ph.NgayTraLoi
    FROM crm.PHAN_HOI ph
    JOIN crm.SAN_PHAM sp ON sp.MaSP = ph.MaSP
    WHERE ph.MaKH = @MaKH
    ORDER BY ph.NgayGui DESC;
END;
GO

/* 5a. Danh sách khảo sát đã được gửi tới tài khoản của mình. */
CREATE OR ALTER PROCEDURE api_kh.usp_DanhSachKhaoSat
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'KH_KHAO_SAT';
    DECLARE @MaKH INT = sec.fn_MaKH();

    SELECT g.MaKS, ks.TieuDe, ks.MoTa, ks.MucDich, ks.HanTraLoi, ks.PhanTramVoucher,
           g.NgayGui, g.NgayHoanThanh, g.TrangThai,
           CAST(CASE WHEN g.NgayHoanThanh IS NULL AND ks.TrangThai = 'DA_GUI'
                          AND ks.HanTraLoi >= SYSDATETIME() THEN 1 ELSE 0 END AS BIT) AS CoTheThucHien
    FROM crm.KHAO_SAT_GUI g
    JOIN crm.KHAO_SAT ks ON ks.MaKS = g.MaKS
    WHERE g.MaKH = @MaKH
    ORDER BY g.NgayGui DESC;
END;
GO

/* 5b. Xem nội dung một khảo sát (chỉ khi đã được gửi cho mình). */
CREATE OR ALTER PROCEDURE api_kh.usp_XemKhaoSat
    @MaKS INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'KH_KHAO_SAT';
    DECLARE @MaKH INT = sec.fn_MaKH();

    IF NOT EXISTS (SELECT 1 FROM crm.KHAO_SAT_GUI WHERE MaKS = @MaKS AND MaKH = @MaKH)
        THROW 52030, N'Không tìm thấy khảo sát.', 1;   -- không tiết lộ khảo sát của người khác

    SELECT ks.MaKS, ks.TieuDe, ks.MoTa, ks.MucDich, sp.TenSP, ks.HanTraLoi, ks.PhanTramVoucher,
           g.TrangThai AS TrangThaiCuaToi
    FROM crm.KHAO_SAT ks
    JOIN crm.KHAO_SAT_GUI g   ON g.MaKS = ks.MaKS AND g.MaKH = @MaKH
    LEFT JOIN crm.SAN_PHAM sp ON sp.MaSP = ks.MaSP
    WHERE ks.MaKS = @MaKS;

    SELECT c.MaCauHoi, c.ThuTu, c.NoiDung, c.LoaiCauHoi, c.BatBuoc
    FROM crm.CAU_HOI c WHERE c.MaKS = @MaKS ORDER BY c.ThuTu;

    SELECT l.MaLC, l.MaCauHoi, l.ThuTu, l.NoiDung
    FROM crm.LUA_CHON l JOIN crm.CAU_HOI c ON c.MaCauHoi = l.MaCauHoi
    WHERE c.MaKS = @MaKS ORDER BY c.ThuTu, l.ThuTu;

    -- Câu trả lời của chính mình (nếu đã hoàn thành)
    SELECT t.MaCauHoi, t.DiemSo, t.NoiDungTuLuan, lc.MaLC
    FROM crm.TRA_LOI t
    LEFT JOIN crm.TRA_LOI_LUA_CHON lc
           ON lc.MaKS = t.MaKS AND lc.MaKH = t.MaKH AND lc.MaCauHoi = t.MaCauHoi
    WHERE t.MaKS = @MaKS AND t.MaKH = @MaKH;
END;
GO

/* 5c. Nộp bài khảo sát: kiểm tra đầy đủ rồi ghi trong 1 giao dịch;
       tự phát voucher nếu khảo sát có PhanTramVoucher > 0. */
CREATE OR ALTER PROCEDURE api_kh.usp_NopKhaoSat
    @MaKS   INT,
    @TraLoi api_kh.BangTraLoi READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC sec.usp_KiemTraQuyen 'KH_KHAO_SAT';
    DECLARE @MaKH INT = sec.fn_MaKH();
    DECLARE @TrangThaiKS VARCHAR(8), @HanTraLoi DATETIME2(0), @PhanTram TINYINT, @SoNgayHL SMALLINT,
            @NgayHoanThanh DATETIME2(0), @DaGui BIT = 0, @MaCode VARCHAR(20) = NULL, @HanDung DATETIME2(0) = NULL;

    BEGIN TRY
        BEGIN TRAN;

        -- Khóa dòng gửi để chặn nộp hai lần đồng thời
        SELECT @DaGui = 1, @NgayHoanThanh = g.NgayHoanThanh
        FROM crm.KHAO_SAT_GUI g WITH (UPDLOCK, HOLDLOCK)
        WHERE g.MaKS = @MaKS AND g.MaKH = @MaKH;

        IF @DaGui = 0
            THROW 52030, N'Không tìm thấy khảo sát.', 1;
        IF @NgayHoanThanh IS NOT NULL
            THROW 52031, N'Bạn đã hoàn thành khảo sát này.', 1;

        SELECT @TrangThaiKS = TrangThai, @HanTraLoi = HanTraLoi,
               @PhanTram = PhanTramVoucher, @SoNgayHL = SoNgayHieuLucVoucher
        FROM crm.KHAO_SAT WHERE MaKS = @MaKS;

        IF @TrangThaiKS <> 'DA_GUI' OR @HanTraLoi < SYSDATETIME()
            THROW 52031, N'Khảo sát đã đóng hoặc đã quá hạn trả lời.', 1;

        -- (a) mọi câu trong bài nộp phải thuộc khảo sát này
        IF EXISTS (SELECT 1 FROM @TraLoi t
                   WHERE NOT EXISTS (SELECT 1 FROM crm.CAU_HOI c WHERE c.MaCauHoi = t.MaCauHoi AND c.MaKS = @MaKS))
            THROW 52032, N'Bài nộp có câu hỏi không thuộc khảo sát.', 1;

        -- (b) đủ các câu bắt buộc
        IF EXISTS (SELECT 1 FROM crm.CAU_HOI c
                   WHERE c.MaKS = @MaKS AND c.BatBuoc = 1
                     AND NOT EXISTS (SELECT 1 FROM @TraLoi t WHERE t.MaCauHoi = c.MaCauHoi))
            THROW 52032, N'Chưa trả lời đủ các câu hỏi bắt buộc.', 1;

        -- (c) câu chọn: phải có MaLC thuộc đúng câu, không kèm điểm/tự luận
        IF EXISTS (SELECT 1 FROM @TraLoi t JOIN crm.CAU_HOI c ON c.MaCauHoi = t.MaCauHoi
                   WHERE c.LoaiCauHoi IN ('MOT_LUA_CHON', 'NHIEU_LUA_CHON')
                     AND (t.MaLC IS NULL OR t.DiemSo IS NOT NULL OR t.NoiDungTuLuan IS NOT NULL
                          OR NOT EXISTS (SELECT 1 FROM crm.LUA_CHON l WHERE l.MaLC = t.MaLC AND l.MaCauHoi = t.MaCauHoi)))
            THROW 52032, N'Lựa chọn không hợp lệ cho câu hỏi trắc nghiệm.', 1;

        -- (d) số dòng mỗi câu: câu 1 lựa chọn/thang điểm/tự luận đúng 1 dòng; nhiều lựa chọn không trùng
        IF EXISTS (SELECT 1 FROM @TraLoi t JOIN crm.CAU_HOI c ON c.MaCauHoi = t.MaCauHoi
                   GROUP BY t.MaCauHoi, c.LoaiCauHoi
                   HAVING (c.LoaiCauHoi <> 'NHIEU_LUA_CHON' AND COUNT(*) > 1)
                       OR COUNT(*) <> COUNT(DISTINCT ISNULL(t.MaLC, -1)))
            THROW 52032, N'Mỗi câu chỉ được trả lời một lần (trừ câu nhiều lựa chọn).', 1;

        -- (e) thang điểm 1-5 / tự luận có nội dung
        IF EXISTS (SELECT 1 FROM @TraLoi t JOIN crm.CAU_HOI c ON c.MaCauHoi = t.MaCauHoi
                   WHERE (c.LoaiCauHoi = 'THANG_DIEM'
                          AND (t.DiemSo IS NULL OR t.DiemSo NOT BETWEEN 1 AND 5 OR t.MaLC IS NOT NULL OR t.NoiDungTuLuan IS NOT NULL))
                      OR (c.LoaiCauHoi = 'TU_LUAN'
                          AND (NULLIF(TRIM(t.NoiDungTuLuan), N'') IS NULL OR t.MaLC IS NOT NULL OR t.DiemSo IS NOT NULL)))
            THROW 52032, N'Câu thang điểm cần điểm 1-5; câu tự luận cần nội dung.', 1;

        INSERT crm.TRA_LOI (MaKS, MaKH, MaCauHoi, LoaiCauHoi, DiemSo, NoiDungTuLuan)
        SELECT @MaKS, @MaKH, c.MaCauHoi, c.LoaiCauHoi,
               MAX(CASE WHEN c.LoaiCauHoi = 'THANG_DIEM' THEN t.DiemSo END),
               MAX(CASE WHEN c.LoaiCauHoi = 'TU_LUAN' THEN TRIM(t.NoiDungTuLuan) END)
        FROM @TraLoi t JOIN crm.CAU_HOI c ON c.MaCauHoi = t.MaCauHoi
        GROUP BY c.MaCauHoi, c.LoaiCauHoi;

        INSERT crm.TRA_LOI_LUA_CHON (MaKS, MaKH, MaCauHoi, MaLC)
        SELECT @MaKS, @MaKH, t.MaCauHoi, t.MaLC FROM @TraLoi t WHERE t.MaLC IS NOT NULL;

        UPDATE crm.KHAO_SAT_GUI SET NgayHoanThanh = SYSDATETIME()
        WHERE MaKS = @MaKS AND MaKH = @MaKH;

        IF @PhanTram > 0
        BEGIN
            SET @MaCode  = CONCAT('V', @MaKS, '-', LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 8));
            SET @HanDung = DATEADD(DAY, @SoNgayHL, SYSDATETIME());
            INSERT crm.VOUCHER (MaCode, MaKH, MaKS, PhanTramGiam, HanDung)
            VALUES (@MaCode, @MaKH, @MaKS, @PhanTram, @HanDung);
        END

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;

    SELECT N'Đã ghi nhận bài khảo sát.' AS ThongBao, @MaCode AS MaVoucher, @PhanTram AS PhanTramGiam, @HanDung AS HanDung;
END;
GO

/* 5d. Voucher của tôi (trạng thái suy ra, không lưu). */
CREATE OR ALTER PROCEDURE api_kh.usp_XemVoucherCuaToi
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sec.usp_KiemTraQuyen 'KH_HO_SO';
    DECLARE @MaKH INT = sec.fn_MaKH();

    SELECT v.MaCode, v.PhanTramGiam, v.NgayPhat, v.HanDung, ks.TieuDe AS TuKhaoSat,
           CASE WHEN h.MaHD IS NOT NULL       THEN 'DA_DUNG'
                WHEN v.HanDung < SYSDATETIME() THEN 'HET_HAN'
                ELSE 'CON_HAN' END AS TrangThai
    FROM crm.VOUCHER v
    JOIN crm.KHAO_SAT ks    ON ks.MaKS = v.MaKS
    LEFT JOIN crm.HOA_DON h ON h.MaVoucher = v.MaVoucher
    WHERE v.MaKH = @MaKH
    ORDER BY v.NgayPhat DESC;
END;
GO

PRINT N'Script 05a hoàn tất.';
GO

/* #################### 05b_API_QuanLy.sql #################### */
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

/* #################### 05c_API_Admin.sql #################### */
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

/* #################### 06_PhanQuyen_RLS.sql #################### */
/* =====================================================================
   Script 06: Phân quyền SQL Server và Row-Level Security
   ---------------------------------------------------------------------
   LỚP 1 – TRẦN QUYỀN THEO CỔNG (SQL Server)
     LOGIN (server)        USER (database)     ROLE (database)
     crm_app_admin    ->   u_app_admin    ->   r_admin      : EXECUTE schema api_admin
     crm_app_quanly   ->   u_app_quanly   ->   r_quanly     : EXECUTE schema api_ql
     crm_app_khachhang->   u_app_khachhang->   r_khachhang  : EXECUTE schema api_kh
     Cả 3 role: EXECUTE + SELECT schema api_chung, EXECUTE sec.usp_DatNguCanh.
     KHÔNG role nào có quyền trực tiếp trên bảng trong schema crm và audit (DENY tường minh).
     Không ai được cấp sysadmin/db_owner.
   LỚP 2 – QUYỀN CHỨC NĂNG (dữ liệu VAI_TRO/QUYEN/VAI_TRO_QUYEN, Admin chỉnh)
     Kiểm tra trong từng thủ tục bằng sec.usp_KiemTraQuyen.
   LỚP 3 – PHẠM VI DỮ LIỆU
     - Khách hàng: thủ tục chỉ dùng MaKH trong SESSION_CONTEXT +
       Row-Level Security trên 7 bảng chứa dữ liệu của từng khách.
     - Quản lý/Admin: phạm vi toàn doanh nghiệp (đề không yêu cầu chia theo
       cửa hàng hay nhân viên phụ trách).
   CHẠY BẰNG: sysadmin (hoặc securityadmin + db_owner).
   TRƯỚC KHI CHẠY: đổi 3 mật khẩu ở phần 1. Máy chủ phải bật SQL Server
   and Windows Authentication mode nếu dùng SQL login.
   ===================================================================== */
USE CRM_Uniqlo;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

/* ---------------------- 1. LOGIN + USER ---------------------- */
DECLARE @MK_Admin     NVARCHAR(128) = N'Doi_MatKhau_Admin#2026',      -- ĐỔI TRƯỚC KHI TRIỂN KHAI
        @MK_QuanLy    NVARCHAR(128) = N'Doi_MatKhau_QuanLy#2026',     -- ĐỔI TRƯỚC KHI TRIỂN KHAI
        @MK_KhachHang NVARCHAR(128) = N'Doi_MatKhau_KhachHang#2026',  -- ĐỔI TRƯỚC KHI TRIỂN KHAI
        @Lenh NVARCHAR(MAX);

IF SUSER_ID(N'crm_app_admin') IS NULL
BEGIN
    SET @Lenh = N'CREATE LOGIN crm_app_admin WITH PASSWORD = ' + QUOTENAME(@MK_Admin, '''')
              + N', DEFAULT_DATABASE = CRM_Uniqlo, CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;';
    EXEC sys.sp_executesql @Lenh;
END
IF SUSER_ID(N'crm_app_quanly') IS NULL
BEGIN
    SET @Lenh = N'CREATE LOGIN crm_app_quanly WITH PASSWORD = ' + QUOTENAME(@MK_QuanLy, '''')
              + N', DEFAULT_DATABASE = CRM_Uniqlo, CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;';
    EXEC sys.sp_executesql @Lenh;
END
IF SUSER_ID(N'crm_app_khachhang') IS NULL
BEGIN
    SET @Lenh = N'CREATE LOGIN crm_app_khachhang WITH PASSWORD = ' + QUOTENAME(@MK_KhachHang, '''')
              + N', DEFAULT_DATABASE = CRM_Uniqlo, CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;';
    EXEC sys.sp_executesql @Lenh;
END
GO

IF USER_ID(N'u_app_admin') IS NULL     CREATE USER u_app_admin     FOR LOGIN crm_app_admin     WITH DEFAULT_SCHEMA = api_admin;
IF USER_ID(N'u_app_quanly') IS NULL    CREATE USER u_app_quanly    FOR LOGIN crm_app_quanly    WITH DEFAULT_SCHEMA = api_ql;
IF USER_ID(N'u_app_khachhang') IS NULL CREATE USER u_app_khachhang FOR LOGIN crm_app_khachhang WITH DEFAULT_SCHEMA = api_kh;
GO

/* ---------------------- 2. DATABASE ROLE ---------------------- */
IF DATABASE_PRINCIPAL_ID(N'r_admin') IS NULL     CREATE ROLE r_admin AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'r_quanly') IS NULL    CREATE ROLE r_quanly AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'r_khachhang') IS NULL CREATE ROLE r_khachhang AUTHORIZATION dbo;
GO
IF IS_ROLEMEMBER(N'r_admin', N'u_app_admin') = 0         ALTER ROLE r_admin ADD MEMBER u_app_admin;
IF IS_ROLEMEMBER(N'r_quanly', N'u_app_quanly') = 0       ALTER ROLE r_quanly ADD MEMBER u_app_quanly;
IF IS_ROLEMEMBER(N'r_khachhang', N'u_app_khachhang') = 0 ALTER ROLE r_khachhang ADD MEMBER u_app_khachhang;
GO

/* ---------------------- 3. CẤP QUYỀN (đặc quyền tối thiểu) ---------------------- */
-- Dùng chung
GRANT EXECUTE ON SCHEMA::api_chung TO r_admin, r_quanly, r_khachhang;
GRANT SELECT  ON SCHEMA::api_chung TO r_admin, r_quanly, r_khachhang;   -- view danh mục công khai
GRANT EXECUTE ON OBJECT::sec.usp_DatNguCanh TO r_admin, r_quanly, r_khachhang;
-- Theo cổng
GRANT EXECUTE ON SCHEMA::api_admin TO r_admin;
GRANT EXECUTE ON SCHEMA::api_ql    TO r_quanly;
GRANT EXECUTE ON SCHEMA::api_kh    TO r_khachhang;
-- Kiểu bảng (TVP) cần quyền EXECUTE để khai báo tham số
GRANT EXECUTE ON TYPE::api_chung.DanhSachMa         TO r_quanly, r_khachhang;
GRANT EXECUTE ON TYPE::api_kh.BangTraLoi            TO r_khachhang;
GRANT EXECUTE ON TYPE::api_ql.DanhSachLuaChon       TO r_quanly;
GRANT EXECUTE ON TYPE::api_admin.DanhSachMaQuyen    TO r_admin;
GRANT EXECUTE ON TYPE::api_admin.BangChiTietHoaDon  TO r_admin;
-- Chặn tường minh truy cập trực tiếp bảng (phòng khi ai đó lỡ cấp cho public).
-- Chuỗi sở hữu (cùng chủ dbo) vẫn cho thủ tục api_* đọc/ghi bảng bình thường.
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::crm   TO r_admin, r_quanly, r_khachhang;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::audit TO r_admin, r_quanly, r_khachhang;
DENY SELECT ON SCHEMA::api_admin TO r_quanly, r_khachhang;   -- view admin chỉ dùng trong thủ tục
DENY SELECT ON SCHEMA::api_ql    TO r_admin, r_khachhang;
GO

/* ---------------------- 4. ROW-LEVEL SECURITY ---------------------- */
/* Vị từ: người gọi KHÔNG thuộc r_khachhang -> thấy mọi dòng (Quản lý, Admin,
   dbo, thủ tục EXECUTE AS OWNER); người gọi thuộc r_khachhang -> chỉ thấy/ghi
   dòng có MaKH = MaKH trong SESSION_CONTEXT (do sec.usp_DatNguCanh đặt read-only).
   - FILTER: lọc âm thầm khi SELECT/UPDATE/DELETE (dòng người khác "không tồn tại").
   - BLOCK AFTER INSERT/UPDATE: chặn ghi dòng mang MaKH của người khác
     (hoặc sửa MaKH sang người khác). Lỗi trả về: Msg 33504.
   Bảng HOA_DON/DOI_TRA không cần RLS vì cổng Khách hàng không đọc chúng
   trực tiếp (không có chức năng xem hóa đơn trong đề). */
IF NOT EXISTS (SELECT 1 FROM sys.security_policies WHERE name = N'pol_DuLieuKhachHang')
BEGIN
    EXEC (N'
CREATE OR ALTER FUNCTION sec.fn_rls_TheoKhachHang (@MaKH INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS DuocPhep
    WHERE ISNULL(IS_MEMBER(N''r_khachhang''), 0) = 0
       OR @MaKH = CAST(SESSION_CONTEXT(N''MaKH'') AS INT);');

    EXEC (N'
CREATE SECURITY POLICY sec.pol_DuLieuKhachHang
    ADD FILTER PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KHACH_HANG,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KHACH_HANG AFTER INSERT,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KHACH_HANG AFTER UPDATE,
    ADD FILTER PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KH_QUAN_TAM,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KH_QUAN_TAM AFTER INSERT,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KH_QUAN_TAM AFTER UPDATE,
    ADD FILTER PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.PHAN_HOI,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.PHAN_HOI AFTER INSERT,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.PHAN_HOI AFTER UPDATE,
    ADD FILTER PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KHAO_SAT_GUI,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KHAO_SAT_GUI AFTER INSERT,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KHAO_SAT_GUI AFTER UPDATE,
    ADD FILTER PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.TRA_LOI,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.TRA_LOI AFTER INSERT,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.TRA_LOI AFTER UPDATE,
    ADD FILTER PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.TRA_LOI_LUA_CHON,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.TRA_LOI_LUA_CHON AFTER INSERT,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.TRA_LOI_LUA_CHON AFTER UPDATE,
    ADD FILTER PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.VOUCHER,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.VOUCHER AFTER INSERT,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.VOUCHER AFTER UPDATE
WITH (STATE = ON, SCHEMABINDING = ON);');
    PRINT N'Đã tạo security policy sec.pol_DuLieuKhachHang.';
END
ELSE
    PRINT N'Security policy đã tồn tại – bỏ qua.';
GO

/* ---------------------- 5. KIỂM TRA NHANH SAU KHI CẤP QUYỀN ---------------------- */
SELECT r.name AS DatabaseRole, m.name AS ThanhVien
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name IN (N'r_admin', N'r_quanly', N'r_khachhang', N'db_owner');

SELECT pr.name AS NguoiNhan, pe.state_desc AS TrangThai, pe.permission_name AS Quyen,
       pe.class_desc AS LoaiDoiTuong,
       COALESCE(SCHEMA_NAME(CASE WHEN pe.class = 3 THEN pe.major_id END),
                OBJECT_SCHEMA_NAME(CASE WHEN pe.class = 1 THEN pe.major_id END) + N'.' + OBJECT_NAME(CASE WHEN pe.class = 1 THEN pe.major_id END),
                (SELECT SCHEMA_NAME(t.schema_id) + N'.' + t.name FROM sys.types t WHERE pe.class = 6 AND t.user_type_id = pe.major_id)) AS DoiTuong
FROM sys.database_permissions pe
JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name IN (N'r_admin', N'r_quanly', N'r_khachhang')
ORDER BY pr.name, pe.state_desc, DoiTuong;

SELECT p.name AS ChinhSach, p.is_enabled, OBJECT_SCHEMA_NAME(sp.target_object_id) + N'.' + OBJECT_NAME(sp.target_object_id) AS Bang,
       sp.predicate_type_desc, sp.operation_desc
FROM sys.security_policies p
JOIN sys.security_predicates sp ON sp.object_id = p.object_id
ORDER BY Bang, sp.predicate_type_desc;
GO
PRINT N'Script 06 hoàn tất.';
GO

/* #################### 07_DuLieuHeThong.sql #################### */
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

/* #################### 08_DuLieuMau.sql #################### */
/* =====================================================================
   Script 08: Dữ liệu mẫu (demo)
   ---------------------------------------------------------------------
   - Toàn bộ là dữ liệu GIẢ (tên, SĐT 0901xxxxxx/0912xxxxxx, email @example.com).
   - Mật khẩu demo của MỌI tài khoản: Demo@2026 (đã băm bcrypt cost 10; CSDL
     chỉ lưu chuỗi băm). Đổi/ xóa trước khi triển khai thật.
   - Chỉ chạy khi CSDL chưa có tài khoản nào (tránh chèn trùng).
   - Ngày của khảo sát đang mở và voucher còn hạn được tính TƯƠNG ĐỐI theo
     thời điểm chạy script để demo luôn hợp lệ; dữ liệu lịch sử dùng ngày cố định 2026.
   ===================================================================== */
USE CRM_Uniqlo;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
IF EXISTS (SELECT 1 FROM crm.TAI_KHOAN)
BEGIN
    PRINT N'CSDL đã có dữ liệu tài khoản – bỏ qua script dữ liệu mẫu.';
    SET NOEXEC ON;
END
GO

BEGIN TRAN;
DECLARE @Nay DATETIME2(0) = SYSDATETIME();

/* ---------- Vai trò demo do Admin tạo (minh họa phân quyền theo account) ---------- */
INSERT crm.VAI_TRO (MaVT, TenVT, LoaiTK, CongTruyCap, MoTa) VALUES
 ('NV_CSKH',       N'Nhân viên CSKH',          'NV', 'QUAN_LY', N'Cổng Quản lý nhưng chỉ xem KH và xử lý phản hồi'),
 ('QTV_TAI_KHOAN', N'Quản trị viên tài khoản', 'NV', 'ADMIN',   N'Cổng Admin nhưng chỉ quản lý tài khoản và tra cứu');
INSERT crm.VAI_TRO_QUYEN (MaVT, MaQuyen, CongTruyCap) VALUES
 ('NV_CSKH', 'QL_KH_XEM', 'QUAN_LY'), ('NV_CSKH', 'QL_PH_XEM', 'QUAN_LY'),
 ('NV_CSKH', 'QL_PH_XU_LY', 'QUAN_LY'), ('NV_CSKH', 'QL_KS_THONG_KE', 'QUAN_LY'),
 ('QTV_TAI_KHOAN', 'AD_TAI_KHOAN', 'ADMIN'), ('QTV_TAI_KHOAN', 'AD_TRA_CUU', 'ADMIN');

/* ---------- Tài khoản (mật khẩu demo Demo@2026, lưu dạng bcrypt) ---------- */
SET IDENTITY_INSERT crm.TAI_KHOAN ON;
INSERT crm.TAI_KHOAN (MaTK, TenDangNhap, MatKhauHash, MaVT, LoaiTK, TrangThai, PhaiDoiMatKhau, NgayTao, NgayKhoa, LyDoKhoa) VALUES
 (1, 'admin.it', '$2b$10$Mt1cv.f2n700Js7Wlag.qeqYb/5KzW1c8cFcQBeGFy5DVu1/WIOae', 'ADMIN', 'NV', 'HOAT_DONG', 0, '2025-06-01 08:00', NULL, NULL),
 (2, 'gd.minh', '$2b$10$RKMe3N3rw4oJkdYxz/5suuom9.8oasuxxRNqUzjnWTNt2pDZIDHiu', 'QUAN_LY', 'NV', 'HOAT_DONG', 0, '2025-06-01 08:05', NULL, NULL),
 (3, 'ql.lan', '$2b$10$/SLZ2eJQOGoX6WN9Hfs77Odzv7RXEi5zMz7pIPIEnB.lSkF7K6zKa', 'QUAN_LY', 'NV', 'HOAT_DONG', 0, '2025-06-01 08:10', NULL, NULL),
 (4, 'cskh.hoa', '$2b$10$uXC20TGLBGzAbDTMKPKARuNoBmNrHLtAb.sgSgVlTHt8N3qP6HgxK', 'NV_CSKH', 'NV', 'HOAT_DONG', 0, '2025-06-02 09:00', NULL, NULL),
 (5, 'it.mai', '$2b$10$Xg69r5cIM9kJFmw5Rj2r/uF2dbQowOOlD0PE17lwVOHBleHITzP26', 'QTV_TAI_KHOAN', 'NV', 'HOAT_DONG', 0, '2025-07-01 09:00', NULL, NULL),
 (6, 'kh.an', '$2b$10$eWVBe5JjKzcJ3s5c5Dp.qONhinFmd.WUOt4pxxo21gSz3pOEDaWr.', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2025-11-02 10:00', NULL, NULL),
 (7, 'kh.binh', '$2b$10$jOLmg4cTMASkM9Tg4Zf1DurXlnKqVhk5syDZIPL2uuWb398uPWjtC', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2025-12-15 11:00', NULL, NULL),
 (8, 'kh.chau', '$2b$10$S9YpmhYkMcJ7lHNTXx9VDO.Cg4NSKQXxjpBMiTNfbeuTAYzNoNTdW', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2026-01-20 12:00', NULL, NULL),
 (9, 'kh.dung', '$2b$10$A/RlSAn4Uul/flCT1OMq2e4YN6Tkmrhjci.k0Sxh.3EbO7bZ0Qyq2', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2026-02-03 13:00', NULL, NULL),
 (10, 'kh.ha', '$2b$10$SzvyiKE.kiVzAm7r/tIO9OvLkH273LLBM98bejsPy9JzT.o.UntPa', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2026-02-10 14:00', NULL, NULL),
 (11, 'kh.khanh', '$2b$10$NPQYZSFk4rwVJhtupUlzfOS5vNJO0r6rGs4KJnzgFScnjIxhJx6u.', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2026-03-01 15:00', NULL, NULL),
 (12, 'kh.lananh', '$2b$10$/aEJAbYgP/HsSgt7PniHHeJJAyXaiFPYtYElmjCSJBaL5a1XUy/N2', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2026-04-05 16:00', NULL, NULL),
 (13, 'kh.phong', '$2b$10$74vfMdcY3lDY3wdh5TJH3eC4kt5V6bSNXVe.pmBFw5B6vK//3GnsS', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2026-04-18 17:00', NULL, NULL),
 (14, 'kh.quyen', '$2b$10$raX85zd8/PsHe0OUzC1sIu/NLwdKkaXU5BZLXDAR76.WVRyVEaf0.', 'KHACH_HANG', 'KH', 'DA_KHOA', 0, '2026-03-20 18:00', '2026-09-01 09:30', N'Đăng nhập bất thường nhiều lần, chờ xác minh'),
 (15, 'kh.nam', '$2b$10$q9tU8HEP80oGR7YXc1QedevbI4izV6omYjSZ6JUAfI6drMrUqqzNG', 'KHACH_HANG', 'KH', 'DA_KHOA', 0, '2026-01-05 19:00', '2026-06-30 10:00', N'Hồ sơ khách hàng đã bị xóa'),
 (16, 'kh.thao', '$2b$10$eqV9Z55t2Qo9FZ2.Fw/mvO7r0kMUYtwtL4XGldduTtCCWHY3aBFl.', 'KHACH_HANG', 'KH', 'HOAT_DONG', 0, '2026-05-22 20:00', NULL, NULL);
SET IDENTITY_INSERT crm.TAI_KHOAN OFF;

/* ---------- Cửa hàng, nhân viên ---------- */
SET IDENTITY_INSERT crm.CUA_HANG ON;
INSERT crm.CUA_HANG (MaCH, TenCH, DiaChi, MaTinh, SDT) VALUES
 (1, N'Cửa hàng Quận 1',    N'Số 10 Đường A, Quận 1',       'HCM', '02800000001'),
 (2, N'Cửa hàng Hoàn Kiếm', N'Số 20 Phố B, Quận Hoàn Kiếm', 'HN',  '02400000002'),
 (3, N'Cửa hàng Hải Châu',  N'Số 30 Đường C, Quận Hải Châu', 'DN', '02360000003');
SET IDENTITY_INSERT crm.CUA_HANG OFF;

/* Giám đốc là một nhân viên có chức vụ GIAM_DOC (không có bảng riêng).
   Chức vụ và vai trò hệ thống độc lập: NV4 (IT) mang vai trò ADMIN, GĐ mang vai trò QUAN_LY. */
SET IDENTITY_INSERT crm.NHAN_VIEN ON;
INSERT crm.NHAN_VIEN (MaNV, HoTen, MaCV, MaCH, SDT, Email, NgayVaoLam, TrangThai, MaTK) VALUES
 (1, N'Nguyễn Văn Minh', 'GIAM_DOC',    NULL, '0912000001', 'minh.nguyen@nv.example.com', '20200102', 'DANG_LAM', 2),
 (2, N'Lê Thị Lan',      'QL_CSKH',     1,    '0912000002', 'lan.le@nv.example.com',      '20210315', 'DANG_LAM', 3),
 (3, N'Phạm Thu Hoa',    'NV_CSKH',     1,    '0912000003', 'hoa.pham@nv.example.com',    '20230601', 'DANG_LAM', 4),
 (4, N'Trần Quốc Bảo',   'NV_IT',       NULL, '0912000004', 'bao.tran@nv.example.com',    '20220910', 'DANG_LAM', 1),
 (5, N'Võ Thanh Tùng',   'NV_BAN_HANG', 1,    '0912000005', 'tung.vo@nv.example.com',     '20240201', 'DANG_LAM', NULL),
 (6, N'Đặng Mỹ Linh',    'NV_BAN_HANG', 2,    '0912000006', 'linh.dang@nv.example.com',   '20240512', 'DANG_LAM', NULL),
 (7, N'Hồ Gia Huy',      'NV_BAN_HANG', 3,    '0912000007', 'huy.ho@nv.example.com',      '20250106', 'DANG_LAM', NULL),
 (8, N'Ngô Thị Mai',     'NV_IT',       NULL, '0912000008', 'mai.ngo@nv.example.com',     '20250701', 'DANG_LAM', 5);
SET IDENTITY_INSERT crm.NHAN_VIEN OFF;

/* ---------- Nhà cung cấp, loại sản phẩm, sản phẩm ---------- */
SET IDENTITY_INSERT crm.NHA_CUNG_CAP ON;
INSERT crm.NHA_CUNG_CAP (MaNCC, TenNCC, QuocGia, DiaChi, SDT, Email, TrangThai) VALUES
 (1, N'Công ty TNHH Dệt May Phương Nam',      N'Việt Nam',   N'KCN Tân Bình, TP. Hồ Chí Minh', '02838000001',    'lienhe@phuongnam.example.com', 'DANG_HOP_TAC'),
 (2, N'Công ty CP May Sông Hồng Xanh',        N'Việt Nam',   N'KCN Phố Nối, Hưng Yên',          '02213000002',    'sales@songhongxanh.example.com', 'DANG_HOP_TAC'),
 (3, N'Dong A Textile Co., Ltd.',              N'Trung Quốc', N'Quảng Châu',                     '+86 20 0000 0003', 'export@donga.example.com',     'DANG_HOP_TAC'),
 (4, N'Công ty TNHH Phụ Kiện Thời Trang Mai Anh', N'Việt Nam', N'Quận 5, TP. Hồ Chí Minh',        '02838000004',    'info@maianh.example.com',       'NGUNG_HOP_TAC');
SET IDENTITY_INSERT crm.NHA_CUNG_CAP OFF;

SET IDENTITY_INSERT crm.LOAI_SP ON;
INSERT crm.LOAI_SP (MaLoai, TenLoai, MoTa) VALUES
 (1, N'Áo thun', NULL), (2, N'Áo khoác', NULL), (3, N'Quần jeans', NULL), (4, N'Quần âu/kaki', NULL),
 (5, N'Đầm/váy', NULL), (6, N'Đồ mặc nhà', NULL), (7, N'Phụ kiện', NULL);
SET IDENTITY_INSERT crm.LOAI_SP OFF;

SET IDENTITY_INSERT crm.SAN_PHAM ON;
INSERT crm.SAN_PHAM (MaSP, MaSKU, TenSP, MaLoai, MaNCC, ChatLieu, GiaNiemYet, TrangThai, NgayRaMat) VALUES
 (1,  'AT-001', N'Áo thun cotton cổ tròn nam',        1, 1, N'100% cotton',          249000,  'DANG_BAN',   NULL),
 (2,  'AT-002', N'Áo thun cotton cổ tròn nữ',         1, 1, N'100% cotton',          249000,  'DANG_BAN',   NULL),
 (3,  'AT-003', N'Áo polo vải pique nam',             1, 2, N'Cotton pique',         399000,  'DANG_BAN',   NULL),
 (4,  'AK-001', N'Áo khoác chần bông siêu nhẹ',       2, 2, N'Nylon, lông vũ',       1290000, 'DANG_BAN',   NULL),
 (5,  'AK-002', N'Áo khoác gió chống nước',           2, 3, N'Polyester',            799000,  'DANG_BAN',   NULL),
 (6,  'QJ-001', N'Quần jeans dáng slim nam',          3, 3, N'Denim co giãn',        799000,  'DANG_BAN',   NULL),
 (7,  'QJ-002', N'Quần jeans ống rộng nữ',            3, 3, N'Denim',                899000,  'DANG_BAN',   NULL),
 (8,  'QK-001', N'Quần kaki co giãn',                 4, 1, N'Cotton, spandex',      599000,  'DANG_BAN',   NULL),
 (9,  'DV-001', N'Đầm suông vải lanh',                5, 2, N'Linen',                699000,  'DANG_BAN',   NULL),
 (10, 'DM-001', N'Bộ mặc nhà vải modal',              6, 1, N'Modal',                499000,  'DANG_BAN',   NULL),
 (11, 'PK-001', N'Mũ lưỡi trai cotton',               7, 4, N'Cotton',               199000,  'NGUNG_BAN',  NULL),
 (12, 'PK-002', N'Túi đeo chéo mini',                 7, 3, N'Polyester',            299000,  'DANG_BAN',   NULL),
 (13, 'AK-003', N'Áo khoác lông cừu nhân tạo 2026',   2, 2, N'Polyester fleece',     990000,  'SAP_RA_MAT', '20261120'),
 (14, 'AT-004', N'Áo thun làm mát thế hệ mới',        1, 1, N'Sợi làm mát',          299000,  'SAP_RA_MAT', '20261201');
SET IDENTITY_INSERT crm.SAN_PHAM OFF;

/* ---------- Khách hàng: một bảng cho cả thường và VIP; hạng do hệ thống xét ở cuối script ---------- */
SET IDENTITY_INSERT crm.KHACH_HANG ON;
INSERT crm.KHACH_HANG (MaKH, HoTen, GioiTinh, NgaySinh, SDT, Email, MaTinh, NgayDangKy, MaTK, TrangThaiHoSo, NgayXoa) VALUES
 (1, N'Nguyễn Thị An', 'NU', '19980412', '0901000001', 'an.nguyen@example.com', 'HCM', '2025-11-02 10:00', 6, 'HOAT_DONG', NULL),
 (2, N'Trần Văn Bình', 'NAM', '19900923', '0901000002', 'binh.tran@example.com', 'HN', '2025-12-15 11:00', 7, 'HOAT_DONG', NULL),
 (3, N'Lê Minh Châu', 'NU', '20030130', '0901000003', 'chau.le@example.com', 'HCM', '2026-01-20 12:00', 8, 'HOAT_DONG', NULL),
 (4, N'Phạm Quốc Dũng', 'NAM', '19850605', '0901000004', 'dung.pham@example.com', 'DN', '2026-02-03 13:00', 9, 'HOAT_DONG', NULL),
 (5, N'Hoàng Thu Hà', 'NU', '19951111', '0901000005', 'ha.hoang@example.com', 'HCM', '2026-02-10 14:00', 10, 'HOAT_DONG', NULL),
 (6, N'Vũ Đức Khánh', 'NAM', '19780317', '0901000006', NULL, 'HN', '2026-03-01 15:00', 11, 'HOAT_DONG', NULL),
 (7, N'Đỗ Ngọc Lan Anh', 'NU', '20060721', '0901000007', 'lananh.do@example.com', 'CT', '2026-04-05 16:00', 12, 'HOAT_DONG', NULL),
 (8, N'Bùi Thanh Phong', 'NAM', '19681202', '0901000008', 'phong.bui@example.com', 'HP', '2026-04-18 17:00', 13, 'HOAT_DONG', NULL),
 (9, N'Phan Mỹ Quyên', 'NU', '20000228', '0901000009', 'quyen.phan@example.com', 'HCM', '2026-03-20 18:00', 14, 'HOAT_DONG', NULL),
 (10, N'Đinh Gia Bảo', 'NAM', NULL, '0901000010', NULL, 'DN', '2026-08-08 15:30', NULL, 'HOAT_DONG', NULL),
 (11, N'Lý Hoài Nam', 'NAM', '19930509', '0901000011', 'nam.ly@example.com', 'HN', '2026-01-05 19:00', 15, 'DA_XOA', '2026-06-30 10:00'),
 (12, N'Mai Phương Thảo', 'NU', '19921014', '0901000012', 'thao.mai@example.com', 'DN', '2026-05-22 20:00', 16, 'HOAT_DONG', NULL);
SET IDENTITY_INSERT crm.KHACH_HANG OFF;

/* Sở thích = loại sản phẩm quan tâm */
INSERT crm.KH_QUAN_TAM (MaKH, MaLoai) VALUES
 (1, 2), (1, 5), (1, 1),
 (2, 2), (2, 3), (2, 1),
 (3, 1), (3, 3), (3, 7),
 (4, 1), (4, 4), (4, 2),
 (5, 5), (5, 2),
 (6, 4),
 (7, 1), (7, 7),
 (8, 1), (8, 6),
 (9, 5),
 (11, 1),
 (12, 6), (12, 2);

/* ---------- Khảo sát ----------
   KS1: đo hài lòng chung (đã đóng, có kết quả, tặng voucher 10%)
   KS2: đo hài lòng SP Áo khoác chần bông (đang mở, voucher 5%)
   KS3: thăm dò SP sắp ra mắt Áo khoác lông cừu 2026 (đang mở, voucher 15%)
   KS4: bản nháp thăm dò Áo thun làm mát (chưa gửi)                       */
SET IDENTITY_INSERT crm.KHAO_SAT ON;
INSERT crm.KHAO_SAT (MaKS, TieuDe, MoTa, MucDich, MaSP, MaNV_Tao, NgayTao, NgayPhatHanh, HanTraLoi, PhanTramVoucher, SoNgayHieuLucVoucher, TrangThai) VALUES
 (1, N'Khảo sát mức độ hài lòng khi mua sắm – Quý 3/2026', N'Đánh giá chất lượng sản phẩm và dịch vụ', 'DO_HAI_LONG', NULL, 2,
     '2026-08-20 09:00', '2026-08-25 09:00', '2026-09-15 23:59', 10, 30, 'DA_DONG'),
 (2, N'Đánh giá Áo khoác chần bông siêu nhẹ', NULL, 'DO_HAI_LONG', 4, 2,
     DATEADD(DAY, -15, @Nay), DATEADD(DAY, -12, @Nay), DATEADD(DAY, 20, @Nay), 5, 30, 'DA_GUI'),
 (3, N'Thăm dò: Áo khoác lông cừu nhân tạo 2026', N'Sản phẩm dự kiến ra mắt 20/11/2026', 'THAM_DO_SP_MOI', 13, 2,
     DATEADD(DAY, -10, @Nay), DATEADD(DAY, -8, @Nay), DATEADD(DAY, 30, @Nay), 15, 30, 'DA_GUI'),
 (4, N'Thăm dò: Áo thun làm mát thế hệ mới', NULL, 'THAM_DO_SP_MOI', 14, 2,
     DATEADD(DAY, -1, @Nay), NULL, DATEADD(DAY, 45, @Nay), 10, 30, 'NHAP');
SET IDENTITY_INSERT crm.KHAO_SAT OFF;

SET IDENTITY_INSERT crm.CAU_HOI ON;
INSERT crm.CAU_HOI (MaCauHoi, MaKS, ThuTu, NoiDung, LoaiCauHoi, BatBuoc) VALUES
 (1,  1, 1, N'Mức độ hài lòng chung với chất lượng sản phẩm (1-5)?', 'THANG_DIEM', 1),
 (2,  1, 2, N'Mức độ hài lòng với thái độ phục vụ của nhân viên (1-5)?', 'THANG_DIEM', 1),
 (3,  1, 3, N'Bạn thường mua sắm qua kênh nào?', 'MOT_LUA_CHON', 1),
 (4,  1, 4, N'Bạn muốn chúng tôi cải thiện điều gì? (chọn nhiều)', 'NHIEU_LUA_CHON', 1),
 (5,  1, 5, N'Góp ý khác', 'TU_LUAN', 0),
 (6,  2, 1, N'Độ ấm của sản phẩm (1-5)?', 'THANG_DIEM', 1),
 (7,  2, 2, N'Độ vừa vặn, thoải mái (1-5)?', 'THANG_DIEM', 1),
 (8,  2, 3, N'Bạn có giới thiệu sản phẩm cho người khác?', 'MOT_LUA_CHON', 1),
 (9,  3, 1, N'Bạn có dự định mua sản phẩm này khi ra mắt?', 'MOT_LUA_CHON', 1),
 (10, 3, 2, N'Mức giá bạn thấy hợp lý?', 'MOT_LUA_CHON', 1),
 (11, 3, 3, N'Màu sắc bạn quan tâm (chọn nhiều)', 'NHIEU_LUA_CHON', 1),
 (12, 3, 4, N'Bạn mong muốn gì thêm ở sản phẩm?', 'TU_LUAN', 0),
 (13, 4, 1, N'Bạn có quan tâm đến áo thun làm mát?', 'MOT_LUA_CHON', 1);
SET IDENTITY_INSERT crm.CAU_HOI OFF;

SET IDENTITY_INSERT crm.LUA_CHON ON;
INSERT crm.LUA_CHON (MaLC, MaCauHoi, ThuTu, NoiDung) VALUES
 (1, 3, 1, N'Tại cửa hàng'), (2, 3, 2, N'Online'), (3, 3, 3, N'Cả hai'),
 (4, 4, 1, N'Thêm size'), (5, 4, 2, N'Thêm màu sắc'), (6, 4, 3, N'Giao hàng nhanh hơn'), (7, 4, 4, N'Ưu đãi thành viên'),
 (8, 8, 1, N'Có'), (9, 8, 2, N'Có thể'), (10, 8, 3, N'Không'),
 (11, 9, 1, N'Chắc chắn mua'), (12, 9, 2, N'Có thể'), (13, 9, 3, N'Không'),
 (14, 10, 1, N'Dưới 800.000đ'), (15, 10, 2, N'800.000đ - 1.000.000đ'), (16, 10, 3, N'Trên 1.000.000đ'),
 (17, 11, 1, N'Đen'), (18, 11, 2, N'Be'), (19, 11, 3, N'Xanh navy'), (20, 11, 4, N'Xám'),
 (21, 13, 1, N'Rất quan tâm'), (22, 13, 2, N'Bình thường'), (23, 13, 3, N'Không quan tâm');
SET IDENTITY_INSERT crm.LUA_CHON OFF;

/* Gửi khảo sát tới TÀI KHOẢN khách hàng */
INSERT crm.KHAO_SAT_GUI (MaKS, MaKH, NgayGui, NgayHoanThanh) VALUES
 (1, 1, '2026-08-25 09:00', '2026-09-02 10:00'),
 (1, 2, '2026-08-25 09:00', '2026-09-14 20:00'),
 (1, 3, '2026-08-25 09:00', '2026-08-27 08:30'),
 (1, 4, '2026-08-25 09:00', '2026-08-30 19:15'),
 (1, 5, '2026-08-25 09:00', '2026-09-10 12:00'),
 (1, 6, '2026-08-25 09:00', NULL),
 (1, 7, '2026-08-25 09:00', NULL),
 (2, 1, DATEADD(DAY, -12, @Nay), NULL),
 (2, 2, DATEADD(DAY, -12, @Nay), DATEADD(DAY, -5, @Nay)),
 (2, 5, DATEADD(DAY, -12, @Nay), DATEADD(DAY, -3, @Nay)),
 (3, 1,  DATEADD(DAY, -8, @Nay), NULL),
 (3, 2,  DATEADD(DAY, -8, @Nay), NULL),
 (3, 4,  DATEADD(DAY, -8, @Nay), DATEADD(DAY, -4, @Nay)),
 (3, 5,  DATEADD(DAY, -8, @Nay), NULL),
 (3, 12, DATEADD(DAY, -8, @Nay), DATEADD(DAY, -2, @Nay));

/* Câu trả lời (TRA_LOI: 1 dòng/câu; TRA_LOI_LUA_CHON: lựa chọn đã chọn) */
INSERT crm.TRA_LOI (MaKS, MaKH, MaCauHoi, LoaiCauHoi, DiemSo, NoiDungTuLuan) VALUES
 (1, 1, 1, 'THANG_DIEM', 5, NULL), (1, 1, 2, 'THANG_DIEM', 4, NULL), (1, 1, 3, 'MOT_LUA_CHON', NULL, NULL),
 (1, 1, 4, 'NHIEU_LUA_CHON', NULL, NULL), (1, 1, 5, 'TU_LUAN', NULL, N'Mong có thêm size XS cho áo khoác'),
 (1, 2, 1, 'THANG_DIEM', 4, NULL), (1, 2, 2, 'THANG_DIEM', 5, NULL), (1, 2, 3, 'MOT_LUA_CHON', NULL, NULL),
 (1, 2, 4, 'NHIEU_LUA_CHON', NULL, NULL),
 (1, 3, 1, 'THANG_DIEM', 4, NULL), (1, 3, 2, 'THANG_DIEM', 3, NULL), (1, 3, 3, 'MOT_LUA_CHON', NULL, NULL),
 (1, 3, 4, 'NHIEU_LUA_CHON', NULL, NULL), (1, 3, 5, 'TU_LUAN', NULL, N'Giao hàng online còn chậm'),
 (1, 4, 1, 'THANG_DIEM', 2, NULL), (1, 4, 2, 'THANG_DIEM', 3, NULL), (1, 4, 3, 'MOT_LUA_CHON', NULL, NULL),
 (1, 4, 4, 'NHIEU_LUA_CHON', NULL, NULL),
 (1, 5, 1, 'THANG_DIEM', 4, NULL), (1, 5, 2, 'THANG_DIEM', 4, NULL), (1, 5, 3, 'MOT_LUA_CHON', NULL, NULL),
 (1, 5, 4, 'NHIEU_LUA_CHON', NULL, NULL),
 (2, 2, 6, 'THANG_DIEM', 5, NULL), (2, 2, 7, 'THANG_DIEM', 4, NULL), (2, 2, 8, 'MOT_LUA_CHON', NULL, NULL),
 (2, 5, 6, 'THANG_DIEM', 4, NULL), (2, 5, 7, 'THANG_DIEM', 3, NULL), (2, 5, 8, 'MOT_LUA_CHON', NULL, NULL),
 (3, 4, 9, 'MOT_LUA_CHON', NULL, NULL), (3, 4, 10, 'MOT_LUA_CHON', NULL, NULL), (3, 4, 11, 'NHIEU_LUA_CHON', NULL, NULL),
 (3, 4, 12, 'TU_LUAN', NULL, N'Nên có mũ trùm đầu tháo rời'),
 (3, 12, 9, 'MOT_LUA_CHON', NULL, NULL), (3, 12, 10, 'MOT_LUA_CHON', NULL, NULL), (3, 12, 11, 'NHIEU_LUA_CHON', NULL, NULL);

INSERT crm.TRA_LOI_LUA_CHON (MaKS, MaKH, MaCauHoi, MaLC) VALUES
 (1, 1, 3, 3), (1, 1, 4, 4), (1, 1, 4, 7),
 (1, 2, 3, 1), (1, 2, 4, 4),
 (1, 3, 3, 2), (1, 3, 4, 5), (1, 3, 4, 6),
 (1, 4, 3, 1), (1, 4, 4, 4),
 (1, 5, 3, 3), (1, 5, 4, 7),
 (2, 2, 8, 8), (2, 5, 8, 9),
 (3, 4, 9, 12), (3, 4, 10, 15), (3, 4, 11, 17), (3, 4, 11, 20),
 (3, 12, 9, 11), (3, 12, 10, 14), (3, 12, 11, 18);

/* Voucher phát khi hoàn thành khảo sát có PhanTramVoucher > 0 */
SET IDENTITY_INSERT crm.VOUCHER ON;
INSERT crm.VOUCHER (MaVoucher, MaCode, MaKH, MaKS, PhanTramGiam, NgayPhat, HanDung) VALUES
 (1, 'V1-A1B2C3D4', 1, 1, 10, '2026-09-02 10:00', '2026-10-02 10:00'),
 (2, 'V1-B5C6D7E8', 2, 1, 10, '2026-09-14 20:00', '2026-10-14 20:00'),
 (3, 'V1-C9D0E1F2', 3, 1, 10, '2026-08-27 08:30', '2026-09-26 08:30'),
 (4, 'V1-D3E4F5A6', 4, 1, 10, '2026-08-30 19:15', '2026-09-29 19:15'),
 (5, 'V1-E7F8A9B0', 5, 1, 10, '2026-09-10 12:00', '2026-10-10 12:00'),
 (6, 'V2-1A2B3C4D', 2, 2, 5,  DATEADD(DAY, -5, @Nay), DATEADD(DAY, 25, @Nay)),
 (7, 'V2-5E6F7A8B', 5, 2, 5,  DATEADD(DAY, -3, @Nay), DATEADD(DAY, 27, @Nay)),
 (8, 'V3-9C0D1E2F', 4, 3, 15, DATEADD(DAY, -4, @Nay), DATEADD(DAY, 26, @Nay)),
 (9, 'V3-3A4B5C6D', 12, 3, 15, DATEADD(DAY, -2, @Nay), DATEADD(DAY, 28, @Nay));
SET IDENTITY_INSERT crm.VOUCHER OFF;

/* ---------- Giao dịch (Admin nạp từ POS) ---------- */
SET IDENTITY_INSERT crm.HOA_DON ON;
INSERT crm.HOA_DON (MaHD, SoHoaDon, MaKH, KenhBan, MaCH, MaNV, NgayLap, MaVoucher, NgayNhap) VALUES
 (1, 'HD0001', 1, 'CUA_HANG', 1, 5, '2026-03-05 10:15', NULL, '2026-03-05 10:15'),
 (2, 'HD0002', 1, 'CUA_HANG', 1, 5, '2026-05-12 17:40', NULL, '2026-05-12 17:40'),
 (3, 'HD0003', 1, 'ONLINE', NULL, NULL, '2026-07-20 21:05', NULL, '2026-07-20 21:05'),
 (4, 'HD0004', 1, 'CUA_HANG', 1, 5, '2026-09-28 18:20', 1, '2026-09-28 18:20'),
 (5, 'HD0005', 2, 'CUA_HANG', 2, 6, '2026-04-02 11:00', NULL, '2026-04-02 11:00'),
 (6, 'HD0006', 2, 'CUA_HANG', 2, 6, '2026-06-15 19:30', NULL, '2026-06-15 19:30'),
 (7, 'HD0007', 2, 'ONLINE', NULL, NULL, '2026-08-30 22:10', NULL, '2026-08-30 22:10'),
 (8, 'HD0008', 3, 'CUA_HANG', 1, 5, '2026-05-03 15:20', NULL, '2026-05-03 15:20'),
 (9, 'HD0009', 3, 'ONLINE', NULL, NULL, '2026-08-11 20:45', NULL, '2026-08-11 20:45'),
 (10, 'HD0010', 4, 'CUA_HANG', 3, 7, '2026-04-20 16:00', NULL, '2026-04-20 16:00'),
 (11, 'HD0011', 5, 'CUA_HANG', 1, 5, '2026-03-15 18:00', NULL, '2026-03-15 18:00'),
 (12, 'HD0012', 5, 'CUA_HANG', 1, 5, '2026-07-07 12:30', NULL, '2026-07-07 12:30'),
 (13, 'HD0013', 5, 'ONLINE', NULL, NULL, '2026-09-19 09:10', NULL, '2026-09-19 09:10'),
 (14, 'HD0014', 6, 'CUA_HANG', 2, 6, '2026-06-01 10:30', NULL, '2026-06-01 10:30'),
 (15, 'HD0015', 7, 'ONLINE', NULL, NULL, '2026-09-05 21:00', NULL, '2026-09-05 21:00'),
 (16, 'HD0016', 8, 'CUA_HANG', 2, 6, '2026-05-25 14:10', NULL, '2026-05-25 14:10'),
 (17, 'HD0017', 9, 'CUA_HANG', 1, 5, '2026-04-11 13:00', NULL, '2026-04-11 13:00'),
 (18, 'HD0018', 10, 'CUA_HANG', 3, 7, '2026-08-08 15:00', NULL, '2026-08-08 15:00'),
 (19, 'HD0019', 11, 'CUA_HANG', 2, 6, '2026-02-14 19:00', NULL, '2026-02-14 19:00'),
 (20, 'HD0020', 12, 'CUA_HANG', 3, 7, '2026-07-30 17:25', NULL, '2026-07-30 17:25');
SET IDENTITY_INSERT crm.HOA_DON OFF;
INSERT crm.CHI_TIET_HOA_DON (MaHD, MaSP, SoLuong, DonGiaBan) VALUES
 (1, 4, 1, 1290000),
 (1, 7, 1, 899000),
 (2, 9, 2, 699000),
 (2, 2, 2, 249000),
 (3, 5, 1, 799000),
 (3, 10, 1, 499000),
 (4, 8, 1, 599000),
 (4, 2, 1, 249000),
 (5, 4, 2, 1290000),
 (5, 6, 1, 799000),
 (6, 3, 3, 399000),
 (6, 8, 1, 599000),
 (7, 5, 1, 799000),
 (7, 12, 1, 299000),
 (8, 2, 2, 249000),
 (8, 7, 1, 899000),
 (9, 10, 1, 499000),
 (10, 1, 3, 249000),
 (10, 8, 1, 599000),
 (11, 4, 1, 1290000),
 (11, 9, 1, 699000),
 (12, 7, 1, 899000),
 (12, 2, 3, 249000),
 (13, 5, 1, 799000),
 (14, 8, 2, 599000),
 (15, 2, 1, 249000),
 (15, 12, 1, 299000),
 (16, 3, 2, 399000),
 (17, 9, 1, 699000),
 (18, 4, 1, 1290000),
 (19, 1, 2, 249000),
 (20, 10, 2, 499000),
 (20, 11, 1, 199000);
SET IDENTITY_INSERT crm.DOI_TRA ON;
INSERT crm.DOI_TRA (MaDT, MaHD, MaSP, SoLuong, LyDo, NgayDoiTra, GhiChu) VALUES
 (1, 2, 9, 1, 'KHONG_VUA', '2026-05-15 10:00', N'Đổi sang size khác không còn hàng'),
 (2, 10, 1, 1, 'LOI_SP', '2026-04-25 09:30', N'Lỗi đường may'),
 (3, 17, 9, 1, 'KHONG_UNG', '2026-04-14 16:00', N'Màu không giống ảnh'),
 (4, 12, 2, 1, 'KHONG_VUA', '2026-07-10 11:15', NULL);
SET IDENTITY_INSERT crm.DOI_TRA OFF;

/* ---------- Phản hồi ở đủ 3 trạng thái ---------- */
SET IDENTITY_INSERT crm.PHAN_HOI ON;
INSERT crm.PHAN_HOI (MaPH, MaKH, MaSP, LoaiPH, DiemDanhGia, NoiDung, NgayGui, TrangThai, MaNV_XuLy, NgayTiepNhan, NoiDungTraLoi, NgayTraLoi) VALUES
 (1, 1, 4, 'KHEN', 5, N'Áo rất nhẹ và ấm, rất đáng tiền.', '2026-03-10 20:00', 'DA_XU_LY', 2, '2026-03-11 09:00', N'Cảm ơn chị đã tin dùng sản phẩm!', '2026-03-11 09:30'),
 (2, 2, 6, 'GOP_Y', 4, N'Mong có thêm size lớn cho quần jeans slim.', '2026-04-10 08:00', 'DA_XU_LY', 3, '2026-04-10 10:00', N'Chúng tôi đã chuyển góp ý tới bộ phận sản phẩm.', '2026-04-11 15:00'),
 (3, 4, 1, 'KHIEU_NAI', 2, N'Áo bị lỗi đường may ở vai.', '2026-04-22 19:00', 'DA_XU_LY', 3, '2026-04-23 08:30', N'Xin lỗi anh, cửa hàng đã hỗ trợ đổi trả và tặng ưu đãi lần sau.', '2026-04-23 14:00'),
 (4, 3, 7, 'KHEN', 5, N'Quần form đẹp, mặc thoải mái.', '2026-05-08 21:00', 'DANG_XU_LY', 3, '2026-05-09 09:00', NULL, NULL),
 (5, 5, 9, 'GOP_Y', 3, N'Vải lanh hơi dễ nhăn.', '2026-07-12 13:00', 'DANG_XU_LY', 2, '2026-07-13 10:00', NULL, NULL),
 (6, 9, 9, 'KHIEU_NAI', 2, N'Màu thực tế không giống ảnh trên web.', '2026-04-13 22:00', 'MOI', NULL, NULL, NULL, NULL),
 (7, 7, 12, 'KHEN', 4, N'Túi nhỏ gọn, đựng vừa điện thoại.', '2026-09-07 18:00', 'MOI', NULL, NULL, NULL, NULL),
 (8, 8, 3, 'GOP_Y', 4, N'Nên có thêm màu xanh rêu.', '2026-06-01 07:30', 'MOI', NULL, NULL, NULL, NULL),
 (9, 12, 10, 'KHEN', 5, N'Đồ mặc nhà rất mát.', '2026-08-05 22:15', 'MOI', NULL, NULL, NULL, NULL),
 (10, 1, 5, 'KHIEU_NAI', 3, N'Khóa kéo hơi kẹt sau vài lần dùng.', '2026-07-25 08:45', 'MOI', NULL, NULL, NULL, NULL);
SET IDENTITY_INSERT crm.PHAN_HOI OFF;

/* ---------- Nhật ký minh họa cho các thao tác quan trọng đã xảy ra ---------- */
INSERT audit.NHAT_KY (ThoiGian, MaTK, NguoiDungCSDL, HanhDong, DoiTuong, MaDoiTuong, ChiTiet) VALUES
 ('2026-06-30 10:00', 3, N'crm_app_quanly', 'XOA_KH',     'KHACH_HANG', N'11', N'Khách yêu cầu ngừng sử dụng dịch vụ'),
 ('2026-09-01 09:30', 3, N'crm_app_quanly', 'KHOA_TK_KH', 'TAI_KHOAN',  N'14', N'Đăng nhập bất thường nhiều lần, chờ xác minh'),
 ('2025-07-01 09:00', 1, N'crm_app_admin',  'TAO_TK',     'TAI_KHOAN',  N'5',  N'Tạo tài khoản it.mai cho NV 8, vai trò QTV_TAI_KHOAN');

/* ---------- Xét hạng lần đầu theo dữ liệu giao dịch (ghi LICH_SU_HANG) ---------- */
EXEC crm.usp_XetHang_NoiBo @MaKH = NULL, @LyDo = N'Xét hạng lần đầu khi nạp dữ liệu mẫu';

COMMIT;
GO
SET NOEXEC OFF;
GO

/* Tóm tắt dữ liệu mẫu */
SELECT 'TAI_KHOAN' AS Bang, COUNT(*) AS SoDong FROM crm.TAI_KHOAN UNION ALL
SELECT 'NHAN_VIEN', COUNT(*) FROM crm.NHAN_VIEN UNION ALL
SELECT 'KHACH_HANG', COUNT(*) FROM crm.KHACH_HANG UNION ALL
SELECT 'KH_QUAN_TAM', COUNT(*) FROM crm.KH_QUAN_TAM UNION ALL
SELECT 'SAN_PHAM', COUNT(*) FROM crm.SAN_PHAM UNION ALL
SELECT 'HOA_DON', COUNT(*) FROM crm.HOA_DON UNION ALL
SELECT 'CHI_TIET_HOA_DON', COUNT(*) FROM crm.CHI_TIET_HOA_DON UNION ALL
SELECT 'DOI_TRA', COUNT(*) FROM crm.DOI_TRA UNION ALL
SELECT 'PHAN_HOI', COUNT(*) FROM crm.PHAN_HOI UNION ALL
SELECT 'KHAO_SAT', COUNT(*) FROM crm.KHAO_SAT UNION ALL
SELECT 'KHAO_SAT_GUI', COUNT(*) FROM crm.KHAO_SAT_GUI UNION ALL
SELECT 'TRA_LOI', COUNT(*) FROM crm.TRA_LOI UNION ALL
SELECT 'VOUCHER', COUNT(*) FROM crm.VOUCHER UNION ALL
SELECT 'LICH_SU_HANG', COUNT(*) FROM crm.LICH_SU_HANG;

SELECT k.MaKH, k.HoTen, k.MaHang, d.Diem, d.ChiTieuRong
FROM crm.KHACH_HANG k JOIN crm.vw_DiemKhachHang d ON d.MaKH = k.MaKH
ORDER BY d.Diem DESC;
GO
PRINT N'Script 08 hoàn tất.';
GO

/* #################### 18_BoSung_QuenMatKhau_LichSuMuaHang.sql #################### */
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
