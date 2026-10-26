using CrmUniqlo.Api.Auth;
using CrmUniqlo.Api.Data;
using CrmUniqlo.Api.Errors;
using CrmUniqlo.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CrmUniqlo.Api.Controllers.Admin;

/// <summary>
/// A17–A24: danh mục sản phẩm, nhà cung cấp, loại sản phẩm (cổng ADMIN).
/// Xem cần AD_TRA_CUU, thêm/sửa cần AD_DANH_MUC (CSDL kiểm). Không có xóa: ngừng bán / ngừng hợp tác
/// bằng trường TrangThai để giữ lịch sử hóa đơn, phản hồi.
/// </summary>
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminCatalogController : CrmControllerBase
{
    public AdminCatalogController(CrmDb db) : base(db) { }

    /// <summary>A17. Danh mục phụ cho các ô chọn: loại SP, cửa hàng, chức vụ, tỉnh/thành.</summary>
    [HttpGet("lookups")]
    public async Task<object> Lookups(CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_admin.usp_DanhSachDanhMucPhu", null, ct);
        return new { loaiSP = r.Rows(), cuaHang = r.Rows(1), chucVu = r.Rows(2), tinhThanh = r.Rows(3) };
    }

    /// <summary>A18. Tìm sản phẩm (phân trang).</summary>
    [HttpGet("products")]
    public async Task<PagedResult> Products([FromQuery] ProductQuery q, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_admin.usp_TimSanPham", new
        {
            q.TuKhoa, MaSP = (int?)null, q.MaLoai, q.MaNCC, q.TrangThai, q.GiaTu, q.GiaDen, q.SapXep, q.Trang, q.SoDong
        }, ct);
        return PagedResult.From(r.Rows(), q.Trang, q.SoDong);
    }

    /// <summary>A18. Một sản phẩm (form sửa).</summary>
    [HttpGet("products/{maSP:int}")]
    public async Task<Row> Product(int maSP, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_admin.usp_TimSanPham", new
        {
            TuKhoa = (string?)null, MaSP = maSP, MaLoai = (int?)null, MaNCC = (int?)null, TrangThai = (string?)null,
            GiaTu = (decimal?)null, GiaDen = (decimal?)null, SapXep = "TEN_TANG", Trang = 1, SoDong = 1
        }, ct);
        var row = r.First() ?? throw ApiException.NotFound("Không tìm thấy sản phẩm.");
        row.Remove("TongSoDong");
        return row;
    }

    /// <summary>A19. Thêm sản phẩm → 201 { maSP }.</summary>
    [HttpPost("products")]
    public async Task<IActionResult> CreateProduct(SaveProductRequest r, CancellationToken ct) =>
        CreatedRow(await SaveProduct(null, r, ct));

    /// <summary>A20. Sửa sản phẩm (gửi đủ mọi trường) → 200 { maSP }.</summary>
    [HttpPut("products/{maSP:int}")]
    public async Task<IActionResult> UpdateProduct(int maSP, SaveProductRequest r, CancellationToken ct) =>
        RowOrNoContent(await SaveProduct(maSP, r, ct));

    private Task<ProcResult> SaveProduct(int? maSP, SaveProductRequest r, CancellationToken ct)
    {
        if (r.TrangThai == "SAP_RA_MAT" && r.NgayRaMat is null)
            throw ApiException.Unprocessable("VALIDATION", "Sản phẩm sắp ra mắt phải có ngày ra mắt.", "ngayRaMat");
        return Db.ExecAsync("api_admin.usp_LuuSanPham", new
        {
            MaSP = maSP, r.MaSKU, r.TenSP, r.MaLoai, r.MaNCC, r.GiaNiemYet, r.TrangThai,
            NgayRaMat = CrmDb.ToDbDate(r.NgayRaMat), r.ChatLieu, r.MoTa
        }, ct);
    }

    /// <summary>A21. Tìm nhà cung cấp (phân trang, kèm số sản phẩm).</summary>
    [HttpGet("suppliers")]
    public async Task<PagedResult> Suppliers([FromQuery] SupplierQuery q, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_admin.usp_TimNhaCungCap", new
        {
            q.TuKhoa, MaNCC = (int?)null, q.QuocGia, q.TrangThai, q.SapXep, q.Trang, q.SoDong
        }, ct);
        return PagedResult.From(r.Rows(), q.Trang, q.SoDong);
    }

    /// <summary>A21. Một nhà cung cấp (form sửa).</summary>
    [HttpGet("suppliers/{maNCC:int}")]
    public async Task<Row> Supplier(int maNCC, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_admin.usp_TimNhaCungCap", new
        {
            TuKhoa = (string?)null, MaNCC = maNCC, QuocGia = (string?)null, TrangThai = (string?)null,
            SapXep = "TEN_TANG", Trang = 1, SoDong = 1
        }, ct);
        var row = r.First() ?? throw ApiException.NotFound("Không tìm thấy nhà cung cấp.");
        row.Remove("TongSoDong");
        return row;
    }

    /// <summary>A22. Thêm nhà cung cấp → 201 { maNCC }.</summary>
    [HttpPost("suppliers")]
    public async Task<IActionResult> CreateSupplier(SaveSupplierRequest r, CancellationToken ct) =>
        CreatedRow(await SaveSupplier(null, r, ct));

    /// <summary>A23. Sửa nhà cung cấp (gửi đủ mọi trường) → 200 { maNCC }.</summary>
    [HttpPut("suppliers/{maNCC:int}")]
    public async Task<IActionResult> UpdateSupplier(int maNCC, SaveSupplierRequest r, CancellationToken ct) =>
        RowOrNoContent(await SaveSupplier(maNCC, r, ct));

    private Task<ProcResult> SaveSupplier(int? maNCC, SaveSupplierRequest r, CancellationToken ct) =>
        Db.ExecAsync("api_admin.usp_LuuNhaCungCap", new
        {
            MaNCC = maNCC, r.TenNCC, r.QuocGia, r.DiaChi, SDT = r.Sdt, r.Email, r.TrangThai
        }, ct);

    /// <summary>A24. Thêm loại sản phẩm → 201 { maLoai }. Danh sách loại: GET /api/admin/lookups.</summary>
    [HttpPost("categories")]
    public async Task<IActionResult> CreateCategory(SaveCategoryRequest r, CancellationToken ct) =>
        CreatedRow(await Db.ExecAsync("api_admin.usp_LuuLoaiSP", new { MaLoai = (int?)null, r.TenLoai, r.MoTa }, ct));

    /// <summary>A24. Sửa loại sản phẩm → 200 { maLoai }.</summary>
    [HttpPut("categories/{maLoai:int}")]
    public async Task<IActionResult> UpdateCategory(int maLoai, SaveCategoryRequest r, CancellationToken ct) =>
        RowOrNoContent(await Db.ExecAsync("api_admin.usp_LuuLoaiSP", new { MaLoai = maLoai, r.TenLoai, r.MoTa }, ct));
}
