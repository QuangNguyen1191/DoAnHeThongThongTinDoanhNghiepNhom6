using CrmUniqlo.Api.Auth;
using CrmUniqlo.Api.Data;
using CrmUniqlo.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CrmUniqlo.Api.Controllers.Manager;

/// <summary>Q12–Q15 (QL-6, QL-7): khảo sát. Quyền QL_KS_QUAN_LY / QL_KS_GUI / QL_KS_THONG_KE do CSDL kiểm.</summary>
[Route("api/manager")]
[Authorize(Policy = Policies.QuanLy)]
public sealed class ManagerSurveysController : CrmControllerBase
{
    public ManagerSurveysController(CrmDb db) : base(db) { }

    [HttpGet("surveys")]
    public async Task<IReadOnlyList<Row>> List([FromQuery] SurveyListQuery q, CancellationToken ct) =>
        (await Db.ExecAsync("api_ql.usp_DanhSachKhaoSat", new { q.TrangThai, q.MucDich }, ct)).Rows();

    /// <summary>Chi tiết: thông tin, câu hỏi, lựa chọn.</summary>
    [HttpGet("surveys/{maKS:int}")]
    public async Task<object> Detail(int maKS, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_ql.usp_XemChiTietKhaoSat", new { MaKS = maKS }, ct);
        var khaoSat = r.First() ?? throw Errors.ApiException.NotFound("Không tìm thấy khảo sát.");
        return new { khaoSat, cauHoi = r.Rows(1), luaChon = r.Rows(2) };
    }

    /// <summary>Tạo khảo sát (trạng thái Nháp).</summary>
    [HttpPost("surveys")]
    public async Task<IActionResult> Create(CreateSurveyRequest r, CancellationToken ct) =>
        CreatedRow(await Db.ExecAsync("api_ql.usp_TaoKhaoSat", new
        {
            r.TieuDe, r.MucDich, HanTraLoi = Db.ToDbTime(r.HanTraLoi), r.MoTa, r.MaSP, r.PhanTramVoucher, r.SoNgayHieuLucVoucher
        }, ct));

    /// <summary>Thêm câu hỏi (khi khảo sát còn Nháp).</summary>
    [HttpPost("surveys/{maKS:int}/questions")]
    public async Task<IActionResult> AddQuestion(int maKS, AddQuestionRequest r, CancellationToken ct) =>
        CreatedRow(await Db.ExecAsync("api_ql.usp_ThemCauHoi", new
        {
            MaKS = maKS, r.NoiDung, r.LoaiCauHoi, r.BatBuoc, DsLuaChon = Tvp.DanhSachLuaChon(r.LuaChon)
        }, ct));

    /// <summary>Xóa câu hỏi (khi khảo sát còn Nháp).</summary>
    [HttpDelete("questions/{maCauHoi:int}")]
    public async Task<IActionResult> DeleteQuestion(int maCauHoi, CancellationToken ct) =>
        RowOrNoContent(await Db.ExecAsync("api_ql.usp_XoaCauHoi", new { MaCauHoi = maCauHoi }, ct));

    /// <summary>Xem trước số người nhận mới theo tiêu chí (không gửi).</summary>
    [HttpPost("surveys/{maKS:int}/send-preview")]
    public Task<IActionResult> SendPreview(int maKS, SendSurveyRequest r, CancellationToken ct) => Send(maKS, r, chiDem: true, ct);

    /// <summary>Gửi khảo sát tới khách thỏa tiêu chí (Nháp → Đã gửi; gửi bổ sung khi đã gửi).</summary>
    [HttpPost("surveys/{maKS:int}/send")]
    public Task<IActionResult> SendNow(int maKS, SendSurveyRequest r, CancellationToken ct) => Send(maKS, r, chiDem: false, ct);

    private async Task<IActionResult> Send(int maKS, SendSurveyRequest r, bool chiDem, CancellationToken ct) =>
        RowOrNoContent(await Db.ExecAsync("api_ql.usp_GuiKhaoSat", new
        {
            MaKS = maKS, r.MaHang, r.MaTinh, r.GioiTinh, r.TuoiTu, r.TuoiDen, r.MaLoaiQuanTam, r.MaLoaiDaMua,
            HanTraLoiMoi = Db.ToDbTime(r.HanTraLoiMoi), ChiDem = chiDem
        }, ct));

    /// <summary>Đóng khảo sát.</summary>
    [HttpPost("surveys/{maKS:int}/close")]
    public async Task<IActionResult> Close(int maKS, CancellationToken ct) =>
        RowOrNoContent(await Db.ExecAsync("api_ql.usp_DongKhaoSat", new { MaKS = maKS }, ct));

    /// <summary>Q15 (QL-7). Thống kê: tổng quan, câu lựa chọn, câu thang điểm, câu tự luận.</summary>
    [HttpGet("surveys/{maKS:int}/stats")]
    public async Task<object> Stats(int maKS, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_ql.usp_ThongKeKhaoSat", new { MaKS = maKS }, ct);
        var tongQuan = r.First() ?? throw Errors.ApiException.NotFound("Không tìm thấy khảo sát.");
        return new { tongQuan, luaChon = r.Rows(1), thangDiem = r.Rows(2), tuLuan = r.Rows(3) };
    }
}
