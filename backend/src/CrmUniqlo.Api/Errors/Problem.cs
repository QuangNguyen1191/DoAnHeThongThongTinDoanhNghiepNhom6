using System.Text.Json;
using Microsoft.Extensions.Options;

namespace CrmUniqlo.Api.Errors;

/// <summary>
/// Thân lỗi thống nhất (ProblemDetails, RFC 9457):
/// { status, code, title, field, traceId }. Không bao giờ chứa stack trace.
/// </summary>
public sealed record ProblemBody(int Status, object Code, string Title, string? Field, string TraceId,
    IDictionary<string, string[]>? Errors = null)
{
    public string Type => $"https://httpstatuses.io/{Status}";
}

public static class Problem
{
    public static string TraceId(HttpContext context) => context.TraceIdentifier;

    public static ProblemBody Create(HttpContext context, int status, object code, string title, string? field = null,
        IDictionary<string, string[]>? errors = null) =>
        new(status, code, title, field, TraceId(context), errors);

    public static async Task WriteAsync(HttpContext context, ProblemBody body)
    {
        if (context.Response.HasStarted) return;
        context.Response.StatusCode = body.Status;
        context.Response.ContentType = "application/problem+json; charset=utf-8";
        var json = context.RequestServices.GetRequiredService<IOptions<Microsoft.AspNetCore.Http.Json.JsonOptions>>().Value;
        await context.Response.WriteAsync(JsonSerializer.Serialize(body, json.SerializerOptions));
    }

    public static Task WriteAsync(HttpContext context, int status, object code, string title, string? field = null) =>
        WriteAsync(context, Create(context, status, code, title, field));
}
