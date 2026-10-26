using CrmUniqlo.Api.Data;
using Microsoft.AspNetCore.Mvc;

namespace CrmUniqlo.Api.Controllers;

/// <summary>Tiện ích chung cho controller nghiệp vụ.</summary>
[ApiController]
[Produces("application/json")]
public abstract class CrmControllerBase : ControllerBase
{
    protected CrmControllerBase(CrmDb db) => Db = db;

    protected CrmDb Db { get; }

    /// <summary>Thủ tục ghi trả 1 dòng (mã vừa tạo, số lượng...) → 200 kèm dòng đó; không trả gì → 204.</summary>
    protected IActionResult RowOrNoContent(ProcResult result) =>
        result.First() is { } row ? Ok(row) : NoContent();

    /// <summary>Thủ tục tạo mới → 201 kèm dòng kết quả (mã vừa tạo).</summary>
    protected IActionResult CreatedRow(ProcResult result, object? extra = null)
    {
        var row = result.First() ?? new Row();
        if (extra is not null)
            foreach (var p in extra.GetType().GetProperties()) row[p.Name] = p.GetValue(extra);
        return StatusCode(StatusCodes.Status201Created, row);
    }

    /// <summary>Thực thi song song nhiều khối dữ liệu cho dashboard; khối nào lỗi (ví dụ thiếu quyền) trả null, không làm hỏng cả trang.</summary>
    protected static async Task<(T? Value, object? Error)> TryBlock<T>(Func<Task<T>> block)
    {
        try
        {
            return (await block(), null);
        }
        catch (Microsoft.Data.SqlClient.SqlException ex) when (ex.Number is >= 50000 or 229)
        {
            return (default, new { code = ex.Number, title = Errors.DbErrorMap.ToTitle(ex.Number, ex.Message, Errors.DbErrorMap.ToStatus(ex.Number)) });
        }
    }
}
