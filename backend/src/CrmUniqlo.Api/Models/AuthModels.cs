using System.ComponentModel.DataAnnotations;

namespace CrmUniqlo.Api.Models;

public sealed class LoginRequest
{
    [Required(ErrorMessage = "Tên đăng nhập là bắt buộc.")]
    [RegularExpression(Patterns.TenDangNhap, ErrorMessage = Patterns.TenDangNhapMessage)]
    public string TenDangNhap { get; set; } = "";

    [Required(ErrorMessage = "Mật khẩu là bắt buộc.")]
    [StringLength(128, MinimumLength = 1, ErrorMessage = "Mật khẩu tối đa 128 ký tự.")]
    public string MatKhau { get; set; } = "";
}

public sealed class RegisterRequest
{
    [Required(ErrorMessage = "Tên đăng nhập là bắt buộc.")]
    [RegularExpression(Patterns.TenDangNhap, ErrorMessage = Patterns.TenDangNhapMessage)]
    public string TenDangNhap { get; set; } = "";

    [Required(ErrorMessage = "Mật khẩu là bắt buộc.")]
    public string MatKhau { get; set; } = "";

    [Required(ErrorMessage = "Họ tên là bắt buộc.")]
    [StringLength(100, ErrorMessage = "Họ tên tối đa 100 ký tự.")]
    public string HoTen { get; set; } = "";

    [Required(ErrorMessage = "Số điện thoại là bắt buộc.")]
    [RegularExpression(Patterns.Sdt, ErrorMessage = Patterns.SdtMessage)]
    public string Sdt { get; set; } = "";

    [RegularExpression(Patterns.GioiTinh, ErrorMessage = Patterns.GioiTinhMessage)]
    public string? GioiTinh { get; set; }

    public DateOnly? NgaySinh { get; set; }

    [EmailAddress(ErrorMessage = "Email không hợp lệ.")]
    [StringLength(100, ErrorMessage = "Email tối đa 100 ký tự.")]
    public string? Email { get; set; }

    [StringLength(10)]
    public string? MaTinh { get; set; }

    /// <summary>Mã loại sản phẩm quan tâm (sở thích).</summary>
    public List<int>? DsLoaiQuanTam { get; set; }
}

public sealed class ChangePasswordRequest
{
    [Required(ErrorMessage = "Mật khẩu cũ là bắt buộc.")]
    [StringLength(128)]
    public string MatKhauCu { get; set; } = "";

    [Required(ErrorMessage = "Mật khẩu mới là bắt buộc.")]
    public string MatKhauMoi { get; set; } = "";
}

public sealed class ForgotPasswordRequest
{
    [Required(ErrorMessage = "Tên đăng nhập là bắt buộc.")]
    [RegularExpression(Patterns.TenDangNhap, ErrorMessage = Patterns.TenDangNhapMessage)]
    public string TenDangNhap { get; set; } = "";

    [Required(ErrorMessage = "Email là bắt buộc.")]
    [EmailAddress(ErrorMessage = "Email không hợp lệ.")]
    [StringLength(100, ErrorMessage = "Email tối đa 100 ký tự.")]
    public string Email { get; set; } = "";
}

public sealed class ResetPasswordRequest
{
    /// <summary>Mã trong liên kết của email đặt lại mật khẩu.</summary>
    [Required(ErrorMessage = "Thiếu mã đặt lại mật khẩu.")]
    [RegularExpression("^[A-Za-z0-9_-]{43}$", ErrorMessage = "Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn.")]
    public string Token { get; set; } = "";

    [Required(ErrorMessage = "Mật khẩu mới là bắt buộc.")]
    public string MatKhauMoi { get; set; } = "";
}

/// <summary>Trả lời chung của "quên mật khẩu" (không cho biết tài khoản có tồn tại hay không).</summary>
public sealed record MessageResponse(string ThongBao);

/// <summary>Thông tin phiên trả về sau đăng nhập và ở GET /api/auth/me.</summary>
public sealed record SessionResponse(
    int MaTK,
    string TenDangNhap,
    string Cong,
    string MaVT,
    string? TenVT,
    string? HoTen,
    string? ChucVu,
    int? MaKH,
    int? MaNV,
    bool PhaiDoiMatKhau,
    IReadOnlyList<string> Quyen,
    IReadOnlyList<QuyenItem> QuyenChiTiet,
    string? XsrfToken = null);

public sealed record QuyenItem(string MaQuyen, string TenQuyen);

public sealed record XsrfResponse(string XsrfToken);
