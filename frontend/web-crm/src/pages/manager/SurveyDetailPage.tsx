import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useParams } from "react-router";
import { ArrowLeft, BarChart3, Plus, Send, Trash2, X } from "lucide-react";
import { api } from "@shared/api/client";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { Alert } from "@shared/ui/Alert";
import { Button } from "@shared/ui/Button";
import { Field, Select, TextInput } from "@shared/ui/Field";
import { Modal } from "@shared/ui/Modal";
import { useToast } from "@shared/ui/Toast";
import {
  Badge, GIOI_TINH, LOAI_CAU_HOI, MUC_DICH_KS, Panel, TRANG_THAI_KS, dateTimeVi, errText, toneTrangThaiKS, useCan, useCategories, useProvinces, useTiers,
} from "./common";

interface SurveyDetail {
  khaoSat: {
    maKS: number; tieuDe: string; moTa: string | null; mucDich: string; tenSP: string | null; nguoiTao: string; ngayTao: string;
    ngayPhatHanh: string | null; hanTraLoi: string; phanTramVoucher: number; soNgayHieuLucVoucher: number;
    trangThai: "NHAP" | "DA_GUI" | "DA_DONG"; soNguoiNhan: number; soHoanThanh: number;
  };
  cauHoi: { maCauHoi: number; thuTu: number; noiDung: string; loaiCauHoi: string; batBuoc: boolean }[];
  luaChon: { maLC: number; maCauHoi: number; thuTu: number; noiDung: string }[];
}

function AddQuestion({ maKS }: { maKS: number }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [noiDung, setNoiDung] = useState("");
  const [loai, setLoai] = useState("MOT_LUA_CHON");
  const [batBuoc, setBatBuoc] = useState(true);
  const [luaChon, setLuaChon] = useState(["", ""]);
  const [err, setErr] = useState<string | null>(null);
  const tracNghiem = loai === "MOT_LUA_CHON" || loai === "NHIEU_LUA_CHON";
  const filled = luaChon.map((x) => x.trim()).filter(Boolean);

  const add = useMutation({
    mutationFn: () =>
      api.post(`/api/manager/surveys/${maKS}/questions`, { noiDung: noiDung.trim(), loaiCauHoi: loai, batBuoc, luaChon: tracNghiem ? filled : null }),
    onSuccess: () => {
      toast("success", "Đã thêm câu hỏi.");
      setNoiDung("");
      setLuaChon(["", ""]);
      void qc.invalidateQueries({ queryKey: ["manager"] });
    },
    onError: (e) => setErr(errText(e)),
  });
  const invalid = !noiDung.trim() || (tracNghiem && filled.length < 2);

  return (
    <Panel title="Thêm câu hỏi">
      <div className="flex flex-col gap-4">
        {err && <Alert tone="error">{err}</Alert>}
        <Field label="Nội dung câu hỏi" required>
          <TextInput value={noiDung} onChange={(e) => setNoiDung(e.target.value)} maxLength={500} />
        </Field>
        <div className="flex flex-wrap items-end gap-4">
          <Field label="Loại câu hỏi" className="w-[220px]">
            <Select value={loai} onChange={(e) => setLoai(e.target.value)}>
              {Object.entries(LOAI_CAU_HOI).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
            </Select>
          </Field>
          <label className="flex h-11 items-center gap-2 text-[15px]">
            <input type="checkbox" className="size-4 accent-[var(--color-ink)]" checked={batBuoc} onChange={(e) => setBatBuoc(e.target.checked)} />
            Bắt buộc trả lời
          </label>
        </div>
        {tracNghiem && (
          <fieldset className="flex flex-col gap-2">
            <legend className="mb-1.5 text-sm font-medium">Các lựa chọn (ít nhất 2)</legend>
            {luaChon.map((x, i) => (
              <div key={i} className="flex gap-2">
                <TextInput aria-label={`Lựa chọn ${i + 1}`} value={x} placeholder={`Lựa chọn ${i + 1}`} maxLength={200}
                  onChange={(e) => setLuaChon((a) => a.map((y, j) => (j === i ? e.target.value : y)))} />
                {luaChon.length > 2 && (
                  <button type="button" aria-label={`Bỏ lựa chọn ${i + 1}`} className="grid size-11 shrink-0 place-items-center rounded-md text-muted hover:bg-surface hover:text-ink"
                    onClick={() => setLuaChon((a) => a.filter((_, j) => j !== i))}>
                    <X className="size-4" aria-hidden="true" />
                  </button>
                )}
              </div>
            ))}
            <div>
              <Button size="sm" variant="ghost" icon={<Plus className="size-4" aria-hidden="true" />} onClick={() => setLuaChon((a) => [...a, ""])}>Thêm lựa chọn</Button>
            </div>
          </fieldset>
        )}
        {loai === "THANG_DIEM" && <p className="text-sm text-muted">Khách chọn điểm từ 1 (rất không hài lòng) đến 5 (rất hài lòng).</p>}
        <div>
          <Button variant="dark" loading={add.isPending} disabled={invalid} onClick={() => { setErr(null); add.mutate(); }}>Thêm câu hỏi</Button>
        </div>
      </div>
    </Panel>
  );
}

interface Criteria { maHang: string; maTinh: string; gioiTinh: string; tuoiTu: string; tuoiDen: string; maLoaiQuanTam: string; maLoaiDaMua: string; hanTraLoiMoi: string }
const NO_CRITERIA: Criteria = { maHang: "", maTinh: "", gioiTinh: "", tuoiTu: "", tuoiDen: "", maLoaiQuanTam: "", maLoaiDaMua: "", hanTraLoiMoi: "" };

function SendPanel({ maKS, expired, sent }: { maKS: number; expired: boolean; sent: boolean }) {
  const qc = useQueryClient();
  const toast = useToast();
  const tiers = useTiers();
  const provinces = useProvinces();
  const categories = useCategories();
  const [c, setC] = useState<Criteria>(NO_CRITERIA);
  const [preview, setPreview] = useState<number | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const body = () => {
    const num = (s: string) => (s ? Number(s) : null);
    return {
      maHang: c.maHang || null, maTinh: c.maTinh || null, gioiTinh: c.gioiTinh || null, tuoiTu: num(c.tuoiTu), tuoiDen: num(c.tuoiDen),
      maLoaiQuanTam: num(c.maLoaiQuanTam), maLoaiDaMua: num(c.maLoaiDaMua), hanTraLoiMoi: c.hanTraLoiMoi ? new Date(c.hanTraLoiMoi).toISOString() : null,
    };
  };
  const count = useMutation({
    mutationFn: () => api.post<{ soNguoiNhanMoi: number }>(`/api/manager/surveys/${maKS}/send-preview`, body()),
    onSuccess: (r) => setPreview(r.soNguoiNhanMoi),
    onError: (e) => setErr(errText(e)),
  });
  const send = useMutation({
    mutationFn: () => api.post<{ soNguoiNhanMoi: number }>(`/api/manager/surveys/${maKS}/send`, body()),
    onSuccess: (r) => {
      setPreview(null);
      toast(r.soNguoiNhanMoi > 0 ? "success" : "info", r.soNguoiNhanMoi > 0 ? `Đã gửi khảo sát tới ${r.soNguoiNhanMoi} tài khoản khách hàng.` : "Không có khách hàng mới nào thỏa tiêu chí.");
      void qc.invalidateQueries({ queryKey: ["manager"] });
    },
    onError: (e) => setErr(errText(e)),
  });
  const set = (k: keyof Criteria) => (e: { target: { value: string } }) => {
    setPreview(null);
    setC((x) => ({ ...x, [k]: e.target.value }));
  };

  return (
    <Panel title={sent ? "Gửi bổ sung cho nhóm khách khác" : "Chọn đối tượng và gửi"}>
      <p className="mb-4 text-sm text-muted">
        Chỉ gửi tới khách có hồ sơ và tài khoản đang hoạt động; khách đã nhận sẽ không nhận lại. Để trống tiêu chí = gửi tất cả.
      </p>
      {err && <Alert tone="error" className="mb-4">{err}</Alert>}
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Field label="Hạng">
          <Select value={c.maHang} onChange={set("maHang")}>
            <option value="">Tất cả</option>
            {tiers.data?.map((t) => <option key={t.maHang} value={t.maHang}>{t.tenHang}</option>)}
          </Select>
        </Field>
        <Field label="Tỉnh/thành">
          <Select value={c.maTinh} onChange={set("maTinh")}>
            <option value="">Tất cả</option>
            {provinces.data?.map((p) => <option key={p.maTinh} value={p.maTinh}>{p.tenTinh}</option>)}
          </Select>
        </Field>
        <Field label="Giới tính">
          <Select value={c.gioiTinh} onChange={set("gioiTinh")}>
            <option value="">Tất cả</option>
            {Object.entries(GIOI_TINH).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
          </Select>
        </Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Tuổi từ"><TextInput type="number" min={0} max={150} value={c.tuoiTu} onChange={set("tuoiTu")} /></Field>
          <Field label="Đến"><TextInput type="number" min={0} max={150} value={c.tuoiDen} onChange={set("tuoiDen")} /></Field>
        </div>
        <Field label="Quan tâm loại SP">
          <Select value={c.maLoaiQuanTam} onChange={set("maLoaiQuanTam")}>
            <option value="">Không lọc</option>
            {categories.data?.map((x) => <option key={x.maLoai} value={x.maLoai}>{x.tenLoai}</option>)}
          </Select>
        </Field>
        <Field label="Đã từng mua loại SP">
          <Select value={c.maLoaiDaMua} onChange={set("maLoaiDaMua")}>
            <option value="">Không lọc</option>
            {categories.data?.map((x) => <option key={x.maLoai} value={x.maLoai}>{x.tenLoai}</option>)}
          </Select>
        </Field>
        <Field label="Gia hạn trả lời" hint={expired ? "Hạn cũ đã qua: bắt buộc gia hạn." : "Tùy chọn."} className="lg:col-span-2">
          <TextInput type="datetime-local" value={c.hanTraLoiMoi} onChange={set("hanTraLoiMoi")} />
        </Field>
      </div>
      <div className="mt-4 flex flex-wrap items-center gap-3">
        <Button variant="secondary" loading={count.isPending} onClick={() => { setErr(null); count.mutate(); }}>Xem trước số người nhận</Button>
        {preview != null && (
          <span className="text-[15px]" aria-live="polite" data-testid="so-nguoi-nhan">
            Sẽ gửi tới <strong className="tabular">{preview}</strong> khách hàng mới
          </span>
        )}
        <Button icon={<Send className="size-4" aria-hidden="true" />} loading={send.isPending} disabled={preview === 0} onClick={() => { setErr(null); send.mutate(); }}>
          Gửi khảo sát
        </Button>
      </div>
    </Panel>
  );
}

/** Q12–Q14 (QL-6). Chi tiết khảo sát: soạn câu hỏi khi còn Nháp, gửi tới tài khoản khách hàng, đóng khảo sát. */
export function SurveyDetailPage() {
  const { maKS } = useParams();
  const id = Number(maKS);
  const can = useCan();
  const qc = useQueryClient();
  const toast = useToast();
  const [closing, setClosing] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const q = useQuery({ queryKey: ["manager", "survey", id], queryFn: () => api.get<SurveyDetail>(`/api/manager/surveys/${id}`) });

  const delQ = useMutation({
    mutationFn: (maCauHoi: number) => api.delete(`/api/manager/questions/${maCauHoi}`),
    onSuccess: () => { toast("success", "Đã xóa câu hỏi."); void qc.invalidateQueries({ queryKey: ["manager"] }); },
    onError: (e) => setErr(errText(e)),
  });
  const close = useMutation({
    mutationFn: () => api.post(`/api/manager/surveys/${id}/close`),
    onSuccess: () => { setClosing(false); toast("success", "Đã đóng khảo sát."); void qc.invalidateQueries({ queryKey: ["manager"] }); },
    onError: (e) => { setClosing(false); setErr(errText(e)); },
  });

  if (q.isError) return <ErrorState error={q.error} onRetry={() => q.refetch()} />;
  if (q.isPending) return <Skeleton className="h-96" />;
  const { khaoSat: k, cauHoi, luaChon } = q.data;
  const draft = k.trangThai === "NHAP";
  const expired = new Date(k.hanTraLoi) <= new Date();

  return (
    <>
      <Link to="/manager/surveys" className="mb-3 inline-flex items-center gap-1.5 text-sm font-medium text-ink-soft hover:text-ink">
        <ArrowLeft className="size-4" aria-hidden="true" /> Về danh sách
      </Link>
      <PageHeader
        title={k.tieuDe}
        description={<span className="inline-flex flex-wrap items-center gap-2"><Badge tone={toneTrangThaiKS(k.trangThai)}>{TRANG_THAI_KS[k.trangThai]}</Badge> {MUC_DICH_KS[k.mucDich]}{k.tenSP ? ` · ${k.tenSP}` : ""}</span>}
        actions={
          <div className="flex flex-wrap gap-2">
            {can("QL_KS_THONG_KE") && !draft && (
              <Link to={`/manager/surveys/${id}/stats`} className="inline-flex h-9 items-center gap-1.5 rounded-md border border-line-strong px-3 text-sm font-semibold hover:border-ink">
                <BarChart3 className="size-4" aria-hidden="true" /> Thống kê kết quả
              </Link>
            )}
            {can("QL_KS_GUI") && k.trangThai === "DA_GUI" && <Button size="sm" variant="danger" onClick={() => setClosing(true)}>Đóng khảo sát</Button>}
          </div>
        }
      />
      <div className="flex flex-col gap-5">
        {err && <Alert tone="error">{err}</Alert>}
        <Panel title="Thông tin">
          <dl className="grid gap-4 text-[15px] sm:grid-cols-2 lg:grid-cols-4">
            <div><dt className="text-xs font-medium uppercase tracking-wider text-muted">Hạn trả lời</dt><dd>{dateTimeVi(k.hanTraLoi)}{expired && k.trangThai !== "DA_DONG" ? " (đã qua)" : ""}</dd></div>
            <div><dt className="text-xs font-medium uppercase tracking-wider text-muted">Người tạo</dt><dd>{k.nguoiTao} · {dateTimeVi(k.ngayTao)}</dd></div>
            <div><dt className="text-xs font-medium uppercase tracking-wider text-muted">Đã gửi · hoàn thành</dt><dd className="tabular">{k.soNguoiNhan} · {k.soHoanThanh}</dd></div>
            <div><dt className="text-xs font-medium uppercase tracking-wider text-muted">Voucher</dt><dd>{k.phanTramVoucher > 0 ? `${k.phanTramVoucher}% · ${k.soNgayHieuLucVoucher} ngày` : "Không tặng"}</dd></div>
          </dl>
          {k.moTa && <p className="mt-4 text-[15px] text-ink-soft">{k.moTa}</p>}
        </Panel>

        <Panel title={`Câu hỏi (${cauHoi.length})`} bodyClass="">
          {cauHoi.length === 0 ? (
            <p className="px-5 py-8 text-center text-sm text-muted">Chưa có câu hỏi. {draft ? "Thêm câu hỏi bên dưới trước khi gửi." : ""}</p>
          ) : (
            <ol className="divide-y divide-line">
              {cauHoi.map((c) => (
                <li key={c.maCauHoi} className="flex gap-4 px-5 py-4">
                  <span className="tabular grid size-7 shrink-0 place-items-center rounded-full bg-surface text-sm font-semibold">{c.thuTu}</span>
                  <div className="min-w-0 flex-1">
                    <p className="font-medium">{c.noiDung}{c.batBuoc && <span className="ml-1 text-accent" aria-label="bắt buộc">*</span>}</p>
                    <p className="text-sm text-muted">{LOAI_CAU_HOI[c.loaiCauHoi]}</p>
                    {luaChon.some((l) => l.maCauHoi === c.maCauHoi) && (
                      <ul className="mt-2 flex flex-col gap-1 text-sm text-ink-soft">
                        {luaChon.filter((l) => l.maCauHoi === c.maCauHoi).map((l) => (
                          <li key={l.maLC} className="flex items-center gap-2">
                            <span aria-hidden="true" className={c.loaiCauHoi === "MOT_LUA_CHON" ? "size-3 rounded-full border border-line-strong" : "size-3 rounded-[2px] border border-line-strong"} />
                            {l.noiDung}
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                  {draft && can("QL_KS_QUAN_LY") && (
                    <button type="button" aria-label={`Xóa câu hỏi ${c.thuTu}`} disabled={delQ.isPending}
                      className="grid size-9 shrink-0 place-items-center rounded-md text-muted hover:bg-danger-soft hover:text-danger"
                      onClick={() => { setErr(null); delQ.mutate(c.maCauHoi); }}>
                      <Trash2 className="size-4" aria-hidden="true" />
                    </button>
                  )}
                </li>
              ))}
            </ol>
          )}
        </Panel>

        {draft && can("QL_KS_QUAN_LY") && <AddQuestion maKS={id} />}
        {k.trangThai !== "DA_DONG" && can("QL_KS_GUI") && (cauHoi.length > 0 ? <SendPanel maKS={id} expired={expired} sent={!draft} /> : null)}
        {k.trangThai === "DA_DONG" && <Alert tone="info">Khảo sát đã đóng: khách không trả lời thêm được. Xem kết quả ở trang Thống kê.</Alert>}
      </div>

      <Modal
        open={closing}
        onClose={() => setClosing(false)}
        role="alertdialog"
        title="Đóng khảo sát?"
        footer={
          <>
            <Button variant="ghost" onClick={() => setClosing(false)}>Hủy</Button>
            <Button variant="danger" loading={close.isPending} onClick={() => close.mutate()}>Đóng khảo sát</Button>
          </>
        }
      >
        Khách hàng chưa trả lời sẽ không trả lời được nữa. Kết quả đã thu vẫn được giữ để thống kê.
      </Modal>
    </>
  );
}
