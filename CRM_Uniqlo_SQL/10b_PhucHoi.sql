/* =====================================================================
   Script 10b: Phục hồi CSDL từ bản sao lưu  (*** CÓ THỂ GHI ĐÈ DỮ LIỆU ***)
   ---------------------------------------------------------------------
   Mặc định phục hồi sang CSDL MỚI tên CRM_Uniqlo_PhucHoi (không đụng CSDL
   đang chạy) để kiểm tra bản sao lưu hoặc lấy lại dữ liệu bị xóa nhầm.
   Chỉ ghi đè CSDL chính khi:
     1) đổi @TenCSDLDich = N'CRM_Uniqlo', VÀ
     2) đặt @XacNhanGhiDe = N'TOI_HIEU_VA_DONG_Y_GHI_DE'.
   QUY TRÌNH KHI SỰ CỐ TRÊN CSDL CHÍNH
     1. Sao lưu "đuôi nhật ký" (tail-log) nếu CSDL còn truy cập được:
          BACKUP LOG CRM_Uniqlo TO DISK = N'...\CRM_Uniqlo_TAIL.trn' WITH NORECOVERY, CHECKSUM;
     2. Khôi phục FULL gần nhất  (NORECOVERY)
     3. Khôi phục DIFF gần nhất sau FULL đó (NORECOVERY)
     4. Khôi phục lần lượt các LOG sau DIFF (NORECOVERY), LOG cuối dùng STOPAT nếu cần
     5. RESTORE DATABASE ... WITH RECOVERY
     6. Kiểm tra: DBCC CHECKDB, đếm dòng bảng chính, đăng nhập thử 3 cổng.
     7. Login SQL được ánh xạ theo SID nên user u_app_* tự khớp lại trên cùng máy chủ;
        nếu khôi phục sang máy chủ khác: ALTER USER u_app_admin WITH LOGIN = crm_app_admin; (tương tự 2 user còn lại)
   ===================================================================== */
USE master;
GO
SET NOCOUNT ON;

DECLARE @TenCSDLDich  SYSNAME       = N'CRM_Uniqlo_PhucHoi';
DECLARE @XacNhanGhiDe NVARCHAR(50)  = N'';                    -- xem hướng dẫn phía trên
DECLARE @TepFull      NVARCHAR(500) = N'C:\SaoLuu\CRM_Uniqlo_FULL_yyyyMMdd_HHmmss.bak';  -- BẮT BUỘC sửa
DECLARE @TepDiff      NVARCHAR(500) = NULL;                    -- tùy chọn
DECLARE @TepLog       NVARCHAR(500) = NULL;                    -- tùy chọn (1 tệp; nhiều tệp thì lặp lệnh RESTORE LOG)
DECLARE @DungLuc      DATETIME2(0)  = NULL;                    -- point-in-time với @TepLog, NULL = tới cuối log

IF @TenCSDLDich = N'CRM_Uniqlo' AND @XacNhanGhiDe <> N'TOI_HIEU_VA_DONG_Y_GHI_DE'
    THROW 53010, N'Từ chối ghi đè CSDL chính khi chưa xác nhận @XacNhanGhiDe.', 1;
IF DB_ID(@TenCSDLDich) IS NOT NULL AND @TenCSDLDich <> N'CRM_Uniqlo'
    THROW 53011, N'CSDL đích đã tồn tại. Chọn tên khác hoặc tự xóa CSDL tạm đó trước (không tự động DROP).', 1;

DECLARE @ThuMucData NVARCHAR(400) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(400));
DECLARE @ThuMucLog  NVARCHAR(400) = CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(400));
DECLARE @CoDiffLog BIT = CASE WHEN @TepDiff IS NULL AND @TepLog IS NULL THEN 0 ELSE 1 END;
DECLARE @Lenh NVARCHAR(MAX);

/* Tên logic mặc định do CREATE DATABASE CRM_Uniqlo sinh ra: CRM_Uniqlo, CRM_Uniqlo_log.
   Kiểm tra bằng: RESTORE FILELISTONLY FROM DISK = @TepFull; */
SET @Lenh = N'RESTORE DATABASE ' + QUOTENAME(@TenCSDLDich) + N' FROM DISK = @f WITH '
          + N'MOVE N''CRM_Uniqlo'' TO @dataFile, MOVE N''CRM_Uniqlo_log'' TO @logFile, CHECKSUM, STATS = 10, '
          + CASE WHEN @TenCSDLDich = N'CRM_Uniqlo' THEN N'REPLACE, ' ELSE N'' END
          + CASE WHEN @CoDiffLog = 1 THEN N'NORECOVERY;' ELSE N'RECOVERY;' END;
DECLARE @dataFile NVARCHAR(500) = @ThuMucData + @TenCSDLDich + N'.mdf',
        @logFile  NVARCHAR(500) = @ThuMucLog  + @TenCSDLDich + N'_log.ldf';
EXEC sys.sp_executesql @Lenh, N'@f NVARCHAR(500), @dataFile NVARCHAR(500), @logFile NVARCHAR(500)',
     @f = @TepFull, @dataFile = @dataFile, @logFile = @logFile;

IF @TepDiff IS NOT NULL
BEGIN
    SET @Lenh = N'RESTORE DATABASE ' + QUOTENAME(@TenCSDLDich) + N' FROM DISK = @f WITH CHECKSUM, '
              + CASE WHEN @TepLog IS NULL THEN N'RECOVERY;' ELSE N'NORECOVERY;' END;
    EXEC sys.sp_executesql @Lenh, N'@f NVARCHAR(500)', @f = @TepDiff;
END

IF @TepLog IS NOT NULL
BEGIN
    SET @Lenh = N'RESTORE LOG ' + QUOTENAME(@TenCSDLDich) + N' FROM DISK = @f WITH CHECKSUM, '
              + CASE WHEN @DungLuc IS NULL THEN N'' ELSE N'STOPAT = @t, ' END + N'RECOVERY;';
    EXEC sys.sp_executesql @Lenh, N'@f NVARCHAR(500), @t DATETIME2(0)', @f = @TepLog, @t = @DungLuc;
END

PRINT N'Đã phục hồi vào ' + @TenCSDLDich + N'. Hãy chạy DBCC CHECKDB và các truy vấn kiểm tra.';
GO
/* Sau khi phục hồi:
   DBCC CHECKDB (N'CRM_Uniqlo_PhucHoi') WITH NO_INFOMSGS;
   SELECT COUNT(*) FROM CRM_Uniqlo_PhucHoi.crm.KHACH_HANG;      */
