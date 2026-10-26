using System.Security.Claims;
using System.Threading.RateLimiting;
using CrmUniqlo.Api.Data;
using CrmUniqlo.Api.Errors;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Cors.Infrastructure;
using Microsoft.Extensions.Options;

namespace CrmUniqlo.Api.Auth;

public static class SecurityServiceExtensions
{
    public const string CookieName = "crm.auth";
    public const string AdminCookieName = "crm.admin.auth";
    public const string AntiforgeryCookieName = "crm.xsrf";
    public const string AntiforgeryHeaderName = "X-XSRF-TOKEN";
    public const string CorsPolicy = "CrmSpa";
    public const string AuthRateLimit = "auth";

    public static IServiceCollection AddCrmSecurity(this IServiceCollection services, IConfiguration configuration)
    {
        // Mọi giá trị cấu hình đọc qua IOptions (lúc chạy), không đọc lúc đăng ký dịch vụ,
        // để cấu hình ghi đè (User Secrets, biến môi trường, dự án kiểm thử) luôn có hiệu lực.
        services.Configure<SecurityOptions>(configuration.GetSection(SecurityOptions.Section));

        services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme).AddCookie();
        services.AddOptions<CookieAuthenticationOptions>(CookieAuthenticationDefaults.AuthenticationScheme)
            .Configure<IOptions<SecurityOptions>>((o, sec) =>
            {
                var options = sec.Value;
                o.Cookie.Name = CookieName;
                o.CookieManager = new PortalCookieManager(new PortalScope(sec));
                o.Cookie.HttpOnly = true;
                o.Cookie.SameSite = SameSiteMode.Lax;
                o.Cookie.SecurePolicy = SecurePolicy(options);
                o.Cookie.Path = "/";
                o.ExpireTimeSpan = TimeSpan.FromMinutes(options.SlidingExpirationMinutes);
                o.SlidingExpiration = true;
                o.Events = new CookieAuthenticationEvents
                {
                    // API không chuyển hướng: trả 401/403 dạng ProblemDetails để SPA tự xử lý.
                    OnRedirectToLogin = ctx => Problem.WriteAsync(ctx.HttpContext, StatusCodes.Status401Unauthorized,
                        "UNAUTHENTICATED", DbErrorMap.ThongBaoHetPhien),
                    OnRedirectToAccessDenied = ctx => Problem.WriteAsync(ctx.HttpContext, StatusCodes.Status403Forbidden,
                        "FORBIDDEN", DbErrorMap.ThongBaoKhongCoQuyen),
                    OnValidatePrincipal = async ctx =>
                    {
                        // Giới hạn tuổi tối đa của phiên (hết hạn tuyệt đối) ngoài hết hạn trượt.
                        var authTime = ctx.Principal?.FindFirst(CrmClaims.AuthTime)?.Value;
                        var max = TimeSpan.FromHours(options.MaxSessionHours);
                        if (!long.TryParse(authTime, out var unix) ||
                            DateTimeOffset.UtcNow - DateTimeOffset.FromUnixTimeSeconds(unix) > max)
                        {
                            ctx.RejectPrincipal();
                            await ctx.HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
                        }
                    }
                };
            });

        services.AddAuthorizationBuilder()
            .AddPolicy(Policies.Admin, p => p.RequireAuthenticatedUser().RequireClaim(CrmClaims.Cong, CongExtensions.AdminDb))
            .AddPolicy(Policies.QuanLy, p => p.RequireAuthenticatedUser().RequireClaim(CrmClaims.Cong, CongExtensions.QuanLyDb))
            .AddPolicy(Policies.KhachHang, p => p.RequireAuthenticatedUser().RequireClaim(CrmClaims.Cong, CongExtensions.KhachHangDb));

        services.AddAntiforgery();
        services.AddOptions<AntiforgeryOptions>().Configure<IOptions<SecurityOptions>>((o, sec) =>
        {
            o.HeaderName = AntiforgeryHeaderName;
            o.Cookie.Name = AntiforgeryCookieName;
            o.Cookie.HttpOnly = true;
            o.Cookie.SameSite = SameSiteMode.Strict;
            o.Cookie.SecurePolicy = SecurePolicy(sec.Value);
        });

        services.AddCors();
        services.AddOptions<CorsOptions>().Configure<IOptions<SecurityOptions>>((o, sec) => o.AddPolicy(CorsPolicy, p =>
        {
            if (sec.Value.AllowedOrigins.Length > 0)
                p.WithOrigins(sec.Value.AllowedOrigins).AllowCredentials().AllowAnyMethod()
                 .WithHeaders("Content-Type", AntiforgeryHeaderName, "X-Correlation-ID");
        }));

        // Giới hạn chung theo IP cho các endpoint xác thực (chống dò mật khẩu, spam đăng ký).
        services.AddRateLimiter(o =>
        {
            o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            o.OnRejected = (ctx, _) => new ValueTask(Problem.WriteAsync(ctx.HttpContext,
                StatusCodes.Status429TooManyRequests, "RATE_LIMIT", "Thử lại sau ít phút."));
            o.AddPolicy(AuthRateLimit, http =>
            {
                var limit = http.RequestServices.GetRequiredService<IOptions<SecurityOptions>>().Value.LoginMaxAttemptsPerIp;
                return RateLimitPartition.GetFixedWindowLimiter(
                    http.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                    _ => new FixedWindowRateLimiterOptions { PermitLimit = limit, Window = LoginThrottle.Window, QueueLimit = 0 });
            });
        });

        services.AddSingleton<PortalScope>();
        services.AddSingleton<LoginThrottle>();
        services.AddSingleton<PasswordService>();
        services.AddHttpContextAccessor();
        services.AddScoped<CurrentUser>();
        return services;
    }

    private static CookieSecurePolicy SecurePolicy(SecurityOptions o) =>
        o.CookieSecureAlways ? CookieSecurePolicy.Always : CookieSecurePolicy.SameAsRequest;

    /// <summary>Tạo principal cho cookie mới (phát lại sau mỗi lần đăng nhập để chống session fixation).</summary>
    public static ClaimsPrincipal BuildPrincipal(int maTK, Cong cong, string tenDangNhap, bool phaiDoiMatKhau, DateTimeOffset? authTime = null)
    {
        var claims = new List<Claim>
        {
            // NameIdentifier giúp token antiforgery giữ nguyên khi phát lại cookie (ví dụ sau khi đổi mật khẩu).
            new(ClaimTypes.NameIdentifier, maTK.ToString()),
            new(CrmClaims.MaTK, maTK.ToString()),
            new(CrmClaims.Cong, cong.ToDb()),
            new(CrmClaims.TenDangNhap, tenDangNhap),
            new(CrmClaims.PhaiDoiMatKhau, phaiDoiMatKhau ? "1" : "0"),
            new(CrmClaims.AuthTime, (authTime ?? DateTimeOffset.UtcNow).ToUnixTimeSeconds().ToString())
        };
        var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme, CrmClaims.TenDangNhap, null);
        return new ClaimsPrincipal(identity);
    }
}
