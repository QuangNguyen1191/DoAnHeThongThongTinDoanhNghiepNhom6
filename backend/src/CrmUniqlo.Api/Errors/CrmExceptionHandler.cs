using System.Text.Json;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.Data.SqlClient;

namespace CrmUniqlo.Api.Errors;

/// <summary>Bắt mọi lỗi, đổi sang ProblemDetails. Chi tiết kỹ thuật chỉ ghi log.</summary>
public sealed class CrmExceptionHandler : IExceptionHandler
{
    private readonly ILogger<CrmExceptionHandler> _logger;

    public CrmExceptionHandler(ILogger<CrmExceptionHandler> logger) => _logger = logger;

    public async ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken ct)
    {
        ProblemBody body;
        switch (exception)
        {
            case ApiException api:
                body = Problem.Create(context, api.Status, api.Code, api.Message, api.Field);
                break;

            case SqlException sql when sql.Number is >= 50000 or 229 or 33504:
            {
                var status = DbErrorMap.ToStatus(sql.Number);
                if (DbErrorMap.IsSecurityAlert(sql.Number))
                    _logger.LogWarning("CẢNH BÁO BẢO MẬT: SQL Server từ chối ({Number}) tại {Path}", sql.Number, context.Request.Path);
                else if (status == StatusCodes.Status500InternalServerError)
                    _logger.LogError(sql, "Lỗi CSDL {Number} tại {Path}", sql.Number, context.Request.Path);
                else
                    _logger.LogInformation("Lỗi nghiệp vụ CSDL {Number} tại {Path}", sql.Number, context.Request.Path);

                if (status == StatusCodes.Status401Unauthorized)
                    await context.SignOutAsync();

                body = Problem.Create(context, status, sql.Number,
                    DbErrorMap.ToTitle(sql.Number, sql.Message, status), DbErrorMap.ToField(sql.Number, sql.Message));
                break;
            }

            case AntiforgeryValidationException:
                body = Problem.Create(context, StatusCodes.Status400BadRequest, "CSRF",
                    "Thiếu hoặc sai mã chống giả mạo (X-XSRF-TOKEN). Tải lại trang rồi thử lại.");
                break;

            case BadHttpRequestException or JsonException:
                body = Problem.Create(context, StatusCodes.Status400BadRequest, "BAD_REQUEST", "Yêu cầu không hợp lệ.");
                break;

            case OperationCanceledException when context.RequestAborted.IsCancellationRequested:
                return true;

            default:
                _logger.LogError(exception, "Lỗi không xử lý tại {Path}", context.Request.Path);
                body = Problem.Create(context, StatusCodes.Status500InternalServerError, "INTERNAL", DbErrorMap.ThongBaoLoiHeThong);
                break;
        }

        await Problem.WriteAsync(context, body);
        return true;
    }
}
