import { useEffect, useState, type ComponentType, type ReactNode } from "react";
import { NavLink, Outlet, useLocation } from "react-router";
import { LogOut, Menu, X, UserRound } from "lucide-react";
import { useAuth } from "../auth/AuthProvider";
import { hasAny, CONG_LABEL } from "../auth/types";
import { Button } from "../ui/Button";
import { cn } from "../ui/cn";
import { Modal } from "../ui/Modal";
import { Wordmark } from "../ui/Wordmark";

export interface NavItem {
  to: string;
  label: string;
  icon: ComponentType<{ className?: string; "aria-hidden"?: boolean }>;
  /** Hiện khi phiên có ít nhất một quyền trong danh sách (để trống = mọi phiên của cổng). */
  any?: readonly string[];
  end?: boolean;
  badge?: string;
}

/** Khung chung 3 web nghiệp vụ (đặc tả hình 4): topbar + sidebar 240px theo quyền; dưới lg sidebar thành drawer. */
export function PortalLayout({ nav, accountPath }: { nav: NavItem[]; accountPath: string }) {
  const { session, logout } = useAuth();
  const [open, setOpen] = useState(false);
  const [confirm, setConfirm] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const loc = useLocation();
  useEffect(() => setOpen(false), [loc.pathname]);
  if (!session) return null;

  const items = nav.filter((n) => hasAny(session, n.any));
  const initials = (session.hoTen ?? session.tenDangNhap)
    .split(/\s+/)
    .slice(-2)
    .map((w) => w[0])
    .join("")
    .toUpperCase();

  const sidebar = (
    <nav aria-label="Điều hướng chính" className="flex flex-col gap-0.5 p-3">
      {items.map(({ to, label, icon: Icon, end, badge }) => (
        <NavLink
          key={to}
          to={to}
          end={end}
          className={({ isActive }) =>
            cn(
              "group relative flex min-h-10 items-center gap-3 rounded-md px-3 py-2 text-[14.5px] leading-tight transition-colors",
              isActive ? "bg-surface font-semibold text-ink" : "text-ink-soft hover:bg-surface hover:text-ink",
            )
          }
        >
          {({ isActive }) => (
            <>
              <span aria-hidden="true" className={cn("absolute inset-y-2 left-0 w-[3px] rounded-r bg-accent transition-opacity", isActive ? "opacity-100" : "opacity-0")} />
              <Icon className="size-[18px] shrink-0" aria-hidden />
              <span className="flex-1">{label}</span>
              {badge && <span className="shrink-0 whitespace-nowrap rounded-sm bg-surface-2 px-1.5 py-px text-[11px] font-medium text-muted">{badge}</span>}
            </>
          )}
        </NavLink>
      ))}
    </nav>
  );

  return (
    <div className="min-h-dvh bg-surface">
      <a href="#noi-dung" className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-ink focus:px-4 focus:py-2 focus:text-white">
        Bỏ qua điều hướng
      </a>
      <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-line bg-bg px-4 lg:px-6">
        <button type="button" className="-ml-1 rounded-md p-2 lg:hidden" aria-label="Mở menu" aria-expanded={open} onClick={() => setOpen(true)}>
          <Menu className="size-5" aria-hidden="true" />
        </button>
        <Wordmark />
        <span aria-hidden="true" className="mx-1 hidden h-6 w-px bg-line sm:block" />
        <span className="hidden text-sm font-medium text-muted sm:block">{CONG_LABEL[session.cong]}</span>
        <div className="ml-auto flex items-center gap-2">
          <NavLink to={accountPath} className="flex items-center gap-3 rounded-md px-2 py-1.5 hover:bg-surface">
            <span aria-hidden="true" className="grid size-9 place-items-center rounded-full bg-ink text-xs font-semibold text-white">
              {initials || <UserRound className="size-4" />}
            </span>
            <span className="hidden text-left leading-tight md:block">
              <span className="block max-w-48 truncate text-sm font-semibold">{session.hoTen ?? session.tenDangNhap}</span>
              <span className="block max-w-48 truncate text-xs text-muted">{session.tenVT ?? session.maVT}</span>
            </span>
          </NavLink>
          <Button variant="ghost" size="sm" onClick={() => setConfirm(true)} icon={<LogOut className="size-4" aria-hidden="true" />}>
            <span className="hidden sm:inline">Đăng xuất</span>
            <span className="sr-only sm:hidden">Đăng xuất</span>
          </Button>
        </div>
      </header>

      <div className="flex">
        <aside className="sticky top-16 hidden h-[calc(100dvh-4rem)] w-60 shrink-0 overflow-y-auto border-r border-line bg-bg lg:block">{sidebar}</aside>
        {open && (
          <div className="fixed inset-0 z-40 lg:hidden" role="dialog" aria-modal="true" aria-label="Menu">
            <div className="absolute inset-0 bg-night/40" onClick={() => setOpen(false)} />
            <div className="animate-fade-up absolute inset-y-0 left-0 w-72 max-w-[85vw] overflow-y-auto bg-bg shadow-xl">
              <div className="flex h-16 items-center justify-between border-b border-line px-4">
                <Wordmark />
                <button type="button" className="rounded-md p-2" aria-label="Đóng menu" onClick={() => setOpen(false)}>
                  <X className="size-5" aria-hidden="true" />
                </button>
              </div>
              {sidebar}
            </div>
          </div>
        )}
        <main id="noi-dung" className="min-w-0 flex-1 px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
          <Outlet />
        </main>
      </div>

      <Modal
        open={confirm}
        onClose={() => setConfirm(false)}
        title="Đăng xuất khỏi hệ thống?"
        footer={
          <>
            <Button variant="secondary" onClick={() => setConfirm(false)}>
              Ở lại
            </Button>
            <Button
              variant="dark"
              loading={leaving}
              onClick={async () => {
                setLeaving(true);
                await logout();
              }}
            >
              Đăng xuất
            </Button>
          </>
        }
      >
        Phiên làm việc trên trình duyệt này sẽ kết thúc. Dữ liệu đã tải sẽ được xóa khỏi trình duyệt.
      </Modal>
    </div>
  );
}

export function PageHeader({ title, description, actions }: { title: ReactNode; description?: ReactNode; actions?: ReactNode }) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div>
        <h1 className="text-2xl font-bold tracking-tight sm:text-[28px]">{title}</h1>
        {description && <p className="mt-1 text-[15px] text-muted">{description}</p>}
      </div>
      {actions && <div className="flex gap-2">{actions}</div>}
    </div>
  );
}
