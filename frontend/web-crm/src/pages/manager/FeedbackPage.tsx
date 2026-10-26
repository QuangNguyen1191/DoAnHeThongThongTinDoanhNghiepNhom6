import { useState } from "react";
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link } from "react-router";
import { Inbox, Star } from "lucide-react";
import { api } from "@shared/api/client";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { Alert } from "@shared/ui/Alert";
import { Button } from "@shared/ui/Button";
import { cn } from "@shared/ui/cn";
import { Field, Select, TextInput } from "@shared/ui/Field";
import { useToast } from "@shared/ui/Toast";
import { Badge, EmptyRow, LOAI_PH, Pager, Panel, TextArea, TRANG_THAI_PH, dateTimeVi, errText, toneTrangThaiPH, useCan, type Paged } from "./common";

interface PhanHoi {
  maPH: number;
  maKH: number;
  tenKhachHang: string;
  maHang: string;
  tenSP: string;
  tenLoai: string;
  loaiPH: string;
  diemDanhGia: number | null;
  noiDung: string;
  ngayGui: string;
  trangThai: "MOI" | "DANG_XU_LY" | "DA_XU_LY";
  nguoiXuLy: string | null;
  ngayTiepNhan: string | null;
  noiDungTraLoi: string | null;
  ngayTraLoi: string | null;
  daMuaSanPham: boolean;
}

const TABS = [
  { v: "MOI", l: "Mới" },
  { v: "DANG_XU_LY", l: "Đang xử lý" },
  { v: "DA_XU_LY", l: "Đã xử lý" },
  { v: "", l: "Tất cả" },
];
const PAGE_SIZE = 10;

function FeedbackItem({ p, canHandle }: { p: PhanHoi; canHandle: boolean }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [loai, setLoai] = useState(p.loaiPH);
  const [reply, setReply] = useState("");
  const [replying, setReplying] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const refresh = () => void qc.invalidateQueries({ queryKey: ["manager"] });

  const accept = useMutation({
    mutationFn: () => api.post(`/api/manager/feedback/${p.maPH}/accept`, { loaiPH: loai !== p.loaiPH ? loai : null }),
    onSuccess: () => { toast("success", `Đã tiếp nhận phản hồi #${p.maPH}.`); refresh(); },
    onError: (e) => setErr(errText(e)),
  });
  const answer = useMutation({
    mutationFn: () => api.post(`/api/manager/feedback/${p.maPH}/reply`, { noiDungTraLoi: reply.trim() }),
    onSuccess: () => { toast("success", `Đã trả lời phản hồi #${p.maPH}.`); refresh(); },
    onError: (e) => setErr(errText(e)),
  });

  return (
    <li className="px-5 py-4" data-testid={`ph-${p.maPH}`}>
      <div className="flex flex-wrap items-center gap-2 text-sm">
        <Badge tone={toneTrangThaiPH(p.trangThai)}>{TRANG_THAI_PH[p.trangThai]}</Badge>
        <Badge tone={p.loaiPH === "KHIEU_NAI" ? "danger" : p.loaiPH === "KHEN" ? "success" : "neutral"}>{LOAI_PH[p.loaiPH]}</Badge>
        <span className="font-semibold">#{p.maPH}</span>
        <Link to={`/manager/customers/${p.maKH}`} className="font-medium underline-offset-2 hover:underline">{p.tenKhachHang}</Link>
        {p.maHang === "VIP" && <Badge tone="accent">VIP</Badge>}
        <span className="text-muted">· {p.tenSP} ({p.tenLoai}){p.daMuaSanPham ? " · đã mua SP" : ""}</span>
        <span className="ml-auto text-muted">{dateTimeVi(p.ngayGui)}</span>
      </div>
      {p.diemDanhGia != null && (
        <p className="mt-2 flex items-center gap-0.5" aria-label={`Đánh giá ${p.diemDanhGia} trên 5 sao`}>
          {Array.from({ length: 5 }, (_, i) => (
            <Star key={i} aria-hidden="true" className={cn("size-4", i < p.diemDanhGia! ? "fill-ink text-ink" : "text-line-strong")} />
          ))}
        </p>
      )}
      <p className="mt-2 whitespace-pre-line text-[15px]">{p.noiDung}</p>

      {p.trangThai !== "MOI" && p.nguoiXuLy && (
        <p className="mt-2 text-sm text-muted">Tiếp nhận bởi {p.nguoiXuLy} lúc {dateTimeVi(p.ngayTiepNhan)}</p>
      )}
      {p.noiDungTraLoi && (
        <div className="mt-3 rounded-md border-l-[3px] border-ink bg-surface px-4 py-3 text-sm">
          <p className="font-semibold">Trả lời · {dateTimeVi(p.ngayTraLoi)}</p>
          <p className="mt-1 whitespace-pre-line text-ink-soft">{p.noiDungTraLoi}</p>
        </div>
      )}

      {canHandle && p.trangThai !== "DA_XU_LY" && (
        <div className="mt-4 flex flex-col gap-3 border-t border-line pt-4">
          {err && <Alert tone="error">{err}</Alert>}
          <div className="flex flex-wrap items-end gap-3">
            {p.trangThai === "MOI" && (
              <>
                <Field label="Phân loại" className="w-[180px]">
                  <Select value={loai} onChange={(e) => setLoai(e.target.value)}>
                    {Object.entries(LOAI_PH).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                  </Select>
                </Field>
                <Button variant="dark" loading={accept.isPending} onClick={() => { setErr(null); accept.mutate(); }}>Tiếp nhận</Button>
              </>
            )}
            {!replying && <Button variant="secondary" onClick={() => setReplying(true)}>Trả lời</Button>}
          </div>
          {replying && (
            <>
              <Field label="Nội dung trả lời khách hàng" hint="Gửi trả lời sẽ chuyển phản hồi sang Đã xử lý.">
                <TextArea value={reply} onChange={(e) => setReply(e.target.value)} maxLength={2000} rows={3} autoFocus />
              </Field>
              <div className="flex gap-2">
                <Button loading={answer.isPending} disabled={!reply.trim()} onClick={() => { setErr(null); answer.mutate(); }}>Gửi trả lời</Button>
                <Button variant="ghost" onClick={() => setReplying(false)}>Hủy</Button>
              </div>
            </>
          )}
        </div>
      )}
    </li>
  );
}

/** Q8 (QL-4). Tiếp nhận phản hồi của khách hàng: lọc, tiếp nhận (Mới → Đang xử lý), trả lời (→ Đã xử lý). */
export function FeedbackPage() {
  const can = useCan();
  const [trangThai, setTrangThai] = useState("MOI");
  const [loaiPH, setLoaiPH] = useState("");
  const [range, setRange] = useState({ tuNgay: "", denNgay: "" });
  const [page, setPage] = useState(1);
  const badRange = !!range.tuNgay && !!range.denNgay && range.tuNgay > range.denNgay;

  const q = useQuery({
    queryKey: ["manager", "feedback", trangThai, loaiPH, range, page],
    queryFn: () => api.get<Paged<PhanHoi>>("/api/manager/feedback", { query: { trangThai, loaiPH, ...range, trang: page, soDong: PAGE_SIZE } }),
    placeholderData: keepPreviousData,
    enabled: !badRange,
  });

  return (
    <>
      <PageHeader title="Phản hồi khách hàng" description="Tiếp nhận, phân loại và trả lời phản hồi khách gửi từ trang Khách hàng." />
      <div className="mb-4 flex flex-wrap gap-1 border-b border-line" role="tablist" aria-label="Trạng thái phản hồi">
        {TABS.map((t) => (
          <button
            key={t.v}
            type="button"
            role="tab"
            aria-selected={trangThai === t.v}
            onClick={() => { setTrangThai(t.v); setPage(1); }}
            className={cn("-mb-px border-b-2 px-4 py-2.5 text-[15px] font-medium", trangThai === t.v ? "border-accent text-ink" : "border-transparent text-muted hover:text-ink")}
          >
            {t.l}
          </button>
        ))}
      </div>
      <div className="mb-5 flex flex-wrap items-end gap-3">
        <Field label="Loại" className="w-[170px]">
          <Select value={loaiPH} onChange={(e) => { setLoaiPH(e.target.value); setPage(1); }}>
            <option value="">Tất cả</option>
            {Object.entries(LOAI_PH).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
          </Select>
        </Field>
        <Field label="Từ ngày" className="w-[170px]">
          <TextInput type="date" value={range.tuNgay} onChange={(e) => { setRange({ ...range, tuNgay: e.target.value }); setPage(1); }} />
        </Field>
        <Field label="Đến ngày" className="w-[170px]" error={badRange ? "Đến ngày phải sau Từ ngày." : undefined}>
          <TextInput type="date" value={range.denNgay} onChange={(e) => { setRange({ ...range, denNgay: e.target.value }); setPage(1); }} />
        </Field>
      </div>

      {q.isError ? (
        <ErrorState error={q.error} onRetry={() => q.refetch()} />
      ) : badRange ? (
        <Alert tone="warning">Chọn lại khoảng ngày để xem phản hồi.</Alert>
      ) : q.isPending ? (
        <Skeleton className="h-72" />
      ) : (
        <Panel
          title={<span aria-live="polite">{q.data.tongSoDong} phản hồi</span>}
          actions={<Pager page={page} size={PAGE_SIZE} total={q.data.tongSoDong} onPage={setPage} />}
          bodyClass=""
        >
          {q.data.items.length === 0 ? (
            <EmptyRow><Inbox className="mx-auto mb-2 size-7" aria-hidden="true" />Không có phản hồi nào.</EmptyRow>
          ) : (
            <ul className="divide-y divide-line">
              {q.data.items.map((p) => <FeedbackItem key={`${p.maPH}-${p.trangThai}`} p={p} canHandle={can("QL_PH_XU_LY")} />)}
            </ul>
          )}
        </Panel>
      )}
    </>
  );
}
