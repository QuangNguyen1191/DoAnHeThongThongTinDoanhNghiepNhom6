using System.ComponentModel.DataAnnotations;

namespace CrmUniqlo.Api.Models;

/// <summary>Khách tự sửa hồ sơ. Không có MaKH: CSDL lấy MaKH từ ngữ cảnh phiên.</summary>
public sealed class UpdateMyProfileRequest : CustomerProfileInput
{
    public bool CapNhatSoThich { get; set; }
}

public sealed class SendFeedbackRequest
{
    /// <summary>Sản phẩm được phản hồi (lấy từ GET /api/catalog/products).</summary>
    [Required(ErrorMessage = "Cần chọn sản phẩm.")]
    public int? MaSP { get; set; }

    [Required][RegularExpression("^(KHEN|GOP_Y|KHIEU_NAI)$", ErrorMessage = "Loại phản hồi là KHEN, GOP_Y hoặc KHIEU_NAI.")]
    public string LoaiPH { get; set; } = "";

    [Required(ErrorMessage = "Cần chấm điểm 1–5.")][Range(1, 5, ErrorMessage = "Điểm đánh giá từ 1 đến 5.")]
    public byte? DiemDanhGia { get; set; }

    [Required(ErrorMessage = "Nội dung là bắt buộc.")][StringLength(2000, MinimumLength = 1)]
    public string NoiDung { get; set; } = "";
}

public sealed class SurveyAnswer
{
    [Required] public int? MaCauHoi { get; set; }
    /// <summary>Câu trắc nghiệm: mã lựa chọn (câu nhiều lựa chọn gửi nhiều dòng cùng maCauHoi).</summary>
    public int? MaLC { get; set; }
    /// <summary>Câu thang điểm: 1–5.</summary>
    [Range(1, 5, ErrorMessage = "Điểm từ 1 đến 5.")] public byte? DiemSo { get; set; }
    /// <summary>Câu tự luận.</summary>
    [StringLength(2000)] public string? NoiDungTuLuan { get; set; }
}

public sealed class SubmitSurveyRequest
{
    [Required(ErrorMessage = "Chưa có câu trả lời.")][MinLength(1, ErrorMessage = "Chưa có câu trả lời.")]
    public List<SurveyAnswer> TraLoi { get; set; } = [];
}

public sealed class PurchaseHistoryQuery
{
    /// <summary>Lọc theo ngày lập hóa đơn (bao gồm hai đầu), yyyy-MM-dd.</summary>
    public DateOnly? TuNgay { get; set; }
    public DateOnly? DenNgay { get; set; }
}
