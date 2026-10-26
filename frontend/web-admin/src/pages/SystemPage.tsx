import { useQuery } from "@tanstack/react-query";
import { CheckCircle2, RefreshCw, XCircle } from "lucide-react";
import { api } from "@shared/api/client";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { Button } from "@shared/ui/Button";
import { Panel } from "@shared/ui/data";
import { CONG } from "./common";

interface SystemStatus {
  ketNoi: { cong: string; ok: boolean; thoiGianMs: number; loi: string | null; phienBan: string | null }[];
  thoiGianApi: string;
}

const LOGIN: Record<string, string> = { ADMIN: "crm_app_admin", QUAN_LY: "crm_app_quanly", KHACH_HANG: "crm_app_khachhang" };

/** A16. Tình trạng 3 kết nối CSDL theo cổng (mỗi cổng một login SQL quyền tối thiểu) + phương án sao lưu/phục hồi. */
export function SystemPage() {
  const q = useQuery({ queryKey: ["admin", "system"], queryFn: () => api.get<SystemStatus>("/api/admin/system") });
  return (
    <>
      <PageHeader
        title="Trạng thái hệ thống"
        description="Kiểm tra kết nối từ API tới SQL Server bằng từng login của 3 cổng."
        actions={<Button variant="secondary" loading={q.isFetching} icon={<RefreshCw className="size-4" aria-hidden="true" />} onClick={() => q.refetch()}>Kiểm tra lại</Button>}
      />
      {q.isError ? (
        <ErrorState error={q.error} onRetry={() => q.refetch()} />
      ) : q.isPending ? (
        <Skeleton className="h-40" />
      ) : (
        <div className="flex flex-col gap-6">
          <div className="grid gap-4 md:grid-cols-3">
            {q.data.ketNoi.map((k) => (
              <div key={k.cong} className="rounded-md border border-line bg-bg p-5" data-testid={`ket-noi-${k.cong}`}>
                <div className="flex items-center gap-2">
                  {k.ok ? <CheckCircle2 className="size-5 text-success" aria-hidden="true" /> : <XCircle className="size-5 text-danger" aria-hidden="true" />}
                  <p className="font-semibold">{CONG[k.cong] ?? k.cong}</p>
                </div>
                <p className={`mt-2 text-[15px] font-semibold ${k.ok ? "text-success" : "text-danger"}`}>{k.ok ? "Kết nối tốt" : "Không kết nối được"}</p>
                <dl className="mt-3 grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-sm text-ink-soft">
                  <dt className="text-muted">Login</dt><dd className="font-mono">{LOGIN[k.cong]}</dd>
                  <dt className="text-muted">Phản hồi</dt><dd className="tabular">{k.thoiGianMs} ms</dd>
                  <dt className="text-muted">SQL Server</dt><dd className="font-mono">{k.phienBan ?? "—"}</dd>
                  {k.loi && (<><dt className="text-muted">Lỗi</dt><dd className="font-mono text-danger">{k.loi}</dd></>)}
                </dl>
              </div>
            ))}
          </div>
          <p className="text-sm text-muted">Giờ máy chủ API: {new Date(q.data.thoiGianApi).toLocaleString("vi-VN")}</p>

          <Panel title="Sao lưu và phục hồi CSDL">
            <div className="flex flex-col gap-3 text-[15px] text-ink-soft">
              <p>
                Sao lưu không chạy từ trang web: 3 login của ứng dụng chỉ được gọi thủ tục, không có quyền BACKUP/RESTORE
                (nguyên tắc quyền tối thiểu). Quản trị viên CSDL chạy script trong SSMS bằng tài khoản sysadmin:
              </p>
              <ul className="list-disc pl-5">
                <li><span className="font-mono text-ink">10_SaoLuu.sql</span>: sao lưu FULL, DIFFERENTIAL, LOG kèm CHECKSUM và RESTORE VERIFYONLY.</li>
                <li><span className="font-mono text-ink">10b_PhucHoi.sql</span>: phục hồi sang CSDL mới để kiểm tra bản sao lưu dùng được.</li>
                <li><span className="font-mono text-ink">11_TaoBanSaoKiemThu.sql</span>: tạo CRM_Uniqlo_Test từ bản sao lưu COPY_ONLY để chạy kiểm thử.</li>
              </ul>
            </div>
          </Panel>
        </div>
      )}
    </>
  );
}
