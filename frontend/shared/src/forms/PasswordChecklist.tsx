import { Check } from "lucide-react";
import { cn } from "../ui/cn";
import { PASSWORD_RULES } from "./schemas";

/** Gợi ý chính sách mật khẩu hiện trực tiếp khi gõ (không chờ bấm gửi). */
export function PasswordChecklist({ value, id }: { value: string; id?: string }) {
  return (
    <ul id={id} className="flex flex-wrap gap-x-4 gap-y-1 text-[13px]" aria-label="Yêu cầu mật khẩu">
      {PASSWORD_RULES.map((r) => {
        const ok = r.test(value);
        return (
          <li key={r.id} className={cn("flex items-center gap-1.5 transition-colors", ok ? "text-success" : "text-muted")}>
            <span aria-hidden="true" className={cn("grid size-4 place-items-center rounded-full border", ok ? "border-success bg-success text-white" : "border-line-strong")}>
              {ok && <Check className="size-3" strokeWidth={3} />}
            </span>
            {r.label}
            <span className="sr-only">{ok ? ": đạt" : ": chưa đạt"}</span>
          </li>
        );
      })}
    </ul>
  );
}
