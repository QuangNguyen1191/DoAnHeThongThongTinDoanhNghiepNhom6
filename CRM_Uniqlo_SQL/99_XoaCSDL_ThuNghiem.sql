/* =====================================================================
   Script 99: XÓA CSDL THỬ NGHIỆM ĐỂ CÀI LẠI TỪ ĐẦU   *** NGUY HIỂM ***
   ---------------------------------------------------------------------
   CHỈ dùng trên máy THỬ NGHIỆM, khi cần cài lại sạch sau khi sửa script
   (ví dụ sửa định nghĩa bảng ở script 02 – script 02 không sửa bảng đã có).
   Script XÓA VĨNH VIỄN: CRM_Uniqlo, CRM_Uniqlo_Test, CRM_Uniqlo_PhucHoi
   và (tùy chọn) 3 login crm_app_*. Tệp sao lưu .bak KHÔNG bị xóa.
   KHÔNG BAO GIỜ chạy trên máy đang có dữ liệu thật của nhóm/web.
   Script KHÔNG nằm trong chay_trien_khai_va_kiem_thu.ps1, phải tự mở và chạy.

   Cách dùng:
     1. Sửa @XacNhan thành đúng chuỗi: XOA CSDL THU NGHIEM
     2. Muốn tạo lại login với mật khẩu mới ở script 06: đặt @XoaLogin = 1
     3. Execute. Sau đó chạy lại 01 -> 08 (hoặc chạy lại tệp .ps1).
   ===================================================================== */
USE master;
GO
SET NOCOUNT ON;

DECLARE @XacNhan  NVARCHAR(100) = N'';   -- <<< gõ: XOA CSDL THU NGHIEM
DECLARE @XoaLogin BIT = 0;               -- 1 = xóa luôn 3 login crm_app_*

IF @XacNhan <> N'XOA CSDL THU NGHIEM'
BEGIN
    RAISERROR (N'Chưa xác nhận. Sửa @XacNhan = N''XOA CSDL THU NGHIEM'' rồi chạy lại. Không có gì bị xóa.', 16, 1);
    RETURN;
END

DECLARE @Ten SYSNAME, @Lenh NVARCHAR(400);
DECLARE @DS TABLE (STT INT, Ten SYSNAME);
INSERT @DS VALUES (1, N'CRM_Uniqlo_Test'), (2, N'CRM_Uniqlo_PhucHoi'), (3, N'CRM_Uniqlo');

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT Ten FROM @DS ORDER BY STT;
OPEN cur;
FETCH NEXT FROM cur INTO @Ten;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF DB_ID(@Ten) IS NOT NULL
    BEGIN
        SET @Lenh = N'ALTER DATABASE ' + QUOTENAME(@Ten) + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; '
                  + N'DROP DATABASE ' + QUOTENAME(@Ten) + N';';
        EXEC sys.sp_executesql @Lenh;
        PRINT N'Đã xóa CSDL ' + @Ten;
    END
    ELSE
        PRINT N'Không có CSDL ' + @Ten + N' – bỏ qua.';
    FETCH NEXT FROM cur INTO @Ten;
END
CLOSE cur; DEALLOCATE cur;

IF @XoaLogin = 1
BEGIN
    IF SUSER_ID(N'crm_app_admin') IS NOT NULL     BEGIN DROP LOGIN crm_app_admin;     PRINT N'Đã xóa login crm_app_admin'; END
    IF SUSER_ID(N'crm_app_quanly') IS NOT NULL    BEGIN DROP LOGIN crm_app_quanly;    PRINT N'Đã xóa login crm_app_quanly'; END
    IF SUSER_ID(N'crm_app_khachhang') IS NOT NULL BEGIN DROP LOGIN crm_app_khachhang; PRINT N'Đã xóa login crm_app_khachhang'; END
END
PRINT N'Script 99 hoàn tất. Chạy lại 01 -> 08 để cài mới.';
GO
