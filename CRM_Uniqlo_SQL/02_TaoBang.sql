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
