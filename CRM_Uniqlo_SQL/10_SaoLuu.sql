/* =====================================================================
   Script 10: Sao lưu CSDL (đáp ứng yêu cầu "phương án sao lưu và phục hồi")
   ---------------------------------------------------------------------
   CHIẾN LƯỢC ĐỀ XUẤT (recovery model FULL – đã đặt ở script 01)
     - FULL         : 01:00 Chủ nhật hằng tuần
     - DIFFERENTIAL : 01:00 Thứ 2 -> Thứ 7
     - LOG          : mỗi 30 phút trong giờ làm việc (08:00-22:00), mỗi 2 giờ ngoài giờ
     => RPO (mất dữ liệu tối đa) ~ 30 phút; RTO mục tiêu < 1 giờ.
     - Lưu giữ: 4 bản FULL gần nhất (4 tuần) + DIFF/LOG tương ứng.
     - Sao chép thư mục sao lưu sang ổ khác/NAS/đám mây mỗi ngày (quy tắc 3-2-1:
       3 bản, 2 loại thiết bị, 1 bản ngoài máy chủ).
     - Mỗi tuần khôi phục thử bản mới nhất sang CSDL tạm (script 10b) để
       chắc chắn bản sao lưu dùng được.
   LẬP LỊCH
     - SQL Server Standard/Enterprise: dùng SQL Server Agent (Job + Schedule).
     - SQL Server Express (không có Agent): lưu 3 bản của tệp này chỉ khác
       biến @Loai (FULL/DIFF/LOG) rồi tạo 3 tác vụ Windows Task Scheduler, ví dụ:
         sqlcmd -S .\SQLEXPRESS -E -I -f 65001 -i "D:\CRM\10_SaoLuu_FULL.sql" -o "D:\CRM\log_saoluu.txt"
     - Nếu SERVERPROPERTY('InstanceDefaultBackupPath') trả NULL (SQL Server 2017),
       script dùng C:\SaoLuu – hãy tạo thư mục này hoặc sửa @ThuMuc.
   QUYỀN: sysadmin hoặc db_backupoperator. Tài khoản dịch vụ SQL Server
   phải có quyền ghi vào thư mục sao lưu. Ứng dụng KHÔNG được cấp quyền BACKUP.
   ===================================================================== */
USE master;
GO
SET NOCOUNT ON;

DECLARE @Loai     VARCHAR(4)     = 'FULL';     -- FULL | DIFF | LOG
DECLARE @ThuMuc   NVARCHAR(400)  =
        COALESCE(CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(400)), N'C:\SaoLuu');
-- Có thể chỉ định cố định, ví dụ: SET @ThuMuc = N'D:\SaoLuu\CRM_Uniqlo';

IF RIGHT(@ThuMuc, 1) <> N'\' SET @ThuMuc += N'\';
DECLARE @Moc NVARCHAR(20) = FORMAT(SYSDATETIME(), 'yyyyMMdd_HHmmss');
DECLARE @Tep NVARCHAR(500) = @ThuMuc + N'CRM_Uniqlo_' + @Loai + N'_' + @Moc
                           + CASE WHEN @Loai = 'LOG' THEN N'.trn' ELSE N'.bak' END;
DECLARE @Ten NVARCHAR(128) = N'CRM_Uniqlo ' + @Loai + N' ' + @Moc;

IF @Loai NOT IN ('FULL', 'DIFF', 'LOG')
    THROW 53001, N'@Loai phải là FULL, DIFF hoặc LOG.', 1;

IF @Loai = 'FULL'
    BACKUP DATABASE CRM_Uniqlo TO DISK = @Tep
        WITH INIT, CHECKSUM, STATS = 10, NAME = @Ten,
             DESCRIPTION = N'Sao lưu toàn bộ CSDL CRM Uniqlo';
ELSE IF @Loai = 'DIFF'
    BACKUP DATABASE CRM_Uniqlo TO DISK = @Tep
        WITH DIFFERENTIAL, INIT, CHECKSUM, STATS = 10, NAME = @Ten;
ELSE
    BACKUP LOG CRM_Uniqlo TO DISK = @Tep
        WITH INIT, CHECKSUM, STATS = 10, NAME = @Ten;

/* Kiểm tra tính toàn vẹn của tệp vừa tạo (không khôi phục) */
RESTORE VERIFYONLY FROM DISK = @Tep WITH CHECKSUM;
PRINT N'Đã sao lưu và kiểm tra: ' + @Tep;
GO

/* Lịch sử sao lưu gần nhất (dùng để chọn tệp khi phục hồi) */
SELECT TOP (20)
       bs.backup_start_date AS BatDau, bs.backup_finish_date AS KetThuc,
       CASE bs.type WHEN 'D' THEN 'FULL' WHEN 'I' THEN 'DIFF' WHEN 'L' THEN 'LOG' ELSE bs.type END AS Loai,
       CAST(bs.backup_size / 1048576.0 AS DECIMAL(12, 2)) AS KichThuocMB,
       bmf.physical_device_name AS Tep, bs.is_copy_only, bs.has_backup_checksums
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = N'CRM_Uniqlo'
ORDER BY bs.backup_finish_date DESC;
GO

/* Dọn lịch sử sao lưu cũ hơn 60 ngày trong msdb (không xóa tệp trên đĩa). */
DECLARE @MocXoa DATETIME = DATEADD(DAY, -60, GETDATE());
EXEC msdb.dbo.sp_delete_backuphistory @oldest_date = @MocXoa;
GO
