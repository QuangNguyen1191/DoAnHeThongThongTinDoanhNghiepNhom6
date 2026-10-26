using System.Net;
using CrmUniqlo.Api.Tests.Infrastructure;

namespace CrmUniqlo.Api.Tests.Integration;

/// <summary>Cổng Admin: tài khoản, vai trò, nhật ký, nạp giao dịch, tình trạng hệ thống.</summary>
[Collection(ApiCollection.Name)]
[Trait("Category", "Integration")]
public sealed class AdminTests(CrmApiFactory factory)
{
    [Fact]
    public async Task Dashboard_system_and_audit_log()
    {
        using var c = await factory.Admin().LoggedInAsync("admin.it");
        var dash = (await c.GetAsync("/api/admin/dashboard?khoang=30")).Expect(HttpStatusCode.OK);
        Assert.True(dash["taiKhoan"]["tong"]!.GetValue<int>() > 0);

        var sys = (await c.GetAsync("/api/admin/system")).Expect(HttpStatusCode.OK);
        Assert.All(sys["ketNoi"].AsArray(), k => Assert.True(k!["ok"]!.GetValue<bool>()));

        var logs = (await c.GetAsync("/api/admin/audit-logs?hanhDong=DANG_NHAP&soDong=5")).Expect(HttpStatusCode.OK);
        Assert.Contains(logs["items"].AsArray(), l => l!["tenDangNhap"]?.GetValue<string>() == "admin.it");
        (await c.GetAsync("/api/admin/audit-logs?soDong=501")).Expect(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Staff_account_lifecycle()
    {
        using var c = await factory.Admin().LoggedInAsync("admin.it");
        var employees = (await c.GetAsync("/api/admin/employees?trangThai=DANG_LAM")).Expect(HttpStatusCode.OK).Json!.AsArray();
        var free = employees.FirstOrDefault(e => e!["maTK"] is null);
        Assert.True(free is not null, "Cần một nhân viên đang làm chưa có tài khoản (CSDL kiểm thử: chạy lại script 11).");
        var maNV = free!["maNV"]!.GetValue<int>();
        var user = "nv.test." + TestData.Suffix();

        var created = (await c.PostAsync("/api/admin/accounts", new { maNV, tenDangNhap = user, maVT = "NV_CSKH" }))
            .Expect(HttpStatusCode.Created);
        var maTK = created["maTK"].GetValue<int>();
        var temp = created["matKhauTam"].GetValue<string>();

        // Nhân viên đã có tài khoản → 422 (52093).
        var dup = (await c.PostAsync("/api/admin/accounts", new { maNV, tenDangNhap = user + "x", maVT = "NV_CSKH" }))
            .Expect(HttpStatusCode.UnprocessableEntity);
        Assert.Equal("52093", dup.Code);

        using (var nv = factory.Crm())
        {
            var login = (await nv.LoginAsync(user, temp)).Expect(HttpStatusCode.OK);
            Assert.Equal("QUAN_LY", login["cong"].GetValue<string>());
            Assert.True(login["phaiDoiMatKhau"].GetValue<bool>());
        }

        (await c.PutAsync($"/api/admin/accounts/{maTK}/role", new { maVT = "QUAN_LY" })).Expect(HttpStatusCode.NoContent);
        (await c.PatchAsync($"/api/admin/accounts/{maTK}/lock", new { khoa = true, lyDo = "Kiểm thử" })).Expect(HttpStatusCode.NoContent);
        using (var nv = factory.Crm()) (await nv.LoginAsync(user, temp)).Expect(HttpStatusCode.Forbidden);
        (await c.PatchAsync($"/api/admin/accounts/{maTK}/lock", new { khoa = false })).Expect(HttpStatusCode.NoContent);

        var reset = (await c.PostAsync($"/api/admin/accounts/{maTK}/reset-password")).Expect(HttpStatusCode.OK);
        using (var nv = factory.Crm()) (await nv.LoginAsync(user, reset["matKhauTam"].GetValue<string>())).Expect(HttpStatusCode.OK);

        (await c.DeleteAsync($"/api/admin/accounts/{maTK}")).Expect(HttpStatusCode.NoContent);
        (await c.DeleteAsync($"/api/admin/accounts/{maTK}")).Expect(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Employee_create_update_and_quit_locks_account()
    {
        using var c = await factory.Admin().LoggedInAsync("admin.it");
        var suffix = TestData.Suffix();
        var body = new
        {
            hoTen = "Nhân Viên KT " + suffix, maCV = "NV_CSKH", sdt = TestData.Phone(), email = $"nv.{suffix}@nv.example.com",
            ngayVaoLam = DateOnly.FromDateTime(DateTime.Today.AddDays(-10)), maCH = 1, trangThai = "DANG_LAM"
        };
        var maNV = (await c.PostAsync("/api/admin/employees", body)).Expect(HttpStatusCode.Created)["maNV"].GetValue<int>();

        // SĐT/email trùng → 409 (52081); SĐT sai định dạng → 400.
        (await c.PostAsync("/api/admin/employees", body with { })).Expect(HttpStatusCode.Conflict);
        (await c.PostAsync("/api/admin/employees", new { body.hoTen, body.maCV, sdt = "12345", email = "a@b.vn", body.ngayVaoLam }))
            .Expect(HttpStatusCode.BadRequest);

        var user = "nv.kt." + suffix;
        var maTK = (await c.PostAsync("/api/admin/accounts", new { maNV, tenDangNhap = user, maVT = "NV_CSKH" }))
            .Expect(HttpStatusCode.Created)["maTK"].GetValue<int>();

        (await c.PutAsync($"/api/admin/employees/{maNV}", new
        {
            body.hoTen, body.maCV, body.sdt, body.email, body.ngayVaoLam, maCH = (int?)null, trangThai = "DA_NGHI"
        })).Expect(HttpStatusCode.OK);
        var accounts = (await c.GetAsync($"/api/admin/accounts?tuKhoa={user}")).Expect(HttpStatusCode.OK).Json!.AsArray();
        Assert.Equal("DA_KHOA", accounts.Single(a => a!["maTK"]!.GetValue<int>() == maTK)!["trangThai"]!.GetValue<string>());

        (await c.PutAsync("/api/admin/employees/999999", body)).Expect(HttpStatusCode.NotFound);

        // QTV tài khoản không có quyền danh mục (AD_DANH_MUC).
        using var mai = await factory.Admin().LoggedInAsync("it.mai");
        (await mai.PostAsync("/api/admin/employees", body)).Expect(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Admin_cannot_lock_or_delete_self()
    {
        using var c = await factory.Admin().LoggedInAsync("admin.it");
        var me = (await c.GetAsync("/api/auth/me")).Expect(HttpStatusCode.OK)["maTK"].GetValue<int>();
        (await c.PatchAsync($"/api/admin/accounts/{me}/lock", new { khoa = true, lyDo = "x" })).Expect(HttpStatusCode.UnprocessableEntity);
        (await c.DeleteAsync($"/api/admin/accounts/{me}")).Expect(HttpStatusCode.UnprocessableEntity);
    }

    [Fact]
    public async Task Roles_create_and_update_permissions()
    {
        using var c = await factory.Admin().LoggedInAsync("admin.it");
        var maVT = "KT_" + TestData.Suffix().ToUpperInvariant()[..6];
        (await c.PostAsync("/api/admin/roles", new { maVT, tenVT = "Vai trò kiểm thử " + maVT, congTruyCap = "QUAN_LY", moTa = "Tạo bởi kiểm thử" }))
            .Expect(HttpStatusCode.Created);
        (await c.PutAsync($"/api/admin/roles/{maVT}/permissions", new { dsQuyen = new[] { "QL_KH_XEM", "QL_PH_XEM" } }))
            .Expect(HttpStatusCode.NoContent);
        var roles = (await c.GetAsync($"/api/admin/roles?maVT={maVT}")).Expect(HttpStatusCode.OK);
        var granted = roles["quyen"].AsArray().Where(q => q!["duocCap"]!.GetValue<bool>()).Select(q => q!["maQuyen"]!.GetValue<string>()).ToList();
        Assert.Equal(new[] { "QL_KH_XEM", "QL_PH_XEM" }, granted.Order());

        // Quyền của cổng khác → 422 (52097).
        var wrong = (await c.PutAsync($"/api/admin/roles/{maVT}/permissions", new { dsQuyen = new[] { "AD_TAI_KHOAN" } }))
            .Expect(HttpStatusCode.UnprocessableEntity);
        Assert.Equal("52097", wrong.Code);
    }

    [Fact]
    public async Task Customer_lookup_masks_contact_data()
    {
        using var c = await factory.Admin().LoggedInAsync("admin.it");
        var rows = (await c.GetAsync("/api/admin/customers?tuKhoa=An")).Expect(HttpStatusCode.OK).Json!.AsArray();
        Assert.NotEmpty(rows);
        Assert.All(rows, r => Assert.Contains("x", r!["sdt_Che"]!.GetValue<string>()));
        Assert.DoesNotContain(rows, r => r!["sdt"] is not null);
    }

    [Fact]
    public async Task Invoice_import_adds_points_and_rejects_duplicates()
    {
        using var ql = await factory.Crm().LoggedInAsync("ql.lan");
        var maKH = (await ql.PostAsync("/api/manager/customers", new { hoTen = "Khách Mua Online", sdt = TestData.Phone() }))
            .Expect(HttpStatusCode.Created)["maKH"].GetValue<int>();

        using var c = await factory.Admin().LoggedInAsync("admin.it");
        var sku = (await c.GetAsync("/api/catalog/products")).Expect(HttpStatusCode.OK).Json!.AsArray()
            .First(p => p!["trangThai"]!.GetValue<string>() == "DANG_BAN")!["maSKU"]!.GetValue<string>();
        var soHoaDon = "KT" + TestData.Suffix().ToUpperInvariant();

        var invoice = (await c.PostAsync("/api/admin/invoices", new
        {
            soHoaDon, maKH, kenhBan = "ONLINE", ngayLap = DateTimeOffset.Now.AddDays(-2),
            chiTiet = new[] { new { maSKU = sku, soLuong = 2, donGiaBan = 299000m } }
        })).Expect(HttpStatusCode.Created);
        Assert.Equal(598000m, invoice["tongTienHang"].GetValue<decimal>());

        var dup = (await c.PostAsync("/api/admin/invoices", new
        {
            soHoaDon, maKH, kenhBan = "ONLINE", ngayLap = DateTimeOffset.Now.AddDays(-2),
            chiTiet = new[] { new { maSKU = sku, soLuong = 1, donGiaBan = 1000m } }
        })).Expect(HttpStatusCode.Conflict);
        Assert.Equal("soHoaDon", dup["field"].GetValue<string>());

        var detail = (await c.GetAsync($"/api/admin/invoices/{soHoaDon}")).Expect(HttpStatusCode.OK);
        Assert.Single(detail["chiTiet"].AsArray());

        var profile = (await ql.GetAsync($"/api/manager/customers/{maKH}")).Expect(HttpStatusCode.OK);
        Assert.True(profile["hoSo"]["diem"]!.GetValue<int>() > 0);

        (await c.PostAsync("/api/admin/returns", new
        {
            soHoaDon, maSKU = sku, soLuong = 1, lyDo = "KHONG_VUA", ngayDoiTra = DateTimeOffset.Now.AddDays(-1), ghiChu = "Kiểm thử"
        })).Expect(HttpStatusCode.Created);

        (await c.PostAsync("/api/admin/tiers/recalculate")).Expect(HttpStatusCode.OK);

        // QTV tài khoản không có quyền nạp giao dịch.
        using var mai = await factory.Admin().LoggedInAsync("it.mai");
        (await mai.PostAsync("/api/admin/tiers/recalculate")).Expect(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Catalog_category_supplier_product()
    {
        using var c = await factory.Admin().LoggedInAsync("admin.it");
        var suffix = TestData.Suffix();

        var lookups = (await c.GetAsync("/api/admin/lookups")).Expect(HttpStatusCode.OK);
        Assert.NotEmpty(lookups["loaiSP"].AsArray());
        Assert.NotEmpty(lookups["tinhThanh"].AsArray());

        var maLoai = (await c.PostAsync("/api/admin/categories", new { tenLoai = "Loại KT " + suffix }))
            .Expect(HttpStatusCode.Created)["maLoai"].GetValue<int>();
        (await c.PutAsync($"/api/admin/categories/{maLoai}", new { tenLoai = "Loại KT " + suffix, moTa = "Đã sửa" }))
            .Expect(HttpStatusCode.OK);
        var dupLoai = (await c.PostAsync("/api/admin/categories", new { tenLoai = "Loại KT " + suffix }))
            .Expect(HttpStatusCode.Conflict);
        Assert.Equal("tenLoai", dupLoai["field"].GetValue<string>());

        var maNCC = (await c.PostAsync("/api/admin/suppliers", new
        {
            tenNCC = "NCC KT " + suffix, quocGia = "Việt Nam", sdt = "+84 28 3800 0000", email = $"ncc.{suffix}@example.com"
        })).Expect(HttpStatusCode.Created)["maNCC"].GetValue<int>();
        var ncc = (await c.GetAsync($"/api/admin/suppliers/{maNCC}")).Expect(HttpStatusCode.OK);
        Assert.Equal("DANG_HOP_TAC", ncc["trangThai"].GetValue<string>());
        Assert.Null(ncc.Json!["tongSoDong"]);
        (await c.PostAsync("/api/admin/suppliers", new { tenNCC = "NCC sai", email = "khong-phai-email" })).Expect(HttpStatusCode.BadRequest);

        var sku = "KT-" + suffix[..6].ToUpperInvariant();
        var noDate = (await c.PostAsync("/api/admin/products", new
        {
            maSKU = sku, tenSP = "SP KT", maLoai, maNCC, giaNiemYet = 199000m, trangThai = "SAP_RA_MAT"
        })).Expect(HttpStatusCode.UnprocessableEntity);
        Assert.Equal("ngayRaMat", noDate["field"].GetValue<string>());

        var maSP = (await c.PostAsync("/api/admin/products", new
        {
            maSKU = sku, tenSP = "SP KT " + suffix, maLoai, maNCC, giaNiemYet = 199000m, chatLieu = "Cotton"
        })).Expect(HttpStatusCode.Created)["maSP"].GetValue<int>();
        var dupSku = (await c.PostAsync("/api/admin/products", new { maSKU = sku, tenSP = "Trùng", maLoai, maNCC, giaNiemYet = 1m }))
            .Expect(HttpStatusCode.Conflict);
        Assert.Equal("maSKU", dupSku["field"].GetValue<string>());

        (await c.PutAsync($"/api/admin/products/{maSP}", new
        {
            maSKU = sku, tenSP = "SP KT " + suffix, maLoai, maNCC, giaNiemYet = 159000m, trangThai = "NGUNG_BAN"
        })).Expect(HttpStatusCode.OK);
        var sp = (await c.GetAsync($"/api/admin/products/{maSP}")).Expect(HttpStatusCode.OK);
        Assert.Equal(159000m, sp["giaNiemYet"].GetValue<decimal>());
        Assert.Equal("NGUNG_BAN", sp["trangThai"].GetValue<string>());

        var found = (await c.GetAsync($"/api/admin/products?tuKhoa={sku}&maNCC={maNCC}")).Expect(HttpStatusCode.OK);
        Assert.Equal(1, found["tongSoDong"].GetValue<int>());
        var bySupplier = (await c.GetAsync($"/api/admin/suppliers?tuKhoa=NCC KT {suffix}")).Expect(HttpStatusCode.OK);
        Assert.Equal(1, bySupplier["items"][0]!["soSanPham"]!.GetValue<int>());

        (await c.PutAsync("/api/admin/products/999999", new { maSKU = "KT-X", tenSP = "X", maLoai, maNCC, giaNiemYet = 1m }))
            .Expect(HttpStatusCode.NotFound);
        (await c.GetAsync("/api/admin/products/999999")).Expect(HttpStatusCode.NotFound);
        (await c.GetAsync("/api/admin/products?sapXep=XYZ")).Expect(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Catalog_read_only_for_account_admin_and_hidden_on_crm_port()
    {
        using var mai = await factory.Admin().LoggedInAsync("it.mai");
        (await mai.GetAsync("/api/admin/products")).Expect(HttpStatusCode.OK);
        (await mai.GetAsync("/api/admin/suppliers")).Expect(HttpStatusCode.OK);
        var denied = (await mai.PostAsync("/api/admin/categories", new { tenLoai = "Không được tạo" })).Expect(HttpStatusCode.Forbidden);
        Assert.Equal("50003", denied.Code);

        using var crm = await factory.Crm().LoggedInAsync("ql.lan");
        (await crm.GetAsync("/api/admin/products")).Expect(HttpStatusCode.NotFound);
    }
}
