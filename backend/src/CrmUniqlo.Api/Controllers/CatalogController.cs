using CrmUniqlo.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CrmUniqlo.Api.Controllers;

/// <summary>Danh mục công khai từ các view api_chung (liệt kê cột cụ thể, không SELECT *).</summary>
[ApiController]
[Route("api/catalog")]
[AllowAnonymous]
[Produces("application/json")]
public sealed class CatalogController : ControllerBase
{
    private readonly CrmDb _db;

    public CatalogController(CrmDb db) => _db = db;

    /// <summary>Tỉnh/thành.</summary>
    [HttpGet("provinces")]
    public Task<IReadOnlyList<Row>> Provinces(CancellationToken ct) =>
        _db.QueryViewAsync("SELECT MaTinh, TenTinh FROM api_chung.vw_TinhThanh ORDER BY TenTinh;", ct);

    /// <summary>Loại sản phẩm (dùng cho sở thích).</summary>
    [HttpGet("categories")]
    public Task<IReadOnlyList<Row>> Categories(CancellationToken ct) =>
        _db.QueryViewAsync("SELECT MaLoai, TenLoai, MoTa FROM api_chung.vw_LoaiSP ORDER BY TenLoai;", ct);

    /// <summary>Sản phẩm (dùng khi gửi phản hồi, tạo khảo sát thăm dò).</summary>
    [HttpGet("products")]
    public Task<IReadOnlyList<Row>> Products(CancellationToken ct) =>
        _db.QueryViewAsync(
            "SELECT MaSP, MaSKU, TenSP, MaLoai, TenLoai, ChatLieu, MoTa, GiaNiemYet, TrangThai, NgayRaMat " +
            "FROM api_chung.vw_SanPham ORDER BY TenSP;", ct);

    /// <summary>Hạng thành viên.</summary>
    [HttpGet("tiers")]
    public Task<IReadOnlyList<Row>> Tiers(CancellationToken ct) =>
        _db.QueryViewAsync("SELECT MaHang, TenHang, DiemToiThieu, MoTa FROM api_chung.vw_HangThanhVien ORDER BY DiemToiThieu;", ct);
}
