namespace CrmUniqlo.Api.Data;

/// <summary>Cổng truy cập. Mỗi cổng dùng một login SQL riêng (crm_app_*).</summary>
public enum Cong
{
    KhachHang,
    QuanLy,
    Admin
}

public static class CongExtensions
{
    public const string AdminDb = "ADMIN";
    public const string QuanLyDb = "QUAN_LY";
    public const string KhachHangDb = "KHACH_HANG";

    /// <summary>Giá trị cột VAI_TRO.CongTruyCap tương ứng.</summary>
    public static string ToDb(this Cong cong) => cong switch
    {
        Cong.Admin => AdminDb,
        Cong.QuanLy => QuanLyDb,
        Cong.KhachHang => KhachHangDb,
        _ => throw new ArgumentOutOfRangeException(nameof(cong))
    };

    public static bool TryParseDb(string? value, out Cong cong)
    {
        switch (value)
        {
            case AdminDb: cong = Cong.Admin; return true;
            case QuanLyDb: cong = Cong.QuanLy; return true;
            case KhachHangDb: cong = Cong.KhachHang; return true;
            default: cong = default; return false;
        }
    }
}
