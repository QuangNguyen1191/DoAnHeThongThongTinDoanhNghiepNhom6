const trim = (url: string | undefined, fallback: string) => (url || fallback).replace(/\/+$/, "");

/** Gốc của web-crm (trang đăng nhập chung của Khách hàng và Quản lý). */
export const CRM_URL = trim(import.meta.env.VITE_CRM_URL, "http://localhost:5000");
/** Gốc của web-admin (trang đăng nhập riêng và khu vực Quản trị). */
export const ADMIN_URL = trim(import.meta.env.VITE_ADMIN_URL, "http://localhost:5001");

/** Hết hạn trượt của cookie phiên phía API (Security:SlidingExpirationMinutes). */
export const SESSION_IDLE_MINUTES = 30;
/** Cảnh báo trước khi hết phiên do không thao tác. */
export const SESSION_WARNING_MINUTES = 2;
