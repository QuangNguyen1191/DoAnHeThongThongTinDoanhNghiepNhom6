using CrmUniqlo.Api.Auth;
using CrmUniqlo.Api.Errors;
using CrmUniqlo.Api.Infrastructure;

namespace CrmUniqlo.Api.Tests.Unit;

public sealed class NamingPolicyTests
{
    [Theory]
    [InlineData("MaKH", "maKH")]
    [InlineData("HoTen", "hoTen")]
    [InlineData("SDT", "sdt")]
    [InlineData("SDT_Che", "sdt_Che")]
    [InlineData("MaNV_Tao", "maNV_Tao")]
    [InlineData("TyLePhanTram", "tyLePhanTram")]
    [InlineData("maKH", "maKH")]
    public void Converts_db_columns_to_camel_case(string input, string expected) =>
        Assert.Equal(expected, CrmNamingPolicy.Instance.ConvertName(input));
}

public sealed class DbErrorMapTests
{
    [Theory]
    [InlineData(50001, 401)]
    [InlineData(50012, 401)]
    [InlineData(50003, 403)]
    [InlineData(229, 403)]
    [InlineData(33504, 403)]
    [InlineData(50013, 403)]
    [InlineData(52002, 409)]
    [InlineData(52004, 409)]
    [InlineData(52072, 409)]
    [InlineData(52081, 409)]
    [InlineData(52030, 404)]
    [InlineData(52040, 404)]
    [InlineData(52095, 404)]
    [InlineData(52001, 422)]
    [InlineData(52063, 422)]
    [InlineData(51001, 422)]
    [InlineData(208, 500)]
    [InlineData(1205, 500)]
    public void Maps_db_errors_to_http(int number, int status) => Assert.Equal(status, DbErrorMap.ToStatus(number));

    [Fact]
    public void Server_errors_never_expose_db_message() =>
        Assert.Equal(DbErrorMap.ThongBaoLoiHeThong, DbErrorMap.ToTitle(208, "Invalid object name 'crm.X'.", 500));

    [Fact]
    public void Business_errors_keep_vietnamese_db_message() =>
        Assert.Equal("Khảo sát đã đóng.", DbErrorMap.ToTitle(52063, "Khảo sát đã đóng.", 422));
}

public sealed class PasswordServiceTests
{
    [Theory]
    [InlineData("Demo@2026", true)]
    [InlineData("abcdefg1", true)]
    [InlineData("abcdefgh", false)]
    [InlineData("12345678", false)]
    [InlineData("ab1", false)]
    public void Policy(string password, bool ok) => Assert.Equal(ok, PasswordService.MeetsPolicy(password));

    [Fact]
    public void Hash_is_bcrypt_cost_10_and_long_enough_for_db_check()
    {
        var hash = new PasswordService().Hash("Demo@2026");
        Assert.StartsWith("$2", hash);
        Assert.Contains("$10$", hash);
        Assert.True(hash.Length >= 50);
        Assert.True(new PasswordService().Verify("Demo@2026", hash));
    }

    [Fact]
    public void Verifies_demo_hash_from_database_scripts() =>
        Assert.True(new PasswordService().Verify("Demo@2026", "$2b$10$eWVBe5JjKzcJ3s5c5Dp.qONhinFmd.WUOt4pxxo21gSz3pOEDaWr."));

    [Fact]
    public void Temporary_password_meets_policy()
    {
        for (var i = 0; i < 100; i++) Assert.True(PasswordService.MeetsPolicy(PasswordService.GenerateTemporary()));
    }
}
