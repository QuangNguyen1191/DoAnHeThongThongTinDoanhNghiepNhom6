import { useQuery } from "@tanstack/react-query";
import { Link, useParams } from "react-router";
import { ArrowLeft } from "lucide-react";
import { api } from "@shared/api/client";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { KpiCard } from "@shared/ui/KpiCard";
import { BarList, Badge, LOAI_CAU_HOI, MUC_DICH_KS, Panel, TRANG_THAI_KS, dateVi, pct, toneTrangThaiKS } from "./common";

interface Stats {
  tongQuan: {
    maKS: number; tieuDe: string; mucDich: string; tenSP: string | null; trangThai: "NHAP" | "DA_GUI" | "DA_DONG";
    ngayPhatHanh: string | null; hanTraLoi: string; soNguoiNhan: number; soHoanThanh: number; tyLePhanHoiPhanTram: number | null;
  };
  luaChon: { cauSo: number; cauHoi: string; loaiCauHoi: string; luaChonSo: number; luaChon: string; soLuotChon: number; tyLePhanTram: number | null }[];
  thangDiem: { cauSo: number; cauHoi: string; soNguoiTraLoi: number; diemTrungBinh: number | null; diem1: number; diem2: number; diem3: number; diem4: number; diem5: number }[];
  tuLuan: { cauSo: number; cauHoi: string; noiDungTuLuan: string | null }[];
}

type Block =
  | { cauSo: number; cauHoi: string; kind: "choice"; loai: string; rows: Stats["luaChon"] }
  | { cauSo: number; cauHoi: string; kind: "scale"; row: Stats["thangDiem"][number] }
  | { cauSo: number; cauHoi: string; kind: "text"; answers: string[] };

function blocks(s: Stats): Block[] {
  const out = new Map<number, Block>();
  for (const r of s.luaChon) {
    const b = out.get(r.cauSo);
    if (b && b.kind === "choice") b.rows.push(r);
    else out.set(r.cauSo, { cauSo: r.cauSo, cauHoi: r.cauHoi, kind: "choice", loai: r.loaiCauHoi, rows: [r] });
  }
  for (const r of s.thangDiem) out.set(r.cauSo, { cauSo: r.cauSo, cauHoi: r.cauHoi, kind: "scale", row: r });
  for (const r of s.tuLuan) {
    const b = out.get(r.cauSo);
    const text = r.noiDungTuLuan?.trim();
    if (b && b.kind === "text") { if (text) b.answers.push(text); }
    else out.set(r.cauSo, { cauSo: r.cauSo, cauHoi: r.cauHoi, kind: "text", answers: text ? [text] : [] });
  }
  return [...out.values()].sort((a, b) => a.cauSo - b.cauSo);
}

/** Q15 (QL-7). Thống kê kết quả một khảo sát: tỷ lệ phản hồi, phân bố lựa chọn, điểm trung bình, câu trả lời tự luận (ẩn danh). */
export function SurveyStatsPage() {
  const { maKS } = useParams();
  const q = useQuery({ queryKey: ["manager", "survey-stats", Number(maKS)], queryFn: () => api.get<Stats>(`/api/manager/surveys/${maKS}/stats`) });
  if (q.isError) return <ErrorState error={q.error} onRetry={() => q.refetch()} />;
  if (q.isPending) return <Skeleton className="h-96" />;
  const t = q.data.tongQuan;
  const list = blocks(q.data);
  const avg = q.data.thangDiem.filter((x) => x.diemTrungBinh != null);

  return (
    <>
      <Link to={`/manager/surveys/${maKS}`} className="mb-3 inline-flex items-center gap-1.5 text-sm font-medium text-ink-soft hover:text-ink">
        <ArrowLeft className="size-4" aria-hidden="true" /> Về khảo sát
      </Link>
      <PageHeader
        title={`Thống kê: ${t.tieuDe}`}
        description={<span className="inline-flex flex-wrap items-center gap-2"><Badge tone={toneTrangThaiKS(t.trangThai)}>{TRANG_THAI_KS[t.trangThai]}</Badge>{MUC_DICH_KS[t.mucDich]}{t.tenSP ? ` · ${t.tenSP}` : ""} · phát hành {dateVi(t.ngayPhatHanh)} · hạn {dateVi(t.hanTraLoi)}</span>}
      />
      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <KpiCard label="Đã gửi" value={t.soNguoiNhan} note="Tài khoản khách hàng nhận khảo sát" />
        <KpiCard label="Đã hoàn thành" value={t.soHoanThanh} note="Khách đã nộp bài" />
        <KpiCard label="Tỷ lệ phản hồi" value={pct(t.tyLePhanHoiPhanTram ?? 0)} note="Hoàn thành / đã gửi" />
        <KpiCard
          label="Điểm hài lòng TB"
          value={avg.length ? (avg.reduce((s, x) => s + x.diemTrungBinh! * x.soNguoiTraLoi, 0) / Math.max(1, avg.reduce((s, x) => s + x.soNguoiTraLoi, 0))).toLocaleString("vi-VN", { maximumFractionDigits: 2 }) + " / 5" : undefined}
          note="Trung bình các câu thang điểm"
          missing={avg.length ? null : "Chưa có câu thang điểm được trả lời"}
        />
      </div>

      {list.length === 0 ? (
        <Panel><p className="text-center text-sm text-muted">Khảo sát chưa có câu hỏi.</p></Panel>
      ) : (
        <div className="grid gap-5 xl:grid-cols-2">
          {list.map((b) => (
            <Panel key={b.cauSo} title={<span>Câu {b.cauSo}. {b.cauHoi}</span>} actions={<span className="text-xs text-muted">{b.kind === "choice" ? LOAI_CAU_HOI[b.loai] : b.kind === "scale" ? LOAI_CAU_HOI.THANG_DIEM : LOAI_CAU_HOI.TU_LUAN}</span>}>
              {b.kind === "choice" && (
                <BarList
                  label={`Phân bố lựa chọn câu ${b.cauSo}`}
                  max={100}
                  rows={b.rows.map((r) => ({
                    key: String(r.luaChonSo), label: r.luaChon, value: Number(r.tyLePhanTram ?? 0),
                    display: `${r.soLuotChon} · ${pct(r.tyLePhanTram ?? 0)}`, detail: `${r.luaChon}: ${r.soLuotChon} lượt chọn (${pct(r.tyLePhanTram ?? 0)} người trả lời câu này)`,
                  }))}
                />
              )}
              {b.kind === "scale" && (
                <>
                  <p className="mb-4 text-[15px]">
                    Điểm trung bình <strong className="tabular text-2xl">{b.row.diemTrungBinh != null ? Number(b.row.diemTrungBinh).toLocaleString("vi-VN") : "—"}</strong>
                    <span className="text-muted"> / 5 · {b.row.soNguoiTraLoi} người trả lời</span>
                  </p>
                  <BarList
                    label={`Phân bố điểm câu ${b.cauSo}`}
                    rows={[5, 4, 3, 2, 1].map((d) => {
                      const n = b.row[`diem${d}` as "diem1"];
                      return { key: String(d), label: `${d} điểm`, value: n, display: `${n} · ${pct(b.row.soNguoiTraLoi ? (100 * n) / b.row.soNguoiTraLoi : 0)}`, detail: `${d} điểm: ${n} người` };
                    })}
                  />
                </>
              )}
              {b.kind === "text" && (
                b.answers.length === 0 ? <p className="text-sm text-muted">Chưa có câu trả lời.</p> : (
                  <ul className="flex max-h-72 flex-col gap-2 overflow-y-auto text-[15px]">
                    {b.answers.map((a, i) => <li key={i} className="rounded-md bg-surface px-3 py-2">“{a}”</li>)}
                  </ul>
                )
              )}
            </Panel>
          ))}
        </div>
      )}
    </>
  );
}
