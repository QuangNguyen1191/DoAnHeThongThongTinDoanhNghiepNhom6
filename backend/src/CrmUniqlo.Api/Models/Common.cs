using System.ComponentModel.DataAnnotations;

namespace CrmUniqlo.Api.Models;

/// <summary>Tham số phân trang (?trang=1&amp;soDong=20). Giới hạn soDong theo từng thủ tục.</summary>
public class PageQuery
{
    [Range(1, int.MaxValue, ErrorMessage = "Trang phải ≥ 1.")]
    public int Trang { get; set; } = 1;

    [Range(1, 200, ErrorMessage = "Số dòng mỗi trang từ 1 đến 200.")]
    public int SoDong { get; set; } = 20;
}

/// <summary>Phân trang cho thủ tục cho phép tới 500 dòng (nhật ký, hóa đơn).</summary>
public class LargePageQuery
{
    [Range(1, int.MaxValue, ErrorMessage = "Trang phải ≥ 1.")]
    public int Trang { get; set; } = 1;

    [Range(1, 500, ErrorMessage = "Số dòng mỗi trang từ 1 đến 500.")]
    public int SoDong { get; set; } = 50;
}

public sealed class LockRequest
{
    /// <summary>true = khóa, false = mở khóa.</summary>
    [Required(ErrorMessage = "Cần chỉ rõ khóa hay mở khóa.")]
    public bool? Khoa { get; set; }

    [StringLength(200, ErrorMessage = "Lý do tối đa 200 ký tự.")]
    public string? LyDo { get; set; }
}
