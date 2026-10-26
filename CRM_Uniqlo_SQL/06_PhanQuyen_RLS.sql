/* =====================================================================
   Script 06: Phân quyền SQL Server và Row-Level Security
   ---------------------------------------------------------------------
   LỚP 1 – TRẦN QUYỀN THEO CỔNG (SQL Server)
     LOGIN (server)        USER (database)     ROLE (database)
     crm_app_admin    ->   u_app_admin    ->   r_admin      : EXECUTE schema api_admin
     crm_app_quanly   ->   u_app_quanly   ->   r_quanly     : EXECUTE schema api_ql
     crm_app_khachhang->   u_app_khachhang->   r_khachhang  : EXECUTE schema api_kh
     Cả 3 role: EXECUTE + SELECT schema api_chung, EXECUTE sec.usp_DatNguCanh.
     KHÔNG role nào có quyền trực tiếp trên bảng trong schema crm và audit (DENY tường minh).
     Không ai được cấp sysadmin/db_owner.
   LỚP 2 – QUYỀN CHỨC NĂNG (dữ liệu VAI_TRO/QUYEN/VAI_TRO_QUYEN, Admin chỉnh)
     Kiểm tra trong từng thủ tục bằng sec.usp_KiemTraQuyen.
   LỚP 3 – PHẠM VI DỮ LIỆU
     - Khách hàng: thủ tục chỉ dùng MaKH trong SESSION_CONTEXT +
       Row-Level Security trên 7 bảng chứa dữ liệu của từng khách.
     - Quản lý/Admin: phạm vi toàn doanh nghiệp (đề không yêu cầu chia theo
       cửa hàng hay nhân viên phụ trách).
   CHẠY BẰNG: sysadmin (hoặc securityadmin + db_owner).
   TRƯỚC KHI CHẠY: đổi 3 mật khẩu ở phần 1. Máy chủ phải bật SQL Server
   and Windows Authentication mode nếu dùng SQL login.
   ===================================================================== */
USE CRM_Uniqlo;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

/* ---------------------- 1. LOGIN + USER ---------------------- */
DECLARE @MK_Admin     NVARCHAR(128) = N'Doi_MatKhau_Admin#2026',      -- ĐỔI TRƯỚC KHI TRIỂN KHAI
        @MK_QuanLy    NVARCHAR(128) = N'Doi_MatKhau_QuanLy#2026',     -- ĐỔI TRƯỚC KHI TRIỂN KHAI
        @MK_KhachHang NVARCHAR(128) = N'Doi_MatKhau_KhachHang#2026',  -- ĐỔI TRƯỚC KHI TRIỂN KHAI
        @Lenh NVARCHAR(MAX);

IF SUSER_ID(N'crm_app_admin') IS NULL
BEGIN
    SET @Lenh = N'CREATE LOGIN crm_app_admin WITH PASSWORD = ' + QUOTENAME(@MK_Admin, '''')
              + N', DEFAULT_DATABASE = CRM_Uniqlo, CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;';
    EXEC sys.sp_executesql @Lenh;
END
IF SUSER_ID(N'crm_app_quanly') IS NULL
BEGIN
    SET @Lenh = N'CREATE LOGIN crm_app_quanly WITH PASSWORD = ' + QUOTENAME(@MK_QuanLy, '''')
              + N', DEFAULT_DATABASE = CRM_Uniqlo, CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;';
    EXEC sys.sp_executesql @Lenh;
END
IF SUSER_ID(N'crm_app_khachhang') IS NULL
BEGIN
    SET @Lenh = N'CREATE LOGIN crm_app_khachhang WITH PASSWORD = ' + QUOTENAME(@MK_KhachHang, '''')
              + N', DEFAULT_DATABASE = CRM_Uniqlo, CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;';
    EXEC sys.sp_executesql @Lenh;
END
GO

IF USER_ID(N'u_app_admin') IS NULL     CREATE USER u_app_admin     FOR LOGIN crm_app_admin     WITH DEFAULT_SCHEMA = api_admin;
IF USER_ID(N'u_app_quanly') IS NULL    CREATE USER u_app_quanly    FOR LOGIN crm_app_quanly    WITH DEFAULT_SCHEMA = api_ql;
IF USER_ID(N'u_app_khachhang') IS NULL CREATE USER u_app_khachhang FOR LOGIN crm_app_khachhang WITH DEFAULT_SCHEMA = api_kh;
GO

/* ---------------------- 2. DATABASE ROLE ---------------------- */
IF DATABASE_PRINCIPAL_ID(N'r_admin') IS NULL     CREATE ROLE r_admin AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'r_quanly') IS NULL    CREATE ROLE r_quanly AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'r_khachhang') IS NULL CREATE ROLE r_khachhang AUTHORIZATION dbo;
GO
IF IS_ROLEMEMBER(N'r_admin', N'u_app_admin') = 0         ALTER ROLE r_admin ADD MEMBER u_app_admin;
IF IS_ROLEMEMBER(N'r_quanly', N'u_app_quanly') = 0       ALTER ROLE r_quanly ADD MEMBER u_app_quanly;
IF IS_ROLEMEMBER(N'r_khachhang', N'u_app_khachhang') = 0 ALTER ROLE r_khachhang ADD MEMBER u_app_khachhang;
GO

/* ---------------------- 3. CẤP QUYỀN (đặc quyền tối thiểu) ---------------------- */
-- Dùng chung
GRANT EXECUTE ON SCHEMA::api_chung TO r_admin, r_quanly, r_khachhang;
GRANT SELECT  ON SCHEMA::api_chung TO r_admin, r_quanly, r_khachhang;   -- view danh mục công khai
GRANT EXECUTE ON OBJECT::sec.usp_DatNguCanh TO r_admin, r_quanly, r_khachhang;
-- Theo cổng
GRANT EXECUTE ON SCHEMA::api_admin TO r_admin;
GRANT EXECUTE ON SCHEMA::api_ql    TO r_quanly;
GRANT EXECUTE ON SCHEMA::api_kh    TO r_khachhang;
-- Kiểu bảng (TVP) cần quyền EXECUTE để khai báo tham số
GRANT EXECUTE ON TYPE::api_chung.DanhSachMa         TO r_quanly, r_khachhang;
GRANT EXECUTE ON TYPE::api_kh.BangTraLoi            TO r_khachhang;
GRANT EXECUTE ON TYPE::api_ql.DanhSachLuaChon       TO r_quanly;
GRANT EXECUTE ON TYPE::api_admin.DanhSachMaQuyen    TO r_admin;
GRANT EXECUTE ON TYPE::api_admin.BangChiTietHoaDon  TO r_admin;
-- Chặn tường minh truy cập trực tiếp bảng (phòng khi ai đó lỡ cấp cho public).
-- Chuỗi sở hữu (cùng chủ dbo) vẫn cho thủ tục api_* đọc/ghi bảng bình thường.
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::crm   TO r_admin, r_quanly, r_khachhang;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::audit TO r_admin, r_quanly, r_khachhang;
DENY SELECT ON SCHEMA::api_admin TO r_quanly, r_khachhang;   -- view admin chỉ dùng trong thủ tục
DENY SELECT ON SCHEMA::api_ql    TO r_admin, r_khachhang;
GO

/* ---------------------- 4. ROW-LEVEL SECURITY ---------------------- */
/* Vị từ: người gọi KHÔNG thuộc r_khachhang -> thấy mọi dòng (Quản lý, Admin,
   dbo, thủ tục EXECUTE AS OWNER); người gọi thuộc r_khachhang -> chỉ thấy/ghi
   dòng có MaKH = MaKH trong SESSION_CONTEXT (do sec.usp_DatNguCanh đặt read-only).
   - FILTER: lọc âm thầm khi SELECT/UPDATE/DELETE (dòng người khác "không tồn tại").
   - BLOCK AFTER INSERT/UPDATE: chặn ghi dòng mang MaKH của người khác
     (hoặc sửa MaKH sang người khác). Lỗi trả về: Msg 33504.
   Bảng HOA_DON/DOI_TRA không cần RLS vì cổng Khách hàng không đọc chúng
   trực tiếp (không có chức năng xem hóa đơn trong đề). */
IF NOT EXISTS (SELECT 1 FROM sys.security_policies WHERE name = N'pol_DuLieuKhachHang')
BEGIN
    EXEC (N'
CREATE OR ALTER FUNCTION sec.fn_rls_TheoKhachHang (@MaKH INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS DuocPhep
    WHERE ISNULL(IS_MEMBER(N''r_khachhang''), 0) = 0
       OR @MaKH = CAST(SESSION_CONTEXT(N''MaKH'') AS INT);');

    EXEC (N'
CREATE SECURITY POLICY sec.pol_DuLieuKhachHang
    ADD FILTER PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KHACH_HANG,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KHACH_HANG AFTER INSERT,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KHACH_HANG AFTER UPDATE,
    ADD FILTER PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KH_QUAN_TAM,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KH_QUAN_TAM AFTER INSERT,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KH_QUAN_TAM AFTER UPDATE,
    ADD FILTER PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.PHAN_HOI,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.PHAN_HOI AFTER INSERT,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.PHAN_HOI AFTER UPDATE,
    ADD FILTER PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KHAO_SAT_GUI,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KHAO_SAT_GUI AFTER INSERT,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.KHAO_SAT_GUI AFTER UPDATE,
    ADD FILTER PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.TRA_LOI,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.TRA_LOI AFTER INSERT,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.TRA_LOI AFTER UPDATE,
    ADD FILTER PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.TRA_LOI_LUA_CHON,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.TRA_LOI_LUA_CHON AFTER INSERT,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.TRA_LOI_LUA_CHON AFTER UPDATE,
    ADD FILTER PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.VOUCHER,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.VOUCHER AFTER INSERT,
    ADD BLOCK  PREDICATE sec.fn_rls_TheoKhachHang(MaKH) ON crm.VOUCHER AFTER UPDATE
WITH (STATE = ON, SCHEMABINDING = ON);');
    PRINT N'Đã tạo security policy sec.pol_DuLieuKhachHang.';
END
ELSE
    PRINT N'Security policy đã tồn tại – bỏ qua.';
GO

/* ---------------------- 5. KIỂM TRA NHANH SAU KHI CẤP QUYỀN ---------------------- */
SELECT r.name AS DatabaseRole, m.name AS ThanhVien
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name IN (N'r_admin', N'r_quanly', N'r_khachhang', N'db_owner');

SELECT pr.name AS NguoiNhan, pe.state_desc AS TrangThai, pe.permission_name AS Quyen,
       pe.class_desc AS LoaiDoiTuong,
       COALESCE(SCHEMA_NAME(CASE WHEN pe.class = 3 THEN pe.major_id END),
                OBJECT_SCHEMA_NAME(CASE WHEN pe.class = 1 THEN pe.major_id END) + N'.' + OBJECT_NAME(CASE WHEN pe.class = 1 THEN pe.major_id END),
                (SELECT SCHEMA_NAME(t.schema_id) + N'.' + t.name FROM sys.types t WHERE pe.class = 6 AND t.user_type_id = pe.major_id)) AS DoiTuong
FROM sys.database_permissions pe
JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name IN (N'r_admin', N'r_quanly', N'r_khachhang')
ORDER BY pr.name, pe.state_desc, DoiTuong;

SELECT p.name AS ChinhSach, p.is_enabled, OBJECT_SCHEMA_NAME(sp.target_object_id) + N'.' + OBJECT_NAME(sp.target_object_id) AS Bang,
       sp.predicate_type_desc, sp.operation_desc
FROM sys.security_policies p
JOIN sys.security_predicates sp ON sp.object_id = p.object_id
ORDER BY Bang, sp.predicate_type_desc;
GO
PRINT N'Script 06 hoàn tất.';
GO
