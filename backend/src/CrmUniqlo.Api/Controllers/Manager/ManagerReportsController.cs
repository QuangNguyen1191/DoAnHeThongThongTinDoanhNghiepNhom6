using CrmUniqlo.Api.Auth;
using CrmUniqlo.Api.Data;
using CrmUniqlo.Api.Errors;
using CrmUniqlo.Api.Infrastructure;
using CrmUniqlo.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CrmUniqlo.Api.Controllers.Manager;

/// <summary>
/// Q9–Q10 (QL-5): báo cáo khách hàng theo độ tuổi (cơ cấu) và sở thích (QL_BAO_CAO).
/// Thêm ?format=csv&amp;bang=... để tải một bảng dạng CSV.
/// </summary>
[Route("api/manager/reports")]
[Authorize(Policy = Policies.QuanLy)]
public sealed class ManagerReportsController : CrmControllerBase
{
    public ManagerReportsController(CrmDb db) : base(db) { }

    /// <summary>Cơ cấu khách hàng. Bảng: nhomTuoi | gioiTinh | tinhThanh | hang.</summary>
    [HttpGet("demographics")]
    public async Task<IActionResult> Demographics([FromQuery] string? format, [FromQuery] string? bang, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_ql.usp_BaoCaoCoCauKhachHang", null, ct);
        return Respond(format, bang, "co-cau-khach-hang", new()
        {
            ["nhomTuoi"] = r.Rows(0), ["gioiTinh"] = r.Rows(1), ["tinhThanh"] = r.Rows(2), ["hang"] = r.Rows(3)
        });
    }

    /// <summary>Sở thích. Bảng: theoLoai | theoNhomTuoi.</summary>
    [HttpGet("interests")]
    public async Task<IActionResult> Interests([FromQuery] string? format, [FromQuery] string? bang, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_ql.usp_BaoCaoSoThich", null, ct);
        return Respond(format, bang, "so-thich", new() { ["theoLoai"] = r.Rows(0), ["theoNhomTuoi"] = r.Rows(1) });
    }

    private IActionResult Respond(string? format, string? bang, string fileName, Dictionary<string, IReadOnlyList<Row>> sections)
    {
        if (!string.Equals(format, "csv", StringComparison.OrdinalIgnoreCase))
            return Ok(sections);

        var key = bang ?? sections.Keys.First();
        var match = sections.FirstOrDefault(s => string.Equals(s.Key, key, StringComparison.OrdinalIgnoreCase));
        if (match.Value is null)
            throw new ApiException(StatusCodes.Status400BadRequest, "VALIDATION",
                $"Bảng không hợp lệ. Chọn một trong: {string.Join(", ", sections.Keys)}.", "bang");
        return Csv.File(match.Value, $"{fileName}-{match.Key}-{DateTime.Now:yyyyMMdd}.csv");
    }
}
