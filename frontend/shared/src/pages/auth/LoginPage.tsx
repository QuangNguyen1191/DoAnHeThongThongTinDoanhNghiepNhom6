import { useEffect, useRef, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Link, useSearchParams } from "react-router";
import { ArrowLeft, ArrowRight } from "lucide-react";
import { useAuth } from "../../auth/AuthProvider";
import { ApiError, fieldErrors, isApiError } from "../../api/errors";
import { CRM_URL } from "../../config";
import { loginSchema, type LoginValues } from "../../forms/schemas";
import { Alert } from "../../ui/Alert";
import { Button } from "../../ui/Button";
import { Field, TextInput } from "../../ui/Field";
import { PasswordInput } from "../../ui/PasswordInput";
import { AuthHeading, AuthLayout } from "./AuthLayout";

// Mỗi trang đăng nhập nhớ tên riêng (origin của web-crm và web-admin vốn đã khác nhau).
const rememberKey = (app: "crm" | "admin") => (app === "admin" ? "crm.admin.rememberedUser" : "crm.rememberedUser");
const readRemembered = (app: "crm" | "admin") => {
  try {
    return localStorage.getItem(rememberKey(app)) ?? "";
  } catch {
    return "";
  }
};

type Problem = { tone: "error" | "warning"; title?: string; text: string; retry?: boolean; trace?: string };

/** Ánh xạ lỗi đăng nhập (đặc tả L1, API mục 1.2) sang thông báo trong vùng lỗi. */
function describe(e: ApiError): Problem {
  if (e.isNetwork) return { tone: "error", title: "Không kết nối được máy chủ", text: "Kiểm tra kết nối mạng hoặc thử lại sau giây lát.", retry: true };
  if (e.status === 401) return { tone: "error", text: e.message || "Sai tên đăng nhập hoặc mật khẩu." };
  if (e.status === 403) return { tone: "error", title: "Tài khoản không thể đăng nhập", text: e.message };
  if (e.status === 429) return { tone: "warning", title: "Tạm khóa đăng nhập", text: "Bạn đã nhập sai quá nhiều lần. Vui lòng thử lại sau ít phút." };
  if (e.status >= 500) return { tone: "error", text: e.userMessage, retry: true, trace: e.traceId };
  return { tone: "error", text: e.message };
}

/**
 * L1. /login của cả hai ứng dụng.
 * web-crm: trang chung cho Khách hàng và Quản lý (có đăng ký thành viên).
 * web-admin: trang riêng, API ở cổng web-admin chỉ nhận tài khoản Admin; tài khoản khác nhận cùng lỗi "Sai tên đăng nhập hoặc mật khẩu".
 */
export function LoginPage() {
  const { login, app } = useAuth();
  const admin = app === "admin";
  const [params] = useSearchParams();
  const [problem, setProblem] = useState<Problem | null>(null);
  const [caps, setCaps] = useState(false);
  const [remember, setRemember] = useState(() => !!readRemembered(app));
  const errorRef = useRef<HTMLDivElement>(null);

  const expired = params.get("het-phien") === "1";
  const loggedOut = params.get("da-dang-xuat") === "1";
  const resetDone = params.get("da-dat-lai") === "1";
  const needLogin = !expired && !loggedOut && !!params.get("quay-lai");

  const {
    register,
    handleSubmit,
    setValue,
    setFocus,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<LoginValues>({
    resolver: zodResolver(loginSchema),
    defaultValues: { tenDangNhap: readRemembered(app), matKhau: "" },
  });

  useEffect(() => setFocus(readRemembered(app) ? "matKhau" : "tenDangNhap"), [setFocus, app]);

  const onSubmit = handleSubmit(async (v) => {
    setProblem(null);
    try {
      await login(v.tenDangNhap.trim(), v.matKhau);
      try {
        if (remember) localStorage.setItem(rememberKey(app), v.tenDangNhap.trim());
        else localStorage.removeItem(rememberKey(app));
      } catch {
        /* bỏ qua */
      }
      // Điều hướng do <PublicOnly> đảm nhận ngay khi phiên có dữ liệu.
    } catch (e) {
      if (!isApiError(e)) throw e;
      if (e.status === 400 && e.code === "VALIDATION") {
        const fe = fieldErrors(e);
        (Object.keys(fe) as (keyof LoginValues)[]).forEach((k) => k in v && setError(k, { message: fe[k] }));
        return;
      }
      setProblem(describe(e));
      // Đặc tả L1: giữ tên đăng nhập, xóa ô mật khẩu, focus về ô mật khẩu.
      setValue("matKhau", "");
      setFocus("matKhau");
    }
  });

  return (
    <AuthLayout>
      {admin ? (
        <AuthHeading eyebrow="Quản trị hệ thống" title="Đăng nhập quản trị">
          Chỉ dành cho tài khoản quản trị viên được cấp. Mọi lần đăng nhập đều được ghi nhật ký.
        </AuthHeading>
      ) : (
        <AuthHeading eyebrow="Chào mừng trở lại" title="Đăng nhập">
          Dùng tài khoản khách hàng của bạn hoặc tài khoản nhân viên cửa hàng được cấp.
        </AuthHeading>
      )}

      <div className="mb-6 flex flex-col gap-3 empty:hidden">
        {expired && (
          <Alert tone="warning" title="Phiên đăng nhập đã hết">
            Phiên đã hết hạn hoặc tài khoản không còn hoạt động. Vui lòng đăng nhập lại để tiếp tục.
          </Alert>
        )}
        {loggedOut && <Alert tone="success">Bạn đã đăng xuất an toàn.</Alert>}
        {resetDone && <Alert tone="success">Đã đặt mật khẩu mới. Hãy đăng nhập bằng mật khẩu mới.</Alert>}
        {needLogin && <Alert tone="info">Vui lòng đăng nhập để tiếp tục.</Alert>}
      </div>

      <form onSubmit={onSubmit} noValidate className="flex flex-col gap-5" aria-describedby={problem ? "login-error" : undefined}>
        <div ref={errorRef} id="login-error" aria-live="assertive" className="empty:hidden">
          {problem && (
            <Alert
              tone={problem.tone}
              title={problem.title}
              action={
                problem.retry && (
                  <button type="submit" className="text-sm font-semibold text-ink underline underline-offset-4">
                    Thử lại
                  </button>
                )
              }
            >
              {problem.text}
              {problem.trace && <span className="mt-1 block text-xs">Mã tra cứu: <span className="font-mono">{problem.trace}</span></span>}
            </Alert>
          )}
        </div>

        <Field label="Tên đăng nhập" required error={errors.tenDangNhap?.message}>
          <TextInput autoComplete="username" autoCapitalize="none" spellCheck={false} inputMode="text" placeholder={admin ? "vd. admin.it" : "vd. kh.an"} {...register("tenDangNhap")} />
        </Field>

        <Field
          label="Mật khẩu"
          required
          error={errors.matKhau?.message}
          hint={caps ? "Caps Lock đang bật." : undefined}
          aside={
            <Link to="/forgot-password" className="text-sm font-medium text-ink-soft underline-offset-4 hover:text-ink hover:underline">
              Quên mật khẩu?
            </Link>
          }
        >
          <PasswordInput autoComplete="current-password" onCapsLockChange={setCaps} {...register("matKhau")} />
        </Field>

        <label className="-mt-1 flex w-fit items-center gap-2.5 text-sm text-ink-soft">
          <input type="checkbox" className="size-4 accent-ink" checked={remember} onChange={(e) => setRemember(e.target.checked)} />
          Ghi nhớ tên đăng nhập trên máy này
        </label>

        <Button type="submit" size="lg" block loading={isSubmitting} className="mt-1 uppercase tracking-[0.12em]">
          {admin ? "Đăng nhập quản trị" : "Đăng nhập"}
        </Button>
      </form>

      {admin ? (
        <p className="mt-8 border-t border-line pt-6 text-sm text-muted">
          Bạn là khách hàng hoặc nhân viên cửa hàng?{" "}
          <a href={`${CRM_URL}/login`} className="inline-flex items-center gap-1 font-medium text-ink underline-offset-4 hover:underline">
            <ArrowLeft className="size-3.5" aria-hidden="true" />
            Đến trang đăng nhập chung
          </a>
        </p>
      ) : (
        <>
          <div className="mt-8 flex items-center gap-4 text-[13px] text-muted">
            <span className="h-px flex-1 bg-line" />
            Chưa là thành viên?
            <span className="h-px flex-1 bg-line" />
          </div>
          <Link
            to="/register"
            className="mt-4 flex h-12 items-center justify-center gap-2 rounded-md border border-ink text-[15px] font-semibold transition-colors hover:bg-ink hover:text-white"
          >
            Đăng ký thành viên
            <ArrowRight className="size-4" aria-hidden="true" />
          </Link>
          <p className="mt-3 text-center text-[13px] text-muted">Tích điểm mỗi lần mua sắm, nhận voucher và ưu đãi hạng VIP.</p>
        </>
      )}
    </AuthLayout>
  );
}
