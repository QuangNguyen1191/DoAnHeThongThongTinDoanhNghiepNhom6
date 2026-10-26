using System.ComponentModel.DataAnnotations;

namespace CrmUniqlo.Api.Models;

public sealed class AccountQuery
{
    [StringLength(100)] public string? TuKhoa { get; set; }
    /// <summary>NV | KH.</summary>
    [RegularExpression("^(NV|KH)$", ErrorMessage = "Loại tài khoản là NV hoặc KH.")] public string? LoaiTK { get; set; }
    [StringLength(20)] public string? MaVT { get; set; }
    /// <summary>HOAT_DONG | DA_KHOA.</summary>
    [StringLength(10)] public string? TrangThai { get; set; }
}

public sealed class EmployeeQuery
{
    [StringLength(100)] public string? TuKhoa { get; set; }
    [StringLength(20)] public string? MaCV { get; set; }
    public int? MaCH { get; set; }
    [StringLength(10)] public string? TrangThai { get; set; }
}

public sealed class SaveEmployeeRequest
{
    [Required(ErrorMessage = "Họ tên là bắt buộc.")][StringLength(100, ErrorMessage = "Họ tên tối đa 100 ký tự.")]
    public string HoTen { get; set; } = "";

    [Required(ErrorMessage = "Cần chọn chức vụ.")][StringLength(20)] public string MaCV { get; set; } = "";

    [Required(ErrorMessage = "Số điện thoại là bắt buộc.")]
    [RegularExpression(Patterns.Sdt, ErrorMessage = Patterns.SdtMessage)]
    public string Sdt { get; set; } = "";

    [Required(ErrorMessage = "Email là bắt buộc.")]
    [RegularExpression(@"^\S+@\S+\.\S+$", ErrorMessage = "Email không hợp lệ.")]
    [StringLength(100, ErrorMessage = "Email tối đa 100 ký tự.")]
    public string Email { get; set; } = "";

    [Required(ErrorMessage = "Ngày vào làm là bắt buộc.")] public DateOnly? NgayVaoLam { get; set; }

    /// <summary>Cửa hàng làm việc; null = văn phòng.</summary>
    public int? MaCH { get; set; }

    /// <summary>DANG_LAM (mặc định) | DA_NGHI (tài khoản của nhân viên bị khóa theo).</summary>
    [RegularExpression("^(DANG_LAM|DA_NGHI)$", ErrorMessage = "Trạng thái là DANG_LAM hoặc DA_NGHI.")]
    public string TrangThai { get; set; } = "DANG_LAM";
}

public sealed class CreateStaffAccountRequest
{
    [Required(ErrorMessage = "Cần chọn nhân viên.")] public int? MaNV { get; set; }

    [Required(ErrorMessage = "Tên đăng nhập là bắt buộc.")]
    [RegularExpression(Patterns.TenDangNhap, ErrorMessage = Patterns.TenDangNhapMessage)]
    public string TenDangNhap { get; set; } = "";

    [Required(ErrorMessage = "Cần chọn vai trò.")][StringLength(20)] public string MaVT { get; set; } = "";
}

public sealed class ChangeRoleRequest
{
    [Required(ErrorMessage = "Cần chọn vai trò mới.")][StringLength(20)] public string MaVT { get; set; } = "";
}

public sealed class CreateRoleRequest
{
    [Required(ErrorMessage = "Mã vai trò là bắt buộc.")]
    [RegularExpression("^[A-Z0-9_]{2,20}$", ErrorMessage = "Mã vai trò 2–20 ký tự IN HOA, số hoặc gạch dưới.")]
    public string MaVT { get; set; } = "";

    [Required(ErrorMessage = "Tên vai trò là bắt buộc.")][StringLength(50)] public string TenVT { get; set; } = "";

    /// <summary>ADMIN | QUAN_LY.</summary>
    [Required][RegularExpression("^(ADMIN|QUAN_LY)$", ErrorMessage = "Cổng truy cập là ADMIN hoặc QUAN_LY.")]
    public string CongTruyCap { get; set; } = "";

    [StringLength(200)] public string? MoTa { get; set; }
}

public sealed class UpdatePermissionsRequest
{
    [Required(ErrorMessage = "Cần danh sách quyền (có thể rỗng).")]
    public List<string> DsQuyen { get; set; } = [];
}

public sealed class AuditLogQuery : LargePageQuery
{
    public DateOnly? TuNgay { get; set; }
    public DateOnly? DenNgay { get; set; }
    [StringLength(40)] public string? HanhDong { get; set; }
    public int? MaTK { get; set; }
}

public sealed class InvoiceQuery : LargePageQuery
{
    [StringLength(20)] public string? SoHoaDon { get; set; }
    public int? MaKH { get; set; }
    public DateOnly? TuNgay { get; set; }
    public DateOnly? DenNgay { get; set; }
}

public sealed class InvoiceLine
{
    [Required][StringLength(20)] public string MaSKU { get; set; } = "";
    [Range(1, int.MaxValue, ErrorMessage = "Số lượng phải > 0.")] public int SoLuong { get; set; }
    [Range(0, 999999999999.99, ErrorMessage = "Đơn giá không hợp lệ.")] public decimal DonGiaBan { get; set; }
}

public sealed class CreateInvoiceRequest
{
    [Required(ErrorMessage = "Số hóa đơn là bắt buộc.")][StringLength(20)] public string SoHoaDon { get; set; } = "";
    [Required(ErrorMessage = "Cần mã khách hàng.")] public int? MaKH { get; set; }
    /// <summary>CUA_HANG (bắt buộc maCH, maNV) | ONLINE (không có maCH, maNV).</summary>
    [Required][RegularExpression("^(CUA_HANG|ONLINE)$", ErrorMessage = "Kênh bán là CUA_HANG hoặc ONLINE.")] public string KenhBan { get; set; } = "";
    [Required(ErrorMessage = "Ngày lập là bắt buộc.")] public DateTimeOffset? NgayLap { get; set; }
    public int? MaCH { get; set; }
    public int? MaNV { get; set; }
    [StringLength(20)] public string? MaCodeVoucher { get; set; }
    [Required][MinLength(1, ErrorMessage = "Hóa đơn phải có ít nhất một dòng chi tiết.")]
    public List<InvoiceLine> ChiTiet { get; set; } = [];
}

public sealed class CreateReturnRequest
{
    [Required][StringLength(20)] public string SoHoaDon { get; set; } = "";
    [Required][StringLength(20)] public string MaSKU { get; set; } = "";
    [Range(1, int.MaxValue, ErrorMessage = "Số lượng phải > 0.")] public int SoLuong { get; set; }
    /// <summary>LOI_SP | KHONG_VUA | KHONG_UNG | KHAC.</summary>
    [Required][RegularExpression("^(LOI_SP|KHONG_VUA|KHONG_UNG|KHAC)$", ErrorMessage = "Lý do là LOI_SP, KHONG_VUA, KHONG_UNG hoặc KHAC.")] public string LyDo { get; set; } = "";
    [Required] public DateTimeOffset? NgayDoiTra { get; set; }
    [StringLength(300)] public string? GhiChu { get; set; }
}

public sealed class ProductQuery : PageQuery
{
    /// <summary>Tìm theo tên, mã SKU, chất liệu.</summary>
    [StringLength(100)] public string? TuKhoa { get; set; }
    public int? MaLoai { get; set; }
    public int? MaNCC { get; set; }
    [RegularExpression(Patterns.TrangThaiSP, ErrorMessage = Patterns.TrangThaiSPMessage)] public string? TrangThai { get; set; }
    [Range(0, 999_999_999_999.99, ErrorMessage = "Giá phải ≥ 0.")] public decimal? GiaTu { get; set; }
    [Range(0, 999_999_999_999.99, ErrorMessage = "Giá phải ≥ 0.")] public decimal? GiaDen { get; set; }
    /// <summary>TEN_TANG (mặc định) | TEN_GIAM | GIA_TANG | GIA_GIAM | MOI_NHAT.</summary>
    [RegularExpression("^(TEN_TANG|TEN_GIAM|GIA_TANG|GIA_GIAM|MOI_NHAT)$", ErrorMessage = "Sắp xếp là TEN_TANG, TEN_GIAM, GIA_TANG, GIA_GIAM hoặc MOI_NHAT.")]
    public string SapXep { get; set; } = "TEN_TANG";
}

public sealed class SaveProductRequest
{
    [Required(ErrorMessage = "Mã SKU là bắt buộc.")]
    [RegularExpression(@"^\S{1,20}$", ErrorMessage = "Mã SKU tối đa 20 ký tự, không có khoảng trắng.")]
    public string MaSKU { get; set; } = "";

    [Required(ErrorMessage = "Tên sản phẩm là bắt buộc.")][StringLength(150, ErrorMessage = "Tên sản phẩm tối đa 150 ký tự.")]
    public string TenSP { get; set; } = "";

    [Required(ErrorMessage = "Cần chọn loại sản phẩm.")] public int? MaLoai { get; set; }
    [Required(ErrorMessage = "Cần chọn nhà cung cấp.")] public int? MaNCC { get; set; }

    [Required(ErrorMessage = "Giá niêm yết là bắt buộc.")]
    [Range(0, 999_999_999_999.99, ErrorMessage = "Giá niêm yết phải ≥ 0.")]
    public decimal? GiaNiemYet { get; set; }

    /// <summary>DANG_BAN (mặc định) | SAP_RA_MAT (bắt buộc có ngày ra mắt) | NGUNG_BAN.</summary>
    [RegularExpression(Patterns.TrangThaiSP, ErrorMessage = Patterns.TrangThaiSPMessage)]
    public string TrangThai { get; set; } = "DANG_BAN";

    public DateOnly? NgayRaMat { get; set; }
    [StringLength(100, ErrorMessage = "Chất liệu tối đa 100 ký tự.")] public string? ChatLieu { get; set; }
    [StringLength(1000, ErrorMessage = "Mô tả tối đa 1000 ký tự.")] public string? MoTa { get; set; }
}

public sealed class SupplierQuery : PageQuery
{
    /// <summary>Tìm theo tên, email, SĐT.</summary>
    [StringLength(100)] public string? TuKhoa { get; set; }
    [StringLength(50)] public string? QuocGia { get; set; }
    [RegularExpression(Patterns.TrangThaiNCC, ErrorMessage = Patterns.TrangThaiNCCMessage)] public string? TrangThai { get; set; }
    /// <summary>TEN_TANG (mặc định) | TEN_GIAM | SO_SP_GIAM.</summary>
    [RegularExpression("^(TEN_TANG|TEN_GIAM|SO_SP_GIAM)$", ErrorMessage = "Sắp xếp là TEN_TANG, TEN_GIAM hoặc SO_SP_GIAM.")]
    public string SapXep { get; set; } = "TEN_TANG";
}

public sealed class SaveSupplierRequest
{
    [Required(ErrorMessage = "Tên nhà cung cấp là bắt buộc.")][StringLength(150, ErrorMessage = "Tên nhà cung cấp tối đa 150 ký tự.")]
    public string TenNCC { get; set; } = "";

    [StringLength(50, ErrorMessage = "Quốc gia tối đa 50 ký tự.")] public string? QuocGia { get; set; }
    [StringLength(200, ErrorMessage = "Địa chỉ tối đa 200 ký tự.")] public string? DiaChi { get; set; }

    [RegularExpression(@"^[0-9+ ]{1,20}$", ErrorMessage = "Số điện thoại chỉ gồm chữ số, dấu + và khoảng trắng (tối đa 20 ký tự).")]
    public string? Sdt { get; set; }

    [EmailAddress(ErrorMessage = "Email không hợp lệ.")]
    [RegularExpression(@"^\S+@\S+\.\S+$", ErrorMessage = "Email không hợp lệ.")]
    [StringLength(100, ErrorMessage = "Email tối đa 100 ký tự.")]
    public string? Email { get; set; }

    /// <summary>DANG_HOP_TAC (mặc định) | NGUNG_HOP_TAC.</summary>
    [RegularExpression(Patterns.TrangThaiNCC, ErrorMessage = Patterns.TrangThaiNCCMessage)]
    public string TrangThai { get; set; } = "DANG_HOP_TAC";
}

public sealed class SaveCategoryRequest
{
    [Required(ErrorMessage = "Tên loại sản phẩm là bắt buộc.")][StringLength(50, ErrorMessage = "Tên loại tối đa 50 ký tự.")]
    public string TenLoai { get; set; } = "";

    [StringLength(200, ErrorMessage = "Mô tả tối đa 200 ký tự.")] public string? MoTa { get; set; }
}
