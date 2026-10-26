using System.Data;
using System.Data.Common;
using CrmUniqlo.Api.Auth;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace CrmUniqlo.Api.Data;

/// <summary>
/// Gọi thủ tục api_* bằng CommandType.StoredProcedure với tham số có kiểu (Dapper).
/// Mỗi lần gọi: mở kết nối cổng → DatNguCanh → 1 thủ tục → đọc mọi result set → đóng.
/// API không mở transaction bao nhiều thủ tục; transaction nằm trong thủ tục.
/// </summary>
public sealed class CrmDb
{
    private readonly SqlConnectionFactory _factory;
    private readonly CurrentUser _user;
    private readonly DatabaseOptions _options;

    public CrmDb(SqlConnectionFactory factory, CurrentUser user, IOptions<DatabaseOptions> options)
    {
        _factory = factory;
        _user = user;
        _options = options.Value;
    }

    /// <summary>Gọi thủ tục bằng cổng và tài khoản của phiên hiện tại.</summary>
    public Task<ProcResult> ExecAsync(string procedure, object? parameters = null, CancellationToken ct = default)
    {
        var (cong, maTK) = _user.Require();
        return ExecAsAsync(cong, maTK, procedure, parameters, ct);
    }

    /// <summary>Gọi thủ tục bằng cổng và tài khoản chỉ định.</summary>
    public async Task<ProcResult> ExecAsAsync(Cong cong, int maTK, string procedure, object? parameters, CancellationToken ct)
    {
        await using var conn = await _factory.OpenAsync(cong, maTK, ct);
        return await ExecOnAsync(conn, procedure, parameters, ct);
    }

    /// <summary>Gọi thủ tục trên kết nối chưa gắn tài khoản (đăng nhập, đăng ký).</summary>
    public async Task<ProcResult> ExecAnonymousAsync(Cong cong, string procedure, object? parameters, CancellationToken ct)
    {
        await using var conn = await _factory.OpenAnonymousAsync(cong, ct);
        return await ExecOnAsync(conn, procedure, parameters, ct);
    }

    /// <summary>Gọi thủ tục trên một kết nối đã mở (dùng khi nhiều bước phải cùng phiên, ví dụ đăng nhập).</summary>
    public async Task<ProcResult> ExecOnAsync(SqlConnection conn, string procedure, object? parameters, CancellationToken ct)
    {
        var command = new CommandDefinition(procedure, parameters, commandType: CommandType.StoredProcedure,
            commandTimeout: _options.CommandTimeoutSeconds, cancellationToken: ct);
        await using var reader = await conn.ExecuteReaderAsync(command);
        var sets = new List<IReadOnlyList<Row>>();
        do
        {
            if (reader.FieldCount == 0) continue;
            var rows = new List<Row>();
            while (await reader.ReadAsync(ct)) rows.Add(ReadRow(reader));
            sets.Add(rows);
        } while (await reader.NextResultAsync(ct));
        return new ProcResult(sets);
    }

    /// <summary>Đọc view api_chung (danh mục). Câu lệnh là hằng, liệt kê cột cụ thể, không ghép chuỗi.</summary>
    public async Task<IReadOnlyList<Row>> QueryViewAsync(string sql, CancellationToken ct)
    {
        await using var conn = await _factory.OpenAnonymousAsync(Cong.KhachHang, ct);
        var command = new CommandDefinition(sql, commandType: CommandType.Text,
            commandTimeout: _options.CommandTimeoutSeconds, cancellationToken: ct);
        await using var reader = await conn.ExecuteReaderAsync(command);
        var rows = new List<Row>();
        while (await reader.ReadAsync(ct)) rows.Add(ReadRow(reader));
        return rows;
    }

    private Row ReadRow(DbDataReader reader)
    {
        var row = new Row();
        for (var i = 0; i < reader.FieldCount; i++)
        {
            var name = reader.GetName(i);
            if (reader.IsDBNull(i))
            {
                row[name] = null;
                continue;
            }
            row[name] = reader.GetDataTypeName(i).ToLowerInvariant() switch
            {
                "date" => DateOnly.FromDateTime(reader.GetDateTime(i)),
                "datetime2" or "datetime" or "smalldatetime" =>
                    new DateTimeOffset(DateTime.SpecifyKind(reader.GetDateTime(i), DateTimeKind.Unspecified), _options.TimeZoneOffset),
                _ => reader.GetValue(i)
            };
        }
        return row;
    }

    /// <summary>Đổi thời điểm client gửi (có múi giờ) sang giờ máy chủ SQL.</summary>
    public DateTime? ToDbTime(DateTimeOffset? value) =>
        value?.ToOffset(_options.TimeZoneOffset).DateTime;

    public static DateTime? ToDbDate(DateOnly? value) => value?.ToDateTime(TimeOnly.MinValue);
}
