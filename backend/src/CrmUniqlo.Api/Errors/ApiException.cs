namespace CrmUniqlo.Api.Errors;

/// <summary>Lỗi nghiệp vụ do API tự phát hiện (không phải từ CSDL).</summary>
public sealed class ApiException : Exception
{
    public ApiException(int status, string code, string title, string? field = null) : base(title)
    {
        Status = status;
        Code = code;
        Field = field;
    }

    public int Status { get; }
    public string Code { get; }
    public string? Field { get; }

    public static ApiException NotFound(string title) => new(StatusCodes.Status404NotFound, "NOT_FOUND", title);
    public static ApiException Unprocessable(string code, string title, string? field = null) =>
        new(StatusCodes.Status422UnprocessableEntity, code, title, field);
}
