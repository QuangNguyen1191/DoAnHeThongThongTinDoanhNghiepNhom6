namespace CrmUniqlo.Api.Errors;

/// <summary>
/// Ánh xạ mã lỗi CSDL → HTTP theo Bảng 13 của đặc tả Front-end (mục 5.5).
/// </summary>
public static class DbErrorMap
{
    public const string ThongBaoLoiHeThong = "Hệ thống đang gặp sự cố, vui lòng thử lại.";
    public const string ThongBaoKhongCoQuyen = "Bạn không có quyền thực hiện chức năng này.";
    public const string ThongBaoHetPhien = "Phiên đã hết hoặc tài khoản không còn hoạt động.";

    private static readonly HashSet<int> Unauthorized = [50001, 50012];
    private static readonly HashSet<int> Forbidden = [50003, 229, 33504, 50013];
    private static readonly HashSet<int> Conflict = [52002, 52003, 52004, 52072, 52081];
    private static readonly HashSet<int> NotFound = [52030, 52040, 52042, 52080, 52095];

    /// <summary>Các lỗi SQL Server từ chối quyền / RLS: cần ghi log cảnh báo bảo mật.</summary>
    public static bool IsSecurityAlert(int number) => number is 229 or 33504;

    public static int ToStatus(int number) => number switch
    {
        _ when Unauthorized.Contains(number) => StatusCodes.Status401Unauthorized,
        _ when Forbidden.Contains(number) => StatusCodes.Status403Forbidden,
        _ when Conflict.Contains(number) => StatusCodes.Status409Conflict,
        _ when NotFound.Contains(number) => StatusCodes.Status404NotFound,
        >= 51000 and < 53000 => StatusCodes.Status422UnprocessableEntity,
        _ => StatusCodes.Status500InternalServerError
    };

    /// <summary>Thông báo cho người dùng: lỗi nghiệp vụ giữ nguyên câu tiếng Việt của CSDL.</summary>
    public static string ToTitle(int number, string dbMessage, int status) => status switch
    {
        StatusCodes.Status500InternalServerError => ThongBaoLoiHeThong,
        StatusCodes.Status401Unauthorized => ThongBaoHetPhien,
        StatusCodes.Status403Forbidden when number is 229 or 33504 => ThongBaoKhongCoQuyen,
        _ => dbMessage
    };

    /// <summary>Trường bị lỗi (để giao diện hiển thị cạnh ô nhập) khi biết chắc.</summary>
    public static string? ToField(int number, string dbMessage) => number switch
    {
        52002 when dbMessage.Contains("email", StringComparison.OrdinalIgnoreCase)
                   && !dbMessage.Contains("Số điện thoại", StringComparison.OrdinalIgnoreCase) => "email",
        52002 => "sdt",
        52003 => "email",
        52004 => "tenDangNhap",
        52072 => "soHoaDon",
        52098 => "token",
        52081 when dbMessage.Contains("SKU", StringComparison.OrdinalIgnoreCase) => "maSKU",
        52081 when dbMessage.Contains("nhà cung cấp", StringComparison.OrdinalIgnoreCase) => "tenNCC",
        52081 when dbMessage.Contains("loại sản phẩm", StringComparison.OrdinalIgnoreCase) => "tenLoai",
        _ => null
    };
}
