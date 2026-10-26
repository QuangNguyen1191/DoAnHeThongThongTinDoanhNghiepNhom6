import { useState } from "react";
import { Controller, useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router";
import { ArrowLeft, Check } from "lucide-react";
import { api } from "@shared/api/client";
import { fieldErrors, isApiError } from "@shared/api/errors";
import { useAuth } from "@shared/auth/AuthProvider";
import { PasswordChecklist } from "@shared/forms/PasswordChecklist";
import { registerSchema, type RegisterValues } from "@shared/forms/schemas";
import { Alert } from "@shared/ui/Alert";
import { Button } from "@shared/ui/Button";
import { cn } from "@shared/ui/cn";
import { Field, Select, TextInput } from "@shared/ui/Field";
import { PasswordInput } from "@shared/ui/PasswordInput";
import { AuthHeading, AuthLayout } from "@shared/pages/auth/AuthLayout";

interface Province { maTinh: string; tenTinh: string }
interface Category { maLoai: number; tenLoai: string; moTa: string | null }

const GENDERS = [
  { v: "NAM", l: "Nam" },
  { v: "NU", l: "Nữ" },
  { v: "KHAC", l: "Khác" },
] as const;

function Section({ n, title, children }: { n: number; title: string; children: React.ReactNode }) {
  return (
    <fieldset className="border-t border-line pt-6 first:border-t-0 first:pt-0">
      <legend className="float-left mb-5 flex w-full items-center gap-3 text-[15px] font-semibold">
        <span aria-hidden="true" className="grid size-6 place-items-center rounded-full bg-ink text-xs font-bold text-white">{n}</span>
        {title}
      </legend>
      <div className="clear-both grid gap-5 sm:grid-cols-2">{children}</div>
    </fieldset>
  );
}

/** L2. Khách tự đăng ký; thành công thì API đăng nhập luôn và <PublicOnly> đưa vào /customer. */
export function RegisterPage() {
  const { register: signUp } = useAuth();
  const [formError, setFormError] = useState<string | null>(null);
  const [sdtTaken, setSdtTaken] = useState(false);

  const provinces = useQuery({ queryKey: ["catalog", "provinces"], queryFn: () => api.get<Province[]>("/api/catalog/provinces"), staleTime: Infinity });
  const categories = useQuery({ queryKey: ["catalog", "categories"], queryFn: () => api.get<Category[]>("/api/catalog/categories"), staleTime: Infinity });

  const {
    register,
    control,
    handleSubmit,
    watch,
    setError,
    setFocus,
    formState: { errors, isSubmitting },
  } = useForm<RegisterValues>({
    resolver: zodResolver(registerSchema),
    defaultValues: { hoTen: "", sdt: "", gioiTinh: null, ngaySinh: "", email: "", maTinh: "", dsLoaiQuanTam: [], tenDangNhap: "", matKhau: "", nhapLai: "" },
  });

  const onSubmit = handleSubmit(async (v) => {
    setFormError(null);
    setSdtTaken(false);
    try {
      await signUp({
        tenDangNhap: v.tenDangNhap.trim(),
        matKhau: v.matKhau,
        hoTen: v.hoTen.trim(),
        sdt: v.sdt.trim(),
        gioiTinh: v.gioiTinh,
        ngaySinh: v.ngaySinh || null,
        email: v.email.trim() || null,
        maTinh: v.maTinh || null,
        dsLoaiQuanTam: v.dsLoaiQuanTam,
      });
    } catch (e) {
      if (!isApiError(e)) throw e;
      const fe = fieldErrors(e);
      const keys = Object.keys(fe).filter((k): k is keyof RegisterValues => k in v);
      if (keys.length) {
        keys.forEach((k) => setError(k, { message: fe[k] }));
        setFocus(keys[0]);
        if (e.code === 52002) setSdtTaken(true);
      } else setFormError(e.status === 429 ? "Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút." : e.userMessage);
    }
  });

  const today = new Date().toISOString().slice(0, 10);

  return (
    <AuthLayout wide>
      <Link to="/login" className="mb-6 inline-flex items-center gap-1.5 text-sm font-medium text-ink-soft hover:text-ink">
        <ArrowLeft className="size-4" aria-hidden="true" />
        Quay lại đăng nhập
      </Link>
      <AuthHeading eyebrow="Thành viên mới" title="Đăng ký tài khoản khách hàng">
        Tạo tài khoản để tích điểm, theo dõi hạng thành viên và nhận voucher. Trường có dấu <span className="text-accent">*</span> là bắt buộc.
      </AuthHeading>

      <form onSubmit={onSubmit} noValidate className="flex flex-col gap-8">
        {formError && <Alert tone="error">{formError}</Alert>}

        <Section n={1} title="Thông tin cá nhân">
          <Field label="Họ và tên" required error={errors.hoTen?.message} className="sm:col-span-2">
            <TextInput autoComplete="name" placeholder="Nguyễn Văn A" {...register("hoTen")} />
          </Field>
          <Field
            label="Số điện thoại"
            required
            error={errors.sdt?.message}
            hint={sdtTaken ? undefined : "10 chữ số, bắt đầu bằng 0."}
          >
            <TextInput type="tel" inputMode="numeric" autoComplete="tel-national" placeholder="09xxxxxxxx" maxLength={10} {...register("sdt")} />
          </Field>
          <Field label="Email" error={errors.email?.message}>
            <TextInput type="email" autoComplete="email" placeholder="ban@example.com" {...register("email")} />
          </Field>
          {sdtTaken && (
            <Alert tone="info" className="sm:col-span-2">
              Nếu bạn đã được cửa hàng tạo hồ sơ thành viên, hãy liên hệ cửa hàng để được cấp tài khoản cho số điện thoại này.
            </Alert>
          )}
          <Field label="Ngày sinh" error={errors.ngaySinh?.message}>
            <TextInput type="date" min="1900-01-01" max={today} autoComplete="bday" {...register("ngaySinh")} />
          </Field>
          <Field label="Tỉnh / thành phố" error={errors.maTinh?.message}>
            <Select {...register("maTinh")} disabled={provinces.isPending}>
              <option value="">{provinces.isError ? "Không tải được danh sách" : "Chọn tỉnh / thành"}</option>
              {provinces.data?.map((p) => (
                <option key={p.maTinh} value={p.maTinh}>
                  {p.tenTinh}
                </option>
              ))}
            </Select>
          </Field>
          <Controller
            control={control}
            name="gioiTinh"
            render={({ field }) => (
              <div role="radiogroup" aria-labelledby="gt-label" className="flex flex-col gap-1.5 sm:col-span-2">
                <span id="gt-label" className="text-sm font-medium">Giới tính</span>
                <div className="grid grid-cols-3 gap-2 sm:max-w-sm">
                  {GENDERS.map((g) => {
                    const on = field.value === g.v;
                    return (
                      <button
                        key={g.v}
                        type="button"
                        role="radio"
                        aria-checked={on}
                        onClick={() => field.onChange(on ? null : g.v)}
                        className={cn(
                          "h-11 rounded-md border text-[15px] transition-colors",
                          on ? "border-ink bg-ink font-semibold text-white" : "border-line-strong hover:border-ink",
                        )}
                      >
                        {g.l}
                      </button>
                    );
                  })}
                </div>
              </div>
            )}
          />
        </Section>

        <Section n={2} title="Sở thích mua sắm">
          <Controller
            control={control}
            name="dsLoaiQuanTam"
            render={({ field }) => (
              <div className="sm:col-span-2">
                <p id="st-hint" className="mb-3 text-sm text-muted">Chọn các nhóm sản phẩm bạn quan tâm để nhận khảo sát và ưu đãi phù hợp (không bắt buộc).</p>
                {categories.isError && <p className="text-sm text-danger">Không tải được danh mục sản phẩm.</p>}
                <ul className="flex flex-wrap gap-2" aria-describedby="st-hint">
                  {categories.data?.map((c) => {
                    const on = field.value.includes(c.maLoai);
                    return (
                      <li key={c.maLoai}>
                        <button
                          type="button"
                          aria-pressed={on}
                          title={c.moTa ?? undefined}
                          onClick={() => field.onChange(on ? field.value.filter((x) => x !== c.maLoai) : [...field.value, c.maLoai])}
                          className={cn(
                            "inline-flex h-10 items-center gap-1.5 rounded-full border px-4 text-sm transition-colors",
                            on ? "border-ink bg-ink text-white" : "border-line-strong text-ink-soft hover:border-ink hover:text-ink",
                          )}
                        >
                          {on && <Check className="size-3.5" strokeWidth={3} aria-hidden="true" />}
                          {c.tenLoai}
                        </button>
                      </li>
                    );
                  })}
                  {categories.isPending && Array.from({ length: 5 }, (_, i) => <li key={i} className="h-10 w-24 animate-pulse rounded-full bg-surface-2" />)}
                </ul>
              </div>
            )}
          />
        </Section>

        <Section n={3} title="Thông tin đăng nhập">
          <Field label="Tên đăng nhập" required error={errors.tenDangNhap?.message} hint="4–50 ký tự, không có khoảng trắng." className="sm:col-span-2">
            <TextInput autoComplete="username" autoCapitalize="none" spellCheck={false} placeholder="vd. nguyen.an" {...register("tenDangNhap")} />
          </Field>
          <Field label="Mật khẩu" required error={errors.matKhau?.message}>
            <PasswordInput autoComplete="new-password" {...register("matKhau")} />
          </Field>
          <Field label="Nhập lại mật khẩu" required error={errors.nhapLai?.message}>
            <PasswordInput autoComplete="new-password" {...register("nhapLai")} />
          </Field>
          <div className="sm:col-span-2">
            <PasswordChecklist value={watch("matKhau") ?? ""} />
          </div>
        </Section>

        <div className="flex flex-col gap-3 border-t border-line pt-6">
          <Button type="submit" size="lg" block loading={isSubmitting} className="uppercase tracking-[0.12em]">
            Tạo tài khoản
          </Button>
          <p className="text-center text-sm text-muted">
            Đã có tài khoản?{" "}
            <Link to="/login" className="font-semibold text-ink underline underline-offset-4">
              Đăng nhập
            </Link>
          </p>
        </div>
      </form>
    </AuthLayout>
  );
}
