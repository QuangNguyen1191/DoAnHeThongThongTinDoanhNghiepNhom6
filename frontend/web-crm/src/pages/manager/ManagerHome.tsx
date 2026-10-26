import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router";
import { BarChart3, ClipboardList, FileBarChart2, Lock, MessageSquareText, Trash2, UserPlus } from "lucide-react";
import { api } from "@shared/api/client";
import { useAuth } from "@shared/auth/AuthProvider";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { KpiCard } from "@shared/ui/KpiCard";

interface Paged<T> { items: T[]; tongSoDong: number }
interface BlockError { code: number | string; title: string }
interface ManagerDashboard {
  khachMoi: Paged<{ maKH: number; hoTen: string; tenHang: string; ngayDangKy: string }> | null;
  phanHoiMoi: Paged<unknown> | null;
  khaoSatDangMo: unknown[] | null;
  theoHang: { tenHang: string; soKhach: number; tyLePhanTram: number }[] | null;
  loi: Record<string, BlockError | null>;
}

/** 7 chức năng của người quản lý (đề III.4), lối tắt theo quyền. */
const FUNCTIONS = [
  { n: 1, label: "Thêm khách hàng mới", to: "/manager/customers/new", perm: "QL_KH_THEM", icon: UserPlus },
  { n: 2, label: "Xóa khách hàng", to: "/manager/customers", perm: "QL_KH_XOA", icon: Trash2 },
  { n: 3, label: "Khóa tài khoản khách hàng", to: "/manager/customers", perm: "QL_KH_KHOA", icon: Lock },
  { n: 4, label: "Tiếp nhận phản hồi", to: "/manager/feedback", perm: "QL_PH_XEM", icon: MessageSquareText },
  { n: 5, label: "Báo cáo độ tuổi, sở thích", to: "/manager/reports", perm: "QL_BAO_CAO", icon: FileBarChart2 },
  { n: 6, label: "Tạo và gửi khảo sát", to: "/manager/surveys/new", perm: "QL_KS_QUAN_LY", icon: ClipboardList },
  { n: 7, label: "Thống kê kết quả khảo sát", to: "/manager/surveys", perm: "QL_KS_THONG_KE", icon: BarChart3 },
] as const;

const reason = (e?: BlockError | null) => (e ? (e.code === 50003 ? "Vai trò của bạn không có quyền xem mục này." : e.title) : null);
const dateVi = (iso: string) => new Date(iso).toLocaleDateString("vi-VN");

/** Q0 – dashboard vận hành: khối nào thiếu quyền thì API trả lỗi riêng cho khối đó. */
export function ManagerHome() {
  const { session } = useAuth();
  const q = useQuery({ queryKey: ["manager", "dashboard"], queryFn: () => api.get<ManagerDashboard>("/api/manager/dashboard") });
  const d = q.data;
  const vip = d?.theoHang?.find((h) => h.tenHang === "VIP");

  return (
    <>
      <PageHeader title={`Xin chào, ${session?.hoTen ?? session?.tenDangNhap}`} description={`${session?.tenVT ?? ""} · Tổng quan hoạt động chăm sóc khách hàng.`} />
      {q.isError ? (
        <ErrorState error={q.error} onRetry={() => q.refetch()} />
      ) : (
        <div className="flex flex-col gap-6">
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            {q.isPending ? (
              Array.from({ length: 4 }, (_, i) => <Skeleton key={i} className="h-[118px]" />)
            ) : (
              <>
                <KpiCard label="Khách hàng đang hoạt động" value={d!.khachMoi?.tongSoDong} note="Hồ sơ chưa xóa" missing={reason(d!.loi.khachMoi)} />
                <KpiCard label="Phản hồi mới" value={d!.phanHoiMoi?.tongSoDong} note="Chờ tiếp nhận" missing={reason(d!.loi.phanHoiMoi)} />
                <KpiCard label="Khảo sát đang mở" value={d!.khaoSatDangMo?.length} note="Đã gửi, còn hạn" missing={reason(d!.loi.khaoSatDangMo)} />
                <KpiCard label="Khách hạng VIP" value={vip?.soKhach ?? 0} note={`${(vip?.tyLePhanTram ?? 0).toLocaleString("vi-VN")}% tổng số khách`} missing={reason(d!.loi.theoHang)} />
              </>
            )}
          </div>
          <nav aria-label="Chức năng quản lý" className="grid gap-2 sm:grid-cols-2 xl:grid-cols-4">
            {FUNCTIONS.filter((f) => session?.quyen.includes(f.perm)).map(({ n, label, to, icon: Icon }) => (
              <Link key={n} to={to} className="flex items-center gap-3 rounded-md border border-line bg-bg px-4 py-3 text-[15px] font-medium transition-colors hover:border-ink">
                <Icon className="size-[18px] shrink-0 text-ink-soft" aria-hidden="true" />
                <span className="flex-1">{label}</span>
                <span className="tabular text-xs text-muted">{n}</span>
              </Link>
            ))}
          </nav>
          {d?.khachMoi && (
            <section className="rounded-md border border-line bg-bg" aria-labelledby="kh-moi">
              <h2 id="kh-moi" className="border-b border-line px-5 py-4 text-base font-semibold">Khách hàng đăng ký gần đây</h2>
              <ul className="divide-y divide-line">
                {d.khachMoi.items.slice(0, 5).map((k) => (
                  <li key={k.maKH} className="flex items-center justify-between gap-4 px-5 py-3 text-[15px]">
                    <Link to={`/manager/customers/${k.maKH}`} className="font-medium underline-offset-2 hover:underline">{k.hoTen}</Link>
                    <span className="flex items-center gap-4 text-sm text-muted">
                      <span className={k.tenHang === "VIP" ? "rounded-sm border border-accent px-1.5 text-xs font-semibold text-accent" : ""}>{k.tenHang}</span>
                      <span className="tabular">{dateVi(k.ngayDangKy)}</span>
                    </span>
                  </li>
                ))}
              </ul>
            </section>
          )}
        </div>
      )}
    </>
  );
}
