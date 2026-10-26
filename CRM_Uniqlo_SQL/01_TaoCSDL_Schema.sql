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
