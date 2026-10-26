/* =====================================================================
   Script 09: Truy vấn báo cáo CRM (minh họa trên dữ liệu mẫu)
   ---------------------------------------------------------------------
   Phần A: gọi đúng các thủ tục báo cáo mà giao diện Quản lý sẽ gọi
           (chạy với ngữ cảnh tài khoản gd.minh – Giám đốc, vai trò QUAN_LY).
   Phần B: truy vấn bổ trợ cho báo cáo đồ án (chạy bằng dbo).
   CHẠY TRONG MỘT CỬA SỔ/KẾT NỐI MỚI: ngữ cảnh phiên là read-only.
   Kết quả mong đợi (dữ liệu mẫu) ghi ở chú thích từng truy vấn.
   ===================================================================== */
USE CRM_Uniqlo;
GO
SET NOCOUNT ON;
GO

/* ============ PHẦN A – Báo cáo theo yêu cầu đề (qua thủ tục, có kiểm tra quyền) ============ */
EXEC sec.usp_DatNguCanh @MaTK = 2;   -- gd.minh (Giám đốc) – dbo được phép đặt ngữ cảnh để minh họa

-- A1. Tỷ lệ độ tuổi / giới tính / tỉnh / hạng (11 hồ sơ đang hoạt động)
--     Mong đợi: 25-34 = 4 (An, Hà, Quyên, Thảo); 18-24 = 2; 35-44 = 2; 45-54 = 1; 55+ = 1; Không rõ = 1.
--     Hạng: Thường 9, VIP 2 (An 544 điểm, Bình 627 điểm).
EXEC api_ql.usp_BaoCaoCoCauKhachHang;

-- A2. Sở thích: loại quan tâm so với loại đã mua
--     Mong đợi: Áo khoác 5 khách quan tâm (An, Bình, Dũng, Hà, Thảo), Áo thun 6 (hồ sơ đã xóa không tính).
EXEC api_ql.usp_BaoCaoSoThich;

-- A3. Mức độ hài lòng: điểm phản hồi, tỷ lệ đổi trả, điểm khảo sát
EXEC api_ql.usp_BaoCaoHaiLong @TuNgay = '20260101', @DenNgay = NULL;

-- A4. Thống kê kết quả khảo sát KS1 (5/7 hoàn thành = 71,43%; câu 1 điểm TB 3,80)
EXEC api_ql.usp_ThongKeKhaoSat @MaKS = 1;

-- A5. Thống kê khảo sát thăm dò sản phẩm sắp ra mắt KS3 (2/5 hoàn thành)
EXEC api_ql.usp_ThongKeKhaoSat @MaKS = 3;
GO

/* ============ PHẦN B – Truy vấn bổ trợ (dbo) ============ */

-- B1. Danh sách khách hàng theo hạng (thường / VIP), kèm điểm suy ra
SELECT h.TenHang, k.MaKH, k.HoTen, d.Diem, d.ChiTieuRong, d.SoHoaDon, d.LanMuaCuoi
FROM crm.KHACH_HANG k
JOIN crm.HANG_THANH_VIEN h  ON h.MaHang = k.MaHang
JOIN crm.vw_DiemKhachHang d ON d.MaKH = k.MaKH
WHERE k.TrangThaiHoSo = 'HOAT_DONG'
ORDER BY h.DiemToiThieu DESC, d.Diem DESC;

-- B2. Lịch sử tương tác CRM của một khách hàng (MaKH = 1): phản hồi, khảo sát, đổi hạng, mua hàng
DECLARE @MaKH INT = 1;
SELECT ThoiGian, LoaiTuongTac, NoiDung
FROM (
    SELECT ph.NgayGui AS ThoiGian, N'Phản hồi (' + ph.LoaiPH + N')' AS LoaiTuongTac,
           CONCAT(sp.TenSP, N': ', ph.NoiDung, N' | Trạng thái: ', ph.TrangThai) AS NoiDung
    FROM crm.PHAN_HOI ph JOIN crm.SAN_PHAM sp ON sp.MaSP = ph.MaSP WHERE ph.MaKH = @MaKH
    UNION ALL
    SELECT g.NgayGui, N'Nhận khảo sát', CONCAT(ks.TieuDe, N' | ', g.TrangThai)
    FROM crm.KHAO_SAT_GUI g JOIN crm.KHAO_SAT ks ON ks.MaKS = g.MaKS WHERE g.MaKH = @MaKH
    UNION ALL
    SELECT ls.ThoiGian, N'Đổi hạng', CONCAT(ISNULL(ls.MaHangCu, N'-'), N' -> ', ls.MaHangMoi, N' (', ls.DiemTaiThoiDiem, N' điểm)')
    FROM crm.LICH_SU_HANG ls WHERE ls.MaKH = @MaKH
    UNION ALL
    SELECT g.NgayLap, N'Mua hàng', CONCAT(g.SoHoaDon, N' – ', FORMAT(g.ThanhTien, 'N0'), N'đ')
    FROM crm.vw_GiaTriHoaDon g WHERE g.MaKH = @MaKH
) x
ORDER BY ThoiGian DESC;

-- B3. Khách hàng chưa được chăm sóc trong 60 ngày gần nhất
--     (không nhận khảo sát, không có phản hồi được trả lời, không mua hàng)
DECLARE @MocNgay DATETIME2(0) = DATEADD(DAY, -60, SYSDATETIME());
SELECT k.MaKH, k.HoTen, k.MaHang, k.SDT,
       (SELECT MAX(g.NgayGui) FROM crm.KHAO_SAT_GUI g WHERE g.MaKH = k.MaKH) AS LanGuiKhaoSatCuoi,
       (SELECT MAX(p.NgayTraLoi) FROM crm.PHAN_HOI p WHERE p.MaKH = k.MaKH) AS LanTraLoiPhanHoiCuoi,
       (SELECT MAX(h.NgayLap) FROM crm.HOA_DON h WHERE h.MaKH = k.MaKH) AS LanMuaCuoi
FROM crm.KHACH_HANG k
WHERE k.TrangThaiHoSo = 'HOAT_DONG'
  AND NOT EXISTS (SELECT 1 FROM crm.KHAO_SAT_GUI g WHERE g.MaKH = k.MaKH AND g.NgayGui >= @MocNgay)
  AND NOT EXISTS (SELECT 1 FROM crm.PHAN_HOI p WHERE p.MaKH = k.MaKH AND p.NgayTraLoi >= @MocNgay)
  AND NOT EXISTS (SELECT 1 FROM crm.HOA_DON h WHERE h.MaKH = k.MaKH AND h.NgayLap >= @MocNgay)
ORDER BY k.HoTen;

-- B4. Hoạt động CRM theo nhân viên (phản hồi đã tiếp nhận/trả lời, khảo sát đã tạo)
SELECT nv.MaNV, nv.HoTen, cv.TenCV,
       (SELECT COUNT(*) FROM crm.PHAN_HOI p WHERE p.MaNV_XuLy = nv.MaNV) AS SoPhanHoiPhuTrach,
       (SELECT COUNT(*) FROM crm.PHAN_HOI p WHERE p.MaNV_XuLy = nv.MaNV AND p.TrangThai = 'DA_XU_LY') AS SoPhanHoiDaXong,
       (SELECT AVG(DATEDIFF(HOUR, p.NgayGui, p.NgayTraLoi)) FROM crm.PHAN_HOI p
         WHERE p.MaNV_XuLy = nv.MaNV AND p.NgayTraLoi IS NOT NULL) AS ThoiGianTraLoiTB_Gio,
       (SELECT COUNT(*) FROM crm.KHAO_SAT ks WHERE ks.MaNV_Tao = nv.MaNV) AS SoKhaoSatDaTao
FROM crm.NHAN_VIEN nv JOIN crm.CHUC_VU cv ON cv.MaCV = nv.MaCV
WHERE nv.MaCV IN ('GIAM_DOC', 'QL_CSKH', 'NV_CSKH')
ORDER BY SoPhanHoiPhuTrach DESC;

-- B5. Bảng điều hành cho Giám đốc (một dòng KPI)
SELECT
    (SELECT COUNT(*) FROM crm.KHACH_HANG WHERE TrangThaiHoSo = 'HOAT_DONG') AS TongKhachHoatDong,
    (SELECT COUNT(*) FROM crm.KHACH_HANG WHERE TrangThaiHoSo = 'HOAT_DONG' AND MaHang = 'VIP') AS SoKhachVIP,
    (SELECT COUNT(*) FROM crm.KHACH_HANG WHERE NgayDangKy >= DATEADD(DAY, -90, SYSDATETIME())) AS KhachMoi90Ngay,
    (SELECT COUNT(*) FROM crm.PHAN_HOI WHERE TrangThai <> 'DA_XU_LY') AS PhanHoiTon,
    (SELECT CAST(AVG(CAST(DiemDanhGia AS DECIMAL(5, 2))) AS DECIMAL(4, 2)) FROM crm.PHAN_HOI) AS DiemPhanHoiTB,
    (SELECT COUNT(*) FROM crm.KHAO_SAT WHERE TrangThai = 'DA_GUI') AS KhaoSatDangMo,
    (SELECT CAST(100.0 * SUM(CASE WHEN NgayHoanThanh IS NOT NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS DECIMAL(5, 2))
       FROM crm.KHAO_SAT_GUI) AS TyLeHoanThanhKhaoSat,
    (SELECT FORMAT(SUM(ThanhTien), 'N0') FROM crm.vw_GiaTriHoaDon) AS TongDoanhThuThanhVien;

-- B6. Khách sắp đạt VIP (còn dưới 100 điểm) – gợi ý chương trình chăm sóc
SELECT k.MaKH, k.HoTen, d.Diem, h.DiemToiThieu - d.Diem AS DiemConThieu
FROM crm.KHACH_HANG k
JOIN crm.vw_DiemKhachHang d ON d.MaKH = k.MaKH
JOIN crm.HANG_THANH_VIEN h  ON h.MaHang = 'VIP'
WHERE k.TrangThaiHoSo = 'HOAT_DONG' AND k.MaHang <> 'VIP' AND h.DiemToiThieu - d.Diem BETWEEN 1 AND 100;
-- Mong đợi: Hoàng Thu Hà, 418 điểm, còn thiếu 82.
GO
