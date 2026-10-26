import { Link, useNavigate, useSearchParams } from "react-router";
import { LogOut } from "lucide-react";
import { useAuth } from "../../auth/AuthProvider";
import { destinationAfterLogin, go, homeHref } from "../../auth/redirect";
import { ChangePasswordForm } from "../../forms/ChangePasswordForm";
import { Alert } from "../../ui/Alert";
import { useToast } from "../../ui/Toast";
import { AuthHeading, AuthLayout } from "./AuthLayout";

/** L3. /change-password – bắt buộc khi PhaiDoiMatKhau = 1 (mọi route nghiệp vụ chuyển về đây, API trả 428). */
export function ChangePasswordPage() {
  const { session, logout, app } = useAuth();
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const toast = useToast();
  const forced = !!session?.phaiDoiMatKhau;

  return (
    <AuthLayout>
      <AuthHeading eyebrow={forced ? "Bảo mật tài khoản" : "Tài khoản"} title={forced ? "Đặt mật khẩu mới" : "Đổi mật khẩu"}>
        {session?.hoTen ? <>Xin chào <strong className="text-ink">{session.hoTen}</strong>. </> : null}
        {forced ? "Bạn đang dùng mật khẩu tạm. Hãy đặt mật khẩu mới để tiếp tục sử dụng hệ thống." : "Nhập mật khẩu hiện tại và mật khẩu mới."}
      </AuthHeading>
      {forced && (
        <Alert tone="warning" className="mb-6">
          Bạn cần đổi mật khẩu trước khi vào khu vực làm việc.
        </Alert>
      )}
      <ChangePasswordForm
        submitLabel={forced ? "Lưu và tiếp tục" : "Đổi mật khẩu"}
        onDone={(s) => {
          toast("success", "Đã đổi mật khẩu.");
          go(destinationAfterLogin(s, params.get("quay-lai"), app), navigate);
        }}
      />
      <div className="mt-6 flex items-center justify-between text-sm">
        {!forced && session ? (
          <Link to={homeHref(session.cong, app)} className="font-medium text-ink-soft hover:text-ink">
            ← Về khu vực của tôi
          </Link>
        ) : (
          <span />
        )}
        <button type="button" onClick={() => void logout()} className="inline-flex items-center gap-1.5 font-medium text-ink-soft hover:text-ink">
          <LogOut className="size-4" aria-hidden="true" />
          Đăng xuất
        </button>
      </div>
    </AuthLayout>
  );
}
