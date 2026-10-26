import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Download } from "lucide-react";
import { api } from "@shared/api/client";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { cn } from "@shared/ui/cn";
import { KpiCard } from "@shared/ui/KpiCard";
import { BarList, Panel, Table, pct, td } from "./common";

interface Share { soKhach: number; tyLePhanTram: number | null }
interface Demographics {
  nhomTuoi: (Share & { nhomTuoi: string })[];
  gioiTinh: (Share & { gioiTinh: string })[];
  tinhThanh: (Share & { tinhThanh: string })[];
  hang: (Share & { tenHang: string })[];
}
interface Interests {
  theoLoai: { tenLoai: string; soKhachQuanTam: number; tyLeQuanTamPhanTram: number | null; soKhachDaMua: number; soKhachQuanTamVaDaMua: number; tyLeChuyenDoiPhanTram: number | null }[];
  theoNhomTuoi: { nhomTuoi: string; tenLoai: string; soKhach: number; tyLeTrongNhomPhanTram: number | null }[];
}

function Csv({ path, bang }: { path: string; bang: string }) {
  return (
    <a href={`/api/manager/reports/${path}?format=csv&bang=${bang}`} download className="inline-flex items-center gap-1.5 text-sm font-medium text-ink-soft hover:text-ink">
      <Download className="size-4" aria-hidden="true" /> CSV
    </a>
  );
}

const shareRows = <T extends Share>(rows: T[], label: (r: T) => string) =>
  rows.map((r) => ({ key: label(r), label: label(r), value: Number(r.tyLePhanTram ?? 0), display: `${r.soKhach} · ${pct(r.tyLePhanTram ?? 0)}`, detail: `${label(r)}: ${r.soKhach} khách (${pct(r.tyLePhanTram ?? 0)})` }));

function AgeTab() {
  const q = useQuery({ queryKey: ["manager", "reports", "demographics"], queryFn: () => api.get<Demographics>("/api/manager/reports/demographics") });
  if (q.isError) return <ErrorState error={q.error} onRetry={() => q.refetch()} />;
  if (q.isPending) return <Skeleton className="h-96" />;
  const d = q.data;
  const total = d.gioiTinh.reduce((s, r) => s + r.soKhach, 0);
  const topAge = [...d.nhomTuoi].filter((r) => r.nhomTuoi !== "Không rõ").sort((a, b) => b.soKhach - a.soKhach)[0];
  return (
    <div className="flex flex-col gap-5">
      <div className="grid gap-4 sm:grid-cols-3">
        <KpiCard label="Khách hàng đang hoạt động" value={total} note="Không tính hồ sơ đã xóa" />
        <KpiCard label="Nhóm tuổi đông nhất" value={topAge?.nhomTuoi ?? "—"} note={topAge ? `${topAge.soKhach} khách · ${pct(topAge.tyLePhanTram)}` : "Chưa có dữ liệu"} />
        <KpiCard label="Số nhóm tuổi" value={d.nhomTuoi.length} note="Theo ngày sinh trong hồ sơ" />
      </div>
      <Panel title="Tỷ lệ theo độ tuổi" actions={<Csv path="demographics" bang="nhomTuoi" />}>
        <BarList label="Tỷ lệ khách hàng theo nhóm tuổi" max={100} rows={shareRows(d.nhomTuoi, (r) => r.nhomTuoi)} />
      </Panel>
      <div className="grid gap-5 lg:grid-cols-3">
        <Panel title="Giới tính" actions={<Csv path="demographics" bang="gioiTinh" />}>
          <BarList label="Tỷ lệ theo giới tính" max={100} rows={shareRows(d.gioiTinh, (r) => r.gioiTinh)} />
        </Panel>
        <Panel title="Hạng thành viên" actions={<Csv path="demographics" bang="hang" />}>
          <BarList label="Tỷ lệ theo hạng" max={100} rows={shareRows(d.hang, (r) => r.tenHang)} />
        </Panel>
        <Panel title="Tỉnh/thành" actions={<Csv path="demographics" bang="tinhThanh" />}>
          <BarList label="Tỷ lệ theo tỉnh/thành" max={100} rows={shareRows(d.tinhThanh, (r) => r.tinhThanh)} />
        </Panel>
      </div>
    </div>
  );
}

function InterestTab() {
  const q = useQuery({ queryKey: ["manager", "reports", "interests"], queryFn: () => api.get<Interests>("/api/manager/reports/interests") });
  if (q.isError) return <ErrorState error={q.error} onRetry={() => q.refetch()} />;
  if (q.isPending) return <Skeleton className="h-96" />;
  const d = q.data;
  const ages = [...new Set(d.theoNhomTuoi.map((r) => r.nhomTuoi))];
  const cats = d.theoLoai.map((r) => r.tenLoai).filter((c) => d.theoNhomTuoi.some((r) => r.tenLoai === c));
  const cell = (a: string, c: string) => d.theoNhomTuoi.find((r) => r.nhomTuoi === a && r.tenLoai === c);
  return (
    <div className="flex flex-col gap-5">
      <Panel title="Tỷ lệ khách quan tâm theo loại sản phẩm" actions={<Csv path="interests" bang="theoLoai" />}>
        <BarList
          label="Tỷ lệ khách quan tâm từng loại sản phẩm"
          max={100}
          rows={d.theoLoai.map((r) => ({
            key: r.tenLoai, label: r.tenLoai, value: Number(r.tyLeQuanTamPhanTram ?? 0),
            display: `${r.soKhachQuanTam} · ${pct(r.tyLeQuanTamPhanTram ?? 0)}`, detail: `${r.tenLoai}: ${r.soKhachQuanTam} khách quan tâm`,
          }))}
        />
      </Panel>
      <Panel title="Sở thích so với hành vi mua" bodyClass="">
        <Table label="Sở thích so với hành vi mua" head={["Loại sản phẩm", "Quan tâm", "Đã mua", "Quan tâm và đã mua", "Tỷ lệ chuyển đổi"]}>
          {d.theoLoai.map((r) => (
            <tr key={r.tenLoai}>
              <td className={`${td} font-medium`}>{r.tenLoai}</td>
              <td className={`${td} tabular`}>{r.soKhachQuanTam} ({pct(r.tyLeQuanTamPhanTram ?? 0)})</td>
              <td className={`${td} tabular`}>{r.soKhachDaMua}</td>
              <td className={`${td} tabular`}>{r.soKhachQuanTamVaDaMua}</td>
              <td className={`${td} tabular`}>{pct(r.tyLeChuyenDoiPhanTram)}</td>
            </tr>
          ))}
        </Table>
      </Panel>
      <Panel title="Sở thích theo nhóm tuổi (% khách trong nhóm)" actions={<Csv path="interests" bang="theoNhomTuoi" />} bodyClass="">
        {ages.length === 0 ? <p className="p-5 text-sm text-muted">Chưa có dữ liệu.</p> : (
          <Table label="Sở thích theo nhóm tuổi" head={["Nhóm tuổi", ...cats]}>
            {ages.map((a) => (
              <tr key={a}>
                <th scope="row" className={`${td} text-left font-medium`}>{a}</th>
                {cats.map((c) => {
                  const r = cell(a, c);
                  const v = Number(r?.tyLeTrongNhomPhanTram ?? 0);
                  return (
                    <td key={c} className={`${td} tabular`} title={r ? `${a} · ${c}: ${r.soKhach} khách (${pct(v)})` : undefined}>
                      <span className="relative block rounded-sm px-2 py-1" style={{ background: v ? `color-mix(in srgb, var(--color-chart) ${Math.round(8 + v * 0.5)}%, transparent)` : undefined }}>
                        <span className={cn(v >= 60 && "font-semibold")}>{r ? `${pct(v)}` : "—"}</span>
                      </span>
                    </td>
                  );
                })}
              </tr>
            ))}
          </Table>
        )}
      </Panel>
    </div>
  );
}

const TABS = [
  { v: "age", l: "Độ tuổi và cơ cấu khách hàng" },
  { v: "interest", l: "Sở thích" },
] as const;

/** Q9–Q10 (QL-5). Báo cáo khách hàng: tỷ lệ độ tuổi (kèm giới tính, hạng, khu vực) và sở thích. */
export function ReportsPage() {
  const [tab, setTab] = useState<(typeof TABS)[number]["v"]>("age");
  return (
    <>
      <PageHeader title="Báo cáo khách hàng" description="Tỷ lệ độ tuổi, cơ cấu và sở thích của khách hàng đang hoạt động. Tải từng bảng dạng CSV để mở bằng Excel." />
      <div className="mb-5 flex flex-wrap gap-1 border-b border-line" role="tablist" aria-label="Loại báo cáo">
        {TABS.map((t) => (
          <button key={t.v} type="button" role="tab" aria-selected={tab === t.v} onClick={() => setTab(t.v)}
            className={cn("-mb-px border-b-2 px-4 py-2.5 text-[15px] font-medium", tab === t.v ? "border-accent text-ink" : "border-transparent text-muted hover:text-ink")}>
            {t.l}
          </button>
        ))}
      </div>
      {tab === "age" ? <AgeTab /> : <InterestTab />}
    </>
  );
}
