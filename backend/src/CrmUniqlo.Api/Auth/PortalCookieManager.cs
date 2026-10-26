using Microsoft.AspNetCore.Authentication.Cookies;

namespace CrmUniqlo.Api.Auth;

/// <summary>
/// Cookie phiên riêng cho từng trang đăng nhập: web-crm dùng "crm.auth", web-admin dùng "crm.admin.auth".
/// Cookie không phân biệt cổng nên nếu dùng chung một tên, đăng nhập Khách hàng/Quản lý sẽ ghi đè phiên Admin
/// trên cùng trình duyệt (và ngược lại).
/// </summary>
public sealed class PortalCookieManager : ICookieManager
{
    private readonly ChunkingCookieManager _inner = new();
    private readonly PortalScope _scope;

    public PortalCookieManager(PortalScope scope) => _scope = scope;

    private string Name(HttpContext ctx, string key) =>
        key == SecurityServiceExtensions.CookieName && _scope.IsAdminPort(ctx) ? SecurityServiceExtensions.AdminCookieName : key;

    public string? GetRequestCookie(HttpContext context, string key) => _inner.GetRequestCookie(context, Name(context, key));

    public void AppendResponseCookie(HttpContext context, string key, string? value, CookieOptions options) =>
        _inner.AppendResponseCookie(context, Name(context, key), value, options);

    public void DeleteCookie(HttpContext context, string key, CookieOptions options) =>
        _inner.DeleteCookie(context, Name(context, key), options);
}
