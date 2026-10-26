using System.Security.Cryptography;
using System.Text.RegularExpressions;

namespace CrmUniqlo.Api.Auth;

/// <summary>
/// Băm/so khớp mật khẩu bằng bcrypt (cost 10, khớp dữ liệu demo $2b$10$).
/// CSDL chỉ nhận chuỗi băm (CHECK LEN(MatKhauHash) >= 50), không bao giờ nhận mật khẩu thô.
/// </summary>
public sealed partial class PasswordService
{
    public const int WorkFactor = 10;

    // Hash giả để cân bằng thời gian khi tên đăng nhập không tồn tại.
    private static readonly string DummyHash = BCrypt.Net.BCrypt.HashPassword("khong-ton-tai", WorkFactor);

    public string Hash(string password) => BCrypt.Net.BCrypt.HashPassword(password, WorkFactor);

    public bool Verify(string password, string? hash)
    {
        try
        {
            return BCrypt.Net.BCrypt.Verify(password, hash ?? DummyHash);
        }
        catch (BCrypt.Net.SaltParseException)
        {
            return false;
        }
    }

    /// <summary>Chạy một lần so khớp vô ích để thời gian trả lời không lộ tên đăng nhập có tồn tại hay không.</summary>
    public void VerifyDummy(string password) => BCrypt.Net.BCrypt.Verify(password, DummyHash);

    /// <summary>Chính sách mật khẩu: ≥ 8 ký tự, có chữ và số, ≤ 128 ký tự.</summary>
    public static bool MeetsPolicy(string? password) =>
        password is { Length: >= 8 and <= 128 } && LetterRegex().IsMatch(password) && DigitRegex().IsMatch(password);

    public const string PolicyMessage = "Mật khẩu phải có ít nhất 8 ký tự, gồm cả chữ và số.";

    /// <summary>Sinh mật khẩu tạm (12 ký tự, có chữ hoa, chữ thường, số) cho tài khoản được cấp / đặt lại.</summary>
    public static string GenerateTemporary()
    {
        const string upper = "ABCDEFGHJKLMNPQRSTUVWXYZ";
        const string lower = "abcdefghijkmnpqrstuvwxyz";
        const string digits = "23456789";
        const string all = upper + lower + digits;
        var chars = new char[12];
        chars[0] = upper[RandomNumberGenerator.GetInt32(upper.Length)];
        chars[1] = lower[RandomNumberGenerator.GetInt32(lower.Length)];
        chars[2] = digits[RandomNumberGenerator.GetInt32(digits.Length)];
        for (var i = 3; i < chars.Length; i++) chars[i] = all[RandomNumberGenerator.GetInt32(all.Length)];
        RandomNumberGenerator.Shuffle(chars.AsSpan());
        return new string(chars);
    }

    [GeneratedRegex(@"\p{L}")]
    private static partial Regex LetterRegex();

    [GeneratedRegex(@"\d")]
    private static partial Regex DigitRegex();
}
