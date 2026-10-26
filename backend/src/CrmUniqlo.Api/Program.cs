using CrmUniqlo.Api.Auth;
using CrmUniqlo.Api.Data;
using CrmUniqlo.Api.Errors;
using CrmUniqlo.Api.Infrastructure;
using CrmUniqlo.Api.Infrastructure.Email;
using Microsoft.AspNetCore.Mvc;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// ---- Dữ liệu: 3 chuỗi kết nối cổng (từ User Secrets / biến môi trường, không có trong mã nguồn) ----
builder.Services.Configure<DatabaseOptions>(builder.Configuration.GetSection(DatabaseOptions.Section));
builder.Services.AddSingleton<SqlConnectionFactory>();
builder.Services.AddScoped<CrmDb>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddSingleton(TimeProvider.System);

// ---- Email (quên mật khẩu): gửi nền qua SMTP; mật khẩu SMTP lấy từ User Secrets / biến môi trường ----
builder.Services.Configure<EmailOptions>(builder.Configuration.GetSection(EmailOptions.Section));
builder.Services.AddSingleton<EmailQueue>();
builder.Services.AddSingleton<IEmailOutbox>(sp => sp.GetRequiredService<EmailQueue>());
builder.Services.AddHostedService(sp => sp.GetRequiredService<EmailQueue>());
builder.Services.AddScoped<PasswordResetService>();

// ---- Bảo mật: cookie HttpOnly, antiforgery, CORS, rate limit, chính sách theo cổng ----
builder.Services.AddCrmSecurity(builder.Configuration);

// ---- Lỗi thống nhất (ProblemDetails) ----
builder.Services.AddExceptionHandler<CrmExceptionHandler>();
builder.Services.AddProblemDetails();

builder.Services.ConfigureHttpJsonOptions(o => JsonSetup.Apply(o.SerializerOptions));
builder.Services.AddControllers()
    .AddJsonOptions(o => JsonSetup.Apply(o.JsonSerializerOptions))
    .ConfigureApiBehaviorOptions(o =>
    {
        o.InvalidModelStateResponseFactory = ctx =>
        {
            var errors = ctx.ModelState
                .Where(e => e.Value?.Errors.Count > 0)
                .ToDictionary(
                    e => CrmNamingPolicy.Instance.ConvertName(e.Key.TrimStart('$', '.')),
                    e => e.Value!.Errors.Select(x => string.IsNullOrEmpty(x.ErrorMessage) ? "Giá trị không hợp lệ." : x.ErrorMessage).ToArray());
            var body = Problem.Create(ctx.HttpContext, StatusCodes.Status400BadRequest, "VALIDATION",
                errors.Values.FirstOrDefault()?.FirstOrDefault() ?? "Dữ liệu không hợp lệ.", errors.Keys.FirstOrDefault(), errors);
            return new ObjectResult(body) { StatusCode = StatusCodes.Status400BadRequest, ContentTypes = { "application/problem+json" } };
        };
    });

builder.Services.AddOpenApi(o => o.AddDocumentTransformer((doc, _, _) =>
{
    doc.Info.Title = "CRM Uniqlo API";
    doc.Info.Version = "v1";
    doc.Info.Description = "Backend API cho hệ thống CRM Uniqlo (đồ án HTTTDN – SGU). " +
                           "Xác thực bằng cookie HttpOnly crm.auth (web-crm) / crm.admin.auth (web-admin); mọi request ghi cần header X-XSRF-TOKEN lấy từ GET /api/auth/antiforgery.";
    return Task.CompletedTask;
}));

var app = builder.Build();

// Kiểm tra cấu hình ngay khi khởi động: thiếu chuỗi kết nối thì dừng với thông báo rõ ràng.
app.Services.GetRequiredService<SqlConnectionFactory>();

app.UseMiddleware<CorrelationIdMiddleware>();
app.UseExceptionHandler();
app.UseStatusCodePages(async ctx =>
{
    var http = ctx.HttpContext;
    if (http.Request.Path.StartsWithSegments("/api") && !http.Response.HasStarted && http.Response.ContentLength is null)
        await Problem.WriteAsync(http, http.Response.StatusCode, http.Response.StatusCode == 404 ? "NOT_FOUND" : "HTTP_" + http.Response.StatusCode,
            http.Response.StatusCode == 404 ? "Không tìm thấy." : "Yêu cầu không hợp lệ.");
});

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference("/docs");
}
else
{
    app.UseHsts();
}

app.UseSpaHosting();
app.UseRouting();
app.UseCors(SecurityServiceExtensions.CorsPolicy);
app.UseRateLimiter();
app.UseAuthentication();
app.UseMiddleware<SecurityMiddleware>(); // tách cổng, Origin, CSRF, 428 – trước khi xét chính sách theo cổng
app.UseAuthorization();
app.MapControllers();
app.MapSpaFallbacks();

app.Run();

/// <summary>Cho phép WebApplicationFactory của dự án kiểm thử truy cập.</summary>
public partial class Program;
