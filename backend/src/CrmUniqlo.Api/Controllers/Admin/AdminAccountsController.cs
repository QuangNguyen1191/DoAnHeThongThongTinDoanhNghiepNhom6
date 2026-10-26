using CrmUniqlo.Api.Auth;
using CrmUniqlo.Api.Data;
using CrmUniqlo.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CrmUniqlo.Api.Controllers.Admin;

/// <summary>A1–A6: quản lý tài khoản (cổng ADMIN). Quyền chi tiết AD_TAI_KHOAN / AD_PHAN_QUYEN do CSDL kiểm.</summary>
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminAccountsController : CrmControllerBase
{
    private readonly PasswordService _passwords;

    public AdminAccountsController(CrmDb db, PasswordService passwords) : base(db) => _passwords = passwords;

    /// <summary>A1. Danh sách tài khoản.</summary>
    [HttpGet("accounts")]
    public async Task<IReadOnlyList<Row>> List([FromQuery] AccountQuery q, CancellationToken ct) =>
        (await Db.ExecAsync("api_admin.usp_DanhSachTaiKhoan", new { q.TuKhoa, q.LoaiTK, q.MaVT, q.TrangThai }, ct)).Rows();

    /// <summary>Nhân viên (để chọn khi tạo tài khoản). Quyền AD_TRA_CUU.</summary>
    [HttpGet("employees")]
    public async Task<IReadOnlyList<Row>> Employees([FromQuery] EmployeeQuery q, CancellationToken ct) =>
        (await Db.ExecAsync("api_admin.usp_DanhSachNhanVien", new { q.TuKhoa, q.MaCV, q.MaCH, q.TrangThai }, ct)).Rows();

    /// <summary>A10. Thêm hồ sơ nhân viên → 201 { maNV }. Quyền AD_DANH_MUC.</summary>
    [HttpPost("employees")]
    public async Task<IActionResult> CreateEmployee(SaveEmployeeRequest r, CancellationToken ct) =>
        CreatedRow(await SaveEmployee(null, r, ct));

    /// <summary>A10. Sửa hồ sơ nhân viên (gửi đủ mọi trường). Chuyển DA_NGHI → CSDL tự khóa tài khoản của nhân viên.</summary>
    [HttpPut("employees/{maNV:int}")]
    public async Task<IActionResult> UpdateEmployee(int maNV, SaveEmployeeRequest r, CancellationToken ct) =>
        RowOrNoContent(await SaveEmployee(maNV, r, ct));

    private Task<ProcResult> SaveEmployee(int? maNV, SaveEmployeeRequest r, CancellationToken ct) =>
        Db.ExecAsync("api_admin.usp_LuuNhanVien", new
        {
            MaNV = maNV, r.HoTen, r.MaCV, SDT = r.Sdt, r.Email, NgayVaoLam = CrmDb.ToDbDate(r.NgayVaoLam), r.MaCH, r.TrangThai
        }, ct);

    /// <summary>A2. Tạo tài khoản nhân viên. API sinh mật khẩu tạm (trả về 1 lần duy nhất); người dùng phải đổi khi đăng nhập.</summary>
    [HttpPost("accounts")]
    public async Task<IActionResult> Create(CreateStaffAccountRequest r, CancellationToken ct)
    {
        var matKhauTam = PasswordService.GenerateTemporary();
        var result = await Db.ExecAsync("api_admin.usp_TaoTaiKhoanNhanVien",
            new { r.MaNV, r.TenDangNhap, MatKhauHashTam = _passwords.Hash(matKhauTam), r.MaVT }, ct);
        return CreatedRow(result, new { r.TenDangNhap, MatKhauTam = matKhauTam });
    }

    /// <summary>A3. Khóa / mở khóa tài khoản.</summary>
    [HttpPatch("accounts/{maTK:int}/lock")]
    public async Task<IActionResult> Lock(int maTK, LockRequest r, CancellationToken ct) =>
        RowOrNoContent(await Db.ExecAsync("api_admin.usp_KhoaMoTaiKhoan", new { MaTK = maTK, Khoa = r.Khoa, r.LyDo }, ct));

    /// <summary>A4. Xóa tài khoản (hồ sơ NV/KH được giữ lại, chỉ gỡ liên kết).</summary>
    [HttpDelete("accounts/{maTK:int}")]
    public async Task<IActionResult> Delete(int maTK, CancellationToken ct) =>
        RowOrNoContent(await Db.ExecAsync("api_admin.usp_XoaTaiKhoan", new { MaTK = maTK }, ct));

    /// <summary>A5. Đặt lại mật khẩu tạm (trả về 1 lần duy nhất).</summary>
    [HttpPost("accounts/{maTK:int}/reset-password")]
    public async Task<IActionResult> ResetPassword(int maTK, CancellationToken ct)
    {
        var matKhauTam = PasswordService.GenerateTemporary();
        await Db.ExecAsync("api_admin.usp_DatLaiMatKhau", new { MaTK = maTK, MatKhauHashTam = _passwords.Hash(matKhauTam) }, ct);
        return Ok(new { maTK, matKhauTam });
    }

    /// <summary>A6. Đổi vai trò.</summary>
    [HttpPut("accounts/{maTK:int}/role")]
    public async Task<IActionResult> ChangeRole(int maTK, ChangeRoleRequest r, CancellationToken ct) =>
        RowOrNoContent(await Db.ExecAsync("api_admin.usp_DoiVaiTro", new { MaTK = maTK, MaVTMoi = r.MaVT }, ct));

    /// <summary>A11. Tra cứu khách hàng (SĐT, email đã che).</summary>
    [HttpGet("customers")]
    public async Task<IReadOnlyList<Row>> Customers([FromQuery] string? tuKhoa, [FromQuery] string? maHang, CancellationToken ct) =>
        (await Db.ExecAsync("api_admin.usp_TraCuuKhachHang", new { TuKhoa = tuKhoa, MaHang = maHang }, ct)).Rows();
}
