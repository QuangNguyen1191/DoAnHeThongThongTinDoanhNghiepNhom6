using CrmUniqlo.Api.Data;
using Microsoft.Extensions.Options;

namespace CrmUniqlo.Api.Auth;

/// <summary>
/// Trang đăng nhập riêng theo cổng: AdminPort chỉ nhận tài khoản Admin; CrmPort chỉ nhận Khách hàng và Quản lý.
/// Tài khoản thuộc cổng khác được trả lời như không tồn tại (không lộ vai trò).
/// Khi tắt SeparatePortalsByPort (chạy sau reverse proxy một cổng) thì nhận cả 3 cổng như trước.
/// </summary>
public sealed class PortalScope
{
    private static readonly Cong[] All = [Cong.KhachHang, Cong.QuanLy, Cong.Admin];
    private static readonly Cong[] CrmOnly = [Cong.KhachHang, Cong.QuanLy];
    private static readonly Cong[] AdminOnly = [Cong.Admin];

    private readonly IOptions<SecurityOptions> _options;

    public PortalScope(IOptions<SecurityOptions> options) => _options = options;

    public static int PortOf(HttpContext http) => http.Request.Host.Port ?? http.Connection.LocalPort;

    public bool IsAdminPort(HttpContext http) =>
        _options.Value.SeparatePortalsByPort && PortOf(http) == _options.Value.AdminPort;

    /// <summary>Các cổng được đăng nhập / đặt lại mật khẩu qua request này.</summary>
    public IReadOnlyList<Cong> PortalsFor(HttpContext http)
    {
        if (!_options.Value.SeparatePortalsByPort) return All;
        return IsAdminPort(http) ? AdminOnly : CrmOnly;
    }
}
