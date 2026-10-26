import { forwardRef, type ReactNode, type TextareaHTMLAttributes } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { isApiError } from "../api/errors";
import { useAuth } from "../auth/AuthProvider";
import { hasAny } from "../auth/types";
import { cn } from "./cn";
import { inputClass } from "./Field";

/** Thành phần dữ liệu dùng chung cho các trang nghiệp vụ (Quản lý, Admin): bảng, khối, nhãn trạng thái, phân trang, định dạng. */

export interface Paged<T> {
  items: T[];
  trang: number;
  soDong: number;
  tongSoDong: number;
}

export const dateVi = (s?: string | null) => (s ? new Date(s).toLocaleDateString("vi-VN") : "—");
export const dateTimeVi = (s?: string | null) =>
  s ? new Date(s).toLocaleString("vi-VN", { dateStyle: "short", timeStyle: "short" }) : "—";
export const vnd = (n?: number | null) => (n ?? 0).toLocaleString("vi-VN") + " ₫";
export const pct = (n?: number | null) => (n == null ? "—" : `${Number(n).toLocaleString("vi-VN", { maximumFractionDigits: 2 })}%`);

export const TRANG_THAI_TK: Record<string, string> = { HOAT_DONG: "Hoạt động", DA_KHOA: "Đã khóa" };

/** Quyền chỉ để ẩn/hiện nút; CSDL vẫn kiểm (lỗi 50003 → 403). */
export function useCan() {
  const { session } = useAuth();
  return (...perms: string[]) => hasAny(session, perms);
}

/** Câu thông báo lỗi ngắn cho toast/alert. */
export const errText = (e: unknown) => (isApiError(e) ? e.userMessage : "Đã có lỗi xảy ra.");

export type Tone = "neutral" | "accent" | "success" | "warning" | "danger" | "info";
const BADGE: Record<Tone, string> = {
  neutral: "border-line-strong text-ink-soft",
  accent: "border-accent text-accent",
  success: "border-success/40 bg-success-soft text-success",
  warning: "border-warning/40 bg-warning-soft text-warning",
  danger: "border-danger/40 bg-danger-soft text-danger",
  info: "border-info/30 bg-info-soft text-info",
};
export function Badge({ tone = "neutral", children }: { tone?: Tone; children: ReactNode }) {
  return <span className={cn("inline-flex items-center whitespace-nowrap rounded-sm border px-1.5 py-px text-xs font-semibold", BADGE[tone])}>{children}</span>;
}

/** Khối nội dung có tiêu đề (thẻ trắng viền mảnh). */
export function Panel({ title, actions, children, className, bodyClass }: {
  title?: ReactNode;
  actions?: ReactNode;
  children: ReactNode;
  className?: string;
  bodyClass?: string;
}) {
  return (
    <section className={cn("rounded-md border border-line bg-bg", className)}>
      {(title || actions) && (
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line px-5 py-3.5">
          {title && <h2 className="text-base font-semibold">{title}</h2>}
          {actions}
        </div>
      )}
      <div className={bodyClass ?? "p-5"}>{children}</div>
    </section>
  );
}

export function EmptyRow({ children }: { children: ReactNode }) {
  return <p className="px-5 py-8 text-center text-sm text-muted">{children}</p>;
}

/** Phân trang: "Trang x / y" + nút trước/sau. */
export function Pager({ page, size, total, onPage }: { page: number; size: number; total: number; onPage: (p: number) => void }) {
  const pages = Math.max(1, Math.ceil(total / size));
  if (total <= size) return null;
  const btn = "grid size-9 place-items-center rounded-md border border-line-strong bg-bg hover:border-ink disabled:cursor-not-allowed disabled:opacity-40";
  return (
    <nav aria-label="Phân trang" className="flex items-center justify-end gap-2 text-sm">
      <span className="tabular mr-2 text-muted">Trang {page} / {pages}</span>
      <button type="button" className={btn} aria-label="Trang trước" disabled={page <= 1} onClick={() => onPage(page - 1)}>
        <ChevronLeft className="size-4" aria-hidden="true" />
      </button>
      <button type="button" className={btn} aria-label="Trang sau" disabled={page >= pages} onClick={() => onPage(page + 1)}>
        <ChevronRight className="size-4" aria-hidden="true" />
      </button>
    </nav>
  );
}

export const TextArea = forwardRef<HTMLTextAreaElement, TextareaHTMLAttributes<HTMLTextAreaElement>>(function TextArea({ className, ...rest }, ref) {
  return <textarea ref={ref} className={cn(inputClass, "h-auto min-h-24 py-2.5 leading-6", className)} {...rest} />;
});

/** Bảng có cuộn ngang trên màn hình hẹp. */
export function Table({ head, children, label }: { head: ReactNode[]; children: ReactNode; label: string }) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[640px] border-collapse text-left text-[14.5px]" aria-label={label}>
        <thead>
          <tr className="border-b border-line text-xs font-semibold uppercase tracking-wider text-muted">
            {head.map((h, i) => (
              <th key={i} scope="col" className="px-4 py-2.5 font-semibold first:pl-5 last:pr-5">{h}</th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-line">{children}</tbody>
      </table>
    </div>
  );
}
export const td = "px-4 py-3 align-top first:pl-5 last:pr-5";
