/* =====================================================================
   Script 11: Tạo bản sao CRM_Uniqlo_Test để chạy kiểm thử chức năng
   ---------------------------------------------------------------------
   Kiểm thử 13–16 GHI dữ liệu (thêm khách, nộp khảo sát, khóa tài khoản...).
   Để dữ liệu demo của CRM_Uniqlo không bị thay đổi, ta sao lưu COPY_ONLY
   (không làm lệch chuỗi sao lưu chính) rồi khôi phục thành CRM_Uniqlo_Test.
   Đồng thời đây là một lần "khôi phục thử" chứng minh bản sao lưu dùng được.
   Script CHỈ ghi đè CSDL có tên đúng CRM_Uniqlo_Test.
   ===================================================================== */
USE master;
GO
SET NOCOUNT ON;

DECLARE @ThuMuc NVARCHAR(400) =
        COALESCE(CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(400)), N'C:\SaoLuu');
IF RIGHT(@ThuMuc, 1) <> N'\' SET @ThuMuc += N'\';
DECLARE @Tep NVARCHAR(500) = @ThuMuc + N'CRM_Uniqlo_COPYONLY_KiemThu.bak';

BACKUP DATABASE CRM_Uniqlo TO DISK = @Tep WITH COPY_ONLY, INIT, CHECKSUM, STATS = 25;

DECLARE @Data NVARCHAR(500) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(400)) + N'CRM_Uniqlo_Test.mdf';
DECLARE @Log  NVARCHAR(500) = CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(400)) + N'CRM_Uniqlo_Test_log.ldf';

IF DB_ID(N'CRM_Uniqlo_Test') IS NOT NULL
    ALTER DATABASE CRM_Uniqlo_Test SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE CRM_Uniqlo_Test FROM DISK = @Tep
    WITH MOVE N'CRM_Uniqlo' TO @Data, MOVE N'CRM_Uniqlo_log' TO @Log,
         REPLACE, RECOVERY, CHECKSUM, STATS = 25;

ALTER DATABASE CRM_Uniqlo_Test SET MULTI_USER;
ALTER DATABASE CRM_Uniqlo_Test SET RECOVERY SIMPLE;   -- CSDL kiểm thử không cần log backup
PRINT N'Đã tạo CRM_Uniqlo_Test từ bản sao lưu COPY_ONLY: ' + @Tep;
GO
