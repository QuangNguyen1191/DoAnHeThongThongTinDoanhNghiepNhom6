import { useEffect, useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Check, Pencil } from "lucide-react";
import { api } from "@shared/api/client";
import { fieldErrors, isApiError } from "@shared/api/errors";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { Alert } from "@shared/ui/Alert";
import { Button } from "@shared/ui/Button";
import { cn } from "@shared/ui/cn";
import { Field, Select, TextInput } from "@shared/ui/Field";
import { useToast } from "@shared/ui/Toast";
import { GIOI_TINH, Panel, dateVi, useCategories, useProvinces } from "../manager/common";

export interface MyProfile {
  hoSo: {
    maKH: number;
    hoTen: string;
    gioiTinh: string | null;
    ngaySinh: string | null;
    tuoi: number | null;
    sdt: string;
    email: string | null;
    maTinh: string | null;
    tenTinh: string | null;
    ngayDangKy: string;
    maHang: string;
    tenHang: string;
    diem: number;
    hangKeTiep: string | null;
    diemCanThem: number | null;
  };
  soThich: { maLoai: number; tenLoai: string }[];
}

interface FormValues {
  hoTen: string;
  sdt: string;
  gioiTinh: string;
  ngaySinh: string;
  email: string;
  maTinh: string;
  dsLoaiQuanTam: number[];
}

const toForm = (p: MyProfile): FormValues => ({
  hoTen: p.hoSo.hoTen,
  sdt: p.hoSo.sdt,
  gioiTinh: p.hoSo.gioiTinh ?? "",
  ngaySinh: p.hoSo.ngaySinh?.slice(0, 10) ?? "",
  email: p.hoSo.email ?? "",
  maTinh: p.hoSo.maTinh ?? "",
  dsLoaiQuanTam: p.soThich.map((s) => s.maLoai),
});

/** Cùng ràng buộc với API (CustomerProfileInput) và CHECK trong CSDL. */
function validate(v: FormValues) {
  const e: Record<string, string> = {};
  if (!v.hoTen.trim()) e.hoTen = "Họ tên là bắt buộc.";
  if (!/^0\d{9}$/.test(v.sdt.trim())) e.sdt = "Số điện thoại gồm đúng 10 chữ số, bắt đầu bằng 0.";
  if (v.email.trim() && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v.email.trim())) e.email = "Email không hợp lệ.";
  if (v.ngaySinh && (v.ngaySinh < "1900-01-01" || v.ngaySinh > new Date().toISOString().slice(0, 10)))
    e.ngaySinh = "Ngày sinh phải từ năm 1900 đến hôm nay.";
  return e;
}

/** K1–K2 (KH-2). Xem và chỉnh sửa thông tin cá nhân, sở thích. */
export function ProfilePage() {
  const qc = useQueryClient();
  const toast = useToast();
  const provinces = useProvinces();
  const categories = useCategories();
  const q = useQuery({ queryKey: ["customer", "profile"], queryFn: () => api.get<MyProfile>("/api/customer/profile") });
  const [editing, setEditing] = useState(false);
  const [v, setV] = useState<FormValues | null>(null);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);

  useEffect(() => {
    if (q.data && !editing) setV(toForm(q.data));
  }, [q.data, editing]);

  const save = useMutation({
    mutationFn: (x: FormValues) =>
      api.put("/api/customer/profile", {
        hoTen: x.hoTen.trim(),
        sdt: x.sdt.trim(),
        gioiTinh: x.gioiTinh || null,
        ngaySinh: x.ngaySinh || null,
        email: x.email.trim() || null,
        maTinh: x.maTinh || null,
        capNhatSoThich: true,
        dsLoaiQuanTam: x.dsLoaiQuanTam,
      }),
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ["customer"] });
      setEditing(false);
      toast("success", "Đã lưu thông tin cá nhân.");
    },
    onError: (e) => {
      if (!isApiError(e)) return setFormError("Đã có lỗi xảy ra.");
      const fe = fieldErrors(e);
      setErrors(fe);
      setFormError(Object.keys(fe).length ? "Vui lòng kiểm tra các ô được đánh dấu." : e.userMessage);
    },
  });

  if (q.isError) return <ErrorState error={q.error} onRetry={() => q.refetch()} />;
  if (q.isPending || !v) return <Skeleton className="h-96" />;
  const h = q.data.hoSo;

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setFormError(null);
    const errs = validate(v);
    setErrors(errs);
    if (Object.keys(errs).length) return setFormError("Vui lòng kiểm tra các ô được đánh dấu.");
    save.mutate(v);
  };
  const set = (k: keyof FormValues) => (e: { target: { value: string } }) => {
    setV((x) => x && { ...x, [k]: e.target.value });
    setErrors(({ [k]: _, ...rest }) => rest);
  };
  const toggle = (m: number) =>
    setV((x) => x && { ...x, dsLoaiQuanTam: x.dsLoaiQuanTam.includes(m) ? x.dsLoaiQuanTam.filter((y) => y !== m) : [...x.dsLoaiQuanTam, m] });
  const cancel = () => {
    setEditing(false);
    setErrors({});
    setFormError(null);
    setV(toForm(q.data));
  };

  return (
    <>
      <PageHeader
        title="Thông tin cá nhân"
        description="Cập nhật thông tin liên hệ và sở thích để nhận khảo sát, ưu đãi phù hợp."
        actions={!editing && <Button variant="secondary" icon={<Pencil className="size-4" aria-hidden="true" />} onClick={() => setEditing(true)}>Chỉnh sửa thông tin</Button>}
      />
      <div className="grid gap-5 lg:grid-cols-[1fr_300px]">
        <form onSubmit={submit} noValidate className="flex flex-col gap-5" aria-label="Thông tin cá nhân">
          {formError && <Alert tone="error">{formError}</Alert>}
          <Panel title="Thông tin liên hệ">
            {editing ? (
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label="Họ tên" required error={errors.hoTen} className="sm:col-span-2">
                  <TextInput value={v.hoTen} onChange={set("hoTen")} maxLength={100} autoComplete="name" />
                </Field>
                <Field label="Số điện thoại" required error={errors.sdt}>
                  <TextInput value={v.sdt} onChange={set("sdt")} type="tel" inputMode="numeric" maxLength={10} autoComplete="tel-national" />
                </Field>
                <Field label="Email" error={errors.email} hint="Dùng để lấy lại mật khẩu khi quên.">
                  <TextInput type="email" value={v.email} onChange={set("email")} maxLength={100} autoComplete="email" />
                </Field>
                <Field label="Giới tính" error={errors.gioiTinh}>
                  <Select value={v.gioiTinh} onChange={set("gioiTinh")}>
                    <option value="">Không muốn nêu</option>
                    {Object.entries(GIOI_TINH).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
                  </Select>
                </Field>
                <Field label="Ngày sinh" error={errors.ngaySinh}>
                  <TextInput type="date" value={v.ngaySinh} onChange={set("ngaySinh")} min="1900-01-01" max={new Date().toISOString().slice(0, 10)} />
                </Field>
                <Field label="Tỉnh / thành phố" error={errors.maTinh} className="sm:col-span-2">
                  <Select value={v.maTinh} onChange={set("maTinh")}>
                    <option value="">Chọn tỉnh / thành</option>
                    {provinces.data?.map((p) => <option key={p.maTinh} value={p.maTinh}>{p.tenTinh}</option>)}
                  </Select>
                </Field>
              </div>
            ) : (
              <dl className="grid gap-x-6 gap-y-4 text-[15px] sm:grid-cols-2" data-testid="ho-so">
                {[
                  ["Họ tên", h.hoTen],
                  ["Số điện thoại", h.sdt],
                  ["Email", h.email ?? "—"],
                  ["Giới tính", h.gioiTinh ? GIOI_TINH[h.gioiTinh] : "—"],
                  ["Ngày sinh", h.ngaySinh ? `${dateVi(h.ngaySinh)} (${h.tuoi} tuổi)` : "—"],
                  ["Tỉnh / thành phố", h.tenTinh ?? "—"],
                ].map(([k, val]) => (
                  <div key={k}>
                    <dt className="text-sm text-muted">{k}</dt>
                    <dd className="mt-0.5 font-medium">{val}</dd>
                  </div>
                ))}
              </dl>
            )}
          </Panel>
          <Panel title="Sở thích mua sắm">
            {editing ? (
              <>
                <p className="mb-3 text-sm text-muted">Chọn các nhóm sản phẩm bạn quan tâm. Bỏ chọn hết nếu không muốn nêu.</p>
                <div className="flex flex-wrap gap-2" role="group" aria-label="Loại sản phẩm quan tâm">
                  {categories.data?.map((c) => {
                    const on = v.dsLoaiQuanTam.includes(c.maLoai);
                    return (
                      <button
                        key={c.maLoai}
                        type="button"
                        aria-pressed={on}
                        onClick={() => toggle(c.maLoai)}
                        className={cn("inline-flex h-10 items-center gap-1.5 rounded-full border px-4 text-sm transition-colors", on ? "border-ink bg-ink text-white" : "border-line-strong hover:border-ink")}
                      >
                        {on && <Check className="size-3.5" strokeWidth={3} aria-hidden="true" />}
                        {c.tenLoai}
                      </button>
                    );
                  })}
                </div>
              </>
            ) : q.data.soThich.length ? (
              <ul className="flex flex-wrap gap-2" aria-label="Sở thích đã chọn">
                {q.data.soThich.map((s) => <li key={s.maLoai} className="rounded-full border border-line-strong px-3.5 py-1.5 text-sm">{s.tenLoai}</li>)}
              </ul>
            ) : (
              <p className="text-sm text-muted">Chưa chọn sở thích nào.</p>
            )}
          </Panel>
          {editing && (
            <div className="flex gap-2">
              <Button type="submit" loading={save.isPending}>Lưu thay đổi</Button>
              <Button variant="ghost" onClick={cancel}>Hủy</Button>
            </div>
          )}
        </form>
        <aside className="flex flex-col gap-4">
          <section className="relative overflow-hidden rounded-md bg-night p-5 text-white">
            <div aria-hidden="true" className="absolute -right-8 -top-8 size-28 bg-accent" style={{ clipPath: "polygon(35% 0, 100% 0, 100% 100%)" }} />
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-white/60">Hạng thành viên</p>
            <p className="mt-1.5 text-2xl font-bold">{h.tenHang}</p>
            <p className="tabular mt-3 text-white/80"><span className="text-xl font-bold text-white">{h.diem.toLocaleString("vi-VN")}</span> điểm</p>
            {h.hangKeTiep && h.diemCanThem != null && (
              <p className="mt-1 text-sm text-white/60">Còn {h.diemCanThem.toLocaleString("vi-VN")} điểm để lên {h.hangKeTiep}.</p>
            )}
          </section>
          <p className="text-sm text-muted">Thành viên từ {dateVi(h.ngayDangKy)} · mã khách hàng {h.maKH}. Hạng và điểm do hệ thống tính từ hóa đơn, không sửa được.</p>
        </aside>
      </div>
    </>
  );
}
