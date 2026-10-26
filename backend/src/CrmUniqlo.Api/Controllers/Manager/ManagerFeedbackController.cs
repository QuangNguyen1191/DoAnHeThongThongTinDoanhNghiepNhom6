using CrmUniqlo.Api.Auth;
using CrmUniqlo.Api.Data;
using CrmUniqlo.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CrmUniqlo.Api.Controllers.Manager;

/// <summary>Q8 (QL-4): xử lý phản hồi khách hàng (QL_PH_XEM / QL_PH_XU_LY).</summary>
[Route("api/manager/feedback")]
[Authorize(Policy = Policies.QuanLy)]
public sealed class ManagerFeedbackController : CrmControllerBase
{
    public ManagerFeedbackController(CrmDb db) : base(db) { }

    [HttpGet]
    public async Task<PagedResult> List([FromQuery] FeedbackQuery q, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_ql.usp_DanhSachPhanHoi", new
        {
            q.TrangThai, q.LoaiPH, q.MaSP, TuNgay = CrmDb.ToDbDate(q.TuNgay), DenNgay = CrmDb.ToDbDate(q.DenNgay), q.Trang, q.SoDong
        }, ct);
        return PagedResult.From(r.Rows(), q.Trang, q.SoDong);
    }

    /// <summary>Tiếp nhận phản hồi (MOI → DANG_XU_LY), có thể phân loại lại.</summary>
    [HttpPost("{maPH:int}/accept")]
    public async Task<IActionResult> Accept(int maPH, AcceptFeedbackRequest? r, CancellationToken ct) =>
        RowOrNoContent(await Db.ExecAsync("api_ql.usp_TiepNhanPhanHoi", new { MaPH = maPH, LoaiPH = r?.LoaiPH }, ct));

    /// <summary>Trả lời phản hồi (→ DA_XU_LY).</summary>
    [HttpPost("{maPH:int}/reply")]
    public async Task<IActionResult> Reply(int maPH, ReplyFeedbackRequest r, CancellationToken ct) =>
        RowOrNoContent(await Db.ExecAsync("api_ql.usp_TraLoiPhanHoi", new { MaPH = maPH, r.NoiDungTraLoi }, ct));
}
