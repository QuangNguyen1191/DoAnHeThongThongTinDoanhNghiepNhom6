using CrmUniqlo.Api.Auth;
using CrmUniqlo.Api.Data;
using CrmUniqlo.Api.Errors;
using CrmUniqlo.Api.Models;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CrmUniqlo.Api.Controllers;

/// <summary>L1–L6: đăng nhập, đăng ký, phiên, đổi mật khẩu, quên mật khẩu, đăng xuất, token chống CSRF.</summary>
[ApiController]
[Route("api/auth")]
[Produces("application/json")]
public sealed class AuthController : ControllerBase
{
    private readonly AuthService _auth;
    private readonly CrmDb _db;
    private readonly CurrentUser _user;
    private readonly PasswordService _passwords;
    private readonly LoginThrottle _throttle;
    private readonly PasswordResetService _reset;
    private readonly PortalScope _scope;

    public const string ForgotPasswordMessage =
        "Nếu tên đăng nhập và email khớp một tài khoản đang hoạt động, email hướng dẫn đặt lại mật khẩu đã được gửi.";

    private static readonly TimeSpan ForgotPasswordMinDuration = TimeSpan.FromMilliseconds(400);

    public AuthController(AuthService auth, CrmDb db, CurrentUser user, PasswordService passwords, LoginThrottle throttle,
        PasswordResetService reset, PortalScope scope)
    {
        _reset = reset;
        _scope = scope;
        _auth = auth;
        _db = db;
        _user = user;
        _passwords = passwords;
        _throttle = throttle;
    }

    private string ClientIp => HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";

    /// <summary>Lấy token chống CSRF cho phiên hiện tại. Gửi lại trong header X-XSRF-TOKEN ở mọi request ghi.</summary>
    [HttpGet("antiforgery")]
    [AllowAnonymous]
    public XsrfResponse Antiforgery() => new(_auth.IssueXsrf(HttpContext));

    /// <summary>
    /// L1. Đăng nhập. Cổng web-crm (CrmPort) nhận Khách hàng và Quản lý; cổng web-admin (AdminPort) chỉ nhận Admin.
    /// Tài khoản không thuộc cổng đang gọi trả 401 LOGIN_FAILED như sai mật khẩu.
    /// </summary>
    [HttpPost("login")]
    [AllowAnonymous]
    [EnableRateLimiting(SecurityServiceExtensions.AuthRateLimit)]
    public async Task<SessionResponse> Login(LoginRequest request, CancellationToken ct)
    {
        if (!_throttle.TryBegin(ClientIp, request.TenDangNhap))
            throw new ApiException(StatusCodes.Status429TooManyRequests, "RATE_LIMIT", "Thử lại sau ít phút.");
        try
        {
            var (maTK, cong) = await _auth.VerifyCredentialsAsync(request.TenDangNhap, request.MatKhau,
                _scope.PortalsFor(HttpContext), ct);
            var session = await _auth.OpenSessionAsync(HttpContext, maTK, cong, ct);
            _throttle.Succeed(ClientIp, request.TenDangNhap);
            return session;
        }
        catch (ApiException ex) when (ex.Code == "LOGIN_FAILED")
        {
            _throttle.Fail(ClientIp, request.TenDangNhap);
            throw;
        }
    }

    /// <summary>L2. Khách tự đăng ký; thành công thì đăng nhập luôn.</summary>
    [HttpPost("register")]
    [AllowAnonymous]
    [EnableRateLimiting(SecurityServiceExtensions.AuthRateLimit)]
    [ProducesResponseType<SessionResponse>(StatusCodes.Status201Created)]
    public async Task<IActionResult> Register(RegisterRequest request, CancellationToken ct)
    {
        if (_user.IsAuthenticated)
            throw ApiException.Unprocessable("52010", "Phiên đang đăng nhập, không thể đăng ký tài khoản mới.");
        if (!PasswordService.MeetsPolicy(request.MatKhau))
            throw ApiException.Unprocessable("WEAK_PASSWORD", PasswordService.PolicyMessage, "matKhau");
        ValidateNgaySinh(request.NgaySinh);

        var result = await _db.ExecAnonymousAsync(Cong.KhachHang, "api_kh.usp_DangKy", new
        {
            request.TenDangNhap,
            MatKhauHash = _passwords.Hash(request.MatKhau),
            request.HoTen,
            SDT = request.Sdt,
            request.GioiTinh,
            NgaySinh = CrmDb.ToDbDate(request.NgaySinh),
            request.Email,
            request.MaTinh,
            DsLoaiQuanTam = Tvp.DanhSachMa(request.DsLoaiQuanTam)
        }, ct);

        var maTK = result.First()?.Get<int>("MaTK") ?? throw new InvalidOperationException("usp_DangKy không trả MaTK.");
        var session = await _auth.OpenSessionAsync(HttpContext, maTK, Cong.KhachHang, ct);
        return StatusCode(StatusCodes.Status201Created, session);
    }

    /// <summary>L6. Thông tin phiên và danh sách quyền (để giao diện ẩn/hiện chức năng).</summary>
    [HttpGet("me")]
    [Authorize]
    public async Task<SessionResponse> Me(CancellationToken ct) =>
        AuthService.ToSession(await _db.ExecAsync("api_chung.usp_ThongTinPhien", null, ct));

    /// <summary>L3. Đổi mật khẩu (bắt buộc khi PhaiDoiMatKhau = 1). Phát lại cookie và token CSRF.</summary>
    [HttpPost("change-password")]
    [Authorize]
    public async Task<SessionResponse> ChangePassword(ChangePasswordRequest request, CancellationToken ct)
    {
        var (cong, maTK) = _user.Require();
        var account = await _auth.FindAccountAsync(_user.TenDangNhap ?? "", ct, cong);
        if (account is null || account.Get<int>("MaTK") != maTK)
            throw new ApiException(StatusCodes.Status401Unauthorized, "UNAUTHENTICATED", DbErrorMap.ThongBaoHetPhien);

        if (!_passwords.Verify(request.MatKhauCu, account.Get<string>("MatKhauHash")))
            throw ApiException.Unprocessable("WRONG_PASSWORD", "Mật khẩu cũ không đúng.", "matKhauCu");
        if (!PasswordService.MeetsPolicy(request.MatKhauMoi))
            throw ApiException.Unprocessable("WEAK_PASSWORD", PasswordService.PolicyMessage, "matKhauMoi");
        if (request.MatKhauMoi == request.MatKhauCu)
            throw ApiException.Unprocessable("SAME_PASSWORD", "Mật khẩu mới phải khác mật khẩu cũ.", "matKhauMoi");

        await _db.ExecAsync("api_chung.usp_DoiMatKhau", new { MatKhauHashMoi = _passwords.Hash(request.MatKhauMoi) }, ct);

        var session = AuthService.ToSession(await _db.ExecAsync("api_chung.usp_ThongTinPhien", null, ct));
        await AuthService.SignInAsync(HttpContext, session);
        return session with { XsrfToken = _auth.IssueXsrf(HttpContext) };
    }

    /// <summary>
    /// L5 bước 1. Quên mật khẩu: nhập tên đăng nhập + email trong hồ sơ. Luôn trả 202 với cùng thông báo
    /// (không lộ tài khoản có tồn tại hay không); email chứa liên kết đặt lại được gửi nền.
    /// </summary>
    [HttpPost("forgot-password")]
    [AllowAnonymous]
    [EnableRateLimiting(SecurityServiceExtensions.AuthRateLimit)]
    [ProducesResponseType<MessageResponse>(StatusCodes.Status202Accepted)]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest request, CancellationToken ct)
    {
        RequireSignedOut();
        // Thời gian trả lời tối thiểu cố định: có hay không có tài khoản khớp đều trả lời sau cùng một khoảng.
        var minimum = Task.Delay(ForgotPasswordMinDuration, ct);
        await _reset.RequestAsync(request.TenDangNhap, request.Email, _scope.PortalsFor(HttpContext), ct);
        await minimum;
        return StatusCode(StatusCodes.Status202Accepted, new MessageResponse(ForgotPasswordMessage));
    }

    /// <summary>L5 bước 2. Đặt mật khẩu mới bằng mã trong email. Sau đó đăng nhập lại như bình thường.</summary>
    [HttpPost("reset-password")]
    [AllowAnonymous]
    [EnableRateLimiting(SecurityServiceExtensions.AuthRateLimit)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest request, CancellationToken ct)
    {
        RequireSignedOut();
        if (!PasswordService.MeetsPolicy(request.MatKhauMoi))
            throw ApiException.Unprocessable("WEAK_PASSWORD", PasswordService.PolicyMessage, "matKhauMoi");
        await _reset.ResetAsync(request.Token, request.MatKhauMoi, _scope.PortalsFor(HttpContext), ct);
        return NoContent();
    }

    private void RequireSignedOut()
    {
        if (_user.IsAuthenticated)
            throw ApiException.Unprocessable("ALREADY_SIGNED_IN", "Bạn đang đăng nhập; hãy dùng chức năng đổi mật khẩu.");
    }

    /// <summary>L4. Đăng xuất: xóa cookie phiên. Không gọi CSDL.</summary>
    [HttpPost("logout")]
    [AllowAnonymous]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Logout()
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return NoContent();
    }

    internal static void ValidateNgaySinh(DateOnly? ngaySinh)
    {
        if (ngaySinh is { } d && (d.Year < 1900 || d > DateOnly.FromDateTime(DateTime.Today)))
            throw ApiException.Unprocessable("VALIDATION", "Ngày sinh phải từ năm 1900 đến hôm nay.", "ngaySinh");
    }
}
