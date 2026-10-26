import { useEffect, useRef, type ReactNode } from "react";
import { cn } from "./cn";

/** Modal dùng <dialog> gốc: tự bẫy focus, Esc đóng, trả focus về nút mở (đặc tả 6.2). */
export function Modal({ open, onClose, title, children, footer, role = "dialog", className }: {
  open: boolean;
  onClose: () => void;
  title: ReactNode;
  children?: ReactNode;
  footer?: ReactNode;
  role?: "dialog" | "alertdialog";
  className?: string;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);
  return (
    <dialog
      ref={ref}
      role={role}
      aria-labelledby="modal-title"
      onCancel={(e) => {
        e.preventDefault();
        onClose();
      }}
      className={cn(
        "m-auto w-[min(440px,calc(100vw-32px))] rounded-md border border-line bg-bg p-0 text-ink shadow-[0_12px_40px_rgb(0_0_0/0.18)]",
        className,
      )}
    >
      {open && (
        <div className="animate-fade-up">
          <div className="px-6 pt-6">
            <h2 id="modal-title" className="text-lg font-semibold">
              {title}
            </h2>
            {children && <div className="mt-2 text-[15px] text-ink-soft">{children}</div>}
          </div>
          {footer && <div className="mt-6 flex flex-wrap justify-end gap-2 border-t border-line px-6 py-4">{footer}</div>}
        </div>
      )}
    </dialog>
  );
}
