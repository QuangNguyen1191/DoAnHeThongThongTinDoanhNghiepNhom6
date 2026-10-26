namespace CrmUniqlo.Api.Auth;

/// <summary>Claim trong cookie crm.auth. Không chứa danh sách quyền: quyền luôn do CSDL kiểm.</summary>
public static class CrmClaims
{
    public const string MaTK = "maTK";
    public const string Cong = "cong";
    public const string TenDangNhap = "tenDangNhap";
    public const string PhaiDoiMatKhau = "phaiDoiMatKhau";
    /// <summary>Thời điểm đăng nhập (Unix giây) để giới hạn tuổi tối đa của phiên.</summary>
    public const string AuthTime = "authTime";
}
