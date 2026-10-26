using CrmUniqlo.Api.Data;

namespace CrmUniqlo.Api.Auth;

/// <summary>Danh tính của request hiện tại, đọc từ cookie đã giải mã.</summary>
public sealed class CurrentUser
{
    private readonly IHttpContextAccessor _accessor;

    public CurrentUser(IHttpContextAccessor accessor) => _accessor = accessor;

    private System.Security.Claims.ClaimsPrincipal? Principal => _accessor.HttpContext?.User;

    public bool IsAuthenticated => Principal?.Identity?.IsAuthenticated == true;

    public int? MaTK => int.TryParse(Principal?.FindFirst(CrmClaims.MaTK)?.Value, out var v) ? v : null;

    public Cong? Cong => CongExtensions.TryParseDb(Principal?.FindFirst(CrmClaims.Cong)?.Value, out var c) ? c : null;

    public string? TenDangNhap => Principal?.FindFirst(CrmClaims.TenDangNhap)?.Value;

    public bool PhaiDoiMatKhau => Principal?.FindFirst(CrmClaims.PhaiDoiMatKhau)?.Value == "1";

    /// <summary>Cổng + MaTK của phiên; ném 401 nếu chưa đăng nhập.</summary>
    public (Cong Cong, int MaTK) Require()
    {
        if (Cong is { } cong && MaTK is { } maTK) return (cong, maTK);
        throw new Errors.ApiException(StatusCodes.Status401Unauthorized, "UNAUTHENTICATED", "Bạn chưa đăng nhập.");
    }
}
