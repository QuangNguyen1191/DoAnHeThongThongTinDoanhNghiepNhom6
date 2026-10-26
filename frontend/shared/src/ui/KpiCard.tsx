import type { ReactNode } from "react";

/** Thẻ KPI (đặc tả 6.2): không hiện số khi chưa có dữ liệu – hiện "—" và lý do. */
export function KpiCard({ label, value, note, missing }: { label: string; value?: ReactNode; note?: ReactNode; missing?: string | null }) {
  return (
    <div className="rounded-md border border-line bg-bg p-5">
      <p className="text-sm font-medium text-muted">{label}</p>
      <p className="tabular mt-2 text-[30px] font-bold leading-none tracking-tight">{missing ? "—" : value}</p>
      <p className="mt-2 text-[13px] text-muted">{missing ?? note}</p>
    </div>
  );
}
