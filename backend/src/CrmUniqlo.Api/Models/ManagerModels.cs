using System.ComponentModel.DataAnnotations;

namespace CrmUniqlo.Api.Models;

public sealed class CustomerSearchQuery : PageQuery
{
    [StringLength(100)] public string? TuKhoa { get; set; }
    [StringLength(10)] public string? MaHang { get; set; }
    [StringLength(10)] public string? MaTinh { get; set; }
    [RegularExpression(Patterns.GioiTinh, ErrorMessage = Patterns.GioiTinhMessage)] public string? GioiTinh { get; set; }
    [Range(0, 150)] public int? TuoiTu { get; set; }
    [Range(0, 150)] public int? TuoiDen { get; set; }
    public int? MaLoaiQuanTam { get; set; }
    /// <summary>HOAT_DONG (mặc định) | DA_XOA.</summary>
    [RegularExpression("^(HOAT_DONG|DA_XOA)$", ErrorMessage = "Trạng thái hồ sơ là HOAT_DONG hoặc DA_XOA.")]
    public string TrangThaiHoSo { get; set; } = "HOAT_DONG";
    /// <summary>TEN | NGAY_DK_MOI | DIEM_CAO.</summary>
    [RegularExpression("^(TEN|NGAY_DK_MOI|DIEM_CAO)$", ErrorMessage = "Sắp xếp là TEN, NGAY_DK_MOI hoặc DIEM_CAO.")]
    public string SapXep { get; set; } = "TEN";
}

/// <summary>Thông tin hồ sơ khách hàng dùng chung cho thêm / sửa.</summary>
public class CustomerProfileInput
{
    [Required(ErrorMessage = "Họ tên là bắt buộc.")][StringLength(100, ErrorMessage = "Họ tên tối đa 100 ký tự.")]
    public string HoTen { get; set; } = "";

    [Required(ErrorMessage = "Số điện thoại là bắt buộc.")]
    [RegularExpression(Patterns.Sdt, ErrorMessage = Patterns.SdtMessage)]
    public string Sdt { get; set; } = "";

    [RegularExpression(Patterns.GioiTinh, ErrorMessage = Patterns.GioiTinhMessage)] public string? GioiTinh { get; set; }
    public DateOnly? NgaySinh { get; set; }
    [EmailAddress(ErrorMessage = "Email không hợp lệ.")][StringLength(100)] public string? Email { get; set; }
    [StringLength(10)] public string? MaTinh { get; set; }
    /// <summary>Mã loại sản phẩm quan tâm.</summary>
    public List<int>? DsLoaiQuanTam { get; set; }
}

public sealed class CreateCustomerRequest : CustomerProfileInput
{
    /// <summary>Nếu có: cấp luôn tài khoản với mật khẩu tạm (trả về 1 lần).</summary>
    [RegularExpression(Patterns.TenDangNhap, ErrorMessage = Patterns.TenDangNhapMessage)]
    public string? TenDangNhap { get; set; }
}

public sealed class UpdateCustomerRequest : CustomerProfileInput
{
    /// <summary>true: thay toàn bộ sở thích bằng dsLoaiQuanTam; false: giữ nguyên sở thích.</summary>
    public bool CapNhatSoThich { get; set; }
}

public sealed class GrantCustomerAccountRequest
{
    [Required(ErrorMessage = "Tên đăng nhập là bắt buộc.")]
    [RegularExpression(Patterns.TenDangNhap, ErrorMessage = Patterns.TenDangNhapMessage)]
    public string TenDangNhap { get; set; } = "";
}

public sealed class DeleteCustomerRequest
{
    [Required(ErrorMessage = "Cần nhập lý do xóa.")][StringLength(200, MinimumLength = 1)] public string LyDo { get; set; } = "";
}

public sealed class FeedbackQuery : PageQuery
{
    /// <summary>MOI | DANG_XU_LY | DA_XU_LY.</summary>
    [StringLength(10)] public string? TrangThai { get; set; }
    /// <summary>KHEN | GOP_Y | KHIEU_NAI.</summary>
    [StringLength(10)] public string? LoaiPH { get; set; }
    public int? MaSP { get; set; }
    public DateOnly? TuNgay { get; set; }
    public DateOnly? DenNgay { get; set; }
}

public sealed class AcceptFeedbackRequest
{
    /// <summary>Phân loại lại (tùy chọn): KHEN | GOP_Y | KHIEU_NAI.</summary>
    [RegularExpression("^(KHEN|GOP_Y|KHIEU_NAI)$", ErrorMessage = "Loại phản hồi là KHEN, GOP_Y hoặc KHIEU_NAI.")]
    public string? LoaiPH { get; set; }
}

public sealed class ReplyFeedbackRequest
{
    [Required(ErrorMessage = "Nội dung trả lời là bắt buộc.")][StringLength(2000)] public string NoiDungTraLoi { get; set; } = "";
}

public sealed class SurveyListQuery
{
    /// <summary>NHAP | DA_GUI | DA_DONG.</summary>
    [StringLength(8)] public string? TrangThai { get; set; }
    /// <summary>DO_HAI_LONG | THAM_DO_SP_MOI.</summary>
    [StringLength(15)] public string? MucDich { get; set; }
}

public sealed class CreateSurveyRequest
{
    [Required(ErrorMessage = "Tiêu đề là bắt buộc.")][StringLength(200)] public string TieuDe { get; set; } = "";

    [Required][RegularExpression("^(DO_HAI_LONG|THAM_DO_SP_MOI)$", ErrorMessage = "Mục đích là DO_HAI_LONG hoặc THAM_DO_SP_MOI.")]
    public string MucDich { get; set; } = "";

    [Required(ErrorMessage = "Hạn trả lời là bắt buộc.")] public DateTimeOffset? HanTraLoi { get; set; }
    [StringLength(1000)] public string? MoTa { get; set; }
    /// <summary>Bắt buộc với THAM_DO_SP_MOI (sản phẩm Sắp ra mắt).</summary>
    public int? MaSP { get; set; }
    /// <summary>0 = không tặng voucher; 1–50 = % giảm.</summary>
    [Range(0, 50, ErrorMessage = "Phần trăm voucher từ 0 đến 50.")] public byte PhanTramVoucher { get; set; }
    [Range(1, 365, ErrorMessage = "Số ngày hiệu lực voucher từ 1 đến 365.")] public short SoNgayHieuLucVoucher { get; set; } = 30;
}

public sealed class AddQuestionRequest
{
    [Required(ErrorMessage = "Nội dung câu hỏi là bắt buộc.")][StringLength(500)] public string NoiDung { get; set; } = "";

    [Required][RegularExpression("^(MOT_LUA_CHON|NHIEU_LUA_CHON|THANG_DIEM|TU_LUAN)$",
        ErrorMessage = "Loại câu hỏi là MOT_LUA_CHON, NHIEU_LUA_CHON, THANG_DIEM hoặc TU_LUAN.")]
    public string LoaiCauHoi { get; set; } = "";

    public bool BatBuoc { get; set; } = true;

    /// <summary>Nội dung các lựa chọn theo thứ tự (chỉ cho câu trắc nghiệm, ≥ 2).</summary>
    public List<string>? LuaChon { get; set; }
}

/// <summary>Tiêu chí chọn người nhận khảo sát (xem trước số người hoặc gửi thật).</summary>
public sealed class SendSurveyRequest
{
    [StringLength(10)] public string? MaHang { get; set; }
    [StringLength(10)] public string? MaTinh { get; set; }
    [RegularExpression(Patterns.GioiTinh, ErrorMessage = Patterns.GioiTinhMessage)] public string? GioiTinh { get; set; }
    [Range(0, 150)] public int? TuoiTu { get; set; }
    [Range(0, 150)] public int? TuoiDen { get; set; }
    public int? MaLoaiQuanTam { get; set; }
    public int? MaLoaiDaMua { get; set; }
    /// <summary>Gia hạn trả lời (khi hạn cũ đã qua).</summary>
    public DateTimeOffset? HanTraLoiMoi { get; set; }
}
