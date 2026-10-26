import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Link, useNavigate } from "react-router";
import { ArrowLeft, LinkIcon } from "lucide-react";
import { api } from "../../api/client";
import { fieldErrors, isApiError } from "../../api/errors";
import { useAuth } from "../../auth/AuthProvider";
import { PasswordChecklist } from "../../forms/PasswordChecklist";
import { RESET_TOKEN, resetPasswordSchema, type ResetPasswordValues } from "../../forms/schemas";
import { Alert } from "../../ui/Alert";
import { Button } from "../../ui/Button";
import { Field } from "../../ui/Field";
import { PasswordInput } from "../../ui/PasswordInput";
import { AuthHeading, AuthLayout } from "./AuthLayout";

/** Mã nằm sau dấu # nên không được gửi lên máy chủ hay ghi vào nhật ký truy cập. */
function readToken(): string | null {
  const token = new URLSearchParams(window.location.hash.slice(1)).get("token");
  return token && RESET_TOKEN.test(token) ? token : null;
}

/** L5 bước 2. /dat-lai-mat-khau#token=… (liên kết trong email): đặt mật khẩu mới rồi đăng nhập lại. */
export function ResetPasswordPage() {
  const { session, logout } = useAuth();
  const navigate = useNavigate();
  const [token] = useState(readToken);
  const [invalid, setInvalid] = useState(!token);
  // Đã đọc mã: xóa khỏi thanh địa chỉ để không nằm trong lịch sử trình duyệt.
  useEffect(() => {
    if (window.location.hash) history.replaceState(history.state, "", window.location.pathname + window.location.search);
  }, []);
  const [formError, setFormError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    watch,
    setError,
    setFocus,
    formState: { errors, isSubmitting },
  } = useForm<ResetPasswordValues>({ resolver: zodResolver(resetPasswordSchema), defaultValues: { matKhauMoi: "", nhapLai: "" } });

  const onSubmit = handleSubmit(async (v) => {
    setFormError(null);
    try {
      await api.post("/api/auth/reset-password", { token, matKhauMoi: v.matKhauMoi }, { silentAuth: true });
      navigate("/login?da-dat-lai=1", { replace: true });
    } catch (e) {
      if (!isApiError(e)) throw e;
      const fe = fieldErrors(e);
      if (fe.token || e.code === "52098") setInvalid(true);
      else if (fe.matKhauMoi) {
        setError("matKhauMoi", { message: fe.matKhauMoi });
        setFocus("matKhauMoi");
      } else if (e.code === "ALREADY_SIGNED_IN") setFormError("Bạn đang đăng nhập. Hãy đăng xuất rồi mở lại liên kết trong email.");
      else if (e.status === 429) setFormError("Bạn đã thử quá nhiều lần. Vui lòng thử lại sau ít phút.");
      else setFormError(e.userMessage);
    }
  });

  if (invalid)
    return (
      <AuthLayout>
        <span className="mb-6 grid size-12 place-items-center rounded-md bg-surface">
          <LinkIcon className="size-6" aria-hidden="true" />
        </span>
        <AuthHeading eyebrow="Hỗ trợ tài khoản" title="Liên kết không còn hiệu lực">
          Liên kết đặt lại mật khẩu không hợp lệ, đã hết hạn sau 30 phút hoặc đã được dùng. Mỗi lần yêu cầu mới, liên kết cũ cũng hết hiệu lực.
        </AuthHeading>
        <Link
          to="/forgot-password"
          className="flex h-12 items-center justify-center rounded-md bg-accent text-[15px] font-semibold uppercase tracking-[0.12em] text-white hover:bg-accent-hover"
        >
          Yêu cầu liên kết mới
        </Link>
        <Link to="/login" className="mt-4 flex items-center justify-center gap-1.5 text-sm font-medium text-ink-soft hover:text-ink">
          <ArrowLeft className="size-4" aria-hidden="true" />
          Quay lại đăng nhập
        </Link>
      </AuthLayout>
    );

  return (
    <AuthLayout>
      <AuthHeading eyebrow="Hỗ trợ tài khoản" title="Đặt mật khẩu mới">
        Chọn mật khẩu mới cho tài khoản của bạn. Sau khi lưu, hãy đăng nhập lại bằng mật khẩu mới.
      </AuthHeading>
      {session && (
        <Alert
          tone="warning"
          className="mb-6"
          action={
            <button type="button" onClick={() => void logout()} className="text-sm font-semibold text-ink underline underline-offset-4">
              Đăng xuất
            </button>
          }
        >
          Bạn đang đăng nhập bằng tài khoản {session.tenDangNhap}. Đăng xuất trước khi đặt lại mật khẩu.
        </Alert>
      )}
      <form onSubmit={onSubmit} noValidate className="flex flex-col gap-5">
        {formError && <Alert tone="error">{formError}</Alert>}
        <Field label="Mật khẩu mới" required error={errors.matKhauMoi?.message}>
          <PasswordInput autoComplete="new-password" {...register("matKhauMoi")} />
        </Field>
        <PasswordChecklist value={watch("matKhauMoi") ?? ""} />
        <Field label="Nhập lại mật khẩu mới" required error={errors.nhapLai?.message}>
          <PasswordInput autoComplete="new-password" {...register("nhapLai")} />
        </Field>
        <Button type="submit" size="lg" block loading={isSubmitting} className="mt-1 uppercase tracking-[0.12em]">
          Lưu mật khẩu mới
        </Button>
      </form>
    </AuthLayout>
  );
}
