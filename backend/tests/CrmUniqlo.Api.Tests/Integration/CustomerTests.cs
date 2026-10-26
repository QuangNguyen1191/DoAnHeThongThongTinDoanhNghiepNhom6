using System.Net;
using CrmUniqlo.Api.Tests.Infrastructure;

namespace CrmUniqlo.Api.Tests.Integration;

/// <summary>Cổng Khách hàng: lịch sử mua hàng.</summary>
[Collection(ApiCollection.Name)]
[Trait("Category", "Integration")]
public sealed class CustomerTests(CrmApiFactory factory)
{
    [Fact]
    public async Task Purchase_history_contains_only_my_invoices()
    {
        using var an = await factory.Crm().LoggedInAsync("kh.an");
        var r = (await an.GetAsync("/api/customer/purchases")).Expect(HttpStatusCode.OK);
        var hoaDon = r["hoaDon"].AsArray();
        Assert.NotEmpty(hoaDon);
        var mine = hoaDon.Select(h => h!["maHD"]!.GetValue<int>()).ToHashSet();
        Assert.All(r["chiTiet"].AsArray(), ct => Assert.Contains(ct!["maHD"]!.GetValue<int>(), mine));
        Assert.All(r["doiTra"].AsArray(), dt => Assert.Contains(dt!["maHD"]!.GetValue<int>(), mine));
        // Mới nhất trước.
        var dates = hoaDon.Select(h => DateTimeOffset.Parse(h!["ngayLap"]!.GetValue<string>())).ToList();
        Assert.Equal(dates.OrderByDescending(d => d), dates);

        using var binh = await factory.Crm().LoggedInAsync("kh.binh");
        var other = (await binh.GetAsync("/api/customer/purchases")).Expect(HttpStatusCode.OK)["hoaDon"].AsArray();
        Assert.DoesNotContain(other, h => mine.Contains(h!["maHD"]!.GetValue<int>()));
    }

    [Fact]
    public async Task Purchase_history_date_filter()
    {
        using var c = await factory.Crm().LoggedInAsync("kh.an");
        var future = (await c.GetAsync("/api/customer/purchases?tuNgay=2099-01-01")).Expect(HttpStatusCode.OK);
        Assert.Empty(future["hoaDon"].AsArray());
        Assert.Empty(future["chiTiet"].AsArray());

        var bad = (await c.GetAsync("/api/customer/purchases?tuNgay=2026-12-31&denNgay=2026-01-01"))
            .Expect(HttpStatusCode.UnprocessableEntity);
        Assert.Equal("52001", bad.Code);
    }

    [Fact]
    public async Task Staff_cannot_read_customer_purchase_history()
    {
        using var c = await factory.Crm().LoggedInAsync("ql.lan");
        (await c.GetAsync("/api/customer/purchases")).Expect(HttpStatusCode.Forbidden);
    }
}
