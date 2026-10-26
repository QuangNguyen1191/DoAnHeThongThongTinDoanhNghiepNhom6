import { createContext, useCallback, useContext, useMemo, useRef, useState, type ReactNode } from "react";
import { X } from "lucide-react";
import { cn } from "./cn";

type Tone = "success" | "error" | "info";
interface ToastItem {
  id: number;
  tone: Tone;
  message: ReactNode;
}
const Ctx = createContext<(tone: Tone, message: ReactNode) => void>(() => {});

/** Toast góc phải dưới, tự tắt 5 giây; lỗi không tự tắt (đặc tả 6.2). */
export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([]);
  const seq = useRef(0);
  const dismiss = useCallback((id: number) => setItems((xs) => xs.filter((x) => x.id !== id)), []);
  const push = useCallback(
    (tone: Tone, message: ReactNode) => {
      const id = ++seq.current;
      setItems((xs) => [...xs.slice(-3), { id, tone, message }]);
      if (tone !== "error") setTimeout(() => dismiss(id), 5000);
    },
    [dismiss],
  );
  const value = useMemo(() => push, [push]);
  return (
    <Ctx.Provider value={value}>
      {children}
      <div className="pointer-events-none fixed inset-x-4 bottom-4 z-50 flex flex-col items-end gap-2 sm:left-auto sm:right-6 sm:bottom-6">
        {items.map((t) => (
          <div
            key={t.id}
            role={t.tone === "error" ? "alert" : "status"}
            className={cn(
              "animate-fade-up pointer-events-auto flex w-full max-w-sm items-start gap-3 rounded-md border bg-bg px-4 py-3 text-sm shadow-[0_8px_24px_rgb(0_0_0/0.12)]",
              t.tone === "error" ? "border-danger/40" : t.tone === "success" ? "border-success/40" : "border-line",
            )}
          >
            <span
              aria-hidden="true"
              className={cn("mt-1.5 size-2 shrink-0 rounded-full", t.tone === "error" ? "bg-danger" : t.tone === "success" ? "bg-success" : "bg-info")}
            />
            <div className="flex-1 text-ink">{t.message}</div>
            <button type="button" aria-label="Đóng thông báo" onClick={() => dismiss(t.id)} className="-mr-1 rounded p-1 text-muted hover:text-ink">
              <X className="size-4" aria-hidden="true" />
            </button>
          </div>
        ))}
      </div>
    </Ctx.Provider>
  );
}

export const useToast = () => useContext(Ctx);
