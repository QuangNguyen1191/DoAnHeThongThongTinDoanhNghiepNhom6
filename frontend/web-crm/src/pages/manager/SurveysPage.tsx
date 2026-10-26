import { useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useNavigate } from "react-router";
import { ArrowLeft, BarChart3, Plus } from "lucide-react";
import { api } from "@shared/api/client";
import { fieldErrors, isApiError } from "@shared/api/errors";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, ForbiddenState, Skeleton } from "@shared/pages/PageStates";
import { Alert } from "@shared/ui/Alert";
import { Button } from "@shared/ui/Button";
import { Field, Select, TextInput } from "@shared/ui/Field";
import { useToast } from "@shared/ui/Toast";
import { Badge, EmptyRow, MUC_DICH_KS, Panel, Table, TextArea, TRANG_THAI_KS, dateVi, pct, td, toneTrangThaiKS, useCan, useProducts } from "./common";

export interface KhaoSatRow {
  maKS: number;
  tieuDe: string;
  mucDich: string;
  maSP: number | null;
  tenSP: string | null;
  nguoiTao: string;
  ngayTao: string;
  ngayPhatHanh: string | null;
  hanTraLoi: string;
  phanTramVoucher: number;
  trangThai: "NHAP" | "DA_GUI" | "DA_DONG";
  soCauHoi: number;
  soNguoiNhan: number;
  soHoanThanh: number;
  tyLePhanHoiPhanTram: number | null;
}

/** Q12. Danh sách khảo sát theo trạng thái; vào chi tiết để soạn câu hỏi, gửi, đóng; xem thống kê (QL-7). */
export function SurveysPage() {
  const can = useCan();
  const nav = useNavigate();
  const [trangThai, setTrangThai] = useState("");
  const [mucDich, setMucDich] = useState("");
  const q = useQuery({
    queryKey: ["manager", "surveys", trangThai, mucDich],
    queryFn: () => api.get<KhaoSatRow[]>("/api/manager/surveys", { query: { trangThai, mucDich } }),
  });

  return (
    <>
      <PageHeader
        title="Khảo sát"
        description="Tạo bảng khảo sát, gửi tới tài khoản khách hàng và thống kê kết quả."
        actions={can("QL_KS_QUAN_LY") && (
          <Button icon={<Plus className="size-4" aria-hidden="true" />} onClick={() => nav("/manager/surveys/new")}>Tạo khảo sát</Button>
        )}
      />
      <div className="mb-5 flex flex-wrap items-end gap-3">
        <Field label="Trạng thái" className="w-[180px]">
          <Select value={trangThai} onChange={(e) => setTrangThai(e.target.value)}>
            <option value="">Tất cả</option>
            {Object.entries(TRANG_THAI_KS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
          </Select>
        </Field>
        <Field label="Mục đích" className="w-[220px]">
          <Select value={mucDich} onChange={(e) => setMucDich(e.target.value)}>
            <option value="">Tất cả</option>
            {Object.entries(MUC_DICH_KS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
          </Select>
        </Field>
      </div>
      {q.isError ? (
        <ErrorState error={q.error} onRetry={() => q.refetch()} />
      ) : q.isPending ? (
        <Skeleton className="h-64" />
      ) : (
        <Panel title={`${q.data.length} khảo sát`} bodyClass="">
          {q.data.length === 0 ? <EmptyRow>Chưa có khảo sát nào.</EmptyRow> : (
            <Table label="Danh sách khảo sát" head={["Khảo sát", "Trạng thái", "Hạn trả lời", "Câu hỏi", "Đã gửi · hoàn thành", ""]}>
              {q.data.map((k) => (
                <tr key={k.maKS} className="hover:bg-surface">
                  <td className={td}>
                    <Link to={`/manager/surveys/${k.maKS}`} className="font-semibold underline-offset-2 hover:underline">{k.tieuDe}</Link>
                    <span className="block text-xs text-muted">
                      {MUC_DICH_KS[k.mucDich]}{k.tenSP ? ` · ${k.tenSP}` : ""}{k.phanTramVoucher > 0 ? ` · tặng voucher ${k.phanTramVoucher}%` : ""}
                    </span>
                  </td>
                  <td className={td}><Badge tone={toneTrangThaiKS(k.trangThai)}>{TRANG_THAI_KS[k.trangThai]}</Badge></td>
                  <td className={td}>{dateVi(k.hanTraLoi)}</td>
                  <td className={`${td} tabular`}>{k.soCauHoi}</td>
                  <td className={`${td} tabular`}>{k.soNguoiNhan} · {k.soHoanThanh} ({pct(k.tyLePhanHoiPhanTram ?? 0)})</td>
                  <td className={`${td} text-right`}>
                    {can("QL_KS_THONG_KE") && k.trangThai !== "NHAP" && (
                      <Link to={`/manager/surveys/${k.maKS}/stats`} className="inline-flex items-center gap-1 text-sm font-medium text-ink-soft hover:text-ink">
                        <BarChart3 className="size-4" aria-hidden="true" /> Thống kê
                      </Link>
                    )}
                  </td>
                </tr>
              ))}
            </Table>
          )}
        </Panel>
      )}
    </>
  );
}

const inDays = (n: number) => {
  const d = new Date(Date.now() + n * 86400000);
  d.setHours(23, 59, 0, 0);
  const p = (x: number) => String(x).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T23:59`;
};

/** Q13 (QL-6, bước 1). Tạo khảo sát ở trạng thái Nháp, sau đó thêm câu hỏi trong trang chi tiết. */
export function SurveyCreatePage() {
  const can = useCan();
  const nav = useNavigate();
  const qc = useQueryClient();
  const toast = useToast();
  const products = useProducts();
  const [v, setV] = useState({ tieuDe: "", mucDich: "DO_HAI_LONG", hanTraLoi: inDays(14), moTa: "", maSP: "", phanTramVoucher: "0", soNgayHieuLucVoucher: "30" });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);

  const create = useMutation({
    mutationFn: () =>
      api.post<{ maKS: number }>("/api/manager/surveys", {
        tieuDe: v.tieuDe.trim(), mucDich: v.mucDich, hanTraLoi: new Date(v.hanTraLoi).toISOString(), moTa: v.moTa.trim() || null,
        maSP: v.maSP ? Number(v.maSP) : null, phanTramVoucher: Number(v.phanTramVoucher), soNgayHieuLucVoucher: Number(v.soNgayHieuLucVoucher),
      }),
    onSuccess: (r) => {
      void qc.invalidateQueries({ queryKey: ["manager"] });
      toast("success", "Đã tạo khảo sát nháp. Thêm câu hỏi rồi gửi cho khách hàng.");
      nav(`/manager/surveys/${r.maKS}`);
    },
    onError: (e) => {
      if (!isApiError(e)) return setFormError("Đã có lỗi xảy ra.");
      const fe = fieldErrors(e);
      setErrors(fe);
      setFormError(e.userMessage);
    },
  });
  if (!can("QL_KS_QUAN_LY")) return <ForbiddenState />;

  const thamDo = v.mucDich === "THAM_DO_SP_MOI";
  const options = (products.data ?? []).filter((p) => !thamDo || p.trangThai === "SAP_RA_MAT");
  const set = (k: keyof typeof v) => (e: { target: { value: string } }) => setV((x) => ({ ...x, [k]: e.target.value }));
  const submit = (e: FormEvent) => {
    e.preventDefault();
    const errs: Record<string, string> = {};
    if (!v.tieuDe.trim()) errs.tieuDe = "Tiêu đề là bắt buộc.";
    if (!v.hanTraLoi || new Date(v.hanTraLoi) <= new Date()) errs.hanTraLoi = "Hạn trả lời phải ở tương lai.";
    if (thamDo && !v.maSP) errs.maSP = "Khảo sát thăm dò phải gắn với một sản phẩm Sắp ra mắt.";
    const pv = Number(v.phanTramVoucher);
    if (!(pv >= 0 && pv <= 50)) errs.phanTramVoucher = "Từ 0 đến 50.";
    const nd = Number(v.soNgayHieuLucVoucher);
    if (!(nd >= 1 && nd <= 365)) errs.soNgayHieuLucVoucher = "Từ 1 đến 365.";
    setErrors(errs);
    setFormError(Object.keys(errs).length ? "Vui lòng kiểm tra các ô được đánh dấu." : null);
    if (!Object.keys(errs).length) create.mutate();
  };

  return (
    <>
      <Link to="/manager/surveys" className="mb-3 inline-flex items-center gap-1.5 text-sm font-medium text-ink-soft hover:text-ink">
        <ArrowLeft className="size-4" aria-hidden="true" /> Về danh sách
      </Link>
      <PageHeader title="Tạo khảo sát" description="Bước 1: thông tin chung. Bước 2: thêm câu hỏi. Bước 3: chọn đối tượng và gửi." />
      <form onSubmit={submit} noValidate className="flex max-w-3xl flex-col gap-5">
        {formError && <Alert tone="error">{formError}</Alert>}
        <Panel title="Thông tin khảo sát">
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Tiêu đề" required error={errors.tieuDe} className="sm:col-span-2">
              <TextInput value={v.tieuDe} onChange={set("tieuDe")} maxLength={200} />
            </Field>
            <Field label="Mục đích" required>
              <Select value={v.mucDich} onChange={(e) => setV((x) => ({ ...x, mucDich: e.target.value, maSP: "" }))}>
                {Object.entries(MUC_DICH_KS).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
              </Select>
            </Field>
            <Field label="Hạn trả lời" required error={errors.hanTraLoi}>
              <TextInput type="datetime-local" value={v.hanTraLoi} onChange={set("hanTraLoi")} />
            </Field>
            <Field label={thamDo ? "Sản phẩm sắp ra mắt" : "Sản phẩm (tùy chọn)"} required={thamDo} error={errors.maSP} className="sm:col-span-2">
              <Select value={v.maSP} onChange={set("maSP")}>
                <option value="">{thamDo ? "Chọn sản phẩm" : "Không gắn sản phẩm"}</option>
                {options.map((p) => <option key={p.maSP} value={p.maSP}>{p.tenSP} ({p.tenLoai})</option>)}
              </Select>
            </Field>
            <Field label="Mô tả" className="sm:col-span-2">
              <TextArea value={v.moTa} onChange={set("moTa")} maxLength={1000} rows={3} />
            </Field>
            <Field label="Voucher tặng khi hoàn thành (%)" error={errors.phanTramVoucher} hint="0 = không tặng.">
              <TextInput type="number" min={0} max={50} value={v.phanTramVoucher} onChange={set("phanTramVoucher")} />
            </Field>
            <Field label="Hiệu lực voucher (ngày)" error={errors.soNgayHieuLucVoucher}>
              <TextInput type="number" min={1} max={365} value={v.soNgayHieuLucVoucher} onChange={set("soNgayHieuLucVoucher")} />
            </Field>
          </div>
        </Panel>
        <div className="flex gap-2">
          <Button type="submit" loading={create.isPending}>Tạo khảo sát nháp</Button>
          <Button variant="ghost" onClick={() => nav("/manager/surveys")}>Hủy</Button>
        </div>
      </form>
    </>
  );
}
