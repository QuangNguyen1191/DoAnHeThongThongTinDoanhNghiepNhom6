import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useAuth } from "../auth/AuthProvider";
import type { Session } from "../auth/types";
import { fieldErrors, isApiError } from "../api/errors";
import { Alert } from "../ui/Alert";
import { Button } from "../ui/Button";
import { Field } from "../ui/Field";
import { PasswordInput } from "../ui/PasswordInput";
import { PasswordChecklist } from "./PasswordChecklist";
import { changePasswordSchema, type ChangePasswordValues } from "./schemas";

/** L3. Đổi mật khẩu – dùng cho trang bắt buộc và trang Tài khoản của mọi khu vực. */
export function ChangePasswordForm({ onDone, submitLabel = "Đổi mật khẩu" }: { onDone: (s: Session) => void; submitLabel?: string }) {
  const { changePassword } = useAuth();
  const [formError, setFormError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    watch,
    setError,
    setFocus,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<ChangePasswordValues>({
    resolver: zodResolver(changePasswordSchema),
    defaultValues: { matKhauCu: "", matKhauMoi: "", nhapLai: "" },
  });

  const onSubmit = handleSubmit(async (v) => {
    setFormError(null);
    try {
      const s = await changePassword(v.matKhauCu, v.matKhauMoi);
      reset();
      onDone(s);
    } catch (e) {
      if (!isApiError(e)) throw e;
      const fe = fieldErrors(e);
      const keys = Object.keys(fe).filter((k): k is keyof ChangePasswordValues => k in v);
      if (keys.length) {
        keys.forEach((k) => setError(k, { message: fe[k] }));
        setFocus(keys[0]);
      } else if (e.status !== 401) setFormError(e.userMessage);
    }
  });

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-5">
      {formError && <Alert tone="error">{formError}</Alert>}
      <Field label="Mật khẩu hiện tại" required error={errors.matKhauCu?.message}>
        <PasswordInput autoComplete="current-password" {...register("matKhauCu")} />
      </Field>
      <Field label="Mật khẩu mới" required error={errors.matKhauMoi?.message}>
        <PasswordInput autoComplete="new-password" {...register("matKhauMoi")} />
      </Field>
      <PasswordChecklist value={watch("matKhauMoi") ?? ""} />
      <Field label="Nhập lại mật khẩu mới" required error={errors.nhapLai?.message}>
        <PasswordInput autoComplete="new-password" {...register("nhapLai")} />
      </Field>
      <Button type="submit" size="lg" block loading={isSubmitting}>
        {submitLabel}
      </Button>
    </form>
  );
}
