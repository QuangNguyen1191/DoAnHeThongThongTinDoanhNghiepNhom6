import { createContext, useCallback, useContext, useEffect, useMemo, useRef, type ReactNode } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useLocation, useNavigate } from "react-router";
import { api, onAuthEvent, setXsrfToken } from "../api/client";
import { isApiError } from "../api/errors";
import { sessionClock } from "./sessionClock";
import type { Session } from "./types";

export type AppKind = "crm" | "admin";
export const SESSION_KEY = ["auth", "session"] as const;

export interface RegisterInput {
  tenDangNhap: string;
  matKhau: string;
  hoTen: string;
  sdt: string;
  gioiTinh?: "NAM" | "NU" | "KHAC" | null;
  ngaySinh?: string | null;
  email?: string | null;
  maTinh?: string | null;
  dsLoaiQuanTam?: number[];
}

interface AuthContextValue {
  app: AppKind;
  session: Session | null;
  status: "loading" | "authenticated" | "anonymous" | "error";
  /** Lỗi khi tải phiên (mất mạng, máy chủ lỗi) – khác với chưa đăng nhập. */
  error: unknown;
  login: (tenDangNhap: string, matKhau: string) => Promise<Session>;
  register: (input: RegisterInput) => Promise<Session>;
  changePassword: (matKhauCu: string, matKhauMoi: string) => Promise<Session>;
  logout: () => Promise<void>;
  /** Hết phiên (401 từ API hoặc không thao tác quá lâu): xóa dữ liệu, về trang đăng nhập. */
  expire: () => Promise<void>;
  refresh: () => Promise<Session | null>;
  /** Đang rời ứng dụng sau đăng xuất/hết phiên (web-admin chuyển sang /login của web-crm). */
}

const AuthContext = createContext<AuthContextValue | null>(null);

/** GET /api/auth/me – 401 nghĩa là chưa đăng nhập (không phải lỗi). */
async function fetchSession(): Promise<Session | null> {
  try {
    return await api.get<Session>("/api/auth/me", { silentAuth: true });
  } catch (e) {
    if (isApiError(e) && e.status === 401) return null;
    throw e;
  }
}

/** Báo cho các tab khác của cùng ứng dụng khi đăng nhập/đăng xuất. */
const channel = typeof BroadcastChannel !== "undefined" ? new BroadcastChannel("crm-auth") : null;
type Broadcast = { type: "logout" } | { type: "login"; maTK: number };

export function AuthProvider({ app, children }: { app: AppKind; children: ReactNode }) {
  const qc = useQueryClient();
  const navigate = useNavigate();
  const location = useLocation();
  const locationRef = useRef(location);
  locationRef.current = location;

  /** Ứng dụng này có quản lý phiên của tài khoản không (web-admin: ADMIN; web-crm: QUAN_LY, KHACH_HANG). */
  const owns = useCallback((s: Session) => (app === "admin") === (s.cong === "ADMIN"), [app]);

  const expireRef = useRef<() => void>(() => {});
  const query = useQuery({
    queryKey: SESSION_KEY,
    queryFn: async () => {
      const prev = qc.getQueryData<Session | null>(SESSION_KEY);
      const s = await fetchSession();
      if (s && owns(s)) sessionClock.activity();
      // Đang có phiên mà /me trả 401 (hết hạn, bị khóa giữa chừng): xử lý như hết phiên.
      // Lần tải trang đầu: còn mốc phiên trong localStorage nghĩa là trước đó đã đăng nhập.
      if (!s && (prev || sessionClock.expiresAt())) queueMicrotask(() => expireRef.current());
      return s;
    },
    staleTime: 60_000, // đặc tả L6: cache 60 giây
    refetchOnWindowFocus: true,
    retry: (count, e) => !(isApiError(e) && e.status < 500) && count < 2,
  });

  const session = query.data ?? null;
  const status: AuthContextValue["status"] = query.isPending
    ? "loading"
    : session
      ? "authenticated"
      : query.isError
        ? "error"
        : "anonymous";

  /** Xóa toàn bộ dữ liệu đã tải (để nút Back không hiện lại dữ liệu cũ) và đặt phiên = null. */
  const wipe = useCallback(() => {
    setXsrfToken(null);
    sessionClock.clear();
    qc.cancelQueries();
    qc.removeQueries({ predicate: (q) => q.queryKey[0] !== SESSION_KEY[0] });
    qc.setQueryData(SESSION_KEY, null);
  }, [qc]);

  const toLogin = useCallback(
    (params: Record<string, string>) => {
      // Mỗi ứng dụng có trang đăng nhập riêng: web-crm cho Khách hàng/Quản lý, web-admin chỉ cho Admin.
      navigate(`/login?${new URLSearchParams(params)}`, { replace: true });
    },
    [navigate],
  );

  const currentPath = () => {
    const l = locationRef.current;
    return l.pathname + l.search;
  };

  const startSession = useCallback(
    (s: Session) => {
      if (owns(s)) sessionClock.started();
      else sessionClock.clear();
      qc.removeQueries({ predicate: (q) => q.queryKey[0] !== SESSION_KEY[0] });
      qc.setQueryData(SESSION_KEY, s);
      channel?.postMessage({ type: "login", maTK: s.maTK } satisfies Broadcast);
      return s;
    },
    [qc, owns],
  );

  const login = useCallback(
    async (tenDangNhap: string, matKhau: string) =>
      startSession(await api.post<Session>("/api/auth/login", { tenDangNhap, matKhau }, { silentAuth: true })),
    [startSession],
  );

  const register = useCallback(
    async (input: RegisterInput) => startSession(await api.post<Session>("/api/auth/register", input, { silentAuth: true })),
    [startSession],
  );

  const changePassword = useCallback(
    async (matKhauCu: string, matKhauMoi: string) =>
      startSession(await api.post<Session>("/api/auth/change-password", { matKhauCu, matKhauMoi })),
    [startSession],
  );

  const logout = useCallback(async () => {
    try {
      await api.post("/api/auth/logout", undefined, { silentAuth: true });
    } catch {
      /* mất mạng: vẫn xóa phía giao diện; cookie sẽ tự hết hạn */
    }
    wipe();
    channel?.postMessage({ type: "logout" } satisfies Broadcast);
    toLogin({ "da-dang-xuat": "1" });
  }, [wipe, toLogin]);

  const expire = useCallback(async () => {
    const back = currentPath();
    try {
      await api.post("/api/auth/logout", undefined, { silentAuth: true });
    } catch {
      /* bỏ qua */
    }
    wipe();
    channel?.postMessage({ type: "logout" } satisfies Broadcast);
    const params: Record<string, string> = { "het-phien": "1" };
    const keep = new URLSearchParams(locationRef.current.search).get("quay-lai");
    if (/^\/(login|register|forgot-password|dat-lai-mat-khau)/.test(back)) {
      if (keep) params["quay-lai"] = keep;
    } else params["quay-lai"] = back;
    toLogin(params);
  }, [wipe, toLogin]);

  expireRef.current = () => void expire();

  const refresh = useCallback(async () => {
    const s = await fetchSession();
    if (!s && qc.getQueryData(SESSION_KEY)) {
      await expire();
      return null;
    }
    qc.setQueryData(SESSION_KEY, s);
    return s;
  }, [qc, expire]);

  // 401 / 428 từ bất kỳ request nghiệp vụ nào.
  useEffect(
    () =>
      onAuthEvent((e) => {
        if (e.type === "activity") {
          const cur = qc.getQueryData<Session | null>(SESSION_KEY);
          if (cur && owns(cur)) sessionClock.activity();
        }
        else if (e.type === "unauthorized") {
          if (qc.getQueryData(SESSION_KEY)) void expire();
          else wipe();
        } else if (e.type === "password-change-required") {
          void refresh();
          navigate("/change-password?batbuoc=1", { replace: true });
        }
      }),
    [expire, navigate, owns, qc, refresh, wipe],
  );

  useEffect(() => {
    if (session && !owns(session)) sessionClock.clear();
  }, [session, owns]);

  // Đồng bộ giữa các tab.
  useEffect(() => {
    if (!channel) return;
    const onMessage = (ev: MessageEvent<Broadcast>) => {
      if (ev.data.type === "logout") {
        if (!qc.getQueryData(SESSION_KEY)) return;
        wipe();
        toLogin({ "da-dang-xuat": "1" });
      } else if (ev.data.type === "login") {
        const cur = qc.getQueryData<Session | null>(SESSION_KEY);
        if (cur?.maTK !== ev.data.maTK) {
          qc.removeQueries({ predicate: (q) => q.queryKey[0] !== SESSION_KEY[0] });
          void refresh();
        }
      }
    };
    channel.addEventListener("message", onMessage);
    return () => channel.removeEventListener("message", onMessage);
  }, [qc, refresh, toLogin, wipe]);

  // Trang được khôi phục từ bộ nhớ đệm Back/Forward của trình duyệt: tải lại để kiểm phiên.
  useEffect(() => {
    const onShow = (e: PageTransitionEvent) => e.persisted && window.location.reload();
    window.addEventListener("pageshow", onShow);
    return () => window.removeEventListener("pageshow", onShow);
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({ app, session, status, error: query.error, login, register, changePassword, logout, expire, refresh }),
    [app, session, status, query.error, login, register, changePassword, logout, expire, refresh],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth phải nằm trong <AuthProvider>.");
  return ctx;
}
