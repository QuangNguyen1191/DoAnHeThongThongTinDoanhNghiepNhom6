using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CrmUniqlo.Api.Data;

/// <summary>
/// Mở kết nối theo cổng và gắn ngữ cảnh phiên bằng sec.usp_DatNguCanh ngay sau khi mở,
/// trước mọi lệnh khác.
/// </summary>
public sealed class SqlConnectionFactory
{
    private readonly Dictionary<Cong, string> _connectionStrings;
    private readonly ILogger<SqlConnectionFactory> _logger;

    public SqlConnectionFactory(IConfiguration configuration, ILogger<SqlConnectionFactory> logger)
    {
        _logger = logger;
        _connectionStrings = new Dictionary<Cong, string>
        {
            [Cong.Admin] = Read(configuration, "CrmAdmin"),
            [Cong.QuanLy] = Read(configuration, "CrmQuanLy"),
            [Cong.KhachHang] = Read(configuration, "CrmKhachHang")
        };
    }

    private static string Read(IConfiguration configuration, string name)
    {
        var value = configuration.GetConnectionString(name);
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException(
                $"Thiếu chuỗi kết nối ConnectionStrings:{name}. Đặt bằng 'dotnet user-secrets set \"ConnectionStrings:{name}\" \"...\"' " +
                $"hoặc biến môi trường ConnectionStrings__{name}. Xem README.");
        }
        return value;
    }

    /// <summary>Mở kết nối của cổng, chưa gắn tài khoản (dùng cho đăng nhập, đăng ký, danh mục công khai).</summary>
    public async Task<SqlConnection> OpenAnonymousAsync(Cong cong, CancellationToken ct)
    {
        var conn = new SqlConnection(_connectionStrings[cong]);
        try
        {
            await conn.OpenAsync(ct);
            return conn;
        }
        catch
        {
            await conn.DisposeAsync();
            throw;
        }
    }

    /// <summary>
    /// Mở kết nối của cổng và gọi sec.usp_DatNguCanh @MaTK.
    /// Lỗi 50010 (phiên đã gắn tài khoản khác) → xóa pool, mở lại đúng 1 lần.
    /// </summary>
    public async Task<SqlConnection> OpenAsync(Cong cong, int maTK, CancellationToken ct)
    {
        for (var attempt = 1; ; attempt++)
        {
            var conn = await OpenAnonymousAsync(cong, ct);
            try
            {
                await conn.ExecuteAsync(new CommandDefinition(
                    "sec.usp_DatNguCanh", new { MaTK = maTK },
                    commandType: CommandType.StoredProcedure, cancellationToken: ct));
                return conn;
            }
            catch (SqlException ex) when (ex.Number == 50010 && attempt == 1)
            {
                _logger.LogWarning("Kết nối trong pool còn ngữ cảnh cũ (50010). Xóa pool và mở lại.");
                SqlConnection.ClearPool(conn);
                await conn.DisposeAsync();
            }
            catch
            {
                await conn.DisposeAsync();
                throw;
            }
        }
    }
}
