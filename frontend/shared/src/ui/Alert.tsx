import type { ReactNode } from "react";
import { AlertCircle, CheckCircle2, Info, TriangleAlert } from "lucide-react";
import { cn } from "./cn";

type Tone = "error" | "warning" | "info" | "success";
const TONES: Record<Tone, { box: string; icon: ReactNode }> = {
  error: { box: "border-danger/30 bg-danger-soft text-danger", icon: <AlertCircle aria-hidden="true" className="size-[18px]" /> },
  warning: { box: "border-warning/30 bg-warning-soft text-warning", icon: <TriangleAlert aria-hidden="true" className="size-[18px]" /> },
  info: { box: "border-info/25 bg-info-soft text-info", icon: <Info aria-hidden="true" className="size-[18px]" /> },
  success: { box: "border-success/30 bg-success-soft text-success", icon: <CheckCircle2 aria-hidden="true" className="size-[18px]" /> },
};

export function Alert({ tone = "info", title, children, className, action }: {
  tone?: Tone;
  title?: ReactNode;
  children?: ReactNode;
  className?: string;
  action?: ReactNode;
}) {
  const t = TONES[tone];
  return (
    <div
      role={tone === "error" ? "alert" : "status"}
      className={cn("animate-fade-up flex gap-3 rounded-md border px-3.5 py-3 text-sm leading-5", t.box, className)}
    >
      <span className="mt-px shrink-0">{t.icon}</span>
      <div className="min-w-0 flex-1">
        {title && <p className="font-semibold">{title}</p>}
        {children && <div className={cn("text-ink-soft", !!title && "mt-0.5")}>{children}</div>}
        {action && <div className="mt-2">{action}</div>}
      </div>
    </div>
  );
}
