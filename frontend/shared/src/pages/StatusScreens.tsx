import type { ReactNode } from "react";
import { Link } from "react-router";
import { Compass, Lock, RefreshCw, ServerCrash } from "lucide-react";
import { isApiError } from "../api/errors";
import { Button } from "../ui/Button";
import { Spinner } from "../ui/Spinner";
import { Wordmark } from "../ui/Wordmark";

export function FullPageLoader({ label = "Đang kiểm tra phiên đăng nhập…" }: { label?: string }) {
  return (
    <div className="grid min-h-dvh place-items-center bg-bg">
      <div className="flex flex-col items-center gap-5 text-muted">
        <Wordmark />
        <div className="flex items-center gap-2 text-sm" role="status">
          <Spinner />
          {label}
        </div>
      </div>
    </div>
  );
}

function Shell({ icon, code, title, children, actions }: {
  icon: ReactNode;
  code?: string;
  title: string;
  children: ReactNode;
  actions: ReactNode;
}) {
  return (
    <main className="flex min-h-dvh flex-col bg-surface">
      <header className="border-b border-line bg-bg px-4 py-3 sm:px-8">
        <Wordmark sub="Customer Relationship" />
      </header>
      <div className="flex flex-1 items-center justify-center px-4 py-12">
        <div className="animate-fade-up w-full max-w-md rounded-md border border-line bg-bg p-8 text-center">
          <div className="mx-auto grid size-12 place-items-center rounded-full bg-surface text-ink">{icon}</div>
          {code && <p className="mt-5 text-xs font-semibold uppercase tracking-[0.2em] text-accent">{code}</p>}
          <h1 className="mt-2 text-2xl font-bold tracking-tight">{title}</h1>
          <div className="mt-3 text-[15px] text-muted">{children}</div>
          <div className="mt-7 flex flex-wrap justify-center gap-2">{actions}</div>
        </div>
      </div>
    </main>
  );
}

/** Trang 403: vào khu vực không đúng cổng hoặc thiếu quyền. */
export function ForbiddenScreen({ homeHref, onLogout }: { homeHref: string | null; onLogout?: () => void }) {
  const external = homeHref?.startsWith("http");
  return (
    <Shell icon={<Lock className="size-5" aria-hidden="true" />} code="Lỗi 403" title="Bạn không có quyền truy cập trang này" actions={
      <>
        {homeHref &&
          (external ? (
            <a href={homeHref} className="inline-flex h-11 items-center rounded-md bg-accent px-4 text-[15px] font-semibold text-white hover:bg-accent-hover">
              Về khu vực của tôi
            </a>
          ) : (
            <Link to={homeHref} replace className="inline-flex h-11 items-center rounded-md bg-accent px-4 text-[15px] font-semibold text-white hover:bg-accent-hover">
              Về khu vực của tôi
            </Link>
          ))}
        {onLogout && (
          <Button variant="secondary" onClick={onLogout}>
            Đăng nhập tài khoản khác
          </Button>
        )}
      </>
    }>
      Trang này thuộc khu vực của vai trò khác. Nếu bạn cần quyền này, hãy liên hệ quản trị viên hệ thống.
    </Shell>
  );
}

export function NotFoundScreen({ homeHref = "/" }: { homeHref?: string }) {
  return (
    <Shell icon={<Compass className="size-5" aria-hidden="true" />} code="Lỗi 404" title="Không tìm thấy trang" actions={
      <Link to={homeHref} replace className="inline-flex h-11 items-center rounded-md bg-accent px-4 text-[15px] font-semibold text-white hover:bg-accent-hover">
        Về trang chính
      </Link>
    }>
      Đường dẫn không tồn tại hoặc đã được thay đổi.
    </Shell>
  );
}

export function ErrorScreen({ error, onRetry }: { error: unknown; onRetry: () => void }) {
  const msg = isApiError(error) ? error.userMessage : "Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.";
  const trace = isApiError(error) ? error.traceId : undefined;
  return (
    <Shell icon={<ServerCrash className="size-5" aria-hidden="true" />} title="Chưa tải được hệ thống" actions={
      <Button onClick={onRetry} icon={<RefreshCw className="size-4" aria-hidden="true" />}>
        Thử lại
      </Button>
    }>
      <p>{msg}</p>
      {trace && <p className="mt-2 text-xs">Mã tra cứu: <span className="tabular font-mono">{trace}</span></p>}
    </Shell>
  );
}
