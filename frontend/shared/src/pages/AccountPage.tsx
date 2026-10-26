import { useAuth } from "../auth/AuthProvider";
import { CONG_LABEL } from "../auth/types";
import { ChangePasswordForm } from "../forms/ChangePasswordForm";
import { PageHeader } from "../layouts/PortalLayout";
import { useToast } from "../ui/Toast";

/** /<portal>/account – thông tin phiên và đổi mật khẩu (bảng route mục 7). */
export function AccountPage() {
  const { session } = useAuth();
  const toast = useToast();
  if (!session) return null;
  const rows: [string, string | null][] = [
    ["Họ tên", session.hoTen],
    ["Tên đăng nhập", session.tenDangNhap],
    ["Vai trò", session.tenVT ?? session.maVT],
    ["Khu vực", CONG_LABEL[session.cong]],
    ["Chức vụ", session.chucVu],
  ];
  return (
    <>
      <PageHeader title="Tài khoản của tôi" description="Thông tin phiên đăng nhập và đổi mật khẩu." />
      <div className="grid gap-6 xl:grid-cols-[1fr_420px]">
        <section className="rounded-md border border-line bg-bg p-6" aria-labelledby="tt-phien">
          <h2 id="tt-phien" className="text-base font-semibold">Thông tin phiên</h2>
          <dl className="mt-4 divide-y divide-line">
            {rows.filter(([, v]) => v).map(([k, v]) => (
              <div key={k} className="grid grid-cols-[140px_1fr] gap-4 py-3 text-[15px]">
                <dt className="text-muted">{k}</dt>
                <dd className="font-medium">{v}</dd>
              </div>
            ))}
          </dl>
          {session.quyenChiTiet.length > 0 && (
            <>
              <h3 className="mt-6 text-sm font-semibold">Quyền chức năng ({session.quyenChiTiet.length})</h3>
              <ul className="mt-3 flex flex-wrap gap-2">
                {session.quyenChiTiet.map((q) => (
                  <li key={q.maQuyen} title={q.maQuyen} className="rounded-sm border border-line bg-surface px-2 py-1 text-[13px] text-ink-soft">
                    {q.tenQuyen}
                  </li>
                ))}
              </ul>
            </>
          )}
        </section>
        <section className="rounded-md border border-line bg-bg p-6" aria-labelledby="doi-mk">
          <h2 id="doi-mk" className="text-base font-semibold">Đổi mật khẩu</h2>
          <p className="mb-5 mt-1 text-sm text-muted">Sau khi đổi, mật khẩu cũ không dùng được nữa.</p>
          <ChangePasswordForm onDone={() => toast("success", "Đã đổi mật khẩu.")} />
        </section>
      </div>
    </>
  );
}
