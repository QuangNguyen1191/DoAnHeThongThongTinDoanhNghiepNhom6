/* =====================================================================
   Script 08b: Kiểm tra tự động SAU KHI TRIỂN KHAI (chạy ngay sau 01 -> 08 và 18)
   ---------------------------------------------------------------------
   Mục đích : xác nhận CSDL CRM_Uniqlo được tạo ĐỦ và ĐÚNG trước khi chạy
              kiểm thử chức năng 12 -> 17.
   Chỉ ĐỌC : script không thay đổi dữ liệu hay cấu trúc. Chạy lại bao nhiêu lần
              cũng được.
   Phạm vi : A. Môi trường   B. Đối tượng CSDL   C. Bảo mật
              D. Dữ liệu danh mục (script 07)   E. Dữ liệu mẫu (script 08)
   Số dự kiến được đếm trực tiếp từ các script 01–08 và 18 (28 bảng, 40 khóa ngoại,
   69 thủ tục, 21 vị từ RLS, ...). Nhóm E chỉ đúng với CSDL vừa nạp dữ liệu
   mẫu, CHƯA bị web/kiểm thử thay đổi.
   Cách đọc : tab Results = bảng chi tiết; tab Messages = từng dòng
              PASS/FAIL và 2 dòng cuối "TONG KET ..." + "KET LUAN: DAT/KHONG DAT".
   ===================================================================== */
USE CRM_Uniqlo;
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'tempdb..#KQ') IS NOT NULL DROP TABLE #KQ;   -- bảng tạm của chính script này
CREATE TABLE #KQ (
    STT     INT IDENTITY(1, 1) PRIMARY KEY,
    Nhom    NVARCHAR(30)  NOT NULL,
    HangMuc NVARCHAR(200) NOT NULL,
    MongDoi NVARCHAR(200) NOT NULL,
    ThucTe  NVARCHAR(1000) NULL,
    KetQua  VARCHAR(4)    NOT NULL
);

/* Bảng so sánh số: MongDoi = ThucTe -> PASS */
DECLARE @So TABLE (Nhom NVARCHAR(30), HangMuc NVARCHAR(200), MongDoi INT, ThucTe INT);

/* ============================ A. MÔI TRƯỜNG ============================ */
DECLARE @PB INT = CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), 4) AS INT);
INSERT #KQ (Nhom, HangMuc, MongDoi, ThucTe, KetQua)
SELECT N'A. Môi trường', N'Phiên bản SQL Server', N'>= 14 (SQL Server 2017)',
       CONCAT(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), N' – ', CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128))),
       CASE WHEN @PB >= 14 THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT N'A. Môi trường', N'Collation CSDL', N'Vietnamese_100_CI_AS',
       CAST(DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS NVARCHAR(128)),
       CASE WHEN CAST(DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS NVARCHAR(128)) = N'Vietnamese_100_CI_AS' THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT N'A. Môi trường', N'Compatibility level', N'>= 140',
       CAST(compatibility_level AS NVARCHAR(10)), CASE WHEN compatibility_level >= 140 THEN 'PASS' ELSE 'FAIL' END
FROM sys.databases WHERE name = DB_NAME()
UNION ALL
SELECT N'A. Môi trường', N'Recovery model (để sao lưu nhật ký)', N'FULL',
       recovery_model_desc, CASE WHEN recovery_model_desc = N'FULL' THEN 'PASS' ELSE 'FAIL' END
FROM sys.databases WHERE name = DB_NAME()
UNION ALL
SELECT N'A. Môi trường', N'Chế độ xác thực máy chủ', N'SQL Server and Windows (Mixed)',
       CASE WHEN SERVERPROPERTY('IsIntegratedSecurityOnly') = 1 THEN N'Chỉ Windows' ELSE N'Mixed' END,
       CASE WHEN SERVERPROPERTY('IsIntegratedSecurityOnly') = 0 THEN 'PASS' ELSE 'FAIL' END;

/* Mọi thủ tục/view/hàm phải được tạo với QUOTED_IDENTIFIER ON và ANSI_NULLS ON.
   Nếu tạo bằng sqlcmd thiếu tham số -I, thủ tục ghi vào bảng có filtered index
   sẽ lỗi 1934 lúc chạy. */
INSERT @So
SELECT N'A. Môi trường', N'Module tạo sai SET QUOTED_IDENTIFIER/ANSI_NULLS (phải = 0)', 0, COUNT(*)
FROM sys.sql_modules m JOIN sys.objects o ON o.object_id = m.object_id
WHERE SCHEMA_NAME(o.schema_id) IN (N'crm', N'sec', N'audit', N'api_chung', N'api_kh', N'api_ql', N'api_admin')
  AND (m.uses_quoted_identifier = 0 OR m.uses_ansi_nulls = 0);

/* ========================= B. ĐỐI TƯỢNG CSDL ========================== */
INSERT @So
SELECT N'B. Đối tượng', N'Schema nghiệp vụ', 7,
       (SELECT COUNT(*) FROM sys.schemas WHERE name IN (N'crm', N'sec', N'audit', N'api_chung', N'api_kh', N'api_ql', N'api_admin'))
UNION ALL SELECT N'B. Đối tượng', N'Bảng (crm + audit)', 28,
       (SELECT COUNT(*) FROM sys.tables WHERE SCHEMA_NAME(schema_id) IN (N'crm', N'audit') AND name NOT LIKE N'%KiemThu%')
UNION ALL SELECT N'B. Đối tượng', N'Khóa chính', 28,
       (SELECT COUNT(*) FROM sys.key_constraints WHERE type = 'PK' AND SCHEMA_NAME(schema_id) IN (N'crm', N'audit'))
UNION ALL SELECT N'B. Đối tượng', N'Ràng buộc UNIQUE', 25,
       (SELECT COUNT(*) FROM sys.key_constraints WHERE type = 'UQ' AND SCHEMA_NAME(schema_id) IN (N'crm', N'audit'))
UNION ALL SELECT N'B. Đối tượng', N'Khóa ngoại', 40,
       (SELECT COUNT(*) FROM sys.foreign_keys WHERE SCHEMA_NAME(schema_id) IN (N'crm', N'audit'))
UNION ALL SELECT N'B. Đối tượng', N'Ràng buộc CHECK', 57,
       (SELECT COUNT(*) FROM sys.check_constraints WHERE SCHEMA_NAME(schema_id) IN (N'crm', N'audit'))
UNION ALL SELECT N'B. Đối tượng', N'Ràng buộc DEFAULT', 27,
       (SELECT COUNT(*) FROM sys.default_constraints WHERE SCHEMA_NAME(schema_id) IN (N'crm', N'audit'))
UNION ALL SELECT N'B. Đối tượng', N'Khóa ngoại/CHECK bị vô hiệu hoặc không tin cậy (phải = 0)', 0,
       (SELECT COUNT(*) FROM sys.foreign_keys WHERE (is_disabled = 1 OR is_not_trusted = 1) AND SCHEMA_NAME(schema_id) IN (N'crm', N'audit'))
     + (SELECT COUNT(*) FROM sys.check_constraints WHERE (is_disabled = 1 OR is_not_trusted = 1) AND SCHEMA_NAME(schema_id) IN (N'crm', N'audit'))
UNION ALL SELECT N'B. Đối tượng', N'Chỉ mục đặt tên IX_/UX_ (script 02, 03, 18)', 38,
       (SELECT COUNT(*) FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id
         WHERE SCHEMA_NAME(t.schema_id) IN (N'crm', N'audit') AND (i.name LIKE N'IX[_]%' OR i.name LIKE N'UX[_]%'))
UNION ALL SELECT N'B. Đối tượng', N'View', 20,
       (SELECT COUNT(*) FROM sys.views WHERE SCHEMA_NAME(schema_id) IN (N'crm', N'sec', N'audit', N'api_chung', N'api_kh', N'api_ql', N'api_admin'))
UNION ALL SELECT N'B. Đối tượng', N'Thủ tục schema api_chung', 6,  (SELECT COUNT(*) FROM sys.procedures WHERE SCHEMA_NAME(schema_id) = N'api_chung')
UNION ALL SELECT N'B. Đối tượng', N'Thủ tục schema api_kh', 10,    (SELECT COUNT(*) FROM sys.procedures WHERE SCHEMA_NAME(schema_id) = N'api_kh')
UNION ALL SELECT N'B. Đối tượng', N'Thủ tục schema api_ql', 21,    (SELECT COUNT(*) FROM sys.procedures WHERE SCHEMA_NAME(schema_id) = N'api_ql')
UNION ALL SELECT N'B. Đối tượng', N'Thủ tục schema api_admin', 24, (SELECT COUNT(*) FROM sys.procedures WHERE SCHEMA_NAME(schema_id) = N'api_admin')
UNION ALL SELECT N'B. Đối tượng', N'Thủ tục schema sec', 6,        (SELECT COUNT(*) FROM sys.procedures WHERE SCHEMA_NAME(schema_id) = N'sec')
UNION ALL SELECT N'B. Đối tượng', N'Thủ tục schema crm (nội bộ)', 2,
       (SELECT COUNT(*) FROM sys.procedures WHERE SCHEMA_NAME(schema_id) = N'crm' AND name NOT LIKE N'usp[_]KiemThu[_]%')
UNION ALL SELECT N'B. Đối tượng', N'Hàm (schema sec)', 7,
       (SELECT COUNT(*) FROM sys.objects WHERE type IN ('FN', 'IF', 'TF') AND SCHEMA_NAME(schema_id) = N'sec')
UNION ALL SELECT N'B. Đối tượng', N'Trigger (crm.TR_DOI_TRA_KiemTra)', 1,
       (SELECT COUNT(*) FROM sys.triggers WHERE name = N'TR_DOI_TRA_KiemTra' AND is_disabled = 0)
UNION ALL SELECT N'B. Đối tượng', N'Kiểu bảng (TVP)', 5,
       (SELECT COUNT(*) FROM sys.table_types WHERE SCHEMA_NAME(schema_id) IN (N'api_chung', N'api_kh', N'api_ql', N'api_admin'));

/* Đủ đúng tên 28 bảng */
DECLARE @Bang TABLE (Ten SYSNAME PRIMARY KEY);
INSERT @Bang VALUES
 (N'audit.NHAT_KY'), (N'crm.CAU_HOI'), (N'crm.CHI_TIET_HOA_DON'), (N'crm.CHUC_VU'), (N'crm.CUA_HANG'),
 (N'crm.DOI_TRA'), (N'crm.HANG_THANH_VIEN'), (N'crm.HOA_DON'), (N'crm.KHACH_HANG'), (N'crm.KHAO_SAT'),
 (N'crm.KHAO_SAT_GUI'), (N'crm.KH_QUAN_TAM'), (N'crm.LICH_SU_HANG'), (N'crm.LOAI_SP'), (N'crm.LUA_CHON'),
 (N'crm.NHAN_VIEN'), (N'crm.NHA_CUNG_CAP'), (N'crm.PHAN_HOI'), (N'crm.QUYEN'), (N'crm.SAN_PHAM'),
 (N'crm.TAI_KHOAN'), (N'crm.TINH_THANH'), (N'crm.TRA_LOI'), (N'crm.TRA_LOI_LUA_CHON'), (N'crm.VAI_TRO'),
 (N'crm.VAI_TRO_QUYEN'), (N'crm.VOUCHER'), (N'crm.YEU_CAU_DAT_LAI_MK');
DECLARE @Thieu NVARCHAR(1000) = (SELECT STRING_AGG(Ten, N', ') FROM @Bang WHERE OBJECT_ID(Ten, N'U') IS NULL);
INSERT #KQ (Nhom, HangMuc, MongDoi, ThucTe, KetQua)
VALUES (N'B. Đối tượng', N'Có đủ đúng tên 28 bảng theo thiết kế', N'Không thiếu bảng nào',
        ISNULL(N'Thiếu: ' + @Thieu, N'Đủ 28 bảng'), CASE WHEN @Thieu IS NULL THEN 'PASS' ELSE 'FAIL' END);

/* Mọi module phải biên dịch được (phát hiện tham chiếu tới bảng/cột không tồn tại).
   sp_refreshsqlmodule dùng cho view/hàm không SCHEMABINDING; thủ tục được kiểm bằng
   sys.dm_sql_referenced_entities (lỗi -> không phân giải được). */
DECLARE @LoiModule NVARCHAR(MAX) = N'', @TenModule NVARCHAR(300);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT QUOTENAME(SCHEMA_NAME(o.schema_id)) + N'.' + QUOTENAME(o.name)
    FROM sys.objects o
    WHERE o.type IN ('P', 'V', 'FN', 'IF', 'TF')
      AND SCHEMA_NAME(o.schema_id) IN (N'crm', N'sec', N'audit', N'api_chung', N'api_kh', N'api_ql', N'api_admin')
      AND o.name NOT LIKE N'usp[_]KiemThu[_]%';
OPEN cur;
FETCH NEXT FROM cur INTO @TenModule;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM sys.dm_sql_referenced_entities(@TenModule, N'OBJECT') r
                   WHERE r.referenced_schema_name IN (N'crm', N'sec', N'audit', N'api_chung', N'api_kh', N'api_ql', N'api_admin')
                     AND r.referenced_id IS NULL AND r.is_ambiguous = 0
                     AND r.referenced_entity_name NOT LIKE N'usp[_]KiemThu[_]%')
            SET @LoiModule += @TenModule + N' (tham chiếu đối tượng không tồn tại); ';
    END TRY
    BEGIN CATCH
        SET @LoiModule += @TenModule + N' (' + ERROR_MESSAGE() + N'); ';
    END CATCH;
    FETCH NEXT FROM cur INTO @TenModule;
END
CLOSE cur; DEALLOCATE cur;
INSERT #KQ (Nhom, HangMuc, MongDoi, ThucTe, KetQua)
VALUES (N'B. Đối tượng', N'Mọi thủ tục/view/hàm phân giải được tham chiếu', N'Không có lỗi',
        CASE WHEN @LoiModule = N'' THEN N'Không có lỗi' ELSE LEFT(@LoiModule, 1000) END,
        CASE WHEN @LoiModule = N'' THEN 'PASS' ELSE 'FAIL' END);

/* ============================= C. BẢO MẬT ============================= */
INSERT @So
SELECT N'C. Bảo mật', N'Database role r_admin, r_quanly, r_khachhang', 3,
       (SELECT COUNT(*) FROM sys.database_principals WHERE type = 'R' AND name IN (N'r_admin', N'r_quanly', N'r_khachhang'))
UNION ALL SELECT N'C. Bảo mật', N'User ứng dụng gắn đúng login', 3,
       (SELECT COUNT(*) FROM sys.database_principals d JOIN sys.server_principals s ON s.sid = d.sid
         WHERE (d.name = N'u_app_admin' AND s.name = N'crm_app_admin')
            OR (d.name = N'u_app_quanly' AND s.name = N'crm_app_quanly')
            OR (d.name = N'u_app_khachhang' AND s.name = N'crm_app_khachhang'))
UNION ALL SELECT N'C. Bảo mật', N'User là thành viên đúng role của cổng', 3,
       (SELECT COUNT(*) FROM sys.database_role_members rm
         JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
         JOIN sys.database_principals u ON u.principal_id = rm.member_principal_id
         WHERE (r.name = N'r_admin' AND u.name = N'u_app_admin')
            OR (r.name = N'r_quanly' AND u.name = N'u_app_quanly')
            OR (r.name = N'r_khachhang' AND u.name = N'u_app_khachhang'))
UNION ALL SELECT N'C. Bảo mật', N'User ứng dụng thuộc role khác (db_owner...) (phải = 0)', 0,
       (SELECT COUNT(*) FROM sys.database_role_members rm
         JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
         JOIN sys.database_principals u ON u.principal_id = rm.member_principal_id
         WHERE u.name IN (N'u_app_admin', N'u_app_quanly', N'u_app_khachhang')
           AND NOT ((r.name = N'r_admin' AND u.name = N'u_app_admin')
                 OR (r.name = N'r_quanly' AND u.name = N'u_app_quanly')
                 OR (r.name = N'r_khachhang' AND u.name = N'u_app_khachhang')))
UNION ALL SELECT N'C. Bảo mật', N'Login ứng dụng thuộc server role (sysadmin...) (phải = 0)', 0,
       (SELECT COUNT(*) FROM sys.server_role_members m JOIN sys.server_principals p ON p.principal_id = m.member_principal_id
         WHERE p.name IN (N'crm_app_admin', N'crm_app_quanly', N'crm_app_khachhang'))
UNION ALL SELECT N'C. Bảo mật', N'Security policy RLS đang bật', 1,
       (SELECT COUNT(*) FROM sys.security_policies WHERE name = N'pol_DuLieuKhachHang' AND is_enabled = 1)
UNION ALL SELECT N'C. Bảo mật', N'Số vị từ RLS (7 bảng x FILTER + 2 BLOCK)', 21,
       (SELECT COUNT(*) FROM sys.security_predicates p JOIN sys.security_policies s ON s.object_id = p.object_id
         WHERE s.name = N'pol_DuLieuKhachHang')
UNION ALL SELECT N'C. Bảo mật', N'Số bảng được RLS bảo vệ', 7,
       (SELECT COUNT(DISTINCT p.target_object_id) FROM sys.security_predicates p JOIN sys.security_policies s ON s.object_id = p.object_id
         WHERE s.name = N'pol_DuLieuKhachHang')
UNION ALL SELECT N'C. Bảo mật', N'DENY SELECT/INSERT/UPDATE/DELETE trên schema crm, audit (3 role x 2 schema x 4 quyền)', 24,
       (SELECT COUNT(*) FROM sys.database_permissions p
         WHERE p.class = 3 AND p.state = 'D' AND SCHEMA_NAME(p.major_id) IN (N'crm', N'audit')
           AND USER_NAME(p.grantee_principal_id) IN (N'r_admin', N'r_quanly', N'r_khachhang')
           AND p.permission_name IN (N'SELECT', N'INSERT', N'UPDATE', N'DELETE'))
UNION ALL SELECT N'C. Bảo mật', N'GRANT trực tiếp trên crm/audit cho bất kỳ ai (phải = 0)', 0,
       (SELECT COUNT(*) FROM sys.database_permissions p
         WHERE p.state IN ('G', 'W')
           AND ((p.class = 3 AND SCHEMA_NAME(p.major_id) IN (N'crm', N'audit'))
             OR (p.class = 1 AND OBJECT_SCHEMA_NAME(p.major_id) IN (N'crm', N'audit')
                 AND OBJECT_NAME(p.major_id) NOT LIKE N'usp[_]KiemThu[_]%')))
UNION ALL SELECT N'C. Bảo mật', N'Quyền cấp cho public trên schema ứng dụng (phải = 0)', 0,
       (SELECT COUNT(*) FROM sys.database_permissions p
         WHERE p.grantee_principal_id = 0 AND p.state IN ('G', 'W')
           AND ((p.class = 3 AND SCHEMA_NAME(p.major_id) IN (N'crm', N'sec', N'audit', N'api_chung', N'api_kh', N'api_ql', N'api_admin'))
             OR (p.class = 1 AND OBJECT_SCHEMA_NAME(p.major_id) IN (N'crm', N'sec', N'audit', N'api_chung', N'api_kh', N'api_ql', N'api_admin'))))
UNION ALL SELECT N'C. Bảo mật', N'GRANT EXECUTE schema đúng cổng (api_chung x3, api_admin, api_ql, api_kh)', 6,
       (SELECT COUNT(*) FROM sys.database_permissions p
         WHERE p.class = 3 AND p.state = 'G' AND p.permission_name = N'EXECUTE'
           AND ((SCHEMA_NAME(p.major_id) = N'api_chung' AND USER_NAME(p.grantee_principal_id) IN (N'r_admin', N'r_quanly', N'r_khachhang'))
             OR (SCHEMA_NAME(p.major_id) = N'api_admin' AND USER_NAME(p.grantee_principal_id) = N'r_admin')
             OR (SCHEMA_NAME(p.major_id) = N'api_ql'    AND USER_NAME(p.grantee_principal_id) = N'r_quanly')
             OR (SCHEMA_NAME(p.major_id) = N'api_kh'    AND USER_NAME(p.grantee_principal_id) = N'r_khachhang')))
UNION ALL SELECT N'C. Bảo mật', N'GRANT EXECUTE schema sai cổng (phải = 0)', 0,
       (SELECT COUNT(*) FROM sys.database_permissions p
         WHERE p.class = 3 AND p.state IN ('G', 'W') AND p.permission_name = N'EXECUTE'
           AND USER_NAME(p.grantee_principal_id) IN (N'r_admin', N'r_quanly', N'r_khachhang')
           AND NOT ((SCHEMA_NAME(p.major_id) = N'api_chung')
                 OR (SCHEMA_NAME(p.major_id) = N'api_admin' AND USER_NAME(p.grantee_principal_id) = N'r_admin')
                 OR (SCHEMA_NAME(p.major_id) = N'api_ql'    AND USER_NAME(p.grantee_principal_id) = N'r_quanly')
                 OR (SCHEMA_NAME(p.major_id) = N'api_kh'    AND USER_NAME(p.grantee_principal_id) = N'r_khachhang')))
UNION ALL SELECT N'C. Bảo mật', N'Mọi schema do dbo sở hữu (chuỗi sở hữu hoạt động)', 7,
       (SELECT COUNT(*) FROM sys.schemas WHERE principal_id = 1
          AND name IN (N'crm', N'sec', N'audit', N'api_chung', N'api_kh', N'api_ql', N'api_admin'));

/* ===================== D. DỮ LIỆU DANH MỤC (script 07) ===================== */
INSERT @So
SELECT N'D. Danh mục', N'Vai trò gốc ADMIN, QUAN_LY, KHACH_HANG', 3,
       (SELECT COUNT(*) FROM crm.VAI_TRO WHERE MaVT IN ('ADMIN', 'QUAN_LY', 'KHACH_HANG'))
UNION ALL SELECT N'D. Danh mục', N'Quyền chức năng (QUYEN)', 20, (SELECT COUNT(*) FROM crm.QUYEN)
UNION ALL SELECT N'D. Danh mục', N'Quyền của vai trò ADMIN', 6,       (SELECT COUNT(*) FROM crm.VAI_TRO_QUYEN WHERE MaVT = 'ADMIN')
UNION ALL SELECT N'D. Danh mục', N'Quyền của vai trò QUAN_LY', 11,    (SELECT COUNT(*) FROM crm.VAI_TRO_QUYEN WHERE MaVT = 'QUAN_LY')
UNION ALL SELECT N'D. Danh mục', N'Quyền của vai trò KHACH_HANG', 3,  (SELECT COUNT(*) FROM crm.VAI_TRO_QUYEN WHERE MaVT = 'KHACH_HANG')
UNION ALL SELECT N'D. Danh mục', N'Hạng thành viên THUONG, VIP', 2,   (SELECT COUNT(*) FROM crm.HANG_THANH_VIEN WHERE MaHang IN ('THUONG', 'VIP'))
UNION ALL SELECT N'D. Danh mục', N'Ngưỡng VIP = 500 điểm', 500,       (SELECT DiemToiThieu FROM crm.HANG_THANH_VIEN WHERE MaHang = 'VIP')
UNION ALL SELECT N'D. Danh mục', N'Chức vụ', 5,                       (SELECT COUNT(*) FROM crm.CHUC_VU)
UNION ALL SELECT N'D. Danh mục', N'Tỉnh/thành (bản rút gọn)', 5,      (SELECT COUNT(*) FROM crm.TINH_THANH);

/* ===================== E. DỮ LIỆU MẪU (script 08) ===================== */
IF EXISTS (SELECT 1 FROM crm.TAI_KHOAN WHERE TenDangNhap = 'admin.it')
BEGIN
    INSERT @So
    SELECT N'E. Dữ liệu mẫu', N'TAI_KHOAN', 16, (SELECT COUNT(*) FROM crm.TAI_KHOAN)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'VAI_TRO (3 gốc + NV_CSKH, QTV_TAI_KHOAN)', 5, (SELECT COUNT(*) FROM crm.VAI_TRO)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'VAI_TRO_QUYEN (20 + 6)', 26, (SELECT COUNT(*) FROM crm.VAI_TRO_QUYEN)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'NHAN_VIEN', 8,          (SELECT COUNT(*) FROM crm.NHAN_VIEN)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'CUA_HANG', 3,           (SELECT COUNT(*) FROM crm.CUA_HANG)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'NHA_CUNG_CAP', 4,       (SELECT COUNT(*) FROM crm.NHA_CUNG_CAP)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'LOAI_SP', 7,            (SELECT COUNT(*) FROM crm.LOAI_SP)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'SAN_PHAM', 14,          (SELECT COUNT(*) FROM crm.SAN_PHAM)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'KHACH_HANG', 12,        (SELECT COUNT(*) FROM crm.KHACH_HANG)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'KH_QUAN_TAM', 23,       (SELECT COUNT(*) FROM crm.KH_QUAN_TAM)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'HOA_DON', 20,           (SELECT COUNT(*) FROM crm.HOA_DON)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'CHI_TIET_HOA_DON', 33,  (SELECT COUNT(*) FROM crm.CHI_TIET_HOA_DON)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'DOI_TRA', 4,            (SELECT COUNT(*) FROM crm.DOI_TRA)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'PHAN_HOI', 10,          (SELECT COUNT(*) FROM crm.PHAN_HOI)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'KHAO_SAT', 4,           (SELECT COUNT(*) FROM crm.KHAO_SAT)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'CAU_HOI', 13,           (SELECT COUNT(*) FROM crm.CAU_HOI)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'LUA_CHON', 23,          (SELECT COUNT(*) FROM crm.LUA_CHON)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'KHAO_SAT_GUI', 15,      (SELECT COUNT(*) FROM crm.KHAO_SAT_GUI)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'TRA_LOI', 35,           (SELECT COUNT(*) FROM crm.TRA_LOI)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'TRA_LOI_LUA_CHON', 21,  (SELECT COUNT(*) FROM crm.TRA_LOI_LUA_CHON)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'VOUCHER', 9,            (SELECT COUNT(*) FROM crm.VOUCHER)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'LICH_SU_HANG (An, Bình lên VIP)', 2, (SELECT COUNT(*) FROM crm.LICH_SU_HANG)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'Điểm Nguyễn Thị An (MaKH 1)', 544,  (SELECT Diem FROM crm.vw_DiemKhachHang WHERE MaKH = 1)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'Điểm Trần Văn Bình (MaKH 2)', 627,  (SELECT Diem FROM crm.vw_DiemKhachHang WHERE MaKH = 2)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'Điểm Hoàng Thu Hà (MaKH 5)', 418,   (SELECT Diem FROM crm.vw_DiemKhachHang WHERE MaKH = 5)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'Số khách hạng VIP (An, Bình)', 2,   (SELECT COUNT(*) FROM crm.KHACH_HANG WHERE MaHang = 'VIP')
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'Khách có hạng lệch với điểm (phải = 0)', 0,
           (SELECT COUNT(*) FROM crm.vw_DiemKhachHang d JOIN crm.KHACH_HANG k ON k.MaKH = d.MaKH
             WHERE k.TrangThaiHoSo = 'HOAT_DONG' AND d.HangHienTai <> d.HangTheoDiem)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'Mật khẩu lưu dạng bcrypt ($2a/$2b/$2y, 60 ký tự)', 16,
           (SELECT COUNT(*) FROM crm.TAI_KHOAN WHERE MatKhauHash LIKE '$2[aby]$%' AND LEN(MatKhauHash) = 60)
    UNION ALL SELECT N'E. Dữ liệu mẫu', N'Mật khẩu dạng văn bản thuần "Demo@2026" (phải = 0)', 0,
           (SELECT COUNT(*) FROM crm.TAI_KHOAN WHERE MatKhauHash = 'Demo@2026');
END
ELSE
    INSERT #KQ (Nhom, HangMuc, MongDoi, ThucTe, KetQua)
    VALUES (N'E. Dữ liệu mẫu', N'Dữ liệu mẫu (script 08)', N'Đã nạp', N'Chưa có tài khoản admin.it – script 08 chưa chạy', 'FAIL');

/* ============================== TỔNG KẾT ============================== */
INSERT #KQ (Nhom, HangMuc, MongDoi, ThucTe, KetQua)
SELECT Nhom, HangMuc, CAST(MongDoi AS NVARCHAR(20)), CAST(ThucTe AS NVARCHAR(20)),
       CASE WHEN ThucTe = MongDoi THEN 'PASS' ELSE 'FAIL' END
FROM @So;

SELECT STT, Nhom, KetQua, HangMuc, MongDoi, ThucTe FROM #KQ ORDER BY Nhom, STT;

DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM #KQ), @Dong NVARCHAR(2000);
WHILE @i <= @n
BEGIN
    SELECT @Dong = CONCAT(KetQua, N' | ', Nhom, N' | ', HangMuc, N' | Mong đợi: ', MongDoi, N' | Thực tế: ', ThucTe)
    FROM #KQ WHERE STT = @i;
    PRINT @Dong;
    SET @i += 1;
END
DECLARE @Fail INT = (SELECT COUNT(*) FROM #KQ WHERE KetQua = 'FAIL');
PRINT N'------------------------------------------------------------';
PRINT CONCAT(N'TONG KET ', DB_NAME(), N' (08b kiem tra trien khai): ', @n - @Fail, N'/', @n, N' PASS, ', @Fail, N' FAIL');
PRINT CASE WHEN @Fail = 0 THEN N'KET LUAN: DAT' ELSE N'KET LUAN: KHONG DAT' END;
SELECT HangMuc AS HANG_MUC_FAIL, MongDoi, ThucTe FROM #KQ WHERE KetQua = 'FAIL';
DROP TABLE #KQ;
GO
