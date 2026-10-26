import { cloneElement, forwardRef, isValidElement, useId, type InputHTMLAttributes, type ReactElement, type ReactNode, type SelectHTMLAttributes } from "react";
import { cn } from "./cn";

interface FieldProps {
  label: ReactNode;
  required?: boolean;
  hint?: ReactNode;
  error?: string;
  /** Nội dung đặt cùng hàng với nhãn, bên phải (vd. liên kết "Quên mật khẩu?"). */
  aside?: ReactNode;
  className?: string;
  children: ReactElement<{ id?: string; "aria-invalid"?: boolean; "aria-describedby"?: string; required?: boolean }>;
}

/** Ô nhập theo quy chuẩn 6.2: nhãn luôn hiện phía trên, dấu * khi bắt buộc, lỗi đỏ ngay dưới, gắn aria-describedby. */
export function Field({ label, required, hint, error, aside, className, children }: FieldProps) {
  const auto = useId();
  const id = children.props.id ?? auto;
  const hintId = hint ? `${id}-hint` : undefined;
  const errId = error ? `${id}-err` : undefined;
  const describedBy = [errId, hintId].filter(Boolean).join(" ") || undefined;
  return (
    <div className={cn("flex flex-col gap-1.5", className)}>
      <div className="flex items-baseline justify-between gap-3">
        <label htmlFor={id} className="text-sm font-medium text-ink">
          {label}
          {required && (
            <span className="ml-0.5 text-accent" aria-hidden="true">
              *
            </span>
          )}
        </label>
        {aside}
      </div>
      {isValidElement(children) &&
        cloneElement(children, { id, "aria-invalid": error ? true : undefined, "aria-describedby": describedBy, required })}
      {error ? (
        <p id={errId} className="flex items-start gap-1.5 text-[13px] leading-5 text-danger">
          <svg viewBox="0 0 16 16" className="mt-0.5 size-3.5 shrink-0" aria-hidden="true">
            <circle cx="8" cy="8" r="7" fill="currentColor" />
            <path d="M8 4.5v4M8 10.8v.2" stroke="#fff" strokeWidth="1.6" strokeLinecap="round" />
          </svg>
          {error}
        </p>
      ) : hint ? (
        <p id={hintId} className="text-[13px] leading-5 text-muted">
          {hint}
        </p>
      ) : null}
    </div>
  );
}

export const inputClass =
  "h-11 w-full rounded-md border border-line-strong bg-bg px-3 text-[15px] text-ink placeholder:text-[#8a8d91] transition-colors duration-150 hover:border-ink-soft focus:border-ink focus:outline-none focus-visible:outline-2 focus-visible:outline-offset-0 focus-visible:outline-ink aria-invalid:border-danger aria-invalid:focus-visible:outline-danger disabled:bg-surface disabled:text-muted";

export const TextInput = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(function TextInput(
  { className, ...rest },
  ref,
) {
  return <input ref={ref} className={cn(inputClass, className)} {...rest} />;
});

export const Select = forwardRef<HTMLSelectElement, SelectHTMLAttributes<HTMLSelectElement>>(function Select(
  { className, children, ...rest },
  ref,
) {
  return (
    <select
      ref={ref}
      className={cn(
        inputClass,
        "appearance-none bg-[length:16px] bg-[right_12px_center] bg-no-repeat pr-10",
        "bg-[url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%231a1a1a' stroke-width='2'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E\")]",
        className,
      )}
      {...rest}
    >
      {children}
    </select>
  );
});
