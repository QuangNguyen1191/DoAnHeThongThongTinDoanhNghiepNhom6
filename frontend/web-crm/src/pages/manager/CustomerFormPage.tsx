import { useEffect, useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useNavigate, useParams } from "react-router";
import { ArrowLeft, Check, Copy } from "lucide-react";
import { api } from "@shared/api/client";
import { fieldErrors, isApiError } from "@shared/api/errors";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, ForbiddenState, Skeleton } from "@shared/pages/PageStates";
import { Alert } from "@shared/ui/Alert";
import { Button } from "@shared/ui/Button";
import { cn } from "@shared/ui/cn";
import { Field, Select, TextInput } from "@shared/ui/Field";
import { useToast } from "@shared/ui/Toast";
import { GIOI_TINH, Panel, useCan, useCategories, useProvinces } from "./common";
import type { CustomerProfile } from "./CustomerDetailPage";

interface FormValues {
  hoTen: string;
  sdt: string;
  gioiTinh: string;
  ngaySinh: string;
  email: string;
  maTinh: string;
  dsLoaiQuanTam: number[];
  capTaiKhoan: boolean;
  tenDangNhap: string;
}
const EMPTY: FormValues = { hoTen: "", sdt: "", gioiTinh: "", ngaySinh: "", email: "", maTinh: "", dsLoaiQuanTam: [], capTaiKhoan: true, tenDangNhap: "" };

function validate(v: FormValues, creating: boolean) {
  const e: Record<string, string> = {};
  if (!v.hoTen.trim()) e.hoTen = "Họ tên là bắt buộc.";
  if (!/^0\d{9}$/.test(v.sdt.trim())) e.sdt = "Số điện thoại gồm đúng 10 chữ số, bắt đầu bằng 0.";
  if (v.email.trim() && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v.email.trim())) e.email = "Email không hợp lệ.";
  if (v.ngaySinh && v.ngaySinh > new Date().toISOString().slice(0, 10)) e.ngaySinh = "Ngày sinh không được ở tương lai.";
  if (creating && v.capTaiKhoan && !/^\S{4,50}$/.test(v.tenDangNhap.trim())) e.tenDangNhap = "Tên đăng nhập 4–50 ký tự, không có khoảng trắng.";
  return e;
}

export interface TempPassword { tenDangNhap: string; matKhauTam: string }

/** Hộp hiện mật khẩu tạm một lần (sau khi thêm khách hoặc cấp tài khoản). */
export function TempPasswordBox({ value }: { value: TempPassword }) {
  const [copied, setCopied] = useState(false);
  return (
    <Alert tone="success" title="Đã cấp tài khoản cho khách hàng">
      <p>Mật khẩu tạm chỉ hiện một lần. Gửi cho khách; khách phải đổi mật khẩu ở lần đăng nhập đầu tiên.</p>
      <dl className="mt-2 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1">
        <dt>Tên đăng nhập</dt>
        <dd className="font-mono font-semibold text-ink" data-testid="ten-dang-nhap">{value.tenDangNhap}</dd>
        <dt>Mật khẩu tạm</dt>
        <dd className="flex items-center gap-2">
          <span className="font-mono font-semibold text-ink" data-testid="mat-khau-tam">{value.matKhauTam}</span>
          <button
            type="button"
            className="inline-flex items-center gap-1 text-xs font-medium text-ink-soft hover:text-ink"
            onClick={() => void navigator.clipboard?.writeText(value.matKhauTam).then(() => setCopied(true))}
          >
            {copied ? <Check className="size-3.5" aria-hidden="true" /> : <Copy className="size-3.5" aria-hidden="true" />}
            {copied ? "Đã chép" : "Chép"}
          </button>
        </dd>
      </dl>
    </Alert>
  );
}

/** Q3 (QL-1) thêm khách hàng mới · Q4 sửa hồ sơ. Cùng một form; ở chế độ thêm có tùy chọn cấp tài khoản. */
export function CustomerFormPage() {
  const { maKH } = useParams();
  const editing = !!maKH;
  const can = useCan();
  const nav = useNavigate();
  const qc = useQueryClient();
  const toast = useToast();
  const provinces = useProvinces();
  const categories = useCategories();
  const [v, setV] = useState<FormValues>(EMPTY);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [created, setCreated] = useState<{ maKH: number; tk?: TempPassword } | null>(null);

  const profile = useQuery({
    queryKey: ["manager", "customer", Number(maKH)],
    queryFn: () => api.get<CustomerProfile>(`/api/manager/customers/${maKH}`),
    enabled: editing,
  });
  useEffect(() => {
    const h = profile.data?.hoSo;
    if (!h) return;
    setV({
      hoTen: h.hoTen, sdt: h.sdt, gioiTinh: h.gioiTinh ?? "", ngaySinh: h.ngaySinh?.slice(0, 10) ?? "", email: h.email ?? "",
      maTinh: h.maTinh ?? "", dsLoaiQuanTam: profile.data!.soThich.map((s) => s.maLoai), capTaiKhoan: false, tenDangNhap: "",
    });
  }, [profile.data]);

  const save = useMutation({
    mutationFn: async (x: FormValues) => {
      const body = {
        hoTen: x.hoTen.trim(), sdt: x.sdt.trim(), gioiTinh: x.gioiTinh || null, ngaySinh: x.ngaySinh || null,
        email: x.email.trim() || null, maTinh: x.maTinh || null, dsLoaiQuanTam: x.dsLoaiQuanTam,
      };
      if (editing) {
        await api.put(`/api/manager/customers/${maKH}`, { ...body, capNhatSoThich: true });
        return null;
      }
      return api.post<{ maKH: number; tenDangNhap?: string; matKhauTam?: string }>("/api/manager/customers", {
        ...body, tenDangNhap: x.capTaiKhoan ? x.tenDangNhap.trim() : null,
      });
    },
    onSuccess: (r) => {
      void qc.invalidateQueries({ queryKey: ["manager"] });
      if (editing) {
        toast("success", "Đã cập nhật hồ sơ khách hàng.");
        nav(`/manager/customers/${maKH}`);
      } else if (r) {
        toast("success", `Đã thêm khách hàng ${v.hoTen.trim()}.`);
        setCreated({ maKH: r.maKH, tk: r.matKhauTam ? { tenDangNhap: r.tenDangNhap!, matKhauTam: r.matKhauTam } : undefined });
      }
    },
    onError: (e) => {
      if (!isApiError(e)) return setFormError("Đã có lỗi xảy ra.");
      // Lỗi trùng SĐT/email/tên đăng nhập (409) đã kèm `field` từ API.
      const fe = fieldErrors(e);
      setErrors(fe);
      setFormError(Object.keys(fe).length ? "Vui lòng kiểm tra các ô được đánh dấu." : e.userMessage);
    },
  });

  if (!can(editing ? "QL_KH_SUA" : "QL_KH_THEM")) return <ForbiddenState />;
  if (editing && profile.isError) return <ErrorState error={profile.error} onRetry={() => profile.refetch()} />;
  if (editing && profile.isPending) return <Skeleton className="h-96" />;
  if (editing && profile.data?.hoSo.trangThaiHoSo === "DA_XOA") return <Alert tone="warning">Hồ sơ đã bị xóa, không sửa được.</Alert>;

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setFormError(null);
    const errs = validate(v, !editing);
    setErrors(errs);
    if (Object.keys(errs).length) return setFormError("Vui lòng kiểm tra các ô được đánh dấu.");
    save.mutate(v);
  };
  const set = (k: keyof FormValues) => (e: { target: { value: string } }) => setV((x) => ({ ...x, [k]: e.target.value }));
  const toggle = (m: number) =>
    setV((x) => ({ ...x, dsLoaiQuanTam: x.dsLoaiQuanTam.includes(m) ? x.dsLoaiQuanTam.filter((y) => y !== m) : [...x.dsLoaiQuanTam, m] }));
  const back = editing ? `/manager/customers/${maKH}` : "/manager/customers";

  if (created) {
    return (
      <>
        <PageHeader title="Đã thêm khách hàng" description={`${v.hoTen.trim()} · mã ${created.maKH}`} />
        <div className="flex max-w-xl flex-col gap-4">
          {created.tk ? <TempPasswordBox value={created.tk} /> : <Alert tone="success">Đã tạo hồ sơ (chưa cấp tài khoản đăng nhập). Có thể cấp sau trong trang hồ sơ.</Alert>}
          <div className="flex flex-wrap gap-2">
            <Button onClick={() => nav(`/manager/customers/${created.maKH}`)}>Xem hồ sơ</Button>
            <Button variant="secondary" onClick={() => { setCreated(null); setV(EMPTY); }}>Thêm khách khác</Button>
          </div>
        </div>
      </>
    );
  }

  return (
    <>
      <Link to={back} className="mb-3 inline-flex items-center gap-1.5 text-sm font-medium text-ink-soft hover:text-ink">
        <ArrowLeft className="size-4" aria-hidden="true" /> {editing ? "Về hồ sơ" : "Về danh sách"}
      </Link>
      <PageHeader title={editing ? "Sửa hồ sơ khách hàng" : "Thêm khách hàng mới"} description={editing ? profile.data?.hoSo.hoTen : "Tạo hồ sơ, có thể cấp luôn tài khoản đăng nhập với mật khẩu tạm."} />
      <form onSubmit={submit} noValidate className="flex max-w-3xl flex-col gap-5">
        {formError && <Alert tone="error">{formError}</Alert>}
        <Panel title="Thông tin cá nhân">
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Họ tên" required error={errors.hoTen} className="sm:col-span-2">
              <TextInput value={v.hoTen} onChange={set("hoTen")} maxLength={100} autoComplete="off" />
            </Field>
            <Field label="Số điện thoại" required error={errors.sdt}>
              <TextInput value={v.sdt} onChange={set("sdt")} inputMode="numeric" maxLength={10} placeholder="0901234567" />
            </Field>
            <Field label="Email" error={errors.email}>
              <TextInput type="email" value={v.email} onChange={set("email")} maxLength={100} />
            </Field>
            <Field label="Giới tính" error={errors.gioiTinh}>
              <Select value={v.gioiTinh} onChange={set("gioiTinh")}>
                <option value="">Không rõ</option>
                {Object.entries(GIOI_TINH).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
              </Select>
            </Field>
            <Field label="Ngày sinh" error={errors.ngaySinh}>
              <TextInput type="date" value={v.ngaySinh} onChange={set("ngaySinh")} max={new Date().toISOString().slice(0, 10)} />
            </Field>
            <Field label="Tỉnh/thành" error={errors.maTinh}>
              <Select value={v.maTinh} onChange={set("maTinh")}>
                <option value="">Chọn tỉnh/thành</option>
                {provinces.data?.map((p) => <option key={p.maTinh} value={p.maTinh}>{p.tenTinh}</option>)}
              </Select>
            </Field>
          </div>
        </Panel>
        <Panel title="Sở thích (loại sản phẩm quan tâm)">
          <div className="flex flex-wrap gap-2" role="group" aria-label="Loại sản phẩm quan tâm">
            {categories.data?.map((c) => {
              const on = v.dsLoaiQuanTam.includes(c.maLoai);
              return (
                <button
                  key={c.maLoai}
                  type="button"
                  aria-pressed={on}
                  onClick={() => toggle(c.maLoai)}
                  className={cn("inline-flex h-9 items-center gap-1.5 rounded-full border px-3.5 text-sm transition-colors", on ? "border-ink bg-ink text-white" : "border-line-strong hover:border-ink")}
                >
                  {on && <Check className="size-3.5" aria-hidden="true" />}
                  {c.tenLoai}
                </button>
              );
            })}
          </div>
        </Panel>
        {!editing && (
          <Panel title="Tài khoản đăng nhập">
            <label className="flex items-center gap-2.5 text-[15px]">
              <input type="checkbox" className="size-4 accent-[var(--color-ink)]" checked={v.capTaiKhoan} onChange={(e) => setV((x) => ({ ...x, capTaiKhoan: e.target.checked }))} />
              Cấp tài khoản ngay (để khách đăng nhập và nhận khảo sát)
            </label>
            {v.capTaiKhoan && (
              <Field label="Tên đăng nhập" required error={errors.tenDangNhap} hint="Hệ thống tự sinh mật khẩu tạm và hiện một lần sau khi lưu." className="mt-4 max-w-sm">
                <TextInput value={v.tenDangNhap} onChange={set("tenDangNhap")} autoComplete="off" spellCheck={false} placeholder="vd. kh.minh" />
              </Field>
            )}
          </Panel>
        )}
        <div className="flex gap-2">
          <Button type="submit" loading={save.isPending}>{editing ? "Lưu thay đổi" : "Thêm khách hàng"}</Button>
          <Button variant="ghost" onClick={() => nav(back)}>Hủy</Button>
        </div>
      </form>
    </>
  );
}
