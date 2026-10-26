import { useState, type FormEvent } from "react";
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "react-router";
import { Plus, RefreshCcw, Search, Undo2 } from "lucide-react";
import { api } from "@shared/api/client";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { Alert } from "@shared/ui/Alert";
import { Button } from "@shared/ui/Button";
import { EmptyRow, Pager, Panel, Table, TextArea, dateTimeVi, errText, pct, td, vnd, type Paged } from "@shared/ui/data";
import { Field, Select, TextInput } from "@shared/ui/Field";
import { Modal } from "@shared/ui/Modal";
import { useToast } from "@shared/ui/Toast";
import { KENH_BAN, LY_DO_DOI_TRA, localDateTime } from "./common";

export interface HoaDon {
  maHD: number;
  soHoaDon: string;
  ngayLap: string;
  kenhBan: "CUA_HANG" | "ONLINE";
  tenCH: string | null;
  nhanVienBan: string | null;
  maKH: number;
  tenKhachHang: string;
  tongTienHang: number;
  phanTramGiam: number;
  thanhTien: number;
  soLuongDaDoiTra: number;
}
interface DongHang { maSKU: string; tenSP: string; soLuong: number; donGiaBan: number; daDoiTra: number }

interface Filters { soHoaDon: string; maKH: string; tuNgay: string; denNgay: string }
const EMPTY: Filters = { soHoaDon: "", maKH: "", tuNgay: "", denNgay: "" };
const PAGE_SIZE = 20;

/** A12–A14. Hóa đơn đã nạp từ POS: tìm, xem chi tiết, nạp đổi trả; nạp hóa đơn mới; xét lại hạng toàn bộ. */
export function InvoicesPage() {
  const nav = useNavigate();
  const qc = useQueryClient();
  const toast = useToast();
  const [draft, setDraft] = useState<Filters>(EMPTY);
  const [filters, setFilters] = useState<Filters>(EMPTY);
  const [page, setPage] = useState(1);
  const [detail, setDetail] = useState<string | null>(null);
  const [recalc, setRecalc] = useState<"confirm" | number | null>(null);
  const [recalcError, setRecalcError] = useState<string | null>(null);

  const q = useQuery({
    queryKey: ["admin", "invoices", filters, page],
    queryFn: () => api.get<Paged<HoaDon>>("/api/admin/invoices", { query: { ...filters, soHoaDon: filters.soHoaDon.trim(), trang: page, soDong: PAGE_SIZE } }),
    placeholderData: keepPreviousData,
  });
  const tiers = useMutation({
    mutationFn: () => api.post<{ soKhachDoiHang: number }>("/api/admin/tiers/recalculate"),
    onSuccess: (r) => {
      setRecalc(r?.soKhachDoiHang ?? 0);
      toast("success", "Đã xét lại hạng toàn bộ khách hàng.");
      void qc.invalidateQueries({ queryKey: ["admin"] });
    },
    onError: (e) => setRecalcError(errText(e)),
  });

  const set = (k: keyof Filters) => (e: { target: { value: string } }) => setDraft((d) => ({ ...d, [k]: e.target.value }));
  const apply = (e: FormEvent) => {
    e.preventDefault();
    setPage(1);
    setFilters(draft);
  };
  const badRange = !!draft.tuNgay && !!draft.denNgay && draft.tuNgay > draft.denNgay;

  return (
    <>
      <PageHeader
        title="Hóa đơn và đổi trả"
        description="Nạp dữ liệu bán hàng từ POS/online. Hệ thống tự cộng điểm, áp voucher và xét hạng thành viên cho khách."
        actions={
          <>
            <Button variant="secondary" icon={<RefreshCcw className="size-4" aria-hidden="true" />} onClick={() => { setRecalcError(null); setRecalc("confirm"); }}>Xét lại hạng</Button>
            <Button icon={<Plus className="size-4" aria-hidden="true" />} onClick={() => nav("/admin/invoices/new")}>Nạp hóa đơn</Button>
          </>
        }
      />

      <form onSubmit={apply} noValidate className="mb-5 rounded-md border border-line bg-bg p-4">
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <Field label="Số hóa đơn">
            <TextInput value={draft.soHoaDon} onChange={set("soHoaDon")} placeholder="Ví dụ HD0004" spellCheck={false} />
          </Field>
          <Field label="Mã khách hàng">
            <TextInput type="number" min={1} value={draft.maKH} onChange={set("maKH")} />
          </Field>
          <Field label="Từ ngày" error={badRange ? "Từ ngày phải trước đến ngày." : undefined}>
            <TextInput type="date" value={draft.tuNgay} onChange={set("tuNgay")} />
          </Field>
          <Field label="Đến ngày">
            <TextInput type="date" value={draft.denNgay} onChange={set("denNgay")} />
          </Field>
          <div className="flex items-end gap-2">
            <Button type="submit" variant="dark" disabled={badRange} icon={<Search className="size-4" aria-hidden="true" />}>Tìm</Button>
            <Button type="button" variant="ghost" onClick={() => { setDraft(EMPTY); setFilters(EMPTY); setPage(1); }}>Xóa lọc</Button>
          </div>
        </div>
      </form>

      {q.isError ? (
        <ErrorState error={q.error} onRetry={() => q.refetch()} />
      ) : q.isPending ? (
        <Skeleton className="h-80" />
      ) : (
        <Panel
          title={<span aria-live="polite">{q.data.tongSoDong} hóa đơn</span>}
          actions={<Pager page={page} size={PAGE_SIZE} total={q.data.tongSoDong} onPage={setPage} />}
          bodyClass=""
        >
          {q.data.items.length === 0 ? (
            <EmptyRow>Không có hóa đơn nào khớp bộ lọc.</EmptyRow>
          ) : (
            <Table label="Danh sách hóa đơn" head={["Số hóa đơn", "Ngày lập", "Khách hàng", "Kênh · Nơi bán", "Tổng tiền hàng", "Giảm", "Thành tiền", "Đã đổi trả"]}>
              {q.data.items.map((h) => (
                <tr key={h.maHD} className="hover:bg-surface">
                  <td className={td}>
                    <button type="button" className="font-mono font-semibold underline-offset-2 hover:underline" onClick={() => setDetail(h.soHoaDon)}>{h.soHoaDon}</button>
                  </td>
                  <td className={`${td} tabular text-sm`}>{dateTimeVi(h.ngayLap)}</td>
                  <td className={td}>
                    {h.tenKhachHang}
                    <span className="block text-xs text-muted">Mã KH {h.maKH}</span>
                  </td>
                  <td className={td}>
                    {KENH_BAN[h.kenhBan]}
                    {h.tenCH && <span className="block text-xs text-muted">{h.tenCH}{h.nhanVienBan ? ` · ${h.nhanVienBan}` : ""}</span>}
                  </td>
                  <td className={`${td} tabular text-right`}>{vnd(h.tongTienHang)}</td>
                  <td className={`${td} tabular text-right`}>{h.phanTramGiam ? pct(h.phanTramGiam) : "—"}</td>
                  <td className={`${td} tabular text-right font-semibold`}>{vnd(h.thanhTien)}</td>
                  <td className={`${td} tabular text-right`}>{h.soLuongDaDoiTra || "—"}</td>
                </tr>
              ))}
            </Table>
          )}
        </Panel>
      )}

      {detail && <InvoiceDetailModal soHoaDon={detail} onClose={() => setDetail(null)} />}

      <Modal
        open={recalc !== null}
        onClose={() => setRecalc(null)}
        title="Xét lại hạng toàn bộ khách hàng"
        footer={typeof recalc === "number" ? <Button onClick={() => setRecalc(null)}>Xong</Button> : (
          <>
            <Button variant="ghost" onClick={() => setRecalc(null)}>Hủy</Button>
            <Button loading={tiers.isPending} onClick={() => tiers.mutate()}>Xét hạng</Button>
          </>
        )}
      >
        {typeof recalc === "number" ? (
          <Alert tone="success" title={`${recalc} khách hàng đổi hạng`}>Lịch sử đổi hạng được ghi vào hồ sơ từng khách; trang Quản lý và trang Khách hàng thấy hạng mới ngay.</Alert>
        ) : (
          <p>Tính lại điểm tích lũy của mọi khách hàng (trừ phần đã đổi trả) và đổi hạng nếu cần. Thường chạy định kỳ; mỗi lần nạp hóa đơn đã tự xét hạng cho khách của hóa đơn đó.</p>
        )}
        {recalcError && <Alert tone="error" className="mt-3">{recalcError}</Alert>}
      </Modal>
    </>
  );
}

/** Chi tiết hóa đơn + nạp đổi trả cho một dòng hàng (số lượng ≤ phần còn lại). */
function InvoiceDetailModal({ soHoaDon, onClose }: { soHoaDon: string; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const q = useQuery({
    queryKey: ["admin", "invoice", soHoaDon],
    queryFn: () => api.get<{ hoaDon: HoaDon; chiTiet: DongHang[] }>(`/api/admin/invoices/${encodeURIComponent(soHoaDon)}`),
  });
  const [ret, setRet] = useState({ maSKU: "", soLuong: "1", lyDo: "KHONG_VUA", ngayDoiTra: localDateTime(), ghiChu: "" });
  const [error, setError] = useState<string | null>(null);
  const line = q.data?.chiTiet.find((c) => c.maSKU === ret.maSKU);
  const conLai = line ? line.soLuong - line.daDoiTra : 0;
  const set = (k: keyof typeof ret) => (e: { target: { value: string } }) => setRet((x) => ({ ...x, [k]: e.target.value }));

  const save = useMutation({
    mutationFn: () => api.post("/api/admin/returns", {
      soHoaDon, maSKU: ret.maSKU, soLuong: Number(ret.soLuong), lyDo: ret.lyDo,
      ngayDoiTra: new Date(ret.ngayDoiTra).toISOString(), ghiChu: ret.ghiChu.trim() || null,
    }),
    onSuccess: () => {
      toast("success", `Đã nạp đổi trả ${ret.soLuong} × ${ret.maSKU}. Điểm và hạng của khách đã được tính lại.`);
      setRet((x) => ({ ...x, maSKU: "", soLuong: "1", ghiChu: "" }));
      setError(null);
      void qc.invalidateQueries({ queryKey: ["admin"] });
    },
    onError: (e) => setError(errText(e)),
  });
  const qty = Number(ret.soLuong);
  const valid = !!line && Number.isInteger(qty) && qty >= 1 && qty <= conLai && !!ret.ngayDoiTra;

  return (
    <Modal open onClose={onClose} title={`Hóa đơn ${soHoaDon}`} className="w-[min(760px,calc(100vw-32px))]" footer={<Button variant="secondary" onClick={onClose}>Đóng</Button>}>
      {q.isError ? (
        <ErrorState error={q.error} onRetry={() => q.refetch()} />
      ) : q.isPending ? (
        <Skeleton className="h-48" />
      ) : (
        <div className="flex flex-col gap-5 text-ink">
          <dl className="grid grid-cols-2 gap-x-6 gap-y-2 text-sm sm:grid-cols-4">
            <div><dt className="text-xs text-muted">Khách hàng</dt><dd>{q.data.hoaDon.tenKhachHang} (mã {q.data.hoaDon.maKH})</dd></div>
            <div><dt className="text-xs text-muted">Ngày lập</dt><dd className="tabular">{dateTimeVi(q.data.hoaDon.ngayLap)}</dd></div>
            <div><dt className="text-xs text-muted">Kênh</dt><dd>{KENH_BAN[q.data.hoaDon.kenhBan]}{q.data.hoaDon.tenCH ? ` · ${q.data.hoaDon.tenCH}` : ""}</dd></div>
            <div><dt className="text-xs text-muted">Thành tiền</dt><dd className="tabular font-semibold">{vnd(q.data.hoaDon.thanhTien)}{q.data.hoaDon.phanTramGiam ? ` (giảm ${pct(q.data.hoaDon.phanTramGiam)})` : ""}</dd></div>
          </dl>
          <div className="rounded-md border border-line">
            <Table label="Dòng hàng" head={["SKU", "Sản phẩm", "SL", "Đơn giá", "Đã đổi trả"]}>
              {q.data.chiTiet.map((c) => (
                <tr key={c.maSKU}>
                  <td className={`${td} font-mono text-sm`}>{c.maSKU}</td>
                  <td className={td}>{c.tenSP}</td>
                  <td className={`${td} tabular`}>{c.soLuong}</td>
                  <td className={`${td} tabular`}>{vnd(c.donGiaBan)}</td>
                  <td className={`${td} tabular`}>{c.daDoiTra || "—"}</td>
                </tr>
              ))}
            </Table>
          </div>

          <section aria-labelledby="doi-tra" className="rounded-md border border-line p-4">
            <h3 id="doi-tra" className="mb-3 flex items-center gap-2 font-semibold"><Undo2 className="size-4" aria-hidden="true" /> Nạp đổi trả</h3>
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Sản phẩm trả" required>
                <Select value={ret.maSKU} onChange={set("maSKU")}>
                  <option value="">Chọn dòng hàng</option>
                  {q.data.chiTiet.map((c) => (
                    <option key={c.maSKU} value={c.maSKU} disabled={c.soLuong - c.daDoiTra <= 0}>
                      {c.maSKU} · {c.tenSP} (còn {c.soLuong - c.daDoiTra})
                    </option>
                  ))}
                </Select>
              </Field>
              <Field label="Số lượng" required hint={line ? `Tối đa ${conLai}` : undefined} error={line && (qty < 1 || qty > conLai) ? `Số lượng từ 1 đến ${conLai}.` : undefined}>
                <TextInput type="number" min={1} max={conLai || undefined} value={ret.soLuong} onChange={set("soLuong")} />
              </Field>
              <Field label="Lý do" required>
                <Select value={ret.lyDo} onChange={set("lyDo")}>
                  {Object.entries(LY_DO_DOI_TRA).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
                </Select>
              </Field>
              <Field label="Ngày đổi trả" required>
                <TextInput type="datetime-local" value={ret.ngayDoiTra} onChange={set("ngayDoiTra")} />
              </Field>
              <Field label="Ghi chú" className="sm:col-span-2">
                <TextArea value={ret.ghiChu} onChange={set("ghiChu")} maxLength={300} rows={2} className="min-h-16" />
              </Field>
            </div>
            {error && <Alert tone="error" className="mt-3">{error}</Alert>}
            <div className="mt-3 flex justify-end">
              <Button loading={save.isPending} disabled={!valid} onClick={() => save.mutate()}>Nạp đổi trả</Button>
            </div>
          </section>
        </div>
      )}
    </Modal>
  );
}
