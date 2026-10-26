import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router";
import { ChevronRight, ClipboardList, Ticket } from "lucide-react";
import { api } from "@shared/api/client";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { Badge, EmptyRow, MUC_DICH_KS, Panel, dateTimeVi, dateVi } from "../manager/common";

export interface MySurvey {
  maKS: number;
  tieuDe: string;
  moTa: string | null;
  mucDich: string;
  hanTraLoi: string;
  phanTramVoucher: number;
  ngayGui: string;
  ngayHoanThanh: string | null;
  trangThai: "CHUA_LAM" | "DA_HOAN_THANH";
  coTheThucHien: boolean;
}
export interface MyVoucher {
  maCode: string;
  phanTramGiam: number;
  ngayPhat: string;
  hanDung: string;
  tuKhaoSat: string;
  trangThai: "CON_HAN" | "DA_DUNG" | "HET_HAN";
}

export const useMySurveys = () =>
  useQuery({ queryKey: ["customer", "surveys"], queryFn: () => api.get<MySurvey[]>("/api/customer/surveys") });

const VOUCHER: Record<MyVoucher["trangThai"], { l: string; tone: "success" | "neutral" | "warning" }> = {
  CON_HAN: { l: "Còn hạn", tone: "success" },
  DA_DUNG: { l: "Đã dùng", tone: "neutral" },
  HET_HAN: { l: "Hết hạn", tone: "warning" },
};

/** Nhóm theo việc khách cần làm: chờ thực hiện, đã hoàn thành, đã đóng/quá hạn mà chưa làm. */
function group(list: MySurvey[]) {
  return {
    cho: list.filter((k) => k.coTheThucHien),
    xong: list.filter((k) => k.trangThai === "DA_HOAN_THANH"),
    dong: list.filter((k) => !k.coTheThucHien && k.trangThai !== "DA_HOAN_THANH"),
  };
}

function SurveyRow({ k }: { k: MySurvey }) {
  const status = k.coTheThucHien
    ? <Badge tone="accent">Chờ thực hiện</Badge>
    : k.trangThai === "DA_HOAN_THANH"
      ? <Badge tone="success">Đã hoàn thành</Badge>
      : <Badge tone="warning">Đã đóng</Badge>;
  return (
    <li>
      <Link to={`/customer/surveys/${k.maKS}`} className="group flex items-center gap-4 px-5 py-4 hover:bg-surface">
        <div className="flex min-w-0 flex-1 flex-col gap-1">
          <div className="flex flex-wrap items-center gap-2">
            <span className="font-semibold group-hover:underline">{k.tieuDe}</span>
            {status}
          </div>
          <p className="text-sm text-muted">
            {MUC_DICH_KS[k.mucDich] ?? k.mucDich}
            {k.phanTramVoucher > 0 && <> · tặng voucher <strong className="text-ink">{k.phanTramVoucher}%</strong></>}
            {k.trangThai === "DA_HOAN_THANH" ? <> · hoàn thành {dateVi(k.ngayHoanThanh)}</> : <> · hạn {dateTimeVi(k.hanTraLoi)}</>}
          </p>
        </div>
        <ChevronRight className="size-5 shrink-0 text-muted" aria-hidden="true" />
      </Link>
    </li>
  );
}

/** K4 (KH-4). Khảo sát được gửi tới tài khoản của tôi và voucher nhận được khi hoàn thành. */
export function SurveysPage() {
  const q = useMySurveys();
  const vouchers = useQuery({ queryKey: ["customer", "vouchers"], queryFn: () => api.get<MyVoucher[]>("/api/customer/vouchers") });

  if (q.isError) return <ErrorState error={q.error} onRetry={() => q.refetch()} />;
  const g = q.data ? group(q.data) : null;

  return (
    <>
      <PageHeader title="Khảo sát của tôi" description="Khảo sát cửa hàng gửi riêng cho bạn. Hoàn thành trước hạn để nhận voucher giảm giá." />
      {!g ? (
        <Skeleton className="h-64" />
      ) : (
        <div className="flex flex-col gap-5">
          <Panel title={<span className="flex items-center gap-2"><ClipboardList className="size-[18px]" aria-hidden="true" /> Chờ bạn thực hiện ({g.cho.length})</span>} bodyClass="">
            {g.cho.length ? <ul className="divide-y divide-line" aria-label="Khảo sát chờ thực hiện">{g.cho.map((k) => <SurveyRow key={k.maKS} k={k} />)}</ul>
              : <EmptyRow>Hiện không có khảo sát nào chờ bạn.</EmptyRow>}
          </Panel>
          {(g.xong.length > 0 || g.dong.length > 0) && (
            <Panel title={`Đã hoàn thành hoặc đã đóng (${g.xong.length + g.dong.length})`} bodyClass="">
              <ul className="divide-y divide-line" aria-label="Khảo sát đã hoàn thành hoặc đã đóng">
                {[...g.xong, ...g.dong].map((k) => <SurveyRow key={k.maKS} k={k} />)}
              </ul>
            </Panel>
          )}
          <Panel title={<span className="flex items-center gap-2"><Ticket className="size-[18px]" aria-hidden="true" /> Voucher nhận từ khảo sát</span>} bodyClass="">
            {vouchers.isError ? (
              <div className="p-5"><ErrorState error={vouchers.error} onRetry={() => vouchers.refetch()} /></div>
            ) : vouchers.isPending ? (
              <div className="p-5"><Skeleton className="h-20" /></div>
            ) : vouchers.data.length === 0 ? (
              <EmptyRow>Chưa có voucher. Hoàn thành khảo sát có ưu đãi để nhận.</EmptyRow>
            ) : (
              <ul className="divide-y divide-line" aria-label="Voucher của tôi">
                {vouchers.data.map((v) => (
                  <li key={v.maCode} className="flex flex-wrap items-center gap-x-4 gap-y-1 px-5 py-3.5">
                    <span className="tabular text-2xl font-bold">-{v.phanTramGiam}%</span>
                    <span className="flex min-w-0 flex-1 flex-col">
                      <span className="font-mono text-[15px] font-semibold">{v.maCode}</span>
                      <span className="truncate text-sm text-muted">Từ: {v.tuKhaoSat} · dùng đến {dateVi(v.hanDung)}</span>
                    </span>
                    <Badge tone={VOUCHER[v.trangThai].tone}>{VOUCHER[v.trangThai].l}</Badge>
                  </li>
                ))}
              </ul>
            )}
          </Panel>
        </div>
      )}
    </>
  );
}
