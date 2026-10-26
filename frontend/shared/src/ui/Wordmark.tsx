import { cn } from "./cn";

/**
 * Nhận diện tạm thời "CRM UNIQLO" bằng chữ (đặc tả 6: không dùng logo/tài sản thương hiệu không được cung cấp).
 * Khối vuông đỏ chỉ là điểm nhấn hình học.
 */
export function Wordmark({ tone = "dark", className, sub }: { tone?: "dark" | "light"; className?: string; sub?: string }) {
  return (
    <span className={cn("inline-flex items-center gap-2.5", className)}>
      <span aria-hidden="true" className="grid size-8 place-items-center rounded-[3px] bg-accent text-[10px] font-extrabold tracking-[0.08em] text-white">
        CRM
      </span>
      <span aria-hidden="true" className="flex flex-col leading-none">
        <span className={cn("text-[17px] font-extrabold tracking-[0.18em]", tone === "light" ? "text-white" : "text-ink")}>
          UNIQLO
        </span>
        {sub && (
          <span className={cn("mt-1 text-[10.5px] font-medium uppercase tracking-[0.14em]", tone === "light" ? "text-white/60" : "text-muted")}>
            {sub}
          </span>
        )}
      </span>
      <span className="sr-only">CRM Uniqlo</span>
    </span>
  );
}
