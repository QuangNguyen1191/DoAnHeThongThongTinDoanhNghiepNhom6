using System.Net;
using System.Text.Json.Nodes;
using CrmUniqlo.Api.Tests.Infrastructure;

namespace CrmUniqlo.Api.Tests.Integration;

/// <summary>Cổng Quản lý: QL-1..QL-7 và luồng khảo sát end-to-end với khách hàng.</summary>
[Collection(ApiCollection.Name)]
[Trait("Category", "Integration")]
public sealed class ManagerTests(CrmApiFactory factory)
{
    [Fact]
    public async Task Search_customers_is_paged_and_sorted()
    {
        using var c = await factory.Crm().LoggedInAsync("ql.lan");
        var r = (await c.GetAsync("/api/manager/customers?sapXep=DIEM_CAO&soDong=3")).Expect(HttpStatusCode.OK);
        var items = r["items"].AsArray();
        Assert.InRange(items.Count, 1, 3);
        Assert.True(r["tongSoDong"].GetValue<int>() >= items.Count);
        var diem = items.Select(i => i!["diem"]!.GetValue<int>()).ToList();
        Assert.Equal(diem.OrderByDescending(x => x), diem);
        Assert.Null(items[0]!["tongSoDong"]);
    }

    [Fact]
    public async Task Invalid_sort_value_is_400()
    {
        using var c = await factory.Crm().LoggedInAsync("ql.lan");
        var r = (await c.GetAsync("/api/manager/customers?sapXep=DROP")).Expect(HttpStatusCode.BadRequest);
        Assert.Equal("sapXep", r["field"].GetValue<string>());
    }

    [Fact]
    public async Task Customer_360_profile_has_all_blocks_and_missing_is_404()
    {
        using var c = await factory.Crm().LoggedInAsync("ql.lan");
        var r = (await c.GetAsync("/api/manager/customers/1")).Expect(HttpStatusCode.OK);
        foreach (var key in new[] { "hoSo", "soThich", "hoaDon", "doiTra", "phanHoi", "khaoSat", "voucher", "lichSuHang" })
            Assert.NotNull(r.Json![key]);
        Assert.Matches(@"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?\+07:00$", r["hoSo"]["ngayDangKy"]!.GetValue<string>());

        (await c.GetAsync("/api/manager/customers/999999")).Expect(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Create_update_grant_delete_customer()
    {
        using var c = await factory.Crm().LoggedInAsync("ql.lan");
        var phone = TestData.Phone();
        var created = (await c.PostAsync("/api/manager/customers", new
        {
            hoTen = "Khách Tại Quầy", sdt = phone, gioiTinh = "NAM", ngaySinh = "1990-05-20", maTinh = "HCM",
            dsLoaiQuanTam = new[] { 1 }
        })).Expect(HttpStatusCode.Created);
        var maKH = created["maKH"].GetValue<int>();
        Assert.Null(created.Json!["matKhauTam"]);

        // Trùng SĐT với hồ sơ vừa tạo → 409.
        var dup = (await c.PostAsync("/api/manager/customers", new { hoTen = "Trùng", sdt = phone })).Expect(HttpStatusCode.Conflict);
        Assert.Equal("sdt", dup["field"].GetValue<string>());

        (await c.PutAsync($"/api/manager/customers/{maKH}", new
        {
            hoTen = "Khách Tại Quầy (sửa)", sdt = phone, gioiTinh = "NAM", email = $"k{phone}@example.com",
            capNhatSoThich = true, dsLoaiQuanTam = new[] { 1, 2 }
        })).Expect(HttpStatusCode.NoContent);
        var profile = (await c.GetAsync($"/api/manager/customers/{maKH}")).Expect(HttpStatusCode.OK);
        Assert.Equal("Khách Tại Quầy (sửa)", profile["hoSo"]["hoTen"]!.GetValue<string>());
        Assert.Equal(2, profile["soThich"].AsArray().Count);

        var user = "kh.quay." + TestData.Suffix();
        var account = (await c.PostAsync($"/api/manager/customers/{maKH}/account", new { tenDangNhap = user })).Expect(HttpStatusCode.Created);
        Assert.Equal(12, account["matKhauTam"].GetValue<string>().Length);

        // Không cấp tài khoản lần 2.
        (await c.PostAsync($"/api/manager/customers/{maKH}/account", new { tenDangNhap = user + "x" })).Expect(HttpStatusCode.UnprocessableEntity);

        // Xóa mềm cần lý do.
        (await c.DeleteAsync($"/api/manager/customers/{maKH}", new { lyDo = "" })).Expect(HttpStatusCode.BadRequest);
        (await c.DeleteAsync($"/api/manager/customers/{maKH}", new { lyDo = "Khách yêu cầu xóa" })).Expect(HttpStatusCode.NoContent);
        var deleted = (await c.GetAsync($"/api/manager/customers?trangThaiHoSo=DA_XOA&tuKhoa={phone}")).Expect(HttpStatusCode.OK);
        Assert.Contains(deleted["items"].AsArray(), i => i!["maKH"]!.GetValue<int>() == maKH);

        // Tài khoản của hồ sơ đã xóa không đăng nhập được.
        using var kh = factory.Crm();
        var login = await kh.LoginAsync(user, account["matKhauTam"].GetValue<string>());
        Assert.True(login.Status is HttpStatusCode.Forbidden or HttpStatusCode.Unauthorized, login.Body);
    }

    [Fact]
    public async Task Temporary_password_forces_change_with_428()
    {
        using var ql = await factory.Crm().LoggedInAsync("ql.lan");
        var user = "kh.tam." + TestData.Suffix();
        var created = (await ql.PostAsync("/api/manager/customers", new { hoTen = "Mật Khẩu Tạm", sdt = TestData.Phone(), tenDangNhap = user }))
            .Expect(HttpStatusCode.Created);
        var temp = created["matKhauTam"].GetValue<string>();

        using var kh = factory.Crm();
        Assert.True((await kh.LoginAsync(user, temp)).Expect(HttpStatusCode.OK)["phaiDoiMatKhau"].GetValue<bool>());
        var blocked = (await kh.GetAsync("/api/customer/profile")).Expect(HttpStatusCode.PreconditionRequired);
        Assert.Equal("PASSWORD_CHANGE_REQUIRED", blocked.Code);

        (await kh.PostAsync("/api/auth/change-password", new { matKhauCu = "sai-mat-khau", matKhauMoi = "MatKhauMoi9" }))
            .Expect(HttpStatusCode.UnprocessableEntity);
        var changed = (await kh.PostAsync("/api/auth/change-password", new { matKhauCu = temp, matKhauMoi = "MatKhauMoi9" }))
            .Expect(HttpStatusCode.OK);
        Assert.False(changed["phaiDoiMatKhau"].GetValue<bool>());
        (await kh.GetAsync("/api/customer/profile")).Expect(HttpStatusCode.OK);

        using var again = factory.Crm();
        (await again.LoginAsync(user, temp)).Expect(HttpStatusCode.Unauthorized);
        (await again.LoginAsync(user, "MatKhauMoi9")).Expect(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Feedback_flow_customer_to_manager()
    {
        using var kh = await factory.Crm().LoggedInAsync("kh.chau");
        var noiDung = "Phản hồi kiểm thử " + TestData.Suffix();
        var maSP = (await kh.GetAsync("/api/catalog/products")).Expect(HttpStatusCode.OK).Json!.AsArray()[0]!["maSP"]!.GetValue<int>();
        (await kh.PostAsync("/api/customer/feedback", new { loaiPH = "GOP_Y", diemDanhGia = 4, noiDung })).Expect(HttpStatusCode.BadRequest);
        var sent = (await kh.PostAsync("/api/customer/feedback", new { maSP, loaiPH = "GOP_Y", diemDanhGia = 4, noiDung }))
            .Expect(HttpStatusCode.Created);
        var maPH = sent["maPH"].GetValue<int>();

        using var ql = await factory.Crm().LoggedInAsync("cskh.hoa");
        var list = (await ql.GetAsync("/api/manager/feedback?trangThai=MOI&soDong=200")).Expect(HttpStatusCode.OK);
        Assert.Contains(list["items"].AsArray(), i => i!["maPH"]!.GetValue<int>() == maPH);

        (await ql.PostAsync($"/api/manager/feedback/{maPH}/accept", new { loaiPH = "KHIEU_NAI" })).Expect(HttpStatusCode.NoContent);
        (await ql.PostAsync($"/api/manager/feedback/{maPH}/accept", new { })).Expect(HttpStatusCode.UnprocessableEntity);
        (await ql.PostAsync($"/api/manager/feedback/{maPH}/reply", new { noiDungTraLoi = "Cảm ơn bạn đã góp ý." })).Expect(HttpStatusCode.NoContent);

        var mine = (await kh.GetAsync("/api/customer/feedback")).Expect(HttpStatusCode.OK).Json!.AsArray()
            .First(p => p!["maPH"]!.GetValue<int>() == maPH)!;
        Assert.Equal("Cảm ơn bạn đã góp ý.", mine["noiDungTraLoi"]!.GetValue<string>());
        Assert.Equal("KHIEU_NAI", mine["loaiPH"]!.GetValue<string>());
    }

    [Fact]
    public async Task Reports_return_all_sections_and_csv()
    {
        using var c = await factory.Crm().LoggedInAsync("ql.lan");
        var demo = (await c.GetAsync("/api/manager/reports/demographics")).Expect(HttpStatusCode.OK);
        foreach (var key in new[] { "nhomTuoi", "gioiTinh", "tinhThanh", "hang" }) Assert.NotNull(demo.Json![key]);
        var interests = (await c.GetAsync("/api/manager/reports/interests")).Expect(HttpStatusCode.OK);
        Assert.NotNull(interests.Json!["theoNhomTuoi"]);
        // Báo cáo hài lòng nằm ngoài 7 chức năng của Quản lý nên không còn endpoint.
        (await c.GetAsync("/api/manager/reports/satisfaction")).Expect(HttpStatusCode.NotFound);

        var csv = (await c.GetAsync("/api/manager/reports/demographics?format=csv&bang=hang")).Expect(HttpStatusCode.OK);
        Assert.Equal("text/csv", csv.ContentType);
        Assert.StartsWith("TenHang,SoKhach", csv.Body.TrimStart('﻿'));

        (await c.GetAsync("/api/manager/reports/demographics?format=csv&bang=khong-co")).Expect(HttpStatusCode.BadRequest);

        using var cskh = await factory.Crm().LoggedInAsync("cskh.hoa");
        (await cskh.GetAsync("/api/manager/reports/demographics")).Expect(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Dashboard_returns_blocks_and_hides_forbidden_ones()
    {
        using var ql = await factory.Crm().LoggedInAsync("ql.lan");
        var r = (await ql.GetAsync("/api/manager/dashboard")).Expect(HttpStatusCode.OK);
        Assert.NotNull(r.Json!["khachMoi"]);
        Assert.NotNull(r.Json!["theoHang"]);

        using var cskh = await factory.Crm().LoggedInAsync("cskh.hoa");
        var limited = (await cskh.GetAsync("/api/manager/dashboard")).Expect(HttpStatusCode.OK);
        Assert.Null(limited.Json!["theoHang"]);
        Assert.Equal("50003", limited.Json!["loi"]!["theoHang"]!["code"]!.ToJsonString());
    }

    [Fact]
    public async Task Survey_lifecycle_from_draft_to_stats_with_voucher()
    {
        using var ql = await factory.Crm().LoggedInAsync("ql.lan");
        var created = (await ql.PostAsync("/api/manager/surveys", new
        {
            tieuDe = "Khảo sát kiểm thử " + TestData.Suffix(), mucDich = "DO_HAI_LONG",
            hanTraLoi = DateTimeOffset.Now.AddDays(10), moTa = "Tạo bởi kiểm thử tự động", phanTramVoucher = 5, soNgayHieuLucVoucher = 15
        })).Expect(HttpStatusCode.Created);
        var maKS = created["maKS"].GetValue<int>();

        // Gửi khi chưa có câu hỏi → 422.
        (await ql.PostAsync($"/api/manager/surveys/{maKS}/send", new { maHang = "VIP" })).Expect(HttpStatusCode.UnprocessableEntity);

        var q1 = (await ql.PostAsync($"/api/manager/surveys/{maKS}/questions", new
        {
            noiDung = "Bạn hài lòng với cửa hàng?", loaiCauHoi = "MOT_LUA_CHON", batBuoc = true, luaChon = new[] { "Có", "Không" }
        })).Expect(HttpStatusCode.Created)["maCauHoi"].GetValue<int>();
        var q2 = (await ql.PostAsync($"/api/manager/surveys/{maKS}/questions", new
        {
            noiDung = "Chấm điểm chất lượng", loaiCauHoi = "THANG_DIEM", batBuoc = true
        })).Expect(HttpStatusCode.Created)["maCauHoi"].GetValue<int>();
        var q3 = (await ql.PostAsync($"/api/manager/surveys/{maKS}/questions", new
        {
            noiDung = "Góp ý thêm", loaiCauHoi = "TU_LUAN", batBuoc = false
        })).Expect(HttpStatusCode.Created)["maCauHoi"].GetValue<int>();
        var tam = (await ql.PostAsync($"/api/manager/surveys/{maKS}/questions", new
        {
            noiDung = "Câu sẽ xóa", loaiCauHoi = "TU_LUAN", batBuoc = false
        })).Expect(HttpStatusCode.Created)["maCauHoi"].GetValue<int>();
        (await ql.DeleteAsync($"/api/manager/questions/{tam}")).Expect(HttpStatusCode.NoContent);

        // Trắc nghiệm 1 lựa chọn → 422 (cần ≥ 2).
        (await ql.PostAsync($"/api/manager/surveys/{maKS}/questions", new
        {
            noiDung = "Sai", loaiCauHoi = "MOT_LUA_CHON", luaChon = new[] { "Một" }
        })).Expect(HttpStatusCode.UnprocessableEntity);

        var preview = (await ql.PostAsync($"/api/manager/surveys/{maKS}/send-preview", new { maHang = "VIP" })).Expect(HttpStatusCode.OK);
        var expected = preview["soNguoiNhanMoi"].GetValue<int>();
        Assert.True(expected >= 1);
        var sent = (await ql.PostAsync($"/api/manager/surveys/{maKS}/send", new { maHang = "VIP" })).Expect(HttpStatusCode.OK);
        Assert.Equal(expected, sent["soNguoiNhanMoi"].GetValue<int>());

        // Đã gửi thì không thêm câu hỏi được.
        (await ql.PostAsync($"/api/manager/surveys/{maKS}/questions", new { noiDung = "Muộn", loaiCauHoi = "TU_LUAN" }))
            .Expect(HttpStatusCode.UnprocessableEntity);

        using var kh = await factory.Crm().LoggedInAsync("kh.an");
        Assert.Contains((await kh.GetAsync("/api/customer/surveys")).Expect(HttpStatusCode.OK).Json!.AsArray(),
            s => s!["maKS"]!.GetValue<int>() == maKS);
        var detail = (await kh.GetAsync($"/api/customer/surveys/{maKS}")).Expect(HttpStatusCode.OK);
        var maLC = detail["luaChon"].AsArray().First(l => l!["maCauHoi"]!.GetValue<int>() == q1)!["maLC"]!.GetValue<int>();

        // Thiếu câu bắt buộc → 422 52032.
        var missing = (await kh.PostAsync($"/api/customer/surveys/{maKS}/submit", new
        {
            traLoi = new object[] { new { maCauHoi = q1, maLC } }
        })).Expect(HttpStatusCode.UnprocessableEntity);
        Assert.Equal("52032", missing.Code);

        var submit = (await kh.PostAsync($"/api/customer/surveys/{maKS}/submit", new
        {
            traLoi = new object[]
            {
                new { maCauHoi = q1, maLC }, new { maCauHoi = q2, diemSo = 4 }, new { maCauHoi = q3, noiDungTuLuan = "Rất tốt" }
            }
        })).Expect(HttpStatusCode.OK);
        Assert.True(submit["hoanThanh"].GetValue<bool>());
        Assert.Equal(5, submit["voucher"]["phanTramGiam"]!.GetValue<int>());
        var maCode = submit["voucher"]["maCode"]!.GetValue<string>();
        Assert.Contains((await kh.GetAsync("/api/customer/vouchers")).Json!.AsArray(), v => v!["maCode"]!.GetValue<string>() == maCode);

        // Nộp lần 2 → 422.
        (await kh.PostAsync($"/api/customer/surveys/{maKS}/submit", new
        {
            traLoi = new object[] { new { maCauHoi = q1, maLC }, new { maCauHoi = q2, diemSo = 5 } }
        })).Expect(HttpStatusCode.UnprocessableEntity);

        var stats = (await ql.GetAsync($"/api/manager/surveys/{maKS}/stats")).Expect(HttpStatusCode.OK);
        Assert.Equal(1, stats["tongQuan"]["soHoanThanh"]!.GetValue<int>());
        Assert.Contains(stats["tuLuan"].AsArray(), t => t!["noiDungTuLuan"]!.GetValue<string>() == "Rất tốt");

        (await ql.PostAsync($"/api/manager/surveys/{maKS}/close")).Expect(HttpStatusCode.NoContent);
        var closed = (await ql.GetAsync($"/api/manager/surveys/{maKS}")).Expect(HttpStatusCode.OK);
        Assert.Equal("DA_DONG", closed["khaoSat"]["trangThai"]!.GetValue<string>());
    }
}
