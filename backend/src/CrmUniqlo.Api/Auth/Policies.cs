namespace CrmUniqlo.Api.Auth;

/// <summary>Chính sách phân quyền theo cổng (lớp 1 ở API; lớp 2–3 do CSDL kiểm).</summary>
public static class Policies
{
    public const string Admin = "Cong.ADMIN";
    public const string QuanLy = "Cong.QUAN_LY";
    public const string KhachHang = "Cong.KHACH_HANG";
}
