namespace CrmUniqlo.Api.Data;

/// <summary>Một dòng kết quả: tên cột CSDL → giá trị (JSON hóa thành camelCase).</summary>
public sealed class Row : Dictionary<string, object?>
{
    public Row() : base(StringComparer.OrdinalIgnoreCase) { }

    public T? Get<T>(string column)
    {
        if (!TryGetValue(column, out var value) || value is null) return default;
        if (value is T typed) return typed;
        var target = Nullable.GetUnderlyingType(typeof(T)) ?? typeof(T);
        return (T)Convert.ChangeType(value, target, System.Globalization.CultureInfo.InvariantCulture);
    }
}

/// <summary>Toàn bộ các result set do một thủ tục trả về, theo đúng thứ tự.</summary>
public sealed class ProcResult
{
    public ProcResult(IReadOnlyList<IReadOnlyList<Row>> sets) => Sets = sets;

    public IReadOnlyList<IReadOnlyList<Row>> Sets { get; }

    public IReadOnlyList<Row> Rows(int index = 0) => index < Sets.Count ? Sets[index] : Array.Empty<Row>();

    public Row? First(int index = 0) => Rows(index).FirstOrDefault();
}

/// <summary>Kết quả phân trang. TongSoDong được tách khỏi từng dòng.</summary>
public sealed record PagedResult(IReadOnlyList<Row> Items, int Trang, int SoDong, int TongSoDong)
{
    public static PagedResult From(IReadOnlyList<Row> rows, int trang, int soDong)
    {
        var tong = rows.Count > 0 ? rows[0].Get<int>("TongSoDong") : 0;
        foreach (var row in rows) row.Remove("TongSoDong");
        return new PagedResult(rows, trang, soDong, tong);
    }
}
