import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link } from "react-router";
import { ArrowLeft, Plus, X } from "lucide-react";
import { api } from "@shared/api/client";
import { fieldErrors, isApiError } from "@shared/api/errors";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { Alert } from "@shared/ui/Alert";
import { Button } from "@shared/ui/Button";
import { Panel, pct, vnd } from "@shared/ui/data";
import { Field, Select, TextInput } from "@shared/ui/Field";
import { KENH_BAN, localDateTime, useLookups, type NhanVien } from "./common";
import type { KhachHangTraCuu } from "./CustomerLookupPage";

interface SanPham { maSP: number; maSKU: string; tenSP: string; giaNiemYet: number; trangThai: string }
interface Line { maSKU: string; soLuong: string; donGiaBan: string }
interface Result { maHD: number; soHoaDon: string; tongTienHang: number; phanTramGiam: number; thanhTien: number; hangSauKhiNap: string }

const newLine = (): Line => ({ maSKU: "", soLuong: "1", donGiaBan: "" });

/** A13. Nạp một hóa đơn nhiều dòng (SKU, số lượng, đơn giá) + voucher tùy chọn; kênh Online thì không có cửa hàng/nhân viên. */
export function InvoiceFormPage() {
  const qc = useQueryClient();
  const lookups = useLookups();
  const [v, setV] = useState({ soHoaDon: "", maKH: "", kenhBan: "CUA_HANG", ngayLap: localDateTime(), maCH: "", maNV: "", maCodeVoucher: "" });
  const [lines, setLines] = useState<Line[]>([newLine()]);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [result, setResult] = useState<Result | null>(null);

  const customers = useQuery({
    queryKey: ["admin", "customers", { tuKhoa: "", maHang: "" }],
    queryFn: () => api.get<KhachHangTraCuu[]>("/api/admin/customers"),
  });
  const products = useQuery({
    queryKey: ["catalog", "products"],
    queryFn: () => api.get<SanPham[]>("/api/catalog/products"),
    staleTime: Infinity,
  });
  const staff = useQuery({
    queryKey: ["admin", "employees", { trangThai: "DANG_LAM", maCH: v.maCH }],
    queryFn: () => api.get<NhanVien[]>("/api/admin/employees", { query: { trangThai: "DANG_LAM", maCH: v.maCH } }),
    enabled: v.kenhBan === "CUA_HANG" && !!v.maCH,
  });
  const sellable = (products.data ?? []).filter((p) => p.trangThai !== "SAP_RA_MAT");
  const activeCustomers = (customers.data ?? []).filter((k) => k.trangThaiHoSo === "HOAT_DONG");

  const set = (k: keyof typeof v) => (e: { target: { value: string } }) => setV((x) => ({ ...x, [k]: e.target.value }));
  const setLine = (i: number, k: keyof Line, value: string) =>
    setLines((ls) => ls.map((l, j) => {
      if (j !== i) return l;
      const next = { ...l, [k]: value };
      // Chọn SKU → điền sẵn giá niêm yết (sửa được nếu POS bán giá khác).
      if (k === "maSKU") next.donGiaBan = String(sellable.find((p) => p.maSKU === value)?.giaNiemYet ?? "");
      return next;
    }));
  const tongTam = lines.reduce((s, l) => s + (Number(l.soLuong) || 0) * (Number(l.donGiaBan) || 0), 0);

  const save = useMutation({
    mutationFn: () => api.post<Result>("/api/admin/invoices", {
      soHoaDon: v.soHoaDon.trim(),
      maKH: Number(v.maKH),
      kenhBan: v.kenhBan,
      ngayLap: new Date(v.ngayLap).toISOString(),
      maCH: v.kenhBan === "CUA_HANG" ? Number(v.maCH) : null,
      maNV: v.kenhBan === "CUA_HANG" ? Number(v.maNV) : null,
      maCodeVoucher: v.maCodeVoucher.trim() || null,
      chiTiet: lines.map((l) => ({ maSKU: l.maSKU, soLuong: Number(l.soLuong), donGiaBan: Number(l.donGiaBan) })),
    }),
    onSuccess: (r) => {
      setResult(r);
      void qc.invalidateQueries({ queryKey: ["admin"] });
    },
    onError: (e) => {
      if (!isApiError(e)) return setFormError("Đã có lỗi xảy ra.");
      const f = fieldErrors(e);
      setErrors(f);
      setFormError(f.soHoaDon ? null : e.userMessage);
    },
  });

  const submit = () => {
    const err: Record<string, string> = {};
    if (!v.soHoaDon.trim()) err.soHoaDon = "Số hóa đơn là bắt buộc.";
    if (!v.maKH) err.maKH = "Cần chọn khách hàng.";
    if (!v.ngayLap) err.ngayLap = "Ngày lập là bắt buộc.";
    else if (new Date(v.ngayLap) > new Date()) err.ngayLap = "Ngày lập không được ở tương lai.";
    if (v.kenhBan === "CUA_HANG" && !v.maCH) err.maCH = "Hóa đơn tại cửa hàng cần cửa hàng.";
    if (v.kenhBan === "CUA_HANG" && !v.maNV) err.maNV = "Hóa đơn tại cửa hàng cần nhân viên bán.";
    lines.forEach((l, i) => {
      if (!l.maSKU) err[`l${i}`] = "Chọn sản phẩm.";
      else if (!(Number(l.soLuong) >= 1) || !Number.isInteger(Number(l.soLuong))) err[`l${i}`] = "Số lượng phải là số nguyên ≥ 1.";
      else if (l.donGiaBan === "" || Number(l.donGiaBan) < 0) err[`l${i}`] = "Đơn giá phải ≥ 0.";
    });
    if (new Set(lines.map((l) => l.maSKU)).size !== lines.length) err.lines = "Mỗi SKU chỉ một dòng; tăng số lượng thay vì thêm dòng trùng.";
    setErrors(err);
    setFormError(null);
    if (!Object.keys(err).length) save.mutate();
  };

  if (result) {
    const kh = activeCustomers.find((k) => k.maKH === Number(v.maKH));
    return (
      <>
        <PageHeader title="Đã nạp hóa đơn" />
        <Alert tone="success" title={`Hóa đơn ${result.soHoaDon} đã được nạp`}>
          <dl className="mt-2 grid max-w-md grid-cols-[auto_1fr] gap-x-6 gap-y-1">
            <dt>Khách hàng</dt><dd className="text-ink">{kh?.hoTen ?? `Mã ${v.maKH}`}</dd>
            <dt>Tổng tiền hàng</dt><dd className="tabular text-ink">{vnd(result.tongTienHang)}</dd>
            <dt>Giảm (voucher)</dt><dd className="tabular text-ink">{result.phanTramGiam ? pct(result.phanTramGiam) : "—"}</dd>
            <dt>Thành tiền</dt><dd className="tabular font-semibold text-ink">{vnd(result.thanhTien)}</dd>
            <dt>Hạng sau khi nạp</dt><dd className="font-semibold text-accent" data-testid="hang-sau-khi-nap">{result.hangSauKhiNap}</dd>
          </dl>
        </Alert>
        <div className="mt-5 flex gap-2">
          <Button onClick={() => { setResult(null); setV((x) => ({ ...x, soHoaDon: "", maCodeVoucher: "" })); setLines([newLine()]); }}>Nạp hóa đơn khác</Button>
          <Link to="/admin/invoices" className="inline-flex h-11 items-center rounded-md border border-line-strong px-4 text-[15px] font-semibold hover:border-ink">Về danh sách hóa đơn</Link>
        </div>
      </>
    );
  }

  return (
    <>
      <Link to="/admin/invoices" className="mb-3 inline-flex items-center gap-1.5 text-sm font-medium text-ink-soft hover:text-ink">
        <ArrowLeft className="size-4" aria-hidden="true" /> Về danh sách
      </Link>
      <PageHeader title="Nạp hóa đơn" description="Nhập hóa đơn từ máy POS hoặc đơn online. Điểm, voucher và hạng thành viên do CSDL tính trong cùng một giao dịch." />

      <div className="flex flex-col gap-5">
        <Panel title="Thông tin hóa đơn">
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <Field label="Số hóa đơn" required error={errors.soHoaDon} hint="Số in trên hóa đơn POS, không trùng hóa đơn đã nạp.">
              <TextInput value={v.soHoaDon} onChange={set("soHoaDon")} maxLength={20} spellCheck={false} />
            </Field>
            <Field label="Khách hàng" required error={errors.maKH}>
              <Select value={v.maKH} onChange={set("maKH")}>
                <option value="">{customers.isPending ? "Đang tải…" : "Chọn khách hàng"}</option>
                {activeCustomers.map((k) => <option key={k.maKH} value={k.maKH}>{k.hoTen} · mã {k.maKH} · {k.maHang}</option>)}
              </Select>
            </Field>
            <Field label="Ngày lập" required error={errors.ngayLap}>
              <TextInput type="datetime-local" value={v.ngayLap} onChange={set("ngayLap")} />
            </Field>
            <Field label="Kênh bán" required>
              <Select value={v.kenhBan} onChange={set("kenhBan")}>
                {Object.entries(KENH_BAN).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
              </Select>
            </Field>
            {v.kenhBan === "CUA_HANG" && (
              <>
                <Field label="Cửa hàng" required error={errors.maCH}>
                  <Select value={v.maCH} onChange={(e) => setV((x) => ({ ...x, maCH: e.target.value, maNV: "" }))}>
                    <option value="">Chọn cửa hàng</option>
                    {lookups.data?.cuaHang.filter((c) => c.trangThai === "HOAT_DONG").map((c) => <option key={c.maCH} value={c.maCH}>{c.tenCH}</option>)}
                  </Select>
                </Field>
                <Field label="Nhân viên bán" required error={errors.maNV}>
                  <Select value={v.maNV} onChange={set("maNV")} disabled={!v.maCH}>
                    <option value="">{v.maCH ? (staff.data?.length === 0 ? "Cửa hàng chưa có nhân viên" : "Chọn nhân viên") : "Chọn cửa hàng trước"}</option>
                    {staff.data?.map((e) => <option key={e.maNV} value={e.maNV}>{e.hoTen} · {e.tenCV}</option>)}
                  </Select>
                </Field>
              </>
            )}
            <Field label="Mã voucher" hint="Tùy chọn. Voucher phải của đúng khách này, chưa dùng và còn hạn tại ngày lập.">
              <TextInput value={v.maCodeVoucher} onChange={set("maCodeVoucher")} maxLength={20} spellCheck={false} />
            </Field>
          </div>
        </Panel>

        <Panel
          title="Dòng hàng"
          actions={<Button size="sm" variant="secondary" icon={<Plus className="size-4" aria-hidden="true" />} onClick={() => setLines((ls) => [...ls, newLine()])}>Thêm dòng</Button>}
        >
          <div className="flex flex-col gap-3">
            {lines.map((l, i) => (
              <div key={i} className="grid items-start gap-3 sm:grid-cols-[2fr_100px_160px_auto]">
                <Field label={`Sản phẩm dòng ${i + 1}`} error={errors[`l${i}`]}>
                  <Select value={l.maSKU} onChange={(e) => setLine(i, "maSKU", e.target.value)}>
                    <option value="">Chọn sản phẩm</option>
                    {sellable.map((p) => <option key={p.maSKU} value={p.maSKU}>{p.maSKU} · {p.tenSP}</option>)}
                  </Select>
                </Field>
                <Field label="Số lượng">
                  <TextInput type="number" min={1} value={l.soLuong} onChange={(e) => setLine(i, "soLuong", e.target.value)} />
                </Field>
                <Field label="Đơn giá bán (₫)">
                  <TextInput type="number" min={0} step={1000} value={l.donGiaBan} onChange={(e) => setLine(i, "donGiaBan", e.target.value)} />
                </Field>
                <div className="pt-7">
                  <Button variant="ghost" size="sm" aria-label={`Xóa dòng ${i + 1}`} disabled={lines.length === 1} onClick={() => setLines((ls) => ls.filter((_, j) => j !== i))}>
                    <X className="size-4" aria-hidden="true" />
                  </Button>
                </div>
              </div>
            ))}
            {errors.lines && <Alert tone="error">{errors.lines}</Alert>}
            <p className="text-right text-sm text-muted">Tạm tính (chưa trừ voucher): <span className="tabular font-semibold text-ink">{vnd(tongTam)}</span></p>
          </div>
        </Panel>

        {formError && <Alert tone="error">{formError}</Alert>}
        <div className="flex justify-end gap-2">
          <Link to="/admin/invoices" className="inline-flex h-11 items-center rounded-md px-4 text-[15px] font-semibold hover:bg-surface">Hủy</Link>
          <Button loading={save.isPending} onClick={submit}>Nạp hóa đơn</Button>
        </div>
      </div>
    </>
  );
}
