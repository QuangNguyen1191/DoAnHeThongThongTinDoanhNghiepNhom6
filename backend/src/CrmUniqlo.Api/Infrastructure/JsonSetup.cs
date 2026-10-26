using System.Text.Json;
using System.Text.Json.Serialization;

namespace CrmUniqlo.Api.Infrastructure;

/// <summary>
/// Quy ước JSON: khóa camelCase giữ nguyên tên cột CSDL (MaKH → maKH, SDT_Che → sdt_Che),
/// ngày "yyyy-MM-dd", thời điểm ISO 8601 kèm múi giờ (+07:00).
/// </summary>
public sealed class CrmNamingPolicy : JsonNamingPolicy
{
    public static readonly CrmNamingPolicy Instance = new();

    public override string ConvertName(string name)
    {
        if (string.IsNullOrEmpty(name) || !char.IsUpper(name[0])) return name;
        var upperRun = 0;
        while (upperRun < name.Length && char.IsUpper(name[upperRun])) upperRun++;
        // "HoTen" → "hoTen"; "SDT" → "sdt"; "SDT_Che" → "sdt_Che"; "URLPath" → "urlPath".
        var lowerCount = upperRun == name.Length || upperRun == 1 || !char.IsLower(name[upperRun])
            ? upperRun
            : upperRun - 1;
        return string.Concat(name[..lowerCount].ToLowerInvariant(), name.AsSpan(lowerCount));
    }
}

public static class JsonSetup
{
    public static void Apply(JsonSerializerOptions o)
    {
        o.PropertyNamingPolicy = CrmNamingPolicy.Instance;
        o.DictionaryKeyPolicy = CrmNamingPolicy.Instance;
        o.PropertyNameCaseInsensitive = true;
        o.DefaultIgnoreCondition = JsonIgnoreCondition.Never;
        o.NumberHandling = JsonNumberHandling.Strict;
    }
}
