import type { ReactNode } from "react";
import { Navigate, useLocation } from "react-router";
import { useQueryClient } from "@tanstack/react-query";
import { ErrorScreen, ForbiddenScreen, FullPageLoader } from "../pages/StatusScreens";
import { ForbiddenState } from "../pages/PageStates";
import { SESSION_KEY, useAuth } from "./AuthProvider";
import { destinationAfterLogin, homeHref } from "./redirect";
import { hasAny, type Cong } from "./types";

/** Chuyển sang URL ngoài ứng dụng (web-crm ↔ web-admin) trong lúc render. */
function ExternalRedirect({ to }: { to: string }) {
  window.location.replace(to);
  return <FullPageLoader label="Đang chuyển trang…" />;
}

function LoginRedirect() {
  const loc = useLocation();
  const back = loc.pathname + loc.search;
  return <Navigate to={`/login?quay-lai=${encodeURIComponent(back)}`} replace />;
}

function useGate() {
  const auth = useAuth();
  const qc = useQueryClient();
  if (auth.status === "loading") return <FullPageLoader />;
  if (auth.status === "error")
    return <ErrorScreen error={auth.error} onRetry={() => void qc.refetchQueries({ queryKey: SESSION_KEY })} />;
  if (!auth.session) return <LoginRedirect />;
  return null;
}

/** Đã đăng nhập (mọi cổng) – dùng cho /change-password. */
export function RequireSession({ children }: { children: ReactNode }) {
  return useGate() ?? <>{children}</>;
}

/**
 * Khu vực của một cổng. Chưa đăng nhập → /login?quay-lai=…; khác cổng → 403;
 * phiên phải đổi mật khẩu → /change-password?batbuoc=1. Guard chỉ phục vụ trải nghiệm, API vẫn kiểm lại.
 */
export function RequirePortal({ cong, children }: { cong: Cong; children: ReactNode }) {
  const gate = useGate();
  const { session, app, logout } = useAuth();
  const loc = useLocation();
  if (gate) return gate;
  const s = session!;
  if (s.phaiDoiMatKhau) {
    const dest = destinationAfterLogin(s, loc.pathname + loc.search, app);
    return dest.external ? <ExternalRedirect to={dest.external} /> : <Navigate to={dest.internal!} replace />;
  }
  if (s.cong !== cong) return <ForbiddenScreen homeHref={homeHref(s.cong, app)} onLogout={() => void logout()} />;
  return <>{children}</>;
}

/** Chức năng trong khu vực cần ít nhất một quyền (bảng route mục 7). Thiếu quyền → trạng thái 403 ngay trong khung trang. */
export function RequirePermission({ any, children }: { any: readonly string[]; children: ReactNode }) {
  const { session } = useAuth();
  return hasAny(session, any) ? <>{children}</> : <ForbiddenState />;
}

/** /login, /register, /forgot-password: đang đăng nhập thì về thẳng khu vực của phiên. */
export function PublicOnly({ children }: { children: ReactNode }) {
  const { session, status, app } = useAuth();
  const loc = useLocation();
  if (status === "loading") return <FullPageLoader />;
  if (session) {
    const dest = destinationAfterLogin(session, new URLSearchParams(loc.search).get("quay-lai"), app);
    return dest.external ? <ExternalRedirect to={dest.external} /> : <Navigate to={dest.internal!} replace />;
  }
  return <>{children}</>;
}
