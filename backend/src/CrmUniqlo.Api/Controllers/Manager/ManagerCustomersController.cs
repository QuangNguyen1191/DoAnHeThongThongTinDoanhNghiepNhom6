using CrmUniqlo.Api.Auth;
using CrmUniqlo.Api.Data;
using CrmUniqlo.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CrmUniqlo.Api.Controllers.Manager;

/// <summary>Q1–Q7: khách hàng (QL-1 thêm, QL-2 xóa, QL-3 khóa). Quyền QL_KH_* do CSDL kiểm.</summary>
[Route("api/manager/customers")]
[Authorize(Policy = Policies.QuanLy)]
public sealed class ManagerCustomersController : CrmControllerBase
{
    private readonly PasswordService _passwords;

    public ManagerCustomersController(CrmDb db, PasswordService passwords) : base(db) => _passwords = passwords;

    /// <summary>Q1. Tìm khách hàng (lọc, sắp xếp, phân trang).</summary>
    [HttpGet]
    public async Task<PagedResult> Search([FromQuery] CustomerSearchQuery q, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_ql.usp_TimKhachHang", new
        {
            q.TuKhoa, q.MaHang, q.MaTinh, q.GioiTinh, q.TuoiTu, q.TuoiDen, q.MaLoaiQuanTam,
            q.TrangThaiHoSo, q.SapXep, q.Trang, q.SoDong
        }, ct);
        return PagedResult.From(r.Rows(), q.Trang, q.SoDong);
    }

    /// <summary>Q2. Hồ sơ 360° (8 khối: hồ sơ, sở thích, hóa đơn, đổi trả, phản hồi, khảo sát, voucher, lịch sử hạng).</summary>
    [HttpGet("{maKH:int}")]
    public async Task<object> Profile(int maKH, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_ql.usp_XemHoSoKhachHang", new { MaKH = maKH }, ct);
        var hoSo = r.First() ?? throw Errors.ApiException.NotFound("Không tìm thấy khách hàng.");
        return new
        {
            hoSo,
            soThich = r.Rows(1),
            hoaDon = r.Rows(2),
            doiTra = r.Rows(3),
            phanHoi = r.Rows(4),
            khaoSat = r.Rows(5),
            voucher = r.Rows(6),
            lichSuHang = r.Rows(7)
        };
    }

    /// <summary>Q3 (QL-1). Thêm khách hàng; có tenDangNhap thì cấp luôn tài khoản với mật khẩu tạm.</summary>
    [HttpPost]
    public async Task<IActionResult> Create(CreateCustomerRequest r, CancellationToken ct)
    {
        AuthController.ValidateNgaySinh(r.NgaySinh);
        var matKhauTam = string.IsNullOrWhiteSpace(r.TenDangNhap) ? null : PasswordService.GenerateTemporary();
        var result = await Db.ExecAsync("api_ql.usp_ThemKhachHang", new
        {
            r.HoTen, SDT = r.Sdt, r.GioiTinh, NgaySinh = CrmDb.ToDbDate(r.NgaySinh), r.Email, r.MaTinh,
            TenDangNhap = matKhauTam is null ? null : r.TenDangNhap,
            MatKhauHashTam = matKhauTam is null ? null : _passwords.Hash(matKhauTam),
            DsLoaiQuanTam = Tvp.DanhSachMa(r.DsLoaiQuanTam)
        }, ct);
        return CreatedRow(result, matKhauTam is null ? null : new { r.TenDangNhap, MatKhauTam = matKhauTam });
    }

    /// <summary>Q4. Cập nhật hồ sơ khách hàng.</summary>
    [HttpPut("{maKH:int}")]
    public async Task<IActionResult> Update(int maKH, UpdateCustomerRequest r, CancellationToken ct)
    {
        AuthController.ValidateNgaySinh(r.NgaySinh);
        return RowOrNoContent(await Db.ExecAsync("api_ql.usp_CapNhatKhachHang", new
        {
            MaKH = maKH, r.HoTen, SDT = r.Sdt, r.GioiTinh, NgaySinh = CrmDb.ToDbDate(r.NgaySinh), r.Email, r.MaTinh,
            r.CapNhatSoThich, DsLoaiQuanTam = Tvp.DanhSachMa(r.DsLoaiQuanTam)
        }, ct));
    }

    /// <summary>Q5. Cấp tài khoản cho khách chưa có (mật khẩu tạm trả về 1 lần).</summary>
    [HttpPost("{maKH:int}/account")]
    public async Task<IActionResult> GrantAccount(int maKH, GrantCustomerAccountRequest r, CancellationToken ct)
    {
        var matKhauTam = PasswordService.GenerateTemporary();
        var result = await Db.ExecAsync("api_ql.usp_CapTaiKhoanKhachHang",
            new { MaKH = maKH, r.TenDangNhap, MatKhauHashTam = _passwords.Hash(matKhauTam) }, ct);
        return CreatedRow(result, new { MaKH = maKH, r.TenDangNhap, MatKhauTam = matKhauTam });
    }

    /// <summary>Q6 (QL-2). Xóa mềm khách hàng (giữ lịch sử; tài khoản bị khóa).</summary>
    [HttpDelete("{maKH:int}")]
    public async Task<IActionResult> Delete(int maKH, DeleteCustomerRequest r, CancellationToken ct) =>
        RowOrNoContent(await Db.ExecAsync("api_ql.usp_XoaKhachHang", new { MaKH = maKH, r.LyDo }, ct));

    /// <summary>Q7 (QL-3). Khóa / mở khóa tài khoản của khách.</summary>
    [HttpPatch("{maKH:int}/lock")]
    public async Task<IActionResult> Lock(int maKH, LockRequest r, CancellationToken ct) =>
        RowOrNoContent(await Db.ExecAsync("api_ql.usp_KhoaTaiKhoanKhachHang", new { MaKH = maKH, r.Khoa, r.LyDo }, ct));
}
