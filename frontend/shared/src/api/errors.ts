/** Thân lỗi thống nhất của API (ProblemDetails, RFC 9457) – xem docs/02_DacTa_API.md mục 1.1. */
export interface ProblemBody {
  status: number;
  code: string | number;
  title: string;
  field?: string | null;
  traceId?: string;
  errors?: Record<string, string[]> | null;
}

export const MSG_NETWORK = "Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.";
export const MSG_SERVER = "Hệ thống đang gặp sự cố, vui lòng thử lại.";
export const MSG_FORBIDDEN = "Bạn không có quyền thực hiện chức năng này.";
export const MSG_SESSION_EXPIRED = "Phiên đã hết hoặc tài khoản không còn hoạt động. Vui lòng đăng nhập lại.";

export class ApiError extends Error {
  readonly status: number;
  readonly code: string | number;
  readonly field?: string;
  readonly errors?: Record<string, string[]>;
  readonly traceId?: string;

  constructor(status: number, code: string | number, message: string, extra: Partial<ProblemBody> = {}) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
    this.field = extra.field ?? undefined;
    this.errors = extra.errors ?? undefined;
    this.traceId = extra.traceId;
  }

  get isNetwork() {
    return this.status === 0;
  }
  get isUnauthorized() {
    return this.status === 401;
  }
  get isForbidden() {
    return this.status === 403;
  }

  /** Câu hiển thị cho người dùng; lỗi 500 không lộ chi tiết, chỉ kèm mã tra cứu. */
  get userMessage() {
    if (this.isNetwork) return MSG_NETWORK;
    if (this.status >= 500) return MSG_SERVER;
    return this.message;
  }
}

export function isApiError(e: unknown): e is ApiError {
  return e instanceof ApiError;
}

/** Lỗi theo từng trường (camelCase) để gắn vào form: ưu tiên `errors`, sau đó `field`. */
export function fieldErrors(e: ApiError): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(e.errors ?? {})) if (v?.[0]) out[k] = v[0];
  if (e.field && !out[e.field]) out[e.field] = e.message;
  return out;
}
