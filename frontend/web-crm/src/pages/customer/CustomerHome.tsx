import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router";
import { ClipboardList, MessageSquareText, UserRound } from "lucide-react";
import { api } from "@shared/api/client";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { KpiCard } from "@shared/ui/KpiCard";

interface CustomerDashboard {
  hoSo: { hoTen: string; tenHang: string; maHang: string; diem: number; hangKeTiep: string | null; diemCanThem: number | null } | null;
  khaoSatChoLam: { maKS: number; tieuDe: string; hanTraLoi: string; phanTramVoucher: number }[] | null;
  voucher: { maCode: string; trangThai: string }[] | null;
  phanHoiGanDay: unknown[] | null;
  loi: Record<string, { code: number | string; title: string } | null>;
}

/** Chức năng của khách hàng (đề III.4) sau khi đăng nhập: 2 chỉnh sửa thông tin, 3 gửi phản hồi, 4 thực hiện khảo sát. */
const FUNCTIONS = [
  { label: "Chỉnh sửa thông tin", to: "/customer/profile", icon: UserRound },
  { label: "Gửi phản hồi về sản phẩm", to: "/customer/feedback", icon: MessageSquareText },
  { label: "Khảo sát của tôi", to: "/customer/surveys", icon: ClipboardList },
] as const;

/** K0 – trang chủ khách hàng (mobile-first). */
export function CustomerHome() {
  const q = useQuery({ queryKey: ["customer", "dashboard"], queryFn: () => api.get<CustomerDashboard>("/api/customer/dashboard") });
  const d = q.data;
  const conHan = d?.voucher?.filter((v) => v.trangThai === "CON_HAN").length;

  if (q.isError) return <ErrorState error={q.error} onRetry={() => q.refetch()} />;
  return (
    <>
      <PageHeader title={d?.hoSo ? `Xin chào, ${d.hoSo.hoTen}` : "Trang chủ"} description="Điểm thưởng, voucher và khảo sát dành cho bạn." />
      {q.isPending ? (
        <div className="grid gap-4 sm:grid-cols-3">{Array.from({ length: 3 }, (_, i) => <Skeleton key={i} className="h-[118px]" />)}</div>
      ) : (
        <div className="flex flex-col gap-6">
          {d!.hoSo && (
            <section className="relative overflow-hidden rounded-md bg-night p-6 text-white sm:p-8">
              <div aria-hidden="true" className="absolute -right-10 -top-10 size-40 bg-accent" style={{ clipPath: "polygon(35% 0, 100% 0, 100% 100%)" }} />
              <p className="text-xs font-semibold uppercase tracking-[0.2em] text-white/60">Hạng thành viên</p>
              <p className="mt-2 text-3xl font-bold tracking-tight">{d!.hoSo.tenHang}</p>
              <p className="tabular mt-4 text-[15px] text-white/80">
                <span className="text-2xl font-bold text-white">{d!.hoSo.diem.toLocaleString("vi-VN")}</span> điểm tích lũy
              </p>
              {d!.hoSo.hangKeTiep && d!.hoSo.diemCanThem != null && (
                <p className="mt-1 text-sm text-white/60">
                  Còn {d!.hoSo.diemCanThem.toLocaleString("vi-VN")} điểm để lên hạng {d!.hoSo.hangKeTiep}.
                </p>
              )}
            </section>
          )}
          <nav aria-label="Chức năng khách hàng" className="grid gap-2 sm:grid-cols-3">
            {FUNCTIONS.map(({ label, to, icon: Icon }) => (
              <Link key={to} to={to} className="flex items-center gap-3 rounded-md border border-line bg-bg px-4 py-3 text-[15px] font-medium transition-colors hover:border-ink">
                <Icon className="size-[18px] shrink-0 text-ink-soft" aria-hidden="true" />
                {label}
              </Link>
            ))}
          </nav>
          <div className="grid gap-4 sm:grid-cols-3">
            <KpiCard label="Khảo sát chờ bạn" value={d!.khaoSatChoLam?.length} note="Hoàn thành để nhận voucher" missing={d!.loi.khaoSatChoLam?.title} />
            <KpiCard label="Voucher còn dùng được" value={conHan} note={`Trên tổng ${d!.voucher?.length ?? 0} voucher từ khảo sát`} missing={d!.loi.voucher?.title} />
            <KpiCard label="Phản hồi gần đây" value={d!.phanHoiGanDay?.length} note="Góp ý bạn đã gửi" missing={d!.loi.phanHoiGanDay?.title} />
          </div>
          {!!d!.khaoSatChoLam?.length && (
            <section className="rounded-md border border-line bg-bg" aria-labelledby="ks-cho">
              <h2 id="ks-cho" className="border-b border-line px-5 py-4 text-base font-semibold">Khảo sát dành cho bạn</h2>
              <ul className="divide-y divide-line">
                {d!.khaoSatChoLam.map((k) => (
                  <li key={k.maKS} className="flex flex-wrap items-center justify-between gap-2 px-5 py-3">
                    <Link to={`/customer/surveys/${k.maKS}`} className="font-medium hover:underline">{k.tieuDe}</Link>
                    <span className="text-sm text-muted">
                      Voucher {k.phanTramVoucher}% · hạn {new Date(k.hanTraLoi).toLocaleDateString("vi-VN")}
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
