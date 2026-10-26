using CrmUniqlo.Api.Auth;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Options;

namespace CrmUniqlo.Api.Infrastructure;

/// <summary>
/// Phục vụ tệp tĩnh của 2 ứng dụng React theo cổng (đặc tả 4.1):
/// CrmPort → wwwroot/web-crm, AdminPort → wwwroot/web-admin. Khi chưa có bản build thì bỏ qua.
/// </summary>
public static class SpaHosting
{
    public const string CrmFolder = "web-crm";
    public const string AdminFolder = "web-admin";

    private static PhysicalFileProvider? Provider(IWebHostEnvironment env, string folder)
    {
        var path = Path.Combine(env.WebRootPath ?? Path.Combine(env.ContentRootPath, "wwwroot"), folder);
        return Directory.Exists(path) ? new PhysicalFileProvider(path) : null;
    }

    private static bool IsAdminPort(HttpContext ctx, SecurityOptions o) =>
        (ctx.Request.Host.Port ?? ctx.Connection.LocalPort) == o.AdminPort;

    public static IApplicationBuilder UseSpaHosting(this WebApplication app)
    {
        var options = app.Services.GetRequiredService<IOptions<SecurityOptions>>().Value;
        foreach (var (folder, isAdmin) in new[] { (CrmFolder, false), (AdminFolder, true) })
        {
            var provider = Provider(app.Environment, folder);
            if (provider is null) continue;
            app.UseWhen(ctx => IsAdminPort(ctx, options) == isAdmin && !ctx.Request.Path.StartsWithSegments("/api"),
                branch => branch.UseStaticFiles(new StaticFileOptions { FileProvider = provider }));
        }
        return app;
    }

    /// <summary>Đường dẫn không phải /api và không phải tệp → index.html của ứng dụng theo cổng (SPA routing).</summary>
    public static void MapSpaFallbacks(this WebApplication app)
    {
        var options = app.Services.GetRequiredService<IOptions<SecurityOptions>>().Value;
        var crm = Provider(app.Environment, CrmFolder);
        var admin = Provider(app.Environment, AdminFolder);
        if (crm is null && admin is null) return;

        app.MapFallback(async ctx =>
        {
            if (ctx.Request.Path.StartsWithSegments("/api"))
            {
                ctx.Response.StatusCode = StatusCodes.Status404NotFound;
                return;
            }
            var provider = IsAdminPort(ctx, options) ? admin : crm;
            var index = provider?.GetFileInfo("index.html");
            if (index is null || !index.Exists)
            {
                ctx.Response.StatusCode = StatusCodes.Status404NotFound;
                return;
            }
            ctx.Response.ContentType = "text/html; charset=utf-8";
            ctx.Response.Headers.CacheControl = "no-cache";
            await ctx.Response.SendFileAsync(index);
        });
    }
}
