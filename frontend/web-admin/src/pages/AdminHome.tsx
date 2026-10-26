import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router";
import { BriefcaseBusiness, FileText, KeyRound, ScrollText, ServerCog, UserCog, UserPlus, UsersRound } from "lucide-react";
import { api } from "@shared/api/client";
import { useAuth } from "@shared/auth/AuthProvider";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { KpiCard } from "@shared/ui/KpiCard";
import { HANH_DONG } from "./common";

interface BlockError { code: number | string; title: string }
interface AdminDashboard {
  taiKhoan: { tong: number; hoatDong: number; daKhoa: number; nhanVien: number; khachHang: number; phaiDoiMatKhau: number } | null;
  nhatKyGanDay: { items: { maNK: number; thoiGian: string; tenDangNhap: string | null; hanhDong: string; doiTuong: string | null }[] } | null;
  loi: Record<string, BlockError | null>;
}

/** Chức năng Admin: thêm/xóa/phân quyền account (đề II.2) và quản lý tổng bộ; lối tắt theo quyền. */
const FUNCTIONS = [
  { n: 1, label: "Tạo tài khoản nhân viên", to: "/admin/accounts?tao=1", perms: ["AD_TAI_KHOAN", "AD_PHAN_QUYEN"], icon: UserPlus },
  { n: 2, label: "Khóa, mở khóa, xóa tài khoản", to: "/admin/accounts", perms: ["AD_TAI_KHOAN"], icon: UsersRound },
  { n: 3, label: "Phân quyền cho tài khoản", to: "/admin/accounts", perms: ["AD_PHAN_QUYEN"], icon: UserCog },
  { n: 4, label: "Vai trò và ma trận quyền", to: "/admin/roles", perms: ["AD_PHAN_QUYEN"], icon: KeyRound },
  { n: 5, label: "Hồ sơ nhân viên", to: "/admin/employees", perms: ["AD_TRA_CUU"], icon: BriefcaseBusiness },
  { n: 6, label: "Nạp hóa đơn, đổi trả", to: "/admin/invoices", perms: ["AD_NAP_GIAO_DICH"], icon: FileText },
  { n: 7, label: "Nhật ký hệ thống", to: "/admin/audit-log", perms: ["AD_NHAT_KY"], icon: ScrollText },
  { n: 8, label: "Trạng thái hệ thống", to: "/admin/system", perms: [], icon: ServerCog },
] as const;

const reason = (e?: BlockError | null) => (e ? (e.code === 50003 ? "Vai trò của bạn không có quyền xem mục này." : e.title) : null);

/** A0 – dashboard quản trị. */
export function AdminHome() {
  const { session } = useAuth();
  const q = useQuery({ queryKey: ["admin", "dashboard"], queryFn: () => api.get<AdminDashboard>("/api/admin/dashboard") });
  const d = q.data;
  const tk = d?.taiKhoan;
  return (
    <>
      <PageHeader title="Tổng quan hệ thống" description={`${session?.hoTen ?? session?.tenDangNhap} · ${session?.tenVT ?? ""}`} />
      {q.isError ? (
        <ErrorState error={q.error} onRetry={() => q.refetch()} />
      ) : (
        <div className="flex flex-col gap-6">
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            {q.isPending ? (
              Array.from({ length: 4 }, (_, i) => <Skeleton key={i} className="h-[118px]" />)
            ) : (
              <>
                <KpiCard label="Tổng tài khoản" value={tk?.tong} note={`${tk?.nhanVien ?? 0} nhân viên · ${tk?.khachHang ?? 0} khách hàng`} missing={reason(d!.loi.taiKhoan)} />
                <KpiCard label="Đang hoạt động" value={tk?.hoatDong} note="Đăng nhập được" missing={reason(d!.loi.taiKhoan)} />
                <KpiCard label="Đã khóa" value={tk?.daKhoa} note="Không đăng nhập được" missing={reason(d!.loi.taiKhoan)} />
                <KpiCard label="Chờ đổi mật khẩu" value={tk?.phaiDoiMatKhau} note="Đang dùng mật khẩu tạm" missing={reason(d!.loi.taiKhoan)} />
              </>
            )}
          </div>
          <nav aria-label="Chức năng quản trị" className="grid gap-2 sm:grid-cols-2 xl:grid-cols-4">
            {FUNCTIONS.filter((f) => f.perms.every((p) => session?.quyen.includes(p))).map(({ n, label, to, icon: Icon }) => (
              <Link key={n} to={to} className="flex items-center gap-3 rounded-md border border-line bg-bg px-4 py-3 text-[15px] font-medium transition-colors hover:border-ink">
                <Icon className="size-[18px] shrink-0 text-ink-soft" aria-hidden="true" />
                <span className="flex-1">{label}</span>
                <span className="tabular text-xs text-muted">{n}</span>
              </Link>
            ))}
          </nav>
          <section className="rounded-md border border-line bg-bg" aria-labelledby="nk">
            <h2 id="nk" className="flex items-center justify-between border-b border-line px-5 py-4 text-base font-semibold">Hoạt động gần đây{d && !d.loi.nhatKy && <Link to="/admin/audit-log" className="text-sm font-medium text-ink-soft underline-offset-2 hover:underline">Xem nhật ký</Link>}</h2>
            {q.isPending ? (
              <div className="p-5"><Skeleton className="h-32" /></div>
            ) : d!.loi.nhatKy ? (
              <p className="px-5 py-6 text-sm text-muted">{reason(d!.loi.nhatKy)}</p>
            ) : (
              <ul className="divide-y divide-line">
                {d!.nhatKyGanDay?.items.slice(0, 8).map((n) => (
                  <li key={n.maNK} className="grid grid-cols-[1fr_auto] gap-4 px-5 py-3 text-[15px] sm:grid-cols-[180px_1fr_auto]">
                    <span className="font-mono text-sm">{n.tenDangNhap ?? "—"}</span>
                    <span className="hidden text-ink-soft sm:block">{HANH_DONG[n.hanhDong] ?? n.hanhDong}{n.doiTuong ? ` · ${n.doiTuong}` : ""}</span>
                    <span className="tabular text-sm text-muted">{new Date(n.thoiGian).toLocaleString("vi-VN")}</span>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      )}
    </>
  );
}
