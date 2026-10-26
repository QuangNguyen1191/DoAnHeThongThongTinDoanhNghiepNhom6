using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace CrmUniqlo.Api.Tests.Infrastructure;

/// <summary>HttpClient có cookie riêng (một "trình duyệt") + tự gửi X-XSRF-TOKEN cho request ghi.</summary>
public sealed class CrmClient : IDisposable
{
    public const string DemoPassword = "Demo@2026";
    private readonly HttpClient _http;
    private string? _xsrf;

    public CrmClient(HttpClient http) => _http = http;

    public HttpClient Http => _http;

    public async Task RefreshXsrfAsync()
    {
        var json = await _http.GetFromJsonAsync<JsonObject>("/api/auth/antiforgery");
        _xsrf = json!["xsrfToken"]!.GetValue<string>();
    }

    public async Task<Response> LoginAsync(string user, string password = DemoPassword)
    {
        if (_xsrf is null) await RefreshXsrfAsync();
        return await SendAsync(HttpMethod.Post, "/api/auth/login", new { tenDangNhap = user, matKhau = password });
    }

    public async Task<CrmClient> LoggedInAsync(string user, string password = DemoPassword)
    {
        var r = await LoginAsync(user, password);
        Assert.True(r.Status == HttpStatusCode.OK, $"Đăng nhập {user} thất bại: {(int)r.Status} {r.Body}");
        return this;
    }

    public void UseXsrf(string token) => _xsrf = token;

    public Task<Response> GetAsync(string url) => SendAsync(HttpMethod.Get, url, null);
    public Task<Response> PostAsync(string url, object? body = null) => SendAsync(HttpMethod.Post, url, body);
    public Task<Response> PutAsync(string url, object? body) => SendAsync(HttpMethod.Put, url, body);
    public Task<Response> PatchAsync(string url, object? body) => SendAsync(HttpMethod.Patch, url, body);
    public Task<Response> DeleteAsync(string url, object? body = null) => SendAsync(HttpMethod.Delete, url, body);

    public async Task<Response> SendAsync(HttpMethod method, string url, object? body, bool withXsrf = true)
    {
        using var request = new HttpRequestMessage(method, url);
        if (body is not null) request.Content = JsonContent.Create(body);
        if (withXsrf && method != HttpMethod.Get && _xsrf is not null) request.Headers.Add("X-XSRF-TOKEN", _xsrf);
        using var response = await _http.SendAsync(request);
        var text = await response.Content.ReadAsStringAsync();
        JsonNode? json = null;
        if (text.Length > 0 && (response.Content.Headers.ContentType?.MediaType?.Contains("json") ?? false))
            json = JsonNode.Parse(text);
        // Như SPA: nhận token CSRF mới khi API phát lại (đăng nhập, đăng ký, đổi mật khẩu).
        if (json is JsonObject o && o["xsrfToken"] is JsonValue v && v.TryGetValue<string>(out var t)) _xsrf = t;
        return new Response(response.StatusCode, text, json, response.Content.Headers.ContentType?.MediaType);
    }

    public void Dispose() => _http.Dispose();
}

public sealed record Response(HttpStatusCode Status, string Body, JsonNode? Json, string? ContentType)
{
    public JsonNode this[string key] => Json![key]!;

    /// <summary>Mã lỗi trong ProblemDetails (số của CSDL hoặc chuỗi của API).</summary>
    public string? Code => Json?["code"]?.ToJsonString().Trim('"');

    public Response Expect(HttpStatusCode status)
    {
        Assert.True(Status == status, $"Mong đợi {(int)status}, nhận {(int)Status}: {Body}");
        return this;
    }
}

public static class TestData
{
    private static readonly Random Rng = new();

    /// <summary>Chuỗi ngẫu nhiên để dữ liệu kiểm thử không trùng giữa các lần chạy.</summary>
    public static string Suffix() => Guid.NewGuid().ToString("N")[..8];

    /// <summary>SĐT ngẫu nhiên 10 số, bắt đầu 08 (dữ liệu mẫu dùng 090/091).</summary>
    public static string Phone()
    {
        lock (Rng) return "08" + Rng.Next(0, 100_000_000).ToString("D8");
    }
}
