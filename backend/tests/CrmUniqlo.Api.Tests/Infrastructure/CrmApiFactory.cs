using System.Collections.Concurrent;
using System.Text.RegularExpressions;
using CrmUniqlo.Api.Infrastructure.Email;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CrmUniqlo.Api.Tests.Infrastructure;

/// <summary>
/// Chạy API trong bộ nhớ, nối tới CSDL KIỂM THỬ (mặc định CRM_Uniqlo_Test, tạo bằng script 11).
/// Chuỗi kết nối lấy từ User Secrets của dự án API hoặc biến môi trường ConnectionStrings__*;
/// tên CSDL luôn bị ghi đè sang CSDL kiểm thử để không bao giờ ghi vào CRM_Uniqlo thật.
/// Đổi tên CSDL kiểm thử bằng biến môi trường CRM_TEST_DATABASE.
/// </summary>
public sealed class CrmApiFactory : WebApplicationFactory<Program>
{
    public const string CrmBase = "https://localhost:5000";
    public const string AdminBase = "https://localhost:5001";
    public static readonly string[] Names = ["CrmAdmin", "CrmQuanLy", "CrmKhachHang"];

    public static string TestDatabase => Environment.GetEnvironmentVariable("CRM_TEST_DATABASE") is { Length: > 0 } db
        ? db
        : "CRM_Uniqlo_Test";

    /// <summary>Email API đã "gửi" (giữ trong bộ nhớ, không gửi thật).</summary>
    public TestMailbox Mailbox { get; } = new();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        builder.ConfigureTestServices(services => services.AddSingleton<IEmailOutbox>(Mailbox));
        builder.ConfigureAppConfiguration((_, config) =>
        {
            config.AddUserSecrets<Program>(optional: true);
            config.AddEnvironmentVariables();
            var current = config.Build();

            var overrides = new Dictionary<string, string?>
            {
                ["Security:CookieSecureAlways"] = "true",
                ["Security:LoginMaxAttemptsPerIp"] = "100000",
                ["Security:LoginMaxFailuresPerUser"] = "5"
            };
            foreach (var name in Names)
            {
                var cs = current.GetConnectionString(name);
                if (string.IsNullOrWhiteSpace(cs))
                    throw new InvalidOperationException(
                        $"Chưa cấu hình ConnectionStrings:{name}. Xem README mục Kiểm thử.");
                overrides[$"ConnectionStrings:{name}"] =
                    new SqlConnectionStringBuilder(cs) { InitialCatalog = TestDatabase }.ConnectionString;
            }
            config.AddInMemoryCollection(overrides);
        });
    }

    public CrmClient Crm() => new(CreateClient(new WebApplicationFactoryClientOptions
    {
        BaseAddress = new Uri(CrmBase), HandleCookies = true, AllowAutoRedirect = false
    }));

    public CrmClient Admin() => new(CreateClient(new WebApplicationFactoryClientOptions
    {
        BaseAddress = new Uri(AdminBase), HandleCookies = true, AllowAutoRedirect = false
    }));
}

public sealed partial class TestMailbox : IEmailOutbox
{
    private readonly ConcurrentQueue<EmailMessage> _messages = new();

    public void Enqueue(EmailMessage message) => _messages.Enqueue(message);

    public IReadOnlyList<EmailMessage> To(string email) =>
        _messages.Where(m => string.Equals(m.To, email, StringComparison.OrdinalIgnoreCase)).ToList();

    /// <summary>Mã đặt lại mật khẩu trong email mới nhất gửi tới <paramref name="email"/> (null nếu chưa có).</summary>
    public string? LatestResetToken(string email) =>
        To(email).LastOrDefault() is { } m ? TokenRegex().Match(m.Body).Groups[1].Value : null;

    [GeneratedRegex(@"token=([A-Za-z0-9_-]+)")]
    private static partial Regex TokenRegex();
}

[CollectionDefinition(Name)]
public sealed class ApiCollection : ICollectionFixture<CrmApiFactory>
{
    public const string Name = "api";
}
