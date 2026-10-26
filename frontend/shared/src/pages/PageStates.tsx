import type { ReactNode } from "react";
import { Hammer, Lock, RefreshCw, Ban } from "lucide-react";
import { isApiError, MSG_FORBIDDEN } from "../api/errors";
import { Button } from "../ui/Button";

function State({ icon, title, children, action }: { icon: ReactNode; title: string; children?: ReactNode; action?: ReactNode }) {
  return (
    <div className="animate-fade-up flex flex-col items-center rounded-md border border-dashed border-line-strong bg-bg px-6 py-14 text-center">
      <div className="grid size-11 place-items-center rounded-full bg-surface text-ink">{icon}</div>
      <h2 className="mt-4 text-lg font-semibold">{title}</h2>
      {children && <div className="mt-1.5 max-w-md text-[15px] text-muted">{children}</div>}
      {action && <div className="mt-5">{action}</div>}
    </div>
  );
}

export function ForbiddenState({ message = MSG_FORBIDDEN }: { message?: string }) {
  return (
    <State icon={<Lock className="size-5" aria-hidden="true" />} title="Không có quyền truy cập">
      {message} Liên hệ quản trị viên nếu bạn cần quyền này.
    </State>
  );
}

export function ComingSoon({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <State icon={<Hammer className="size-5" aria-hidden="true" />} title={title}>
      {children ?? "Chức năng này sẽ được hoàn thiện ở giai đoạn tiếp theo. Phân quyền và điều hướng đã hoạt động."}
    </State>
  );
}

export function NotSupported({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <State icon={<Ban className="size-5" aria-hidden="true" />} title={title}>
      <span className="mb-2 inline-block rounded-sm border border-line-strong px-2 py-0.5 text-xs font-semibold uppercase tracking-wider text-muted">
        Chưa hỗ trợ
      </span>
      <div>{children}</div>
    </State>
  );
}

/** Lỗi khi tải dữ liệu: 403 → trạng thái không có quyền; còn lại → thông báo + Thử lại + mã tra cứu. */
export function ErrorState({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  if (isApiError(error) && error.isForbidden) return <ForbiddenState message={error.message} />;
  const msg = isApiError(error) ? error.userMessage : "Đã có lỗi xảy ra.";
  const trace = isApiError(error) ? error.traceId : undefined;
  return (
    <State
      icon={<RefreshCw className="size-5" aria-hidden="true" />}
      title="Chưa tải được dữ liệu"
      action={onRetry && <Button variant="secondary" onClick={onRetry}>Thử lại</Button>}
    >
      {msg}
      {trace && <span className="mt-1 block text-xs">Mã tra cứu: <span className="font-mono">{trace}</span></span>}
    </State>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return <div aria-hidden="true" className={`animate-pulse rounded-md bg-surface-2 ${className ?? ""}`} />;
}
