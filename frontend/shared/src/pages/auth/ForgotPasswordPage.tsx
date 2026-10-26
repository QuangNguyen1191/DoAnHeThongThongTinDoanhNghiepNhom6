import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Link } from "react-router";
import { ArrowLeft, MailCheck } from "lucide-react";
import { api } from "../../api/client";
import { fieldErrors, isApiError } from "../../api/errors";
import { useAuth } from "../../auth/AuthProvider";
import { forgotPasswordSchema, type ForgotPasswordValues } from "../../forms/schemas";
import { Alert } from "../../ui/Alert";
import { Button } from "../../ui/Button";
import { Field, TextInput } from "../../ui/Field";
import { AuthHeading, AuthLayout } from "./AuthLayout";

/**
 * L5 bước 1. Nhập tên đăng nhập + email trong hồ sơ; API luôn trả cùng một thông báo (không lộ tài khoản có tồn tại hay không)
 * và gửi liên kết đặt lại mật khẩu (hiệu lực 30 phút, dùng một lần) nếu khớp.
 * Trang ở web-admin chỉ phục vụ tài khoản Admin; trang ở web-crm phục vụ Khách hàng và Quản lý.
 */
export function ForgotPasswordPage() {
  const { app } = useAuth();
  const [sent, setSent] = useState<{ email: string; message: string } | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<ForgotPasswordValues>({ resolver: zodResolver(forgotPasswordSchema), defaultValues: { tenDangNhap: "", email: "" } });

  const send = async (v: ForgotPasswordValues) => {
    setFormError(null);
    try {
      const r = await api.post<{ thongBao: string }>("/api/auth/forgot-password", { tenDangNhap: v.tenDangNhap.trim(), email: v.email.trim() }, { silentAuth: true });
      setSent({ email: v.email.trim(), message: r.thongBao });
    } catch (e) {
      if (!isApiError(e)) throw e;
      const fe = fieldErrors(e);
      const keys = (Object.keys(fe) as (keyof ForgotPasswordValues)[]).filter((k) => k in v);
      if (keys.length) keys.forEach((k) => setError(k, { message: fe[k] }));
      else if (e.status === 429) setFormError("Bạn đã gửi quá nhiều yêu cầu. Vui lòng thử lại sau ít phút.");
      else setFormError(e.userMessage);
    }
  };

  const back = (
    <Link to="/login" className="mb-6 inline-flex items-center gap-1.5 text-sm font-medium text-ink-soft hover:text-ink">
      <ArrowLeft className="size-4" aria-hidden="true" />
      Quay lại đăng nhập
    </Link>
  );

  if (sent)
    return (
      <AuthLayout>
        {back}
        <span className="mb-6 grid size-12 place-items-center rounded-md bg-surface">
          <MailCheck className="size-6" aria-hidden="true" />
        </span>
        <AuthHeading eyebrow="Hỗ trợ tài khoản" title="Kiểm tra email của bạn" />
        <div role="status" className="flex flex-col gap-4 text-[15px] leading-relaxed text-ink-soft">
          <p>{sent.message}</p>
          <p>
            Liên kết được gửi tới <strong className="break-all text-ink">{sent.email}</strong>, có hiệu lực trong 30 phút và chỉ dùng được một
            lần. Nếu không thấy thư, hãy xem cả mục Thư rác.
          </p>
        </div>
        <Button size="lg" block className="mt-8 uppercase tracking-[0.12em]" loading={isSubmitting} onClick={() => void handleSubmit(send)()}>
          Gửi lại email
        </Button>
        <button type="button" onClick={() => setSent(null)} className="mt-4 w-full text-center text-sm font-medium text-ink-soft hover:text-ink">
          Dùng tên đăng nhập hoặc email khác
        </button>
      </AuthLayout>
    );

  return (
    <AuthLayout>
      {back}
      <AuthHeading eyebrow="Hỗ trợ tài khoản" title="Quên mật khẩu">
        Nhập tên đăng nhập và email trong hồ sơ của bạn. Chúng tôi sẽ gửi liên kết để đặt mật khẩu mới.
      </AuthHeading>

      <form onSubmit={handleSubmit(send)} noValidate className="flex flex-col gap-5">
        {formError && <Alert tone="error">{formError}</Alert>}
        <Field label="Tên đăng nhập" required error={errors.tenDangNhap?.message}>
          <TextInput autoComplete="username" autoCapitalize="none" spellCheck={false} {...register("tenDangNhap")} />
        </Field>
        <Field label="Email trong hồ sơ" required error={errors.email?.message}>
          <TextInput type="email" autoComplete="email" inputMode="email" spellCheck={false} placeholder="ten@example.com" {...register("email")} />
        </Field>
        <Button type="submit" size="lg" block loading={isSubmitting} className="mt-1 uppercase tracking-[0.12em]">
          Gửi liên kết đặt lại
        </Button>
      </form>

      <p className="mt-8 border-l-2 border-accent pl-4 text-sm leading-relaxed text-ink-soft">
        {app === "admin"
          ? "Không còn truy cập được email trong hồ sơ? Liên hệ một quản trị viên khác để được cấp mật khẩu tạm."
          : "Hồ sơ chưa có email? Liên hệ cửa hàng hoặc bộ phận chăm sóc khách hàng để được cấp mật khẩu tạm. Nhân viên liên hệ quản trị viên hệ thống."}
      </p>
    </AuthLayout>
  );
}
