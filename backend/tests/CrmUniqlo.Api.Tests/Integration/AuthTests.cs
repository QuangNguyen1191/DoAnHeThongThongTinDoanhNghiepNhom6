using System.Net;
using CrmUniqlo.Api.Tests.Infrastructure;

namespace CrmUniqlo.Api.Tests.Integration;

/// <summary>L1–L4: đăng nhập, đăng ký, đổi mật khẩu, đăng xuất, CSRF, giới hạn đăng nhập.</summary>
[Collection(ApiCollection.Name)]
[Trait("Category", "Integration")]
public sealed class AuthTests(CrmApiFactory factory)
{
    [Theory]
    [InlineData("admin.it", "ADMIN")]
    [InlineData("ql.lan", "QUAN_LY")]
    [InlineData("cskh.hoa", "QUAN_LY")]
    [InlineData("kh.an", "KHACH_HANG")]
    public async Task Login_demo_accounts_open_the_right_portal(string user, string cong)
    {
        // Admin đăng nhập ở trang riêng của web-admin; Khách hàng và Quản lý dùng chung trang của web-crm.
        using var c = cong == "ADMIN" ? factory.Admin() : factory.Crm();
        var r = (await c.LoginAsync(user)).Expect(HttpStatusCode.OK);
        Assert.Equal(cong, r["cong"].GetValue<string>());
        Assert.False(string.IsNullOrEmpty(r["xsrfToken"].GetValue<string>()));
        Assert.DoesNotContain("matKhauHash", r.Body, StringComparison.OrdinalIgnoreCase);

        var me = (await c.GetAsync("/api/auth/me")).Expect(HttpStatusCode.OK);
        Assert.Equal(user, me["tenDangNhap"].GetValue<string>());
    }

    [Theory]
    [InlineData("admin.it", false)]
    [InlineData("it.mai", false)]
    [InlineData("kh.an", true)]
    [InlineData("ql.lan", true)]
    [InlineData("cskh.hoa", true)]
    public async Task Each_login_page_only_accepts_its_own_portal(string user, bool onAdminPort)
    {
        // Sai trang đăng nhập: trả lời y như sai mật khẩu, không lộ tài khoản có tồn tại hay thuộc vai trò nào.
        using var c = onAdminPort ? factory.Admin() : factory.Crm();
        var r = (await c.LoginAsync(user)).Expect(HttpStatusCode.Unauthorized);
        Assert.Equal("LOGIN_FAILED", r.Code);
        Assert.Equal("Sai tên đăng nhập hoặc mật khẩu.", r["title"].GetValue<string>());
        (await c.GetAsync("/api/auth/me")).Expect(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Admin_and_crm_sessions_use_separate_cookies()
    {
        using var http = factory.CreateClient(new Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri(CrmApiFactory.AdminBase), HandleCookies = false
        });
        var af = await http.GetAsync("/api/auth/antiforgery");
        var xsrfCookie = af.Headers.GetValues("Set-Cookie").First(v => v.StartsWith("crm.xsrf=")).Split(';')[0];
        var token = System.Text.Json.Nodes.JsonNode.Parse(await af.Content.ReadAsStringAsync())!["xsrfToken"]!.GetValue<string>();
        using var req = new HttpRequestMessage(HttpMethod.Post, "/api/auth/login")
        {
            Content = System.Net.Http.Json.JsonContent.Create(new { tenDangNhap = "admin.it", matKhau = CrmClient.DemoPassword })
        };
        req.Headers.Add("X-XSRF-TOKEN", token);
        req.Headers.Add("Cookie", xsrfCookie);
        var res = await http.SendAsync(req);
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        var cookies = res.Headers.GetValues("Set-Cookie").ToList();
        Assert.Contains(cookies, v => v.StartsWith("crm.admin.auth=") && !v.StartsWith("crm.admin.auth=;"));
        Assert.DoesNotContain(cookies, v => v.StartsWith("crm.auth=") && !v.StartsWith("crm.auth=;"));
    }

    [Fact]
    public async Task Login_is_case_insensitive_on_username()
    {
        using var c = factory.Crm();
        (await c.LoginAsync("KH.AN")).Expect(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Wrong_password_and_unknown_user_get_the_same_answer()
    {
        using var c = factory.Crm();
        var wrong = (await c.LoginAsync("kh.chau", "SaiMatKhau1")).Expect(HttpStatusCode.Unauthorized);
        var unknown = (await c.LoginAsync("khong.ton.tai." + TestData.Suffix(), "SaiMatKhau1")).Expect(HttpStatusCode.Unauthorized);
        Assert.Equal(wrong["title"].GetValue<string>(), unknown["title"].GetValue<string>());
        Assert.Equal("LOGIN_FAILED", wrong.Code);
    }

    [Fact]
    public async Task Locked_account_gets_403()
    {
        using var c = factory.Crm();
        var r = (await c.LoginAsync("kh.quyen")).Expect(HttpStatusCode.Forbidden);
        Assert.Equal("ACCOUNT_LOCKED", r.Code);
    }

    [Fact]
    public async Task Deleted_customer_profile_cannot_log_in()
    {
        using var c = factory.Crm();
        var r = await c.LoginAsync("kh.nam");
        Assert.True(r.Status is HttpStatusCode.Forbidden or HttpStatusCode.Unauthorized, r.Body);
    }

    [Fact]
    public async Task Sixth_failure_in_window_gets_429()
    {
        using var c = factory.Crm();
        var user = "khong.co." + TestData.Suffix();
        for (var i = 0; i < 5; i++) (await c.LoginAsync(user, "SaiMatKhau1")).Expect(HttpStatusCode.Unauthorized);
        (await c.LoginAsync(user, "SaiMatKhau1")).Expect(HttpStatusCode.TooManyRequests);
    }

    [Fact]
    public async Task Write_request_without_xsrf_header_is_rejected()
    {
        using var c = factory.Crm();
        var r = await c.SendAsync(HttpMethod.Post, "/api/auth/login", new { tenDangNhap = "kh.an", matKhau = CrmClient.DemoPassword }, withXsrf: false);
        r.Expect(HttpStatusCode.BadRequest);
        Assert.Equal("CSRF", r.Code);
    }

    [Fact]
    public async Task Write_request_from_foreign_origin_is_rejected()
    {
        using var c = await factory.Crm().LoggedInAsync("kh.an");
        c.Http.DefaultRequestHeaders.Add("Origin", "https://evil.example.com");
        var r = await c.PostAsync("/api/customer/feedback", new { loaiPH = "KHEN", diemDanhGia = 5, noiDung = "x" });
        r.Expect(HttpStatusCode.Forbidden);
        Assert.Equal("ORIGIN", r.Code);
    }

    [Fact]
    public async Task Anonymous_calls_get_401_problem_details()
    {
        using var c = factory.Crm();
        var r = (await c.GetAsync("/api/auth/me")).Expect(HttpStatusCode.Unauthorized);
        Assert.Equal("application/problem+json", r.ContentType);
        Assert.NotNull(r.Json?["traceId"]);
        (await c.GetAsync("/api/customer/profile")).Expect(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Logout_clears_the_session()
    {
        using var c = await factory.Crm().LoggedInAsync("kh.binh");
        (await c.PostAsync("/api/auth/logout")).Expect(HttpStatusCode.NoContent);
        (await c.GetAsync("/api/auth/me")).Expect(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Session_cookie_is_httponly_secure_lax_and_new_on_each_login()
    {
        // Client không tự xử lý cookie để đọc được Set-Cookie.
        using var http = factory.CreateClient(new Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri(CrmApiFactory.CrmBase), HandleCookies = false
        });

        async Task<string> LoginAndGetCookie()
        {
            var af = await http.GetAsync("/api/auth/antiforgery");
            var xsrfCookie = af.Headers.GetValues("Set-Cookie").First(v => v.StartsWith("crm.xsrf=")).Split(';')[0];
            var token = System.Text.Json.Nodes.JsonNode.Parse(await af.Content.ReadAsStringAsync())!["xsrfToken"]!.GetValue<string>();
            using var req = new HttpRequestMessage(HttpMethod.Post, "/api/auth/login")
            {
                Content = System.Net.Http.Json.JsonContent.Create(new { tenDangNhap = "kh.an", matKhau = CrmClient.DemoPassword })
            };
            req.Headers.Add("X-XSRF-TOKEN", token);
            req.Headers.Add("Cookie", xsrfCookie);
            var res = await http.SendAsync(req);
            Assert.Equal(HttpStatusCode.OK, res.StatusCode);
            return res.Headers.GetValues("Set-Cookie").Last(v => v.StartsWith("crm.auth=") && !v.StartsWith("crm.auth=;"));
        }

        var first = await LoginAndGetCookie();
        var second = await LoginAndGetCookie();
        Assert.Contains("httponly", first, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("secure", first, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("samesite=lax", first, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("expires", first, StringComparison.OrdinalIgnoreCase); // cookie phiên, không lưu xuống đĩa
        Assert.NotEqual(first.Split(';')[0], second.Split(';')[0]);
    }

    [Fact]
    public async Task Register_then_auto_login_with_default_tier()
    {
        using var c = factory.Crm();
        await c.RefreshXsrfAsync();
        var user = "kh.test." + TestData.Suffix();
        var r = (await c.PostAsync("/api/auth/register", new
        {
            tenDangNhap = user, matKhau = "MatKhau123", hoTen = "Khách Kiểm Thử", sdt = TestData.Phone(),
            gioiTinh = "NU", ngaySinh = "2000-01-15", maTinh = "HCM", dsLoaiQuanTam = new[] { 1, 2 }
        })).Expect(HttpStatusCode.Created);
        Assert.Equal("KHACH_HANG", r["cong"].GetValue<string>());
        c.UseXsrf(r["xsrfToken"].GetValue<string>());

        var profile = (await c.GetAsync("/api/customer/profile")).Expect(HttpStatusCode.OK);
        Assert.Equal("THUONG", profile["hoSo"]["maHang"]!.GetValue<string>());
        Assert.Equal(0, profile["hoSo"]["diem"]!.GetValue<int>());
        Assert.Equal(2, profile["soThich"].AsArray().Count);
    }

    [Fact]
    public async Task Register_with_existing_phone_is_409_on_sdt()
    {
        using var c = factory.Crm();
        await c.RefreshXsrfAsync();
        var r = (await c.PostAsync("/api/auth/register", new
        {
            tenDangNhap = "kh.trung." + TestData.Suffix(), matKhau = "MatKhau123", hoTen = "Trùng SĐT", sdt = "0901000001"
        })).Expect(HttpStatusCode.Conflict);
        Assert.Equal("52002", r.Code);
        Assert.Equal("sdt", r["field"].GetValue<string>());
    }

    [Fact]
    public async Task Register_rejects_weak_password_and_bad_phone()
    {
        using var c = factory.Crm();
        await c.RefreshXsrfAsync();
        var weak = (await c.PostAsync("/api/auth/register", new
        {
            tenDangNhap = "kh.yeu." + TestData.Suffix(), matKhau = "abc", hoTen = "Yếu", sdt = TestData.Phone()
        })).Expect(HttpStatusCode.UnprocessableEntity);
        Assert.Equal("matKhau", weak["field"].GetValue<string>());

        var phone = (await c.PostAsync("/api/auth/register", new
        {
            tenDangNhap = "kh.sdt." + TestData.Suffix(), matKhau = "MatKhau123", hoTen = "SĐT sai", sdt = "12345"
        })).Expect(HttpStatusCode.BadRequest);
        Assert.Equal("VALIDATION", phone.Code);
        Assert.Equal("sdt", phone["field"].GetValue<string>());
    }
}
