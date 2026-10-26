namespace CrmUniqlo.Api.Auth;

/// <summary>Cấu hình phiên, cổng và CORS (mục "Security" trong appsettings).</summary>
public sealed class SecurityOptions
{
    public const string Section = "Security";

    /// <summary>Cổng phục vụ web-crm (/login, /manager, /customer). Mặc định 5000.</summary>
    public int CrmPort { get; set; } = 5000;

    /// <summary>Cổng phục vụ web-admin. Mặc định 5001. /api/admin/* chỉ trả lời trên cổng này.</summary>
    public int AdminPort { get; set; } = 5001;

    /// <summary>Tách nhóm route theo cổng (đặc tả 4.1). Tắt khi chạy sau reverse proxy chỉ có 1 cổng.</summary>
    public bool SeparatePortalsByPort { get; set; } = true;

    /// <summary>Hết hạn trượt của phiên (phút). Mặc định 30.</summary>
    public int SlidingExpirationMinutes { get; set; } = 30;

    /// <summary>Tuổi tối đa của phiên kể từ khi đăng nhập (giờ), dù vẫn hoạt động. Mặc định 8.</summary>
    public int MaxSessionHours { get; set; } = 8;

    /// <summary>true: cookie luôn có cờ Secure (bắt buộc khi triển khai). false: theo request (chỉ dùng cho dev qua HTTP).</summary>
    public bool CookieSecureAlways { get; set; } = true;

    /// <summary>Số lần đăng nhập sai tối đa trong 15 phút theo (IP, tên đăng nhập). Mặc định 5.</summary>
    public int LoginMaxFailuresPerUser { get; set; } = 5;

    /// <summary>Số lần gọi đăng nhập/đăng ký tối đa trong 15 phút theo IP. Mặc định 30.</summary>
    public int LoginMaxAttemptsPerIp { get; set; } = 30;

    /// <summary>
    /// Origin được phép gọi API từ trình duyệt khác origin (CORS + kiểm Origin cho request ghi).
    /// Để trống = chỉ cùng origin (khuyến nghị; dev dùng proxy của Vite).
    /// </summary>
    public string[] AllowedOrigins { get; set; } = [];
}
