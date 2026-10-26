/* =====================================================================
   Script 12: Kiểm thử toàn vẹn dữ liệu (chạy bằng dbo)
   ---------------------------------------------------------------------
   Mỗi ca chạy trong một giao dịch và luôn ROLLBACK => không làm đổi dữ liệu.
   Chạy được trên CRM_Uniqlo hoặc CRM_Uniqlo_Test, ngay sau script 08.
   Kiểm: PK, FK, UNIQUE, CHECK, NOT NULL, trigger, quan hệ tài khoản-con người,
   đổi hạng VIP không đổi quyền, dữ liệu suy ra, RLS bật, không cấp db_owner.
   Cách đọc kết quả: bảng cuối cùng liệt kê từng ca, cột KetQua = PASS/FAIL;
   tab Messages in từng ca và 2 dòng cuối: TONG KET ... và KET LUAN: DAT / KHONG DAT.
   DAT = mọi ca PASS và chạy đủ số ca dự kiến. Xem HUONG_DAN_KIEM_THU (mục 6).
   ===================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT OFF;
GO
IF DB_NAME() NOT IN (N'CRM_Uniqlo', N'CRM_Uniqlo_Test')
BEGIN
    RAISERROR (N'Hãy chọn CSDL CRM_Uniqlo hoặc CRM_Uniqlo_Test.', 16, 1);
    SET NOEXEC ON;
END
GO
DECLARE @KQ TABLE (STT INT IDENTITY, MaKT VARCHAR(10), MucTieu NVARCHAR(300), MongDoi NVARCHAR(100),
                   KetQua VARCHAR(4), ChiTiet NVARCHAR(1000));
DECLARE @Loi INT, @ThongBao NVARCHAR(4000), @DatDK BIT;

/* TV-01: PK: không thêm trùng mã vai trò */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.VAI_TRO (MaVT, TenVT, LoaiTK, CongTruyCap) VALUES ('ADMIN', N'Trùng', 'NV', 'ADMIN');
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-01', N'PK: không thêm trùng mã vai trò', N'Lỗi 2627',
        CASE WHEN @Loi IN (2627) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-02: FK: không thêm sở thích cho khách không tồn tại */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.KH_QUAN_TAM (MaKH, MaLoai) VALUES (99999, 1);
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-02', N'FK: không thêm sở thích cho khách không tồn tại', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-03: UNIQUE: tên đăng nhập không trùng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.TAI_KHOAN (TenDangNhap, MatKhauHash, MaVT, LoaiTK) VALUES ('kh.an', '$2b$10$MLb/KjA8XbVYbdlVIiBbre.rtMSn2YkBLT1E01a.WbM9q4N4LVoi.', 'KHACH_HANG', 'KH');
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-03', N'UNIQUE: tên đăng nhập không trùng', N'Lỗi 2627',
        CASE WHEN @Loi IN (2627) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-04: UNIQUE có lọc: SĐT trùng với hồ sơ đang hoạt động bị chặn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.KHACH_HANG (HoTen, SDT) VALUES (N'Trùng SĐT', '0901000001');
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-04', N'UNIQUE có lọc: SĐT trùng với hồ sơ đang hoạt động bị chặn', N'Lỗi 2601',
        CASE WHEN @Loi IN (2601) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-05: SĐT của hồ sơ đã xóa mềm được đăng ký lại */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.KHACH_HANG (HoTen, SDT) VALUES (N'Đăng ký lại', '0901000011');
    IF NOT (EXISTS (SELECT 1 FROM crm.KHACH_HANG WHERE SDT = '0901000011' AND TrangThaiHoSo = 'HOAT_DONG')) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-05', N'SĐT của hồ sơ đã xóa mềm được đăng ký lại', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-06: CHECK: SĐT sai định dạng bị chặn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.KHACH_HANG (HoTen, SDT) VALUES (N'Sai SĐT', '12345');
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-06', N'CHECK: SĐT sai định dạng bị chặn', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-07: CHECK: ngày sinh ở tương lai bị chặn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.KHACH_HANG (HoTen, SDT, NgaySinh) VALUES (N'Sai ngày sinh', '0909000001', DATEADD(YEAR, 1, SYSDATETIME()));
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-07', N'CHECK: ngày sinh ở tương lai bị chặn', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-08: NOT NULL: thiếu họ tên bị chặn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.KHACH_HANG (HoTen, SDT) VALUES (NULL, '0909000002');
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-08', N'NOT NULL: thiếu họ tên bị chặn', N'Lỗi 515',
        CASE WHEN @Loi IN (515) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-09: Tài khoản/con người: không gắn tài khoản NHÂN VIÊN vào hồ sơ khách hàng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    UPDATE crm.KHACH_HANG SET MaTK = 1 WHERE MaKH = 10;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-09', N'Tài khoản/con người: không gắn tài khoản NHÂN VIÊN vào hồ sơ khách hàng', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-10: Tài khoản/con người: một tài khoản KH không gắn cho 2 hồ sơ */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    UPDATE crm.KHACH_HANG SET MaTK = 6 WHERE MaKH = 10;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-10', N'Tài khoản/con người: một tài khoản KH không gắn cho 2 hồ sơ', N'Lỗi 2601',
        CASE WHEN @Loi IN (2601) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-11: Tài khoản/con người: không gắn tài khoản KHÁCH vào hồ sơ nhân viên */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    UPDATE crm.NHAN_VIEN SET MaTK = 6 WHERE MaNV = 5;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-11', N'Tài khoản/con người: không gắn tài khoản KHÁCH vào hồ sơ nhân viên', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-12: Tài khoản KH không thể mang vai trò ADMIN (FK (MaVT, LoaiTK)) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    UPDATE crm.TAI_KHOAN SET MaVT = 'ADMIN' WHERE MaTK = 6;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-12', N'Tài khoản KH không thể mang vai trò ADMIN (FK (MaVT, LoaiTK))', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-13: Không gán quyền cổng ADMIN cho vai trò KHACH_HANG */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.VAI_TRO_QUYEN (MaVT, MaQuyen, CongTruyCap) VALUES ('KHACH_HANG', 'AD_PHAN_QUYEN', 'ADMIN');
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-13', N'Không gán quyền cổng ADMIN cho vai trò KHACH_HANG', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-14: Không lưu mật khẩu dạng văn bản thuần */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.TAI_KHOAN (TenDangNhap, MatKhauHash, MaVT, LoaiTK) VALUES ('kh.matkhauthuan', '123456', 'KHACH_HANG', 'KH');
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-14', N'Không lưu mật khẩu dạng văn bản thuần', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-15: Trả lời câu hỏi của khảo sát KHÁC bị chặn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.TRA_LOI (MaKS, MaKH, MaCauHoi, LoaiCauHoi, DiemSo) VALUES (2, 1, 1, 'THANG_DIEM', 5);
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-15', N'Trả lời câu hỏi của khảo sát KHÁC bị chặn', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-16: Trả lời khảo sát CHƯA được gửi cho mình bị chặn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.TRA_LOI (MaKS, MaKH, MaCauHoi, LoaiCauHoi, DiemSo) VALUES (1, 8, 1, 'THANG_DIEM', 5);
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-16', N'Trả lời khảo sát CHƯA được gửi cho mình bị chặn', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-17: Sai loại câu trả lời (thang điểm ngoài 1-5) bị chặn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.TRA_LOI (MaKS, MaKH, MaCauHoi, LoaiCauHoi, DiemSo) VALUES (2, 1, 6, 'THANG_DIEM', 7);
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-17', N'Sai loại câu trả lời (thang điểm ngoài 1-5) bị chặn', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-18: Khai sai loại câu hỏi để lách CHECK bị chặn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.TRA_LOI (MaKS, MaKH, MaCauHoi, LoaiCauHoi, NoiDungTuLuan) VALUES (2, 1, 6, 'TU_LUAN', N'lách');
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-18', N'Khai sai loại câu hỏi để lách CHECK bị chặn', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-19: Lựa chọn thuộc câu hỏi khác bị chặn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.TRA_LOI (MaKS, MaKH, MaCauHoi, LoaiCauHoi) VALUES (2, 1, 8, 'MOT_LUA_CHON');
    INSERT crm.TRA_LOI_LUA_CHON (MaKS, MaKH, MaCauHoi, MaLC) VALUES (2, 1, 8, 1);
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-19', N'Lựa chọn thuộc câu hỏi khác bị chặn', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-20: Dùng voucher của khách khác bị chặn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.HOA_DON (SoHoaDon, MaKH, KenhBan, NgayLap, MaVoucher) VALUES ('HD-TV20', 1, 'ONLINE', SYSDATETIME(), 2);
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-20', N'Dùng voucher của khách khác bị chặn', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-21: Dùng lại voucher đã dùng bị chặn */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.HOA_DON (SoHoaDon, MaKH, KenhBan, NgayLap, MaVoucher) VALUES ('HD-TV21', 1, 'ONLINE', SYSDATETIME(), 1);
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-21', N'Dùng lại voucher đã dùng bị chặn', N'Lỗi 2601',
        CASE WHEN @Loi IN (2601) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-22: Kênh ONLINE không được ghi cửa hàng/nhân viên */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.HOA_DON (SoHoaDon, MaKH, KenhBan, MaCH, MaNV, NgayLap) VALUES ('HD-TV22', 1, 'ONLINE', 1, 5, SYSDATETIME());
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-22', N'Kênh ONLINE không được ghi cửa hàng/nhân viên', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-23: Đổi trả vượt số lượng đã mua bị chặn (trigger) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.DOI_TRA (MaHD, MaSP, SoLuong, LyDo, NgayDoiTra) VALUES (2, 9, 2, 'KHAC', SYSDATETIME());
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-23', N'Đổi trả vượt số lượng đã mua bị chặn (trigger)', N'Lỗi 51001',
        CASE WHEN @Loi IN (51001) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-24: Đổi trả trước ngày lập hóa đơn bị chặn (trigger) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.DOI_TRA (MaHD, MaSP, SoLuong, LyDo, NgayDoiTra) VALUES (4, 8, 1, 'KHAC', '20260101');
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-24', N'Đổi trả trước ngày lập hóa đơn bị chặn (trigger)', N'Lỗi 51002',
        CASE WHEN @Loi IN (51002) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-25: Phản hồi 'Đã xử lý' bắt buộc có nội dung trả lời */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    UPDATE crm.PHAN_HOI SET TrangThai = 'DA_XU_LY', MaNV_XuLy = 2, NgayTiepNhan = SYSDATETIME() WHERE MaPH = 6;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-25', N'Phản hồi ''Đã xử lý'' bắt buộc có nội dung trả lời', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-26: Khảo sát thăm dò bắt buộc gắn sản phẩm */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.KHAO_SAT (TieuDe, MucDich, MaNV_Tao) VALUES (N'Thiếu SP', 'THAM_DO_SP_MOI', 2);
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-26', N'Khảo sát thăm dò bắt buộc gắn sản phẩm', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-27: Không xóa cứng khảo sát đã có câu trả lời */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    DELETE crm.KHAO_SAT WHERE MaKS = 1;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-27', N'Không xóa cứng khảo sát đã có câu trả lời', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-28: Không xóa cứng khách hàng có lịch sử */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    DELETE crm.KHACH_HANG WHERE MaKH = 1;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-28', N'Không xóa cứng khách hàng có lịch sử', N'Lỗi 547',
        CASE WHEN @Loi IN (547) THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-29: Xóa khảo sát NHÁP kéo theo câu hỏi, lựa chọn (cascade) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    DELETE crm.KHAO_SAT WHERE MaKS = 4;
    IF NOT (NOT EXISTS (SELECT 1 FROM crm.CAU_HOI WHERE MaKS = 4) AND NOT EXISTS (SELECT 1 FROM crm.LUA_CHON WHERE MaCauHoi = 13)) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-29', N'Xóa khảo sát NHÁP kéo theo câu hỏi, lựa chọn (cascade)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-30: Điểm suy ra đúng với dữ liệu mẫu (An 544, Bình 627, Hà 418) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT ((SELECT Diem FROM crm.vw_DiemKhachHang WHERE MaKH = 1) = 544 AND (SELECT Diem FROM crm.vw_DiemKhachHang WHERE MaKH = 2) = 627 AND (SELECT Diem FROM crm.vw_DiemKhachHang WHERE MaKH = 5) = 418) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-30', N'Điểm suy ra đúng với dữ liệu mẫu (An 544, Bình 627, Hà 418)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-31: Hạng sau dữ liệu mẫu: chỉ An, Bình là VIP */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT ((SELECT STRING_AGG(CAST(MaKH AS VARCHAR(10)), ',') WITHIN GROUP (ORDER BY MaKH) FROM crm.KHACH_HANG WHERE MaHang = 'VIP') = '1,2') SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-31', N'Hạng sau dữ liệu mẫu: chỉ An, Bình là VIP', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-32: Lên VIP khi đủ điểm, có ghi lịch sử, KHÔNG đổi vai trò tài khoản */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    INSERT crm.HOA_DON (SoHoaDon, MaKH, KenhBan, NgayLap) VALUES ('HD-TV32', 5, 'ONLINE', SYSDATETIME());
    INSERT crm.CHI_TIET_HOA_DON (MaHD, MaSP, SoLuong, DonGiaBan) VALUES (SCOPE_IDENTITY(), 4, 1, 1290000);
    EXEC crm.usp_XetHang_NoiBo @MaKH = 5;
    IF NOT ((SELECT MaHang FROM crm.KHACH_HANG WHERE MaKH = 5) = 'VIP' AND (SELECT MaVT FROM crm.TAI_KHOAN WHERE MaTK = 10) = 'KHACH_HANG' AND EXISTS (SELECT 1 FROM crm.LICH_SU_HANG WHERE MaKH = 5 AND MaHangCu = 'THUONG' AND MaHangMoi = 'VIP')) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-32', N'Lên VIP khi đủ điểm, có ghi lịch sử, KHÔNG đổi vai trò tài khoản', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-33: Trạng thái khảo sát gửi được suy ra (không lưu trùng) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT ((SELECT TrangThai FROM crm.KHAO_SAT_GUI WHERE MaKS = 1 AND MaKH = 6) = 'CHUA_LAM' AND (SELECT TrangThai FROM crm.KHAO_SAT_GUI WHERE MaKS = 1 AND MaKH = 1) = 'DA_HOAN_THANH') SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-33', N'Trạng thái khảo sát gửi được suy ra (không lưu trùng)', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-34: Security policy RLS đang bật trên 7 bảng */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT ((SELECT COUNT(DISTINCT sp.target_object_id) FROM sys.security_policies p JOIN sys.security_predicates sp ON sp.object_id = p.object_id WHERE p.name = 'pol_DuLieuKhachHang' AND p.is_enabled = 1) = 7) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-34', N'Security policy RLS đang bật trên 7 bảng', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-35: Không role ứng dụng nào là db_owner/sysadmin */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT (NOT EXISTS (SELECT 1 FROM sys.database_role_members rm JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id WHERE r.name = 'db_owner' AND m.name IN ('u_app_admin','u_app_quanly','u_app_khachhang','r_admin','r_quanly','r_khachhang')) AND NOT EXISTS (SELECT 1 FROM sys.server_role_members sm JOIN sys.server_principals s ON s.principal_id = sm.member_principal_id WHERE s.name LIKE 'crm_app_%')) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-35', N'Không role ứng dụng nào là db_owner/sysadmin', N'Thành công',
        CASE WHEN @Loi IS NULL AND @DatDK = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Loi IS NULL THEN CASE WHEN @DatDK = 1 THEN N'Không lỗi' ELSE N'Không lỗi nhưng điều kiện kiểm tra sai' END
             ELSE CONCAT(N'Lỗi ', @Loi, N': ', @ThongBao) END);

/* TV-36: Không còn tài khoản nào lưu mật khẩu ngắn (nghi văn bản thuần) */
SELECT @Loi = NULL, @ThongBao = NULL, @DatDK = 1;
BEGIN TRAN;
BEGIN TRY
    SELECT @DatDK = 1;
    IF NOT (NOT EXISTS (SELECT 1 FROM crm.TAI_KHOAN WHERE LEN(MatKhauHash) < 50)) SET @DatDK = 0;
END TRY
BEGIN CATCH
    SELECT @Loi = ERROR_NUMBER(), @ThongBao = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @KQ (MaKT, MucTieu, MongDoi, KetQua, ChiTiet)
VALUES ('TV-36', N'Không còn tài khoản nào lưu mật khẩu ngắn (nghi văn bản thuần)', N'Thành công',
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
DECLARE @KT_DuKien INT = 36,
        @KT_Pass INT = (SELECT COUNT(*) FROM @KQ WHERE KetQua = 'PASS'),
        @KT_Fail INT = (SELECT COUNT(*) FROM @KQ WHERE KetQua = 'FAIL');
PRINT N'------------------------------------------------------------';
PRINT CONCAT(N'TONG KET ', DB_NAME(), N': ', @KT_Pass, N'/', @KT_n, N' PASS, ', @KT_Fail, N' FAIL (du kien ', @KT_DuKien, N' ca)');
PRINT CASE WHEN @KT_Fail = 0 AND @KT_n = @KT_DuKien THEN N'KET LUAN: DAT' ELSE N'KET LUAN: KHONG DAT' END;
SELECT MaKT AS CA_FAIL, ChiTiet FROM @KQ WHERE KetQua = 'FAIL';
GO
SET NOEXEC OFF;
GO
