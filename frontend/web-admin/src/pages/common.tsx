import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Check, Copy } from "lucide-react";
import { api } from "@shared/api/client";
import { Alert } from "@shared/ui/Alert";
import type { Tone } from "@shared/ui/data";

/** Phần dùng chung cho các trang Admin (A1–A16). Bảng, khối, nhãn, phân trang ở @shared/ui/data. */

export const LOAI_TK: Record<string, string> = { NV: "Nhân viên", KH: "Khách hàng" };
export const CONG: Record<string, string> = { ADMIN: "Cổng Quản trị", QUAN_LY: "Cổng Quản lý", KHACH_HANG: "Cổng Khách hàng" };
export const TRANG_THAI_NV: Record<string, string> = { DANG_LAM: "Đang làm", DA_NGHI: "Đã nghỉ" };
export const KENH_BAN: Record<string, string> = { CUA_HANG: "Tại cửa hàng", ONLINE: "Online" };
export const LY_DO_DOI_TRA: Record<string, string> = { LOI_SP: "Lỗi sản phẩm", KHONG_VUA: "Không vừa", KHONG_UNG: "Không ưng ý", KHAC: "Khác" };

/** Hành động ghi vào nhật ký (sec.usp_GhiNhatKy) – dùng cho bộ lọc và hiển thị. */
export const HANH_DONG: Record<string, string> = {
  DANG_NHAP: "Đăng nhập",
  DANG_KY: "Khách tự đăng ký",
  DOI_MAT_KHAU: "Đổi mật khẩu",
  QUEN_MAT_KHAU: "Yêu cầu quên mật khẩu",
  QUEN_MAT_KHAU_BI_CHAN: "Quên mật khẩu bị chặn",
  DAT_LAI_MAT_KHAU_BANG_MA: "Đặt lại mật khẩu qua email",
  TAO_TK: "Tạo tài khoản nhân viên",
  CAP_TK_KH: "Cấp tài khoản khách hàng",
  KHOA_TK: "Khóa tài khoản",
  MO_KHOA_TK: "Mở khóa tài khoản",
  XOA_TK: "Xóa tài khoản",
  DAT_LAI_MK: "Đặt lại mật khẩu",
  DOI_VAI_TRO: "Đổi vai trò",
  TAO_VAI_TRO: "Tạo vai trò",
  CAP_NHAT_QUYEN: "Cập nhật quyền vai trò",
  LUU_DANH_MUC: "Lưu danh mục / nhân viên",
  NAP_HOA_DON: "Nạp hóa đơn",
  NAP_DOI_TRA: "Nạp đổi trả",
  XET_HANG: "Xét hạng toàn bộ",
  THEM_KH: "Thêm khách hàng",
  SUA_KH: "Sửa khách hàng",
  XOA_KH: "Xóa khách hàng",
  KHOA_TK_KH: "Khóa tài khoản khách",
  MO_KHOA_TK_KH: "Mở khóa tài khoản khách",
  SUA_HO_SO: "Khách sửa hồ sơ",
  TIEP_NHAN_PH: "Tiếp nhận phản hồi",
  TRA_LOI_PH: "Trả lời phản hồi",
  TAO_KS: "Tạo khảo sát",
  GUI_KS: "Gửi khảo sát",
  DONG_KS: "Đóng khảo sát",
};

export const toneTrangThaiTK = (s?: string | null): Tone => (s === "DA_KHOA" ? "warning" : s === "HOAT_DONG" ? "success" : "neutral");

export interface TaiKhoan {
  maTK: number;
  tenDangNhap: string;
  loaiTK: "NV" | "KH";
  maVT: string;
  tenVT: string;
  congTruyCap: string;
  trangThai: "HOAT_DONG" | "DA_KHOA";
  phaiDoiMatKhau: boolean;
  ngayTao: string;
  lanDangNhapCuoi: string | null;
  ngayKhoa: string | null;
  lyDoKhoa: string | null;
  chuTaiKhoan: string | null;
  maNV: number | null;
  maKH: number | null;
}

export interface NhanVien {
  maNV: number;
  hoTen: string;
  maCV: string;
  tenCV: string;
  maCH: number | null;
  tenCH: string | null;
  sdt: string;
  email: string;
  ngayVaoLam: string;
  trangThai: "DANG_LAM" | "DA_NGHI";
  maTK: number | null;
  tenDangNhap: string | null;
  maVT: string | null;
}

export interface VaiTro { maVT: string; tenVT: string; loaiTK: "NV" | "KH"; congTruyCap: string; moTa: string | null; soTaiKhoan: number }
export interface VaiTroQuyen { maVT: string; tenVT: string; congTruyCap: string; maQuyen: string; tenQuyen: string; duocCap: boolean }
export interface Roles { vaiTro: VaiTro[]; quyen: VaiTroQuyen[] }

export interface Lookups {
  loaiSP: { maLoai: number; tenLoai: string }[];
  cuaHang: { maCH: number; tenCH: string; tenTinh: string | null; trangThai: string }[];
  chucVu: { maCV: string; tenCV: string }[];
  tinhThanh: { maTinh: string; tenTinh: string }[];
}

/** Danh mục phụ cho ô chọn (cửa hàng, chức vụ...). Quyền AD_TRA_CUU. */
export const useLookups = (enabled = true) =>
  useQuery({ queryKey: ["admin", "lookups"], queryFn: () => api.get<Lookups>("/api/admin/lookups"), staleTime: 5 * 60_000, enabled });

/** Vai trò + ma trận quyền. Quyền AD_PHAN_QUYEN. */
export const useRoles = (enabled = true) =>
  useQuery({ queryKey: ["admin", "roles"], queryFn: () => api.get<Roles>("/api/admin/roles"), enabled });

export interface TempPassword { tenDangNhap: string; matKhauTam: string }

/** Hộp hiện mật khẩu tạm đúng một lần (sau khi tạo tài khoản hoặc đặt lại mật khẩu). */
export function TempPasswordBox({ value, title }: { value: TempPassword; title: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <Alert tone="success" title={title}>
      <p>Mật khẩu tạm chỉ hiện một lần. Gửi cho người dùng; họ phải đổi mật khẩu ở lần đăng nhập tới.</p>
      <dl className="mt-2 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1">
        <dt>Tên đăng nhập</dt>
        <dd className="font-mono font-semibold text-ink" data-testid="ten-dang-nhap">{value.tenDangNhap}</dd>
        <dt>Mật khẩu tạm</dt>
        <dd className="flex items-center gap-2">
          <span className="font-mono font-semibold text-ink" data-testid="mat-khau-tam">{value.matKhauTam}</span>
          <button
            type="button"
            className="inline-flex items-center gap-1 text-xs font-medium text-ink-soft hover:text-ink"
            onClick={() => void navigator.clipboard?.writeText(value.matKhauTam).then(() => setCopied(true))}
          >
            {copied ? <Check className="size-3.5" aria-hidden="true" /> : <Copy className="size-3.5" aria-hidden="true" />}
            {copied ? "Đã chép" : "Chép"}
          </button>
        </dd>
      </dl>
    </Alert>
  );
}

/** Giá trị cho ô datetime-local theo giờ máy người dùng. */
export function localDateTime(d = new Date()) {
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}
