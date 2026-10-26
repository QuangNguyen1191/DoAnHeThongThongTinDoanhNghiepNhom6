using CrmUniqlo.Api.Errors;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.Extensions.Options;

namespace CrmUniqlo.Api.Auth;

/// <summary>
/// Các lớp bảo vệ chạy trước controller:
/// 1. Tách nhóm route theo cổng: /api/admin/* chỉ ở AdminPort; /api/manager/*, /api/customer/* chỉ ở CrmPort (sai cổng → 404).
/// 2. Request ghi (POST/PUT/PATCH/DELETE): kiểm Origin (nếu có) và token antiforgery trong header X-XSRF-TOKEN.
/// 3. Phiên phải đổi mật khẩu (PhaiDoiMatKhau = 1) → 428 cho mọi endpoint nghiệp vụ.
/// </summary>
public sealed class SecurityMiddleware
{
    private static readonly string[] PortalPrefixes = ["/api/admin", "/api/manager", "/api/customer"];
    private readonly RequestDelegate _next;
    private readonly IAntiforgery _antiforgery;
    private readonly SecurityOptions _options;

    public SecurityMiddleware(RequestDelegate next, IAntiforgery antiforgery, IOptions<SecurityOptions> options)
    {
        _next = next;
        _antiforgery = antiforgery;
        _options = options.Value;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var path = context.Request.Path;
        if (!path.StartsWithSegments("/api"))
        {
            await _next(context);
            return;
        }

        if (_options.SeparatePortalsByPort && !IsOnRightPort(context, path))
        {
            await Problem.WriteAsync(context, StatusCodes.Status404NotFound, "NOT_FOUND", "Không tìm thấy.");
            return;
        }

        if (IsUnsafe(context.Request.Method))
        {
            if (!IsAllowedOrigin(context))
            {
                await Problem.WriteAsync(context, StatusCodes.Status403Forbidden, "ORIGIN",
                    "Yêu cầu đến từ nguồn không được phép.");
                return;
            }
            // Ném AntiforgeryValidationException → CrmExceptionHandler trả 400 code CSRF.
            await _antiforgery.ValidateRequestAsync(context);
        }

        if (context.User.Identity?.IsAuthenticated == true &&
            context.User.FindFirst(CrmClaims.PhaiDoiMatKhau)?.Value == "1" &&
            PortalPrefixes.Any(p => path.StartsWithSegments(p)))
        {
            await Problem.WriteAsync(context, StatusCodes.Status428PreconditionRequired, "PASSWORD_CHANGE_REQUIRED",
                "Bạn cần đổi mật khẩu trước khi tiếp tục.");
            return;
        }

        await _next(context);
    }

    private bool IsOnRightPort(HttpContext context, PathString path)
    {
        var port = context.Request.Host.Port ?? context.Connection.LocalPort;
        if (path.StartsWithSegments("/api/admin")) return port == _options.AdminPort;
        if (path.StartsWithSegments("/api/manager") || path.StartsWithSegments("/api/customer"))
            return port != _options.AdminPort;
        return true;
    }

    private static bool IsUnsafe(string method) =>
        !(HttpMethods.IsGet(method) || HttpMethods.IsHead(method) || HttpMethods.IsOptions(method) || HttpMethods.IsTrace(method));

    /// <summary>Không có Origin (công cụ, cùng origin cũ) → cho qua; có Origin → phải cùng host hoặc nằm trong AllowedOrigins.</summary>
    private bool IsAllowedOrigin(HttpContext context)
    {
        var origin = context.Request.Headers.Origin.ToString();
        if (string.IsNullOrEmpty(origin)) return true;
        if (!Uri.TryCreate(origin, UriKind.Absolute, out var uri)) return false;
        var sameHost = string.Equals(uri.Authority, context.Request.Host.Value, StringComparison.OrdinalIgnoreCase);
        return sameHost || _options.AllowedOrigins.Contains(origin.TrimEnd('/'), StringComparer.OrdinalIgnoreCase);
    }
}
