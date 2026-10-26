using CrmUniqlo.Api.Data;
using CrmUniqlo.Api.Errors;
using CrmUniqlo.Api.Models;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.Data.SqlClient;

namespace CrmUniqlo.Api.Auth;

/// <summary>Luồng đăng nhập L1 / đăng ký L2 / đổi mật khẩu L3 theo đặc tả.</summary>
public sealed class AuthService
{
    public const string LoginFailedMessage = "Sai tên đăng nhập hoặc mật khẩu.";
    public const string AccountLockedMessage = "Tài khoản đã bị khóa. Vui lòng liên hệ quản trị/cửa hàng.";

    // Thứ tự thử: usp_LayThongTinDangNhap chỉ trả tài khoản thuộc cổng của login đang gọi.
    private static readonly Cong[] LoginOrder = [Cong.KhachHang, Cong.QuanLy, Cong.Admin];

    private readonly CrmDb _db;
    private readonly SqlConnectionFactory _factory;
    private readonly PasswordService _passwords;
    private readonly IAntiforgery _antiforgery;
    private readonly ILogger<AuthService> _logger;

    public AuthService(CrmDb db, SqlConnectionFactory factory, PasswordService passwords, IAntiforgery antiforgery,
        ILogger<AuthService> logger)
    {
        _db = db;
        _factory = factory;
        _passwords = passwords;
        _antiforgery = antiforgery;
        _logger = logger;
    }

    /// <summary>Tìm tài khoản trên lần lượt các kết nối cổng; dừng ở kết nối đầu tiên có dòng.</summary>
    public async Task<Row?> FindAccountAsync(string tenDangNhap, CancellationToken ct, Cong? onlyCong = null,
        IReadOnlyList<Cong>? portals = null)
    {
        foreach (var cong in onlyCong is { } c ? [c] : LoginOrder)
        {
            if (portals is not null && !portals.Contains(cong)) continue;
            var result = await _db.ExecAnonymousAsync(cong, "api_chung.usp_LayThongTinDangNhap",
                new { TenDangNhap = tenDangNhap }, ct);
            if (result.First() is { } row) return row;
        }
        return null;
    }

    /// <summary>
    /// Xác minh tên/mật khẩu trong các cổng được phép của trang đăng nhập đang gọi.
    /// Trả về (MaTK, Cong) hoặc ném 401/403. Tài khoản thuộc cổng khác nhận cùng 401 như sai mật khẩu.
    /// </summary>
    public async Task<(int MaTK, Cong Cong)> VerifyCredentialsAsync(string tenDangNhap, string matKhau,
        IReadOnlyList<Cong> portals, CancellationToken ct)
    {
        var account = await FindAccountAsync(tenDangNhap, ct, portals: portals);
        if (account is null)
        {
            _passwords.VerifyDummy(matKhau);
            throw new ApiException(StatusCodes.Status401Unauthorized, "LOGIN_FAILED", LoginFailedMessage);
        }
        if (!_passwords.Verify(matKhau, account.Get<string>("MatKhauHash")))
            throw new ApiException(StatusCodes.Status401Unauthorized, "LOGIN_FAILED", LoginFailedMessage);

        if (account.Get<string>("TrangThai") != "HOAT_DONG")
            throw new ApiException(StatusCodes.Status403Forbidden, "ACCOUNT_LOCKED", AccountLockedMessage);

        if (!CongExtensions.TryParseDb(account.Get<string>("CongTruyCap"), out var cong))
            throw new InvalidOperationException("Vai trò có CongTruyCap không hợp lệ.");
        return (account.Get<int>("MaTK"), cong);
    }

    /// <summary>
    /// Bước 6–7 của L1: DatNguCanh → GhiNhanDangNhap → ThongTinPhien trên cùng một kết nối,
    /// rồi phát cookie MỚI (chống session fixation) và token chống CSRF gắn với phiên mới.
    /// </summary>
    public async Task<SessionResponse> OpenSessionAsync(HttpContext http, int maTK, Cong cong, CancellationToken ct)
    {
        SqlConnection conn;
        try
        {
            conn = await _factory.OpenAsync(cong, maTK, ct);
        }
        catch (SqlException ex) when (ex.Number == 50012)
        {
            throw new ApiException(StatusCodes.Status403Forbidden, "ACCOUNT_LOCKED", AccountLockedMessage);
        }

        SessionResponse session;
        await using (conn)
        {
            await _db.ExecOnAsync(conn, "api_chung.usp_GhiNhanDangNhap", null, ct);
            session = ToSession(await _db.ExecOnAsync(conn, "api_chung.usp_ThongTinPhien", null, ct));
        }

        await SignInAsync(http, session);
        _logger.LogInformation("Đăng nhập thành công MaTK={MaTK} cổng {Cong}", maTK, session.Cong);
        return session with { XsrfToken = IssueXsrf(http) };
    }

    /// <summary>Phát cookie mới cho phiên (đăng nhập hoặc sau khi đổi mật khẩu).</summary>
    public static async Task SignInAsync(HttpContext http, SessionResponse session)
    {
        CongExtensions.TryParseDb(session.Cong, out var cong);
        var principal = SecurityServiceExtensions.BuildPrincipal(session.MaTK, cong, session.TenDangNhap, session.PhaiDoiMatKhau);
        await http.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        await http.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal,
            new AuthenticationProperties { IsPersistent = false, AllowRefresh = true });
        http.User = principal;
    }

    /// <summary>Token antiforgery gắn với danh tính hiện tại của request.</summary>
    public string IssueXsrf(HttpContext http) => _antiforgery.GetAndStoreTokens(http).RequestToken!;

    public static SessionResponse ToSession(ProcResult result)
    {
        var info = result.First() ?? throw new ApiException(StatusCodes.Status401Unauthorized, "UNAUTHENTICATED",
            DbErrorMap.ThongBaoHetPhien);
        var quyen = result.Rows(1).Select(r => new QuyenItem(r.Get<string>("MaQuyen")!, r.Get<string>("TenQuyen")!)).ToList();
        return new SessionResponse(
            info.Get<int>("MaTK"),
            info.Get<string>("TenDangNhap")!,
            info.Get<string>("CongTruyCap")!,
            info.Get<string>("MaVT")!,
            info.Get<string>("TenVT"),
            info.Get<string>("HoTen"),
            info.Get<string>("ChucVu"),
            info.Get<int?>("MaKH"),
            info.Get<int?>("MaNV"),
            info.Get<bool>("PhaiDoiMatKhau"),
            quyen.Select(q => q.MaQuyen).ToList(),
            quyen);
    }
}
