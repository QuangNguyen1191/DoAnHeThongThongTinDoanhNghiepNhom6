import { ADMIN_URL, CRM_URL } from "../config";
import type { Cong, Session } from "./types";

/**
 * Khu vực của từng cổng. ADMIN nằm ở ứng dụng web-admin riêng (cổng 5001, trang đăng nhập riêng);
 * KHACH_HANG và QUAN_LY dùng chung web-crm (cổng 5000).
 */
const PORTAL_PREFIX: Record<Cong, string> = { ADMIN: "/admin", QUAN_LY: "/manager", KHACH_HANG: "/customer" };

export const portalPrefix = (cong: Cong) => PORTAL_PREFIX[cong];

/** Đường dẫn nội bộ an toàn: bắt đầu bằng 1 dấu "/", không phải "//" hay "/\" (chống open redirect). */
export function isSafePath(p: string | null | undefined): p is string {
  return !!p && p.startsWith("/") && !p.startsWith("//") && !p.startsWith("/\\") && !/[\r\n]/.test(p);
}

function belongsTo(path: string, cong: Cong) {
  const prefix = PORTAL_PREFIX[cong];
  const pathname = path.split(/[?#]/)[0];
  return pathname === prefix || pathname.startsWith(prefix + "/");
}

/**
 * Đích sau đăng nhập (đặc tả L1 bước 7):
 * - phải đổi mật khẩu → /change-password?batbuoc=1 của chính ứng dụng (giữ quay-lai)
 * - quay-lai hợp lệ và thuộc đúng cổng của phiên → về đó; trỏ cổng khác hoặc URL ngoài → bỏ qua
 * - QUAN_LY → /manager, KHACH_HANG → /customer, ADMIN → /admin.
 * API chỉ mở phiên đúng cổng của ứng dụng nên bình thường luôn là { internal }; { external } chỉ còn
 * để phòng khi triển khai một cổng (Security:SeparatePortalsByPort = false).
 */
export function destinationAfterLogin(session: Session, quayLai: string | null, app: "crm" | "admin") {
  const ret = normalizeReturn(quayLai, session.cong);
  if (session.phaiDoiMatKhau) {
    const qs = new URLSearchParams({ batbuoc: "1" });
    if (ret) qs.set("quay-lai", ret);
    return { internal: `/change-password?${qs}` };
  }
  const target = ret ?? PORTAL_PREFIX[session.cong];
  if (session.cong === "ADMIN") return app === "admin" ? { internal: target } : { external: ADMIN_URL + target };
  return app === "crm" ? { internal: target } : { external: CRM_URL + target };
}

/** Chỉ giữ đường dẫn nội bộ thuộc cổng của phiên. */
function normalizeReturn(quayLai: string | null, cong: Cong): string | null {
  if (!quayLai) return null;
  const path = quayLai;
  if (!isSafePath(path)) return null;
  return belongsTo(path, cong) ? path : null;
}

/** Trang chủ của phiên dưới dạng URL tuyệt đối/tương đối tùy ứng dụng hiện tại. */
export function homeHref(cong: Cong, app: "crm" | "admin") {
  if (cong === "ADMIN") return app === "admin" ? "/admin" : `${ADMIN_URL}/admin`;
  return app === "crm" ? PORTAL_PREFIX[cong] : `${CRM_URL}${PORTAL_PREFIX[cong]}`;
}

export function go(dest: { internal?: string; external?: string }, navigate: (to: string, o?: { replace?: boolean }) => void) {
  if (dest.external) window.location.assign(dest.external);
  else if (dest.internal) navigate(dest.internal, { replace: true });
}
