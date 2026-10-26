/** Cổng truy cập của phiên (VAI_TRO.CongTruyCap). Quyết định ứng dụng / khu vực được vào. */
export type Cong = "ADMIN" | "QUAN_LY" | "KHACH_HANG";

/** SessionResponse của POST /api/auth/login, /register, /change-password và GET /api/auth/me. */
export interface Session {
  maTK: number;
  tenDangNhap: string;
  cong: Cong;
  maVT: string;
  tenVT: string | null;
  hoTen: string | null;
  chucVu: string | null;
  maKH: number | null;
  maNV: number | null;
  phaiDoiMatKhau: boolean;
  quyen: string[];
  quyenChiTiet: { maQuyen: string; tenQuyen: string }[];
  xsrfToken?: string | null;
}

export const CONG_LABEL: Record<Cong, string> = {
  ADMIN: "Quản trị hệ thống",
  QUAN_LY: "Quản lý CRM",
  KHACH_HANG: "Khách hàng",
};

/** Có ít nhất một trong các quyền. Danh sách quyền chỉ để ẩn/hiện; quyền thật do CSDL kiểm. */
export function hasAny(session: Session | null | undefined, perms: readonly string[] | undefined) {
  if (!perms || perms.length === 0) return true;
  return !!session && perms.some((p) => session.quyen.includes(p));
}
