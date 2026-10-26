import { forwardRef, useState, type InputHTMLAttributes, type KeyboardEvent } from "react";
import { Eye, EyeOff } from "lucide-react";
import { cn } from "./cn";
import { inputClass } from "./Field";

interface Props extends Omit<InputHTMLAttributes<HTMLInputElement>, "type"> {
  onCapsLockChange?: (on: boolean) => void;
}

/** Ô mật khẩu có nút hiện/ẩn; cho phép dán và trình quản lý mật khẩu (WCAG 2.2 – Accessible Authentication). */
export const PasswordInput = forwardRef<HTMLInputElement, Props>(function PasswordInput(
  { className, onCapsLockChange, onKeyUp, onKeyDown, ...rest },
  ref,
) {
  const [visible, setVisible] = useState(false);
  const caps = (e: KeyboardEvent<HTMLInputElement>) => onCapsLockChange?.(e.getModifierState?.("CapsLock") ?? false);
  return (
    <div className="relative">
      <input
        ref={ref}
        type={visible ? "text" : "password"}
        className={cn(inputClass, "pr-12", className)}
        spellCheck={false}
        autoCapitalize="none"
        onKeyUp={(e) => {
          caps(e);
          onKeyUp?.(e);
        }}
        onKeyDown={(e) => {
          caps(e);
          onKeyDown?.(e);
        }}
        {...rest}
      />
      <button
        type="button"
        onClick={() => setVisible((v) => !v)}
        aria-label={visible ? "Ẩn mật khẩu" : "Hiện mật khẩu"}
        aria-pressed={visible}
        className="absolute inset-y-0 right-0 flex w-11 items-center justify-center rounded-r-md text-muted transition-colors hover:text-ink"
      >
        {visible ? <EyeOff className="size-[18px]" aria-hidden="true" /> : <Eye className="size-[18px]" aria-hidden="true" />}
      </button>
    </div>
  );
});
