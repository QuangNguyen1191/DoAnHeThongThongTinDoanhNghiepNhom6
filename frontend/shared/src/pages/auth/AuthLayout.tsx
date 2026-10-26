import type { ReactNode } from "react";
import { Link } from "react-router";
import { KeyRound, LockKeyhole, ScrollText, ShieldCheck, ShoppingBag, UserCog, UsersRound } from "lucide-react";
import { useAuth } from "../../auth/AuthProvider";
import { Wordmark } from "../../ui/Wordmark";
import { cn } from "../../ui/cn";

type Intro = {
  sub: string;
  eyebrow: string;
  headline: ReactNode;
  lead: string;
  items: { icon: typeof ShoppingBag; title: string; desc: string }[];
  note: string;
};

/** Nội dung cột trái theo ứng dụng: web-crm (Khách hàng, Quản lý) và web-admin (chỉ Admin) có trang đăng nhập riêng. */
const INTRO: Record<"crm" | "admin", Intro> = {
  crm: {
    sub: "Customer Relationship Management",
    eyebrow: "Hệ thống quản lý quan hệ khách hàng",
    headline: (
      <>
        Hiểu từng khách hàng.
        <br />
        Phục vụ tốt hơn <span className="whitespace-nowrap text-[#ff4d5e]">mỗi ngày.</span>
      </>
    ),
    lead: "Một trang đăng nhập cho khách hàng và nhân viên cửa hàng. Hệ thống nhận diện vai trò của tài khoản và đưa bạn đến đúng khu vực.",
    items: [
      { icon: ShoppingBag, title: "Khách hàng", desc: "Điểm thưởng, hạng thành viên, voucher và lịch sử mua hàng." },
      { icon: UsersRound, title: "Quản lý & CSKH", desc: "Hồ sơ khách hàng 360°, phản hồi, khảo sát và báo cáo." },
    ],
    note: "Phiên làm việc tự kết thúc sau 30 phút không thao tác.",
  },
  admin: {
    sub: "Quản trị hệ thống",
    eyebrow: "Khu vực quản trị · Truy cập hạn chế",
    headline: (
      <>
        Quản trị an toàn.
        <br />
        Kiểm soát <span className="whitespace-nowrap text-[#ff4d5e]">từng quyền.</span>
      </>
    ),
    lead: "Trang đăng nhập dành riêng cho quản trị viên hệ thống. Tài khoản khách hàng và nhân viên cửa hàng không đăng nhập được tại đây.",
    items: [
      { icon: UserCog, title: "Tài khoản nhân viên", desc: "Tạo tài khoản, khóa và mở, cấp mật khẩu tạm, đổi vai trò." },
      { icon: KeyRound, title: "Vai trò và quyền", desc: "Gán quyền chức năng cho từng vai trò, đúng việc, đủ dùng." },
      { icon: ScrollText, title: "Nhật ký hệ thống", desc: "Mọi lần đăng nhập và thao tác quản trị đều được ghi lại." },
    ],
    note: "Phiên quản trị tự kết thúc sau 30 phút không thao tác.",
  },
};

/**
 * Bố cục chung của các trang xác thực (/login, /register, /forgot-password, /dat-lai-mat-khau, /change-password).
 * Desktop: cột trái giới thiệu (nền đen, lưới mảnh), cột phải là biểu mẫu. Mobile: chỉ biểu mẫu.
 * web-admin dùng cùng bố cục, khác nội dung và có nhãn "Khu vực hạn chế".
 */
export function AuthLayout({ children, wide = false }: { children: ReactNode; wide?: boolean }) {
  const { app } = useAuth();
  const intro = INTRO[app];
  const admin = app === "admin";

  return (
    <div className="grid min-h-dvh lg:grid-cols-[minmax(0,5fr)_minmax(0,6fr)] xl:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
      <aside className="on-dark relative hidden overflow-hidden bg-night text-white lg:sticky lg:top-0 lg:flex lg:h-dvh lg:flex-col lg:justify-between lg:p-12 xl:p-16">
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-0 opacity-100"
          style={{
            backgroundImage:
              "linear-gradient(rgb(255 255 255 / 0.045) 1px, transparent 1px), linear-gradient(90deg, rgb(255 255 255 / 0.045) 1px, transparent 1px)",
            backgroundSize: "72px 72px",
            maskImage: "linear-gradient(180deg, black 0%, black 55%, transparent 100%)",
          }}
        />
        <div aria-hidden="true" className="absolute bottom-0 right-0 size-24 bg-accent xl:size-28" />

        <div className="relative flex items-center gap-3">
          <Link to="/login" className="inline-block rounded-sm">
            <Wordmark tone="light" sub={intro.sub} />
          </Link>
          {admin && <AdminChip tone="light" />}
        </div>

        <div className="relative max-w-lg">
          <p className="text-xs font-semibold uppercase tracking-[0.24em] text-white/55">{intro.eyebrow}</p>
          <h2 className="mt-5 text-[38px] font-bold leading-[1.1] tracking-[-0.02em] [text-wrap:balance] xl:text-[44px]">{intro.headline}</h2>
          <p className="mt-5 max-w-md text-[15.5px] leading-relaxed text-white/70">{intro.lead}</p>
          <ul className="mt-10 divide-y divide-white/10 border-y border-white/10">
            {intro.items.map(({ icon: Icon, title, desc }) => (
              <li key={title} className="flex gap-4 py-4">
                <span className="grid size-10 shrink-0 place-items-center rounded-md border border-white/15 bg-white/[0.04]">
                  <Icon className="size-[18px]" aria-hidden="true" />
                </span>
                <span>
                  <span className="block text-[15px] font-semibold">{title}</span>
                  <span className="mt-0.5 block text-sm text-white/60">{desc}</span>
                </span>
              </li>
            ))}
          </ul>
        </div>

        <p className="relative flex items-center gap-2 text-[13px] text-white/45">
          <ShieldCheck className="size-4" aria-hidden="true" />
          {intro.note}
        </p>
      </aside>

      <div className="flex min-h-dvh flex-col bg-bg">
        <header className="flex items-center justify-between gap-3 border-b border-line px-5 py-4 lg:hidden">
          <Link to="/login" className="rounded-sm">
            <Wordmark sub={admin ? intro.sub : "Customer Relationship"} />
          </Link>
          {admin && <AdminChip />}
        </header>
        <main className="flex flex-1 items-start justify-center px-5 py-10 sm:items-center sm:px-8 lg:px-12 lg:py-14">
          <div className={cn("animate-fade-up w-full", wide ? "max-w-[600px]" : "max-w-[400px]")}>{children}</div>
        </main>
        <footer className="flex flex-wrap items-center justify-between gap-2 px-5 pb-6 text-[13px] text-muted sm:px-8 lg:px-12">
          <span>© 2026 CRM Uniqlo · Đồ án HTTTDN – SGU</span>
          <span>Dữ liệu trong hệ thống là dữ liệu minh họa</span>
        </footer>
      </div>
    </div>
  );
}

/** Nhãn nhận biết khu vực quản trị (đi kèm chữ, không chỉ dựa vào màu). */
function AdminChip({ tone = "dark" }: { tone?: "dark" | "light" }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-sm border px-2 py-1 text-[11px] font-semibold uppercase tracking-[0.14em]",
        tone === "light" ? "border-white/25 text-white/80" : "border-line-strong text-ink-soft",
      )}
    >
      <LockKeyhole className="size-3.5" aria-hidden="true" />
      Admin
    </span>
  );
}

export function AuthHeading({ eyebrow, title, children }: { eyebrow?: string; title: string; children?: ReactNode }) {
  return (
    <div className="mb-8">
      {eyebrow && <p className="mb-3 text-xs font-semibold uppercase tracking-[0.2em] text-accent">{eyebrow}</p>}
      <h1 className="text-[28px] font-bold leading-tight tracking-[-0.015em] sm:text-[32px]">{title}</h1>
      {children && <p className="mt-2 text-[15px] leading-relaxed text-muted">{children}</p>}
    </div>
  );
}
