namespace CrmUniqlo.Api.Data;

/// <summary>
/// Cấu hình kết nối. Ba chuỗi kết nối (mật khẩu login SQL) KHÔNG nằm trong mã nguồn:
/// đặt bằng User Secrets (dev) hoặc biến môi trường ConnectionStrings__CrmAdmin, ...
/// </summary>
public sealed class DatabaseOptions
{
    public const string Section = "Database";

    /// <summary>Độ lệch múi giờ của máy chủ SQL (SYSDATETIME()). Mặc định +07:00.</summary>
    public TimeSpan TimeZoneOffset { get; set; } = TimeSpan.FromHours(7);

    /// <summary>Thời gian chờ mỗi lệnh (giây).</summary>
    public int CommandTimeoutSeconds { get; set; } = 30;
}
