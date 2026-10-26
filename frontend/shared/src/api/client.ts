import { ApiError, MSG_SERVER, type ProblemBody } from "./errors";

/**
 * API client chung cho cả 2 ứng dụng.
 * - Cookie phiên crm.auth là HttpOnly: JavaScript không đọc, trình duyệt tự gửi (cùng origin).
 * - Request ghi gửi header X-XSRF-TOKEN; token lấy từ GET /api/auth/antiforgery và được thay
 *   bằng token mới trong phản hồi đăng nhập / đăng ký / đổi mật khẩu.
 * - 401 / 428 được báo cho lớp xác thực qua onAuthEvent (chuyển /login, /change-password).
 */

type Method = "GET" | "POST" | "PUT" | "PATCH" | "DELETE";

export type AuthEvent =
  | { type: "unauthorized"; error: ApiError }
  | { type: "password-change-required"; error: ApiError }
  | { type: "activity" };

let xsrfToken: string | null = null;
let xsrfPromise: Promise<string> | null = null;
const listeners = new Set<(e: AuthEvent) => void>();

export function onAuthEvent(fn: (e: AuthEvent) => void) {
  listeners.add(fn);
  return () => void listeners.delete(fn);
}
function emit(e: AuthEvent) {
  listeners.forEach((fn) => fn(e));
}

export function setXsrfToken(token: string | null | undefined) {
  xsrfToken = token ?? null;
}

async function fetchXsrf(): Promise<string> {
  if (xsrfToken) return xsrfToken;
  xsrfPromise ??= (async () => {
    try {
      const res = await fetch("/api/auth/antiforgery", { credentials: "same-origin", cache: "no-store" });
      if (!res.ok) throw await toError(res);
      const body = (await res.json()) as { xsrfToken: string };
      xsrfToken = body.xsrfToken;
      return xsrfToken;
    } finally {
      xsrfPromise = null;
    }
  })();
  return xsrfPromise;
}

async function toError(res: Response): Promise<ApiError> {
  let body: Partial<ProblemBody> = {};
  try {
    body = await res.json();
  } catch {
    /* không phải JSON (proxy, máy chủ chưa chạy) */
  }
  const fallback = res.status >= 500 || res.status === 0 ? MSG_SERVER : `Yêu cầu không thành công (${res.status}).`;
  return new ApiError(res.status, body.code ?? `HTTP_${res.status}`, body.title || fallback, body);
}

export interface RequestOptions {
  body?: unknown;
  query?: Record<string, string | number | boolean | null | undefined>;
  signal?: AbortSignal;
  /** Không phát sự kiện 401/428 toàn cục (dùng cho login, me, logout: tự xử lý). */
  silentAuth?: boolean;
}

export async function request<T>(method: Method, path: string, opts: RequestOptions = {}, retried = false): Promise<T> {
  const unsafe = method !== "GET";
  const headers: Record<string, string> = { Accept: "application/json" };
  if (opts.body !== undefined) headers["Content-Type"] = "application/json";
  if (unsafe) headers["X-XSRF-TOKEN"] = await fetchXsrf();

  let url = path;
  if (opts.query) {
    const qs = new URLSearchParams();
    for (const [k, v] of Object.entries(opts.query)) if (v !== undefined && v !== null && v !== "") qs.set(k, String(v));
    const s = qs.toString();
    if (s) url += (url.includes("?") ? "&" : "?") + s;
  }

  let res: Response;
  try {
    res = await fetch(url, {
      method,
      headers,
      credentials: "same-origin",
      cache: "no-store",
      body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
      signal: opts.signal,
    });
  } catch (e) {
    if ((e as Error)?.name === "AbortError") throw e;
    throw new ApiError(0, "NETWORK", "Không kết nối được máy chủ.");
  }

  if (res.ok) {
    emit({ type: "activity" });
    if (res.status === 204) return undefined as T;
    const text = await res.text();
    const data = text ? JSON.parse(text) : undefined;
    // Phản hồi đăng nhập / đăng ký / đổi mật khẩu mang token CSRF mới gắn với phiên mới.
    if (data && typeof data === "object" && "xsrfToken" in data && data.xsrfToken) setXsrfToken(data.xsrfToken);
    return data as T;
  }

  const error = await toError(res);

  // Token CSRF cũ (vd. sau khi phiên đổi ở tab khác): lấy token mới và thử lại đúng 1 lần.
  if (res.status === 400 && error.code === "CSRF" && !retried) {
    setXsrfToken(null);
    return request<T>(method, path, opts, true);
  }

  if (!opts.silentAuth) {
    if (res.status === 401) {
      setXsrfToken(null);
      emit({ type: "unauthorized", error });
    } else if (res.status === 428) {
      emit({ type: "password-change-required", error });
    }
  }
  throw error;
}

export const api = {
  get: <T>(path: string, opts?: RequestOptions) => request<T>("GET", path, opts),
  post: <T>(path: string, body?: unknown, opts?: RequestOptions) => request<T>("POST", path, { ...opts, body }),
  put: <T>(path: string, body?: unknown, opts?: RequestOptions) => request<T>("PUT", path, { ...opts, body }),
  patch: <T>(path: string, body?: unknown, opts?: RequestOptions) => request<T>("PATCH", path, { ...opts, body }),
  delete: <T>(path: string, body?: unknown, opts?: RequestOptions) => request<T>("DELETE", path, { ...opts, body }),
};
