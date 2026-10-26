namespace CrmUniqlo.Api.Infrastructure;

/// <summary>
/// Gắn Correlation ID cho mỗi request (nhận từ header X-Correlation-ID hoặc tự sinh),
/// trả lại trong header phản hồi và đưa vào scope log. Kèm các header bảo mật cơ bản.
/// </summary>
public sealed class CorrelationIdMiddleware
{
    public const string Header = "X-Correlation-ID";
    private readonly RequestDelegate _next;
    private readonly ILogger<CorrelationIdMiddleware> _logger;

    public CorrelationIdMiddleware(RequestDelegate next, ILogger<CorrelationIdMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var incoming = context.Request.Headers[Header].ToString();
        var id = incoming.Length is > 0 and <= 64 && incoming.All(c => char.IsLetterOrDigit(c) || c is '-' or '_')
            ? incoming
            : context.TraceIdentifier;
        context.TraceIdentifier = id;

        context.Response.OnStarting(() =>
        {
            var h = context.Response.Headers;
            h[Header] = id;
            h.XContentTypeOptions = "nosniff";
            h.XFrameOptions = "DENY";
            h["Referrer-Policy"] = "no-referrer";
            if (context.Request.Path.StartsWithSegments("/api"))
                h.CacheControl = "no-store";
            return Task.CompletedTask;
        });

        using (_logger.BeginScope(new Dictionary<string, object> { ["CorrelationId"] = id }))
        {
            await _next(context);
        }
    }
}
