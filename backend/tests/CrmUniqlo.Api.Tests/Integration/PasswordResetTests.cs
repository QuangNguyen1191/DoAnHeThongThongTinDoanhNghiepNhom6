using System.Net;
using CrmUniqlo.Api.Tests.Infrastructure;

namespace CrmUniqlo.Api.Tests.Integration;

/// <summary>L5. Quên mật khẩu: yêu cầu qua email, đặt lại bằng mã dùng một lần.</summary>
[Collection(ApiCollection.Name)]
[Trait("Category", "Integration")]
public sealed class PasswordResetTests(CrmApiFactory factory)
{
    private const string GenericMessage =
        "Nếu tên đăng nhập và email khớp một tài khoản đang hoạt động, email hướng dẫn đặt lại mật khẩu đã được gửi.";

    private async Task<(string User, string Email)> RegisterAsync()
    {
        var suffix = TestData.Suffix();
        var user = "kh.quen." + suffix;
        var email = $"quen.{suffix}@example.com";
        using var c = factory.Crm();
        await c.RefreshXsrfAsync();
        (await c.PostAsync("/api/auth/register", new
        {
            tenDangNhap = user, matKhau = "MatKhau123", hoTen = "Khách Quên Mật Khẩu", sdt = TestData.Phone(), email
        })).Expect(HttpStatusCode.Created);
        return (user, email);
    }

    [Fact]
    public async Task Forgot_then_reset_password_with_emailed_token()
    {
        var (user, email) = await RegisterAsync();
        using var c = factory.Crm();
        await c.RefreshXsrfAsync();

        // Email không khớp: vẫn 202 cùng thông báo, không gửi thư.
        var wrong = (await c.PostAsync("/api/auth/forgot-password", new { tenDangNhap = user, email = "khac@example.com" }))
            .Expect(HttpStatusCode.Accepted);
        Assert.Equal(GenericMessage, wrong["thongBao"].GetValue<string>());
        Assert.Empty(factory.Mailbox.To(email));

        // Khớp (email khác hoa thường): gửi đúng 1 thư có liên kết web-crm.
        var ok = (await c.PostAsync("/api/auth/forgot-password", new { tenDangNhap = user, email = email.ToUpperInvariant() }))
            .Expect(HttpStatusCode.Accepted);
        Assert.Equal(GenericMessage, ok["thongBao"].GetValue<string>());
        var mail = Assert.Single(factory.Mailbox.To(email));
        Assert.Contains("http://localhost:5000/dat-lai-mat-khau#token=", mail.Body);
        var token = factory.Mailbox.LatestResetToken(email)!;

        var weak = (await c.PostAsync("/api/auth/reset-password", new { token, matKhauMoi = "abc" }))
            .Expect(HttpStatusCode.UnprocessableEntity);
        Assert.Equal("matKhauMoi", weak["field"].GetValue<string>());

        (await c.PostAsync("/api/auth/reset-password", new { token, matKhauMoi = "MatKhauMoi456" })).Expect(HttpStatusCode.NoContent);

        // Mã chỉ dùng một lần.
        var reused = (await c.PostAsync("/api/auth/reset-password", new { token, matKhauMoi = "MatKhauMoi789" }))
            .Expect(HttpStatusCode.UnprocessableEntity);
        Assert.Equal("52098", reused.Code);
        Assert.Equal("token", reused["field"].GetValue<string>());

        using var login = factory.Crm();
        (await login.LoginAsync(user, "MatKhau123")).Expect(HttpStatusCode.Unauthorized);
        var session = (await login.LoginAsync(user, "MatKhauMoi456")).Expect(HttpStatusCode.OK);
        Assert.False(session["phaiDoiMatKhau"].GetValue<bool>());
    }

    [Fact]
    public async Task New_request_cancels_previous_token()
    {
        var (user, email) = await RegisterAsync();
        using var c = factory.Crm();
        await c.RefreshXsrfAsync();
        (await c.PostAsync("/api/auth/forgot-password", new { tenDangNhap = user, email })).Expect(HttpStatusCode.Accepted);
        var first = factory.Mailbox.LatestResetToken(email)!;
        (await c.PostAsync("/api/auth/forgot-password", new { tenDangNhap = user, email })).Expect(HttpStatusCode.Accepted);
        var second = factory.Mailbox.LatestResetToken(email)!;
        Assert.NotEqual(first, second);

        (await c.PostAsync("/api/auth/reset-password", new { token = first, matKhauMoi = "MatKhauMoi456" }))
            .Expect(HttpStatusCode.UnprocessableEntity);
        (await c.PostAsync("/api/auth/reset-password", new { token = second, matKhauMoi = "MatKhauMoi456" }))
            .Expect(HttpStatusCode.NoContent);
    }

    [Fact]
    public async Task Unknown_account_gets_same_answer_and_bad_token_is_rejected()
    {
        using var c = factory.Crm();
        await c.RefreshXsrfAsync();
        var r = (await c.PostAsync("/api/auth/forgot-password", new { tenDangNhap = "khong.ton.tai." + TestData.Suffix(), email = "x@example.com" }))
            .Expect(HttpStatusCode.Accepted);
        Assert.Equal(GenericMessage, r["thongBao"].GetValue<string>());

        (await c.PostAsync("/api/auth/reset-password", new { token = "ngan", matKhauMoi = "MatKhauMoi456" }))
            .Expect(HttpStatusCode.BadRequest);
        var unknown = (await c.PostAsync("/api/auth/reset-password", new { token = new string('A', 43), matKhauMoi = "MatKhauMoi456" }))
            .Expect(HttpStatusCode.UnprocessableEntity);
        Assert.Equal("52098", unknown.Code);

        (await c.SendAsync(HttpMethod.Post, "/api/auth/forgot-password", new { tenDangNhap = "kh.an", email = "a@example.com" }, withXsrf: false))
            .Expect(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Admin_resets_password_only_through_admin_port()
    {
        const string email = "bao.tran@nv.example.com"; // email hồ sơ nhân viên của admin.it
        using var crm = factory.Crm();
        await crm.RefreshXsrfAsync();
        var before = factory.Mailbox.To(email).Count;

        // Trang quên mật khẩu chung (web-crm) không phục vụ tài khoản Admin: vẫn 202 cùng thông báo, không gửi thư.
        (await crm.PostAsync("/api/auth/forgot-password", new { tenDangNhap = "admin.it", email })).Expect(HttpStatusCode.Accepted);
        Assert.Equal(before, factory.Mailbox.To(email).Count);

        using var admin = factory.Admin();
        await admin.RefreshXsrfAsync();
        (await admin.PostAsync("/api/auth/forgot-password", new { tenDangNhap = "admin.it", email })).Expect(HttpStatusCode.Accepted);
        Assert.Contains("http://localhost:5001/dat-lai-mat-khau#token=", factory.Mailbox.To(email)[^1].Body);
        var token = factory.Mailbox.LatestResetToken(email)!;

        // Mã của Admin không dùng được ở web-crm.
        var wrongPort = (await crm.PostAsync("/api/auth/reset-password", new { token, matKhauMoi = CrmClient.DemoPassword }))
            .Expect(HttpStatusCode.UnprocessableEntity);
        Assert.Equal("52098", wrongPort.Code);

        // Đặt lại đúng mật khẩu demo để các kiểm thử khác vẫn đăng nhập được.
        (await admin.PostAsync("/api/auth/reset-password", new { token, matKhauMoi = CrmClient.DemoPassword })).Expect(HttpStatusCode.NoContent);
        (await factory.Admin().LoginAsync("admin.it")).Expect(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Signed_in_user_must_use_change_password()
    {
        using var c = await factory.Crm().LoggedInAsync("kh.an");
        var r = (await c.PostAsync("/api/auth/forgot-password", new { tenDangNhap = "kh.an", email = "an.nguyen@example.com" }))
            .Expect(HttpStatusCode.UnprocessableEntity);
        Assert.Equal("ALREADY_SIGNED_IN", r.Code);
    }
}
