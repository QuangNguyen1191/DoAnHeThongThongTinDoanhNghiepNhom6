using CrmUniqlo.Api.Auth;
using CrmUniqlo.Api.Data;
using CrmUniqlo.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CrmUniqlo.Api.Controllers.Customer;

/// <summary>
/// K0–K7: cổng Khách hàng. Không endpoint nào nhận MaKH: thủ tục api_kh lấy MaKH từ ngữ cảnh phiên
/// và RLS chặn truy cập dữ liệu của khách khác (chống IDOR).
/// </summary>
[Route("api/customer")]
[Authorize(Policy = Policies.KhachHang)]
public sealed class CustomerController : CrmControllerBase
{
    public CustomerController(CrmDb db) : base(db) { }

    /// <summary>K0. Tổng quan: hồ sơ + hạng, khảo sát đang chờ, voucher, phản hồi gần đây.</summary>
    [HttpGet("dashboard")]
    public async Task<object> Dashboard(CancellationToken ct)
    {
        var hoSo = TryBlock(async () => (await Db.ExecAsync("api_kh.usp_XemHoSo", null, ct)).First());
        var khaoSat = TryBlock(async () => (await Db.ExecAsync("api_kh.usp_DanhSachKhaoSat", null, ct)).Rows());
        var voucher = TryBlock(async () => (await Db.ExecAsync("api_kh.usp_XemVoucherCuaToi", null, ct)).Rows());
        var phanHoi = TryBlock(async () => (await Db.ExecAsync("api_kh.usp_XemPhanHoiCuaToi", null, ct)).Rows());
        await Task.WhenAll(hoSo, khaoSat, voucher, phanHoi);
        return new
        {
            hoSo = hoSo.Result.Value,
            khaoSatChoLam = khaoSat.Result.Value?.Where(k => k.Get<bool>("CoTheThucHien")).ToList(),
            voucher = voucher.Result.Value,
            phanHoiGanDay = phanHoi.Result.Value?.Take(5).ToList(),
            loi = new { hoSo = hoSo.Result.Error, khaoSat = khaoSat.Result.Error, voucher = voucher.Result.Error, phanHoi = phanHoi.Result.Error }
        };
    }

    /// <summary>K1 (KH-2). Hồ sơ của tôi và sở thích.</summary>
    [HttpGet("profile")]
    public async Task<object> Profile(CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_kh.usp_XemHoSo", null, ct);
        return new { hoSo = r.First(), soThich = r.Rows(1) };
    }

    /// <summary>K2 (KH-2). Cập nhật hồ sơ của tôi.</summary>
    [HttpPut("profile")]
    public async Task<IActionResult> UpdateProfile(UpdateMyProfileRequest r, CancellationToken ct)
    {
        AuthController.ValidateNgaySinh(r.NgaySinh);
        return RowOrNoContent(await Db.ExecAsync("api_kh.usp_CapNhatHoSo", new
        {
            r.HoTen, SDT = r.Sdt, r.GioiTinh, NgaySinh = CrmDb.ToDbDate(r.NgaySinh), r.Email, r.MaTinh,
            r.CapNhatSoThich, DsLoaiQuanTam = Tvp.DanhSachMa(r.DsLoaiQuanTam)
        }, ct));
    }

    /// <summary>K3. Voucher của tôi.</summary>
    [HttpGet("vouchers")]
    public async Task<IReadOnlyList<Row>> Vouchers(CancellationToken ct) =>
        (await Db.ExecAsync("api_kh.usp_XemVoucherCuaToi", null, ct)).Rows();

    /// <summary>K4. Khảo sát được gửi cho tôi.</summary>
    [HttpGet("surveys")]
    public async Task<IReadOnlyList<Row>> Surveys(CancellationToken ct) =>
        (await Db.ExecAsync("api_kh.usp_DanhSachKhaoSat", null, ct)).Rows();

    /// <summary>K5 (KH-4). Nội dung khảo sát (khảo sát không gửi cho tôi → 404).</summary>
    [HttpGet("surveys/{maKS:int}")]
    public async Task<object> Survey(int maKS, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_kh.usp_XemKhaoSat", new { MaKS = maKS }, ct);
        var khaoSat = r.First() ?? throw Errors.ApiException.NotFound("Không tìm thấy khảo sát.");
        return new { khaoSat, cauHoi = r.Rows(1), luaChon = r.Rows(2), traLoiCuaToi = r.Rows(3) };
    }

    /// <summary>K5 (KH-4). Nộp khảo sát; nếu khảo sát có ưu đãi thì nhận voucher.</summary>
    [HttpPost("surveys/{maKS:int}/submit")]
    public async Task<object> Submit(int maKS, SubmitSurveyRequest r, CancellationToken ct)
    {
        var result = await Db.ExecAsync("api_kh.usp_NopKhaoSat", new
        {
            MaKS = maKS,
            TraLoi = Tvp.BangTraLoi(r.TraLoi.Select(a => (a.MaCauHoi!.Value, a.MaLC, a.DiemSo, a.NoiDungTuLuan)))
        }, ct);
        var row = result.First();
        var maVoucher = row?.Get<string>("MaVoucher");
        return new
        {
            hoanThanh = true,
            thongBao = row?.Get<string>("ThongBao"),
            voucher = maVoucher is null ? null : new
            {
                maCode = maVoucher,
                phanTramGiam = row!["PhanTramGiam"],
                hanDung = row["HanDung"]
            }
        };
    }

    /// <summary>K6 (KH-3). Gửi phản hồi về sản phẩm.</summary>
    [HttpPost("feedback")]
    public async Task<IActionResult> SendFeedback(SendFeedbackRequest r, CancellationToken ct) =>
        CreatedRow(await Db.ExecAsync("api_kh.usp_GuiPhanHoi", new { r.MaSP, r.LoaiPH, r.DiemDanhGia, r.NoiDung }, ct));

    /// <summary>
    /// K8. Lịch sử mua hàng của tôi: hóa đơn (mới nhất trước), chi tiết từng hóa đơn và các lần đổi trả.
    /// Lọc theo ngày lập hóa đơn ?tuNgay=&amp;denNgay= (bao gồm hai đầu).
    /// </summary>
    [HttpGet("purchases")]
    public async Task<object> Purchases([FromQuery] PurchaseHistoryQuery q, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_kh.usp_LichSuGiaoDich",
            new { TuNgay = CrmDb.ToDbDate(q.TuNgay), DenNgay = CrmDb.ToDbDate(q.DenNgay) }, ct);
        return new { hoaDon = r.Rows(), chiTiet = r.Rows(1), doiTra = r.Rows(2) };
    }

    /// <summary>K7 (KH-3). Phản hồi của tôi.</summary>
    [HttpGet("feedback")]
    public async Task<IReadOnlyList<Row>> MyFeedback(CancellationToken ct) =>
        (await Db.ExecAsync("api_kh.usp_XemPhanHoiCuaToi", null, ct)).Rows();
}
