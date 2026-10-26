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
