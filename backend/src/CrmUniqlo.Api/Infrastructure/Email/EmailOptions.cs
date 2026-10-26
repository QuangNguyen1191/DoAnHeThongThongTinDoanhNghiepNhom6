namespace CrmUniqlo.Api.Infrastructure.Email;

/// <summary>
/// Cấu hình gửi email (mục "Email"). Mật khẩu SMTP là bí mật: đặt bằng User Secrets
/// hoặc biến môi trường Email__SmtpPassword, không ghi vào appsettings.json.
/// Có PickupDirectory → ghi tệp .eml vào thư mục đó thay vì gửi thật (dùng khi phát triển).
/// Không có cả SmtpHost lẫn PickupDirectory → không gửi, chỉ ghi log cảnh báo.
/// </summary>
public sealed class EmailOptions
{
    public const string Section = "Email";

    public string? SmtpHost { get; set; }
    public int SmtpPort { get; set; } = 587;
    public bool SmtpEnableSsl { get; set; } = true;
    public string? SmtpUser { get; set; }
    public string? SmtpPassword { get; set; }

    public string? PickupDirectory { get; set; }

    public string From { get; set; } = "no-reply@crm-uniqlo.local";
    public string FromName { get; set; } = "CRM Uniqlo";

    /// <summary>Liên kết đặt lại mật khẩu của web-crm (Khách hàng, Quản lý). {token} được thay bằng mã.</summary>
    public string ResetUrlCrm { get; set; } = "http://localhost:5000/dat-lai-mat-khau#token={token}";

    /// <summary>Liên kết đặt lại mật khẩu của web-admin. {token} được thay bằng mã.</summary>
    public string ResetUrlAdmin { get; set; } = "http://localhost:5001/dat-lai-mat-khau#token={token}";

    /// <summary>Thời hạn của mã đặt lại mật khẩu (CSDL chấp nhận 5–1440 phút).</summary>
    public int ResetTokenMinutes { get; set; } = 30;
}
