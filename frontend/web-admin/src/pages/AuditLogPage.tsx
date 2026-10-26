import { useState, type FormEvent } from "react";
import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { Search } from "lucide-react";
import { api } from "@shared/api/client";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { Button } from "@shared/ui/Button";
import { EmptyRow, Pager, Panel, Table, td, useCan, type Paged } from "@shared/ui/data";
import { Field, Select, TextInput } from "@shared/ui/Field";
import { HANH_DONG, type TaiKhoan } from "./common";

interface NhatKy {
  maNK: number;
  thoiGian: string;
  maTK: number | null;
  tenDangNhap: string | null;
  nguoiDungCSDL: string;
  hanhDong: string;
  doiTuong: string | null;
  maDoiTuong: string | null;
  chiTiet: string | null;
}

interface Filters { tuNgay: string; denNgay: string; hanhDong: string; maTK: string }
const EMPTY: Filters = { tuNgay: "", denNgay: "", hanhDong: "", maTK: "" };
const PAGE_SIZE = 50;

/** A15. Nhật ký kiểm toán: ai làm gì, lúc nào, qua login CSDL nào; mới nhất trước. */
export function AuditLogPage() {
  const can = useCan();
  const [draft, setDraft] = useState<Filters>(EMPTY);
  const [filters, setFilters] = useState<Filters>(EMPTY);
  const [page, setPage] = useState(1);
  const q = useQuery({
    queryKey: ["admin", "audit-logs", filters, page],
    queryFn: () => api.get<Paged<NhatKy>>("/api/admin/audit-logs", { query: { ...filters, trang: page, soDong: PAGE_SIZE } }),
    placeholderData: keepPreviousData,
  });
  // Chọn tài khoản theo tên (cần AD_TAI_KHOAN); không có quyền thì nhập mã tài khoản.
  const accounts = useQuery({
    queryKey: ["admin", "accounts", {}],
    queryFn: () => api.get<TaiKhoan[]>("/api/admin/accounts"),
    enabled: can("AD_TAI_KHOAN"),
  });
  const set = (k: keyof Filters) => (e: { target: { value: string } }) => setDraft((d) => ({ ...d, [k]: e.target.value }));
  const apply = (e: FormEvent) => {
    e.preventDefault();
    setPage(1);
    setFilters(draft);
  };
  const badRange = !!draft.tuNgay && !!draft.denNgay && draft.tuNgay > draft.denNgay;

  return (
    <>
      <PageHeader title="Nhật ký hệ thống" description="Mọi thao tác ghi dữ liệu và đăng nhập trên cả 3 cổng (Admin, Quản lý, Khách hàng) đều được ghi lại. Nhật ký chỉ xem, không sửa hay xóa được." />

      <form onSubmit={apply} noValidate className="mb-5 rounded-md border border-line bg-bg p-4">
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <Field label="Từ ngày" error={badRange ? "Từ ngày phải trước đến ngày." : undefined}>
            <TextInput type="date" value={draft.tuNgay} onChange={set("tuNgay")} />
          </Field>
          <Field label="Đến ngày">
            <TextInput type="date" value={draft.denNgay} onChange={set("denNgay")} />
          </Field>
          <Field label="Hành động">
            <Select value={draft.hanhDong} onChange={set("hanhDong")}>
              <option value="">Tất cả</option>
              {Object.entries(HANH_DONG).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
            </Select>
          </Field>
          <Field label="Tài khoản">
            {accounts.data ? (
              <Select value={draft.maTK} onChange={set("maTK")}>
                <option value="">Tất cả</option>
                {accounts.data.map((t) => <option key={t.maTK} value={t.maTK}>{t.tenDangNhap}</option>)}
              </Select>
            ) : (
              <TextInput type="number" min={1} value={draft.maTK} onChange={set("maTK")} placeholder="Mã tài khoản" />
            )}
          </Field>
          <div className="flex items-end gap-2">
            <Button type="submit" variant="dark" disabled={badRange} icon={<Search className="size-4" aria-hidden="true" />}>Lọc</Button>
            <Button type="button" variant="ghost" onClick={() => { setDraft(EMPTY); setFilters(EMPTY); setPage(1); }}>Xóa lọc</Button>
          </div>
        </div>
      </form>

      {q.isError ? (
        <ErrorState error={q.error} onRetry={() => q.refetch()} />
      ) : q.isPending ? (
        <Skeleton className="h-80" />
      ) : (
        <Panel
          title={<span aria-live="polite">{q.data.tongSoDong} bản ghi</span>}
          actions={<Pager page={page} size={PAGE_SIZE} total={q.data.tongSoDong} onPage={setPage} />}
          bodyClass=""
        >
          {q.data.items.length === 0 ? (
            <EmptyRow>Không có bản ghi nào khớp bộ lọc.</EmptyRow>
          ) : (
            <Table label="Nhật ký hệ thống" head={["Thời gian", "Tài khoản", "Hành động", "Đối tượng", "Chi tiết", "Login CSDL"]}>
              {q.data.items.map((n) => (
                <tr key={n.maNK} className="hover:bg-surface">
                  <td className={`${td} tabular whitespace-nowrap text-sm`}>{new Date(n.thoiGian).toLocaleString("vi-VN")}</td>
                  <td className={`${td} font-mono text-sm`}>{n.tenDangNhap ?? "—"}</td>
                  <td className={td}>
                    {HANH_DONG[n.hanhDong] ?? n.hanhDong}
                    <span className="block font-mono text-xs text-muted">{n.hanhDong}</span>
                  </td>
                  <td className={`${td} font-mono text-xs`}>{n.doiTuong ? `${n.doiTuong}${n.maDoiTuong ? ` #${n.maDoiTuong}` : ""}` : "—"}</td>
                  <td className={`${td} max-w-[320px] text-sm text-ink-soft`}>{n.chiTiet ?? "—"}</td>
                  <td className={`${td} font-mono text-xs text-muted`}>{n.nguoiDungCSDL}</td>
                </tr>
              ))}
            </Table>
          )}
        </Panel>
      )}
    </>
  );
}
