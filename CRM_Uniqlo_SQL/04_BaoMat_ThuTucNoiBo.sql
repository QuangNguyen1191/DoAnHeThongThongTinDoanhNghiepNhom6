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
