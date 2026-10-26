using System.Security.Cryptography;
using System.Text;
using CrmUniqlo.Api.Data;
using CrmUniqlo.Api.Errors;
using CrmUniqlo.Api.Infrastructure.Email;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace CrmUniqlo.Api.Auth;

/// <summary>
/// L5. Quên mật khẩu tự phục vụ bằng email.
/// Mã đặt lại = 32 byte ngẫu nhiên (base64url) chỉ đi trong email; CSDL chỉ giữ SHA-256 của mã,
/// dùng một lần, hết hạn sau Email:ResetTokenMinutes phút. Thủ tục kiểm tra mã thuộc đúng cổng gọi.
/// </summary>
public sealed class PasswordResetService
{
    private static readonly Cong[] PortalOrder = [Cong.KhachHang, Cong.QuanLy, Cong.Admin];

    private readonly CrmDb _db;
    private readonly PasswordService _passwords;
    private readonly IEmailOutbox _email;
    private readonly IOptionsMonitor<EmailOptions> _options;
    private readonly ILogger<PasswordResetService> _logger;

    public PasswordResetService(CrmDb db, PasswordService passwords, IEmailOutbox email, IOptionsMonitor<EmailOptions> options,
        ILogger<PasswordResetService> logger)
    {
        _db = db;
        _passwords = passwords;
        _email = email;
        _options = options;
        _logger = logger;
    }

    /// <summary>
    /// Ghi mã đặt lại và xếp email vào hàng đợi nếu tên đăng nhập + email khớp một tài khoản đang hoạt động.
    /// Không khớp thì không làm gì; người gọi luôn trả lời giống nhau.
    /// Hỏi đủ các cổng của trang đang gọi để thời gian trả lời không phụ thuộc tài khoản thuộc cổng nào.
    /// </summary>
    public async Task RequestAsync(string tenDangNhap, string email, IReadOnlyList<Cong> portals, CancellationToken ct)
    {
        var o = _options.CurrentValue;
        var token = NewToken();
        var tokenHash = HashToken(token);

        foreach (var cong in PortalOrder.Where(portals.Contains))
        {
            var row = (await _db.ExecAnonymousAsync(cong, "api_chung.usp_YeuCauDatLaiMatKhau", new
            {
                TenDangNhap = tenDangNhap,
                Email = email,
                TokenHash = tokenHash,
                SoPhutHieuLuc = o.ResetTokenMinutes
            }, ct)).First();
            if (row is null) continue;

            var link = (cong == Cong.Admin ? o.ResetUrlAdmin : o.ResetUrlCrm).Replace("{token}", token);
            var hoTen = row.Get<string>("HoTen");
            _email.Enqueue(new EmailMessage(row.Get<string>("Email")!, hoTen, "CRM Uniqlo – Đặt lại mật khẩu",
                $"""
                Xin chào {hoTen},

                Chúng tôi nhận được yêu cầu đặt lại mật khẩu cho tài khoản {tenDangNhap}.
                Mở liên kết sau để đặt mật khẩu mới (hiệu lực {o.ResetTokenMinutes} phút, dùng một lần):

                {link}

                Nếu bạn không yêu cầu, hãy bỏ qua email này; mật khẩu hiện tại vẫn giữ nguyên.

                CRM Uniqlo
                """));
            _logger.LogInformation("Đã tạo yêu cầu đặt lại mật khẩu (cổng {Cong}).", cong.ToDb());
        }
    }

    /// <summary>Đặt mật khẩu mới bằng mã trong email. Mã sai/hết hạn/đã dùng → 422 mã 52098.</summary>
    /// <remarks>Mã của tài khoản thuộc cổng khác (ví dụ mã Admin dùng trên web-crm) cũng bị coi là sai.</remarks>
    public async Task ResetAsync(string token, string matKhauMoi, IReadOnlyList<Cong> portals, CancellationToken ct)
    {
        var tokenHash = HashToken(token);
        var hash = _passwords.Hash(matKhauMoi);
        SqlException? last = null;
        foreach (var cong in PortalOrder.Where(portals.Contains))
        {
            try
            {
                await _db.ExecAnonymousAsync(cong, "api_chung.usp_DatLaiMatKhauBangMa",
                    new { TokenHash = tokenHash, MatKhauHashMoi = hash }, ct);
                return;
            }
            catch (SqlException ex) when (ex.Number == 52098)
            {
                last = ex;
            }
        }
        throw last!;
    }

    public static string NewToken() => Base64UrlEncode(RandomNumberGenerator.GetBytes(32));

    /// <summary>SHA-256 (hex thường, 64 ký tự) của mã; khớp CHECK của crm.YEU_CAU_DAT_LAI_MK.</summary>
    public static string HashToken(string token) =>
        Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

    private static string Base64UrlEncode(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}
