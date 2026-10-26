using System.Net;
using CrmUniqlo.Api.Tests.Infrastructure;

namespace CrmUniqlo.Api.Tests.Integration;

/// <summary>Tách cổng, phân quyền dọc/ngang, IDOR, khóa tài khoản đang đăng nhập (SEC-04..12, IT-01).</summary>
[Collection(ApiCollection.Name)]
[Trait("Category", "Integration")]
public sealed class PortalSecurityTests(CrmApiFactory factory)
{
    [Fact]
    public async Task Admin_routes_only_answer_on_admin_port()
    {
        using var crm = await factory.Crm().LoggedInAsync("ql.lan");
        (await crm.GetAsync("/api/admin/accounts")).Expect(HttpStatusCode.NotFound);

        using var admin = await factory.Admin().LoggedInAsync("admin.it");
        (await admin.GetAsync("/api/admin/accounts")).Expect(HttpStatusCode.OK);
        (await admin.GetAsync("/api/manager/customers")).Expect(HttpStatusCode.NotFound);
        (await admin.GetAsync("/api/customer/profile")).Expect(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Customer_cookie_cannot_call_admin_or_manager_api()
    {
        // Khách không đăng nhập được ở web-admin nên không có phiên nào để gọi /api/admin.
        using var admin = factory.Admin();
        (await admin.LoginAsync("kh.an")).Expect(HttpStatusCode.Unauthorized);
        (await admin.GetAsync("/api/admin/accounts")).Expect(HttpStatusCode.Unauthorized);

        using var crm = await factory.Crm().LoggedInAsync("kh.an");
        (await crm.GetAsync("/api/manager/customers")).Expect(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Manager_cookie_cannot_call_customer_or_admin_api()
    {
        using var crm = await factory.Crm().LoggedInAsync("ql.lan");
        (await crm.GetAsync("/api/customer/profile")).Expect(HttpStatusCode.Forbidden);
        using var admin = factory.Admin();
        (await admin.LoginAsync("ql.lan")).Expect(HttpStatusCode.Unauthorized);
        (await admin.GetAsync("/api/admin/accounts")).Expect(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Cskh_staff_cannot_add_customers_50003()
    {
        using var c = await factory.Crm().LoggedInAsync("cskh.hoa");
        (await c.GetAsync("/api/manager/customers")).Expect(HttpStatusCode.OK);
        var r = (await c.PostAsync("/api/manager/customers", new { hoTen = "Không được thêm", sdt = TestData.Phone() }))
            .Expect(HttpStatusCode.Forbidden);
        Assert.Equal("50003", r.Code);
    }

    [Fact]
    public async Task Account_admin_cannot_escalate_to_admin_role()
    {
        using var c = await factory.Admin().LoggedInAsync("it.mai");
        var accounts = (await c.GetAsync("/api/admin/accounts?loaiTK=NV")).Expect(HttpStatusCode.OK);
        var self = accounts.Json!.AsArray().First(a => a!["tenDangNhap"]!.GetValue<string>() == "it.mai")!;
        var r = (await c.PutAsync($"/api/admin/accounts/{self["maTK"]}/role", new { maVT = "ADMIN" }))
            .Expect(HttpStatusCode.Forbidden);
        Assert.Equal("50003", r.Code);
    }

    [Fact]
    public async Task Customer_cannot_open_survey_not_sent_to_them()
    {
        using var c = await factory.Crm().LoggedInAsync("kh.an");
        var mine = (await c.GetAsync("/api/customer/surveys")).Expect(HttpStatusCode.OK).Json!.AsArray()
            .Select(s => s!["maKS"]!.GetValue<int>()).ToHashSet();
        using var ql = await factory.Crm().LoggedInAsync("ql.lan");
        var all = (await ql.GetAsync("/api/manager/surveys")).Expect(HttpStatusCode.OK).Json!.AsArray()
            .Select(s => s!["maKS"]!.GetValue<int>());
        var notMine = all.First(id => !mine.Contains(id));

        var r = (await c.GetAsync($"/api/customer/surveys/{notMine}")).Expect(HttpStatusCode.NotFound);
        Assert.Equal("52030", r.Code);
    }

    [Fact]
    public async Task Customer_profile_update_ignores_foreign_makh_in_body()
    {
        using var c = await factory.Crm().LoggedInAsync("kh.dung");
        var before = (await c.GetAsync("/api/customer/profile")).Expect(HttpStatusCode.OK)["hoSo"];
        await c.PutAsync("/api/customer/profile", new
        {
            maKH = 2, hoTen = before["hoTen"]!.GetValue<string>(), sdt = before["sdt"]!.GetValue<string>(),
            gioiTinh = before["gioiTinh"]?.GetValue<string>(), email = before["email"]?.GetValue<string>(),
            maTinh = before["maTinh"]?.GetValue<string>()
        });
        var after = (await c.GetAsync("/api/customer/profile")).Expect(HttpStatusCode.OK)["hoSo"];
        Assert.Equal(before["maKH"]!.GetValue<int>(), after["maKH"]!.GetValue<int>());

        using var binh = await factory.Crm().LoggedInAsync("kh.binh");
        Assert.Equal("Trần Văn Bình", (await binh.GetAsync("/api/customer/profile")).Expect(HttpStatusCode.OK)["hoSo"]["hoTen"]!.GetValue<string>());
    }

    /// <summary>IT-01: 200 request xen kẽ của 2 khách trên cùng pool kết nối không lẫn dữ liệu, không lỗi 50010.</summary>
    [Fact]
    public async Task Interleaved_requests_never_leak_session_context()
    {
        using var an = await factory.Crm().LoggedInAsync("kh.an");
        using var binh = await factory.Crm().LoggedInAsync("kh.binh");
        var anId = (await an.GetAsync("/api/customer/profile"))["hoSo"]["maKH"]!.GetValue<int>();
        var binhId = (await binh.GetAsync("/api/customer/profile"))["hoSo"]["maKH"]!.GetValue<int>();
        Assert.NotEqual(anId, binhId);

        var tasks = Enumerable.Range(0, 200).Select(async i =>
        {
            var (client, expected) = i % 2 == 0 ? (an, anId) : (binh, binhId);
            var r = (await client.GetAsync("/api/customer/profile")).Expect(HttpStatusCode.OK);
            return r["hoSo"]["maKH"]!.GetValue<int>() == expected;
        });
        var results = await Task.WhenAll(tasks);
        Assert.All(results, Assert.True);
    }

    [Fact]
    public async Task Locking_a_logged_in_customer_takes_effect_on_next_request()
    {
        using var ql = await factory.Crm().LoggedInAsync("ql.lan");
        var user = "kh.khoa." + TestData.Suffix();
        var created = (await ql.PostAsync("/api/manager/customers", new
        {
            hoTen = "Khách Sẽ Bị Khóa", sdt = TestData.Phone(), tenDangNhap = user
        })).Expect(HttpStatusCode.Created);
        var maKH = created["maKH"].GetValue<int>();
        var temp = created["matKhauTam"].GetValue<string>();

        using var kh = factory.Crm();
        var login = (await kh.LoginAsync(user, temp)).Expect(HttpStatusCode.OK);
        Assert.True(login["phaiDoiMatKhau"].GetValue<bool>());
        (await kh.PostAsync("/api/auth/change-password", new { matKhauCu = temp, matKhauMoi = "MatKhauMoi1" })).Expect(HttpStatusCode.OK);
        await kh.LoggedInAsync(user, "MatKhauMoi1");
        (await kh.GetAsync("/api/customer/profile")).Expect(HttpStatusCode.OK);

        (await ql.PatchAsync($"/api/manager/customers/{maKH}/lock", new { khoa = true, lyDo = "Kiểm thử khóa" })).Expect(HttpStatusCode.NoContent);
        (await kh.GetAsync("/api/customer/profile")).Expect(HttpStatusCode.Unauthorized);

        (await ql.PatchAsync($"/api/manager/customers/{maKH}/lock", new { khoa = false })).Expect(HttpStatusCode.NoContent);
    }
}
