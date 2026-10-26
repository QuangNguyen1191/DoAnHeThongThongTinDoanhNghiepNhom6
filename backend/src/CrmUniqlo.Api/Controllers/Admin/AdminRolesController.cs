using CrmUniqlo.Api.Auth;
using CrmUniqlo.Api.Data;
using CrmUniqlo.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CrmUniqlo.Api.Controllers.Admin;

/// <summary>A7: vai trò và quyền (AD_PHAN_QUYEN).</summary>
[Route("api/admin/roles")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminRolesController : CrmControllerBase
{
    public AdminRolesController(CrmDb db) : base(db) { }

    /// <summary>Danh sách vai trò và ma trận quyền (lọc theo maVT nếu có).</summary>
    [HttpGet]
    public async Task<object> List([FromQuery] string? maVT, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_admin.usp_DanhSachVaiTroQuyen", new { MaVT = maVT }, ct);
        return new { vaiTro = r.Rows(0), quyen = r.Rows(1) };
    }

    /// <summary>Tạo vai trò nội bộ (cổng ADMIN hoặc QUAN_LY).</summary>
    [HttpPost]
    public async Task<IActionResult> Create(CreateRoleRequest r, CancellationToken ct) =>
        CreatedRow(await Db.ExecAsync("api_admin.usp_TaoVaiTro", new { r.MaVT, r.TenVT, r.CongTruyCap, r.MoTa }, ct),
            new { r.MaVT });

    /// <summary>Thay toàn bộ danh sách quyền của vai trò.</summary>
    [HttpPut("{maVT}/permissions")]
    public async Task<IActionResult> UpdatePermissions(string maVT, UpdatePermissionsRequest r, CancellationToken ct) =>
        RowOrNoContent(await Db.ExecAsync("api_admin.usp_CapNhatQuyenVaiTro",
            new { MaVT = maVT, DsQuyen = Tvp.DanhSachMaQuyen(r.DsQuyen) }, ct));
}
