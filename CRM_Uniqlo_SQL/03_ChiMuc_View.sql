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
