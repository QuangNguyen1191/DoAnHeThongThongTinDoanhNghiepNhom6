using System.Text;
using CrmUniqlo.Api.Data;
using Microsoft.AspNetCore.Mvc;

namespace CrmUniqlo.Api.Infrastructure;

/// <summary>Xuất một bảng kết quả ra CSV (UTF-8 có BOM để Excel đọc đúng tiếng Việt).</summary>
public static class Csv
{
    public static FileContentResult File(IReadOnlyList<Row> rows, string fileName)
    {
        var sb = new StringBuilder();
        if (rows.Count > 0)
        {
            var columns = rows[0].Keys.ToList();
            sb.AppendLine(string.Join(',', columns.Select(Escape)));
            foreach (var row in rows)
                sb.AppendLine(string.Join(',', columns.Select(c => Escape(Format(row.GetValueOrDefault(c))))));
        }
        var bytes = Encoding.UTF8.GetPreamble().Concat(Encoding.UTF8.GetBytes(sb.ToString())).ToArray();
        return new FileContentResult(bytes, "text/csv; charset=utf-8") { FileDownloadName = fileName };
    }

    private static string Format(object? value) => value switch
    {
        null => "",
        DateTimeOffset d => d.ToString("yyyy-MM-dd HH:mm:ss"),
        DateOnly d => d.ToString("yyyy-MM-dd"),
        IFormattable f => f.ToString(null, System.Globalization.CultureInfo.InvariantCulture),
        _ => value.ToString() ?? ""
    };

    private static string Escape(string value)
    {
        // Chống CSV injection khi mở bằng Excel.
        if (value.Length > 0 && "=+-@\t\r".Contains(value[0]) && !decimal.TryParse(value, System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture, out _))
            value = "'" + value;
        return value.IndexOfAny([',', '"', '\n', '\r']) >= 0 ? $"\"{value.Replace("\"", "\"\"")}\"" : value;
    }
}
