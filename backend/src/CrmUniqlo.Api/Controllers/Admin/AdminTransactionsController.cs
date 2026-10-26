using CrmUniqlo.Api.Auth;
using CrmUniqlo.Api.Data;
using CrmUniqlo.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CrmUniqlo.Api.Controllers.Admin;

/// <summary>A12–A14: nạp hóa đơn, đổi trả, xét hạng (AD_NAP_GIAO_DICH). Điểm/hạng do CSDL tính.</summary>
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminTransactionsController : CrmControllerBase
{
    public AdminTransactionsController(CrmDb db) : base(db) { }

    /// <summary>A12. Danh sách hóa đơn (phân trang, tối đa 500 dòng).</summary>
    [HttpGet("invoices")]
    public async Task<PagedResult> List([FromQuery] InvoiceQuery q, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_admin.usp_DanhSachHoaDon", new
        {
            q.SoHoaDon, q.MaKH, TuNgay = CrmDb.ToDbDate(q.TuNgay), DenNgay = CrmDb.ToDbDate(q.DenNgay), q.Trang, q.SoDong
        }, ct);
        return PagedResult.From(r.Rows(), q.Trang, q.SoDong);
    }

    /// <summary>A12. Chi tiết một hóa đơn (kèm các dòng hàng).</summary>
    [HttpGet("invoices/{soHoaDon}")]
    public async Task<object> Detail(string soHoaDon, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_admin.usp_DanhSachHoaDon", new
        {
            SoHoaDon = soHoaDon, MaKH = (int?)null, TuNgay = (DateTime?)null, DenNgay = (DateTime?)null, Trang = 1, SoDong = 1
        }, ct);
        var hoaDon = r.First() ?? throw Errors.ApiException.NotFound("Không tìm thấy hóa đơn.");
        hoaDon.Remove("TongSoDong");
        return new { hoaDon, chiTiet = r.Rows(1) };
    }

    /// <summary>A13. Nạp hóa đơn (CSDL tự cộng điểm, áp voucher, xét hạng trong một transaction).</summary>
    [HttpPost("invoices")]
    public async Task<IActionResult> Create(CreateInvoiceRequest r, CancellationToken ct) =>
        CreatedRow(await Db.ExecAsync("api_admin.usp_NhapHoaDon", new
        {
            r.SoHoaDon, r.MaKH, r.KenhBan, NgayLap = Db.ToDbTime(r.NgayLap), r.MaCH, r.MaNV, r.MaCodeVoucher,
            ChiTiet = Tvp.BangChiTietHoaDon(r.ChiTiet.Select(x => (x.MaSKU, x.SoLuong, x.DonGiaBan)))
        }, ct));

    /// <summary>A14. Nạp đổi trả.</summary>
    [HttpPost("returns")]
    public async Task<IActionResult> CreateReturn(CreateReturnRequest r, CancellationToken ct) =>
        CreatedRow(await Db.ExecAsync("api_admin.usp_NhapDoiTra", new
        {
            r.SoHoaDon, r.MaSKU, r.SoLuong, r.LyDo, NgayDoiTra = Db.ToDbTime(r.NgayDoiTra), r.GhiChu
        }, ct));

    /// <summary>A14. Xét lại hạng toàn bộ khách hàng.</summary>
    [HttpPost("tiers/recalculate")]
    public async Task<IActionResult> RecalculateTiers(CancellationToken ct) =>
        RowOrNoContent(await Db.ExecAsync("api_admin.usp_XetHangToanBo", null, ct));
}
