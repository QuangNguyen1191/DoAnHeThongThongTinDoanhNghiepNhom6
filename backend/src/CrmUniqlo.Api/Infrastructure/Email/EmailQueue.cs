using System.Net;
using System.Net.Mail;
using System.Threading.Channels;
using Microsoft.Extensions.Options;

namespace CrmUniqlo.Api.Infrastructure.Email;

public sealed record EmailMessage(string To, string? ToName, string Subject, string Body);

/// <summary>Nơi xếp email cần gửi (dự án kiểm thử thay bằng hộp thư trong bộ nhớ).</summary>
public interface IEmailOutbox
{
    void Enqueue(EmailMessage message);
}

/// <summary>
/// Hàng đợi email gửi nền. Request chỉ xếp thư vào hàng đợi rồi trả lời ngay, nên thời gian
/// trả lời của "quên mật khẩu" không để lộ việc tài khoản có tồn tại hay không.
/// </summary>
public sealed class EmailQueue : BackgroundService, IEmailOutbox
{
    private readonly Channel<EmailMessage> _channel =
        Channel.CreateBounded<EmailMessage>(new BoundedChannelOptions(500) { FullMode = BoundedChannelFullMode.DropWrite });
    private readonly IOptionsMonitor<EmailOptions> _options;
    private readonly ILogger<EmailQueue> _logger;
    private readonly IHostEnvironment _env;

    public EmailQueue(IOptionsMonitor<EmailOptions> options, ILogger<EmailQueue> logger, IHostEnvironment env)
    {
        _env = env;
        _options = options;
        _logger = logger;
    }

    public void Enqueue(EmailMessage message)
    {
        if (!_channel.Writer.TryWrite(message))
            _logger.LogWarning("Hàng đợi email đầy, bỏ qua thư \"{Subject}\".", message.Subject);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var message in _channel.Reader.ReadAllAsync(stoppingToken))
        {
            try
            {
                await SendAsync(message, stoppingToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogError(ex, "Gửi email \"{Subject}\" thất bại.", message.Subject);
            }
        }
    }

    private async Task SendAsync(EmailMessage message, CancellationToken ct)
    {
        var o = _options.CurrentValue;
        if (string.IsNullOrWhiteSpace(o.SmtpHost) && string.IsNullOrWhiteSpace(o.PickupDirectory))
        {
            _logger.LogWarning("Chưa cấu hình Email:SmtpHost hoặc Email:PickupDirectory, không gửi thư \"{Subject}\".", message.Subject);
            return;
        }

        using var mail = new MailMessage
        {
            From = new MailAddress(o.From, o.FromName),
            Subject = message.Subject,
            Body = message.Body,
            IsBodyHtml = false,
            BodyEncoding = System.Text.Encoding.UTF8,
            SubjectEncoding = System.Text.Encoding.UTF8
        };
        mail.To.Add(new MailAddress(message.To, message.ToName));

        using var client = new SmtpClient();
        if (!string.IsNullOrWhiteSpace(o.PickupDirectory))
        {
            var dir = Path.GetFullPath(o.PickupDirectory, _env.ContentRootPath);
            Directory.CreateDirectory(dir);
            client.DeliveryMethod = SmtpDeliveryMethod.SpecifiedPickupDirectory;
            client.PickupDirectoryLocation = dir;
        }
        else
        {
            client.Host = o.SmtpHost!;
            client.Port = o.SmtpPort;
            client.EnableSsl = o.SmtpEnableSsl;
            if (!string.IsNullOrEmpty(o.SmtpUser))
                client.Credentials = new NetworkCredential(o.SmtpUser, o.SmtpPassword);
        }
        await client.SendMailAsync(mail, ct);
        _logger.LogInformation("Đã gửi email \"{Subject}\".", message.Subject);
    }
}
