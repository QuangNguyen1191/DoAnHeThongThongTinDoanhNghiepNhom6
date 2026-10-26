import type { ReactNode } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@shared/api/client";
import type { Tone } from "@shared/ui/data";

/** Phần dùng chung cho các trang Quản lý (Q1–Q15). Thành phần chung với trang Admin nằm ở @shared/ui/data. */
export {
  Badge, EmptyRow, Pager, Panel, Table, TextArea, TRANG_THAI_TK, dateTimeVi, dateVi, errText, pct, td, useCan, vnd, type Paged,
} from "@shared/ui/data";

export const GIOI_TINH: Record<string, string> = { NAM: "Nam", NU: "Nữ", KHAC: "Khác" };
export const LOAI_PH: Record<string, string> = { KHEN: "Khen", GOP_Y: "Góp ý", KHIEU_NAI: "Khiếu nại" };
export const TRANG_THAI_PH: Record<string, string> = { MOI: "Mới", DANG_XU_LY: "Đang xử lý", DA_XU_LY: "Đã xử lý" };
export const TRANG_THAI_KS: Record<string, string> = { NHAP: "Nháp", DA_GUI: "Đã gửi", DA_DONG: "Đã đóng" };
export const MUC_DICH_KS: Record<string, string> = { DO_HAI_LONG: "Đo mức độ hài lòng", THAM_DO_SP_MOI: "Thăm dò sản phẩm mới" };
export const LOAI_CAU_HOI: Record<string, string> = {
  MOT_LUA_CHON: "Một lựa chọn",
  NHIEU_LUA_CHON: "Nhiều lựa chọn",
  THANG_DIEM: "Thang điểm 1–5",
  TU_LUAN: "Tự luận",
};
export interface Province { maTinh: string; tenTinh: string }
export interface Category { maLoai: number; tenLoai: string }
export interface Tier { maHang: string; tenHang: string; diemToiThieu: number }
export interface Product { maSP: number; maSKU: string; tenSP: string; maLoai: number; tenLoai: string; trangThai: string }

const catalog = <T,>(key: string) => ({ queryKey: ["catalog", key], queryFn: () => api.get<T[]>(`/api/catalog/${key}`), staleTime: Infinity });
export const useProvinces = () => useQuery(catalog<Province>("provinces"));
export const useCategories = () => useQuery(catalog<Category>("categories"));
export const useTiers = () => useQuery(catalog<Tier>("tiers"));
export const useProducts = () => useQuery(catalog<Product>("products"));

export const toneTrangThaiPH = (s: string): Tone => (s === "MOI" ? "accent" : s === "DANG_XU_LY" ? "warning" : "success");
export const toneTrangThaiKS = (s: string): Tone => (s === "NHAP" ? "neutral" : s === "DA_GUI" ? "info" : "success");

/**
 * Biểu đồ thanh ngang một chuỗi (độ lớn theo hạng mục): một màu, nhãn và giá trị ghi trực tiếp,
 * di chuột/focus hiện chi tiết. Không dùng màu để mã hóa thứ hạng.
 */
export function BarList({ rows, max, label }: {
  rows: { key: string; label: ReactNode; value: number; display: ReactNode; detail?: string }[];
  max?: number;
  label: string;
}) {
  const top = max ?? Math.max(1, ...rows.map((r) => r.value));
  if (rows.length === 0) return <p className="text-sm text-muted">Chưa có dữ liệu.</p>;
  return (
    <ul className="flex flex-col gap-2.5" aria-label={label}>
      {rows.map((r) => (
        <li key={r.key} className="group grid grid-cols-[minmax(96px,34%)_1fr_auto] items-center gap-3 text-sm" title={r.detail} tabIndex={0}>
          <span className="truncate text-ink-soft">{r.label}</span>
          <span className="relative h-3.5 rounded-sm bg-surface">
            <span
              className="absolute inset-y-0 left-0 rounded-r-[4px] bg-chart transition-[filter] group-hover:brightness-90 group-focus:brightness-90"
              style={{ width: `${Math.max(r.value > 0 ? 1.5 : 0, (100 * r.value) / top)}%` }}
            />
          </span>
          <span className="tabular min-w-[92px] text-right font-medium text-ink">{r.display}</span>
        </li>
      ))}
    </ul>
  );
}
