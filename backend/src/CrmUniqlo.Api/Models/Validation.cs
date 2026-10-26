namespace CrmUniqlo.Api.Models;

/// <summary>Biểu thức kiểm tra đầu vào dùng chung (khớp ràng buộc CHECK trong CSDL).</summary>
public static class Patterns
{
    /// <summary>4–50 ký tự, không khoảng trắng (CK_TAI_KHOAN_TenDangNhap).</summary>
    public const string TenDangNhap = @"^\S{4,50}$";
    public const string TenDangNhapMessage = "Tên đăng nhập 4–50 ký tự, không có khoảng trắng.";

    /// <summary>Đúng 10 chữ số, bắt đầu bằng 0.</summary>
    public const string Sdt = @"^0\d{9}$";
    public const string SdtMessage = "Số điện thoại gồm đúng 10 chữ số, bắt đầu bằng 0.";

    public const string GioiTinh = "^(NAM|NU|KHAC)$";
    public const string GioiTinhMessage = "Giới tính là NAM, NU hoặc KHAC.";

    public const string TrangThaiSP = "^(DANG_BAN|SAP_RA_MAT|NGUNG_BAN)$";
    public const string TrangThaiSPMessage = "Trạng thái sản phẩm là DANG_BAN, SAP_RA_MAT hoặc NGUNG_BAN.";

    public const string TrangThaiNCC = "^(DANG_HOP_TAC|NGUNG_HOP_TAC)$";
    public const string TrangThaiNCCMessage = "Trạng thái nhà cung cấp là DANG_HOP_TAC hoặc NGUNG_HOP_TAC.";

    public const string Required = "{0} là bắt buộc.";
    public const string MaxLength = "{0} tối đa {1} ký tự.";
}
