import { useState, type FormEvent } from "react";
import { useQuery } from "@tanstack/react-query";
import { Search } from "lucide-react";
import { api } from "@shared/api/client";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { Button } from "@shared/ui/Button";
import { Badge, EmptyRow, Panel, Table, TRANG_THAI_TK, dateVi, td } from "@shared/ui/data";
import { Field, Select, TextInput } from "@shared/ui/Field";
import { toneTrangThaiTK } from "./common";

export interface KhachHangTraCuu {
  maKH: number;
  hoTen: string;
  sdt_Che: string;
  email_Che: string | null;
  maHang: string;
  trangThaiHoSo: "HOAT_DONG" | "DA_XOA";
  ngayDangKy: string;
  maTK: number | null;
  trangThaiTaiKhoan: string | null;
}

/** A11. Tra cứu khách hàng mức kỹ thuật: chỉ xem, SĐT/email đã che, không có nút sửa (nghiệp vụ khách hàng thuộc trang Quản lý). */
export function CustomerLookupPage() {
  const [tuKhoa, setTuKhoa] = useState("");
  const [maHang, setMaHang] = useState("");
  const [filters, setFilters] = useState({ tuKhoa: "", maHang: "" });
  const tiers = useQuery({
    queryKey: ["catalog", "tiers"],
    queryFn: () => api.get<{ maHang: string; tenHang: string }[]>("/api/catalog/tiers"),
    staleTime: Infinity,
  });
  const q = useQuery({
    queryKey: ["admin", "customers", filters],
    queryFn: () => api.get<KhachHangTraCuu[]>("/api/admin/customers", { query: filters }),
  });
  const apply = (e: FormEvent) => {
    e.preventDefault();
    setFilters({ tuKhoa, maHang });
  };
  const tenHang = (m: string) => tiers.data?.find((t) => t.maHang === m)?.tenHang ?? m;
  const rows = q.data ?? [];

  return (
    <>
      <PageHeader
        title="Tra cứu khách hàng"
        description="Chỉ xem để hỗ trợ kỹ thuật (ví dụ kiểm tra khách đã có tài khoản chưa). Số điện thoại và email được che; thêm, sửa, xóa khách hàng làm ở trang Quản lý."
      />
      <form onSubmit={apply} noValidate className="mb-5 rounded-md border border-line bg-bg p-4">
        <div className="grid gap-3 sm:grid-cols-[2fr_1fr_auto]">
          <Field label="Họ tên">
            <TextInput value={tuKhoa} onChange={(e) => setTuKhoa(e.target.value)} placeholder="Nhập một phần họ tên" />
          </Field>
          <Field label="Hạng thành viên">
            <Select value={maHang} onChange={(e) => setMaHang(e.target.value)}>
              <option value="">Tất cả</option>
              {tiers.data?.map((t) => <option key={t.maHang} value={t.maHang}>{t.tenHang}</option>)}
            </Select>
          </Field>
          <div className="flex items-end">
            <Button type="submit" variant="dark" icon={<Search className="size-4" aria-hidden="true" />}>Tìm kiếm</Button>
          </div>
        </div>
      </form>

      {q.isError ? (
        <ErrorState error={q.error} onRetry={() => q.refetch()} />
      ) : q.isPending ? (
        <Skeleton className="h-80" />
      ) : (
        <Panel title={<span aria-live="polite">{rows.length} khách hàng</span>} bodyClass="">
          {rows.length === 0 ? (
            <EmptyRow>Không có khách hàng nào khớp.</EmptyRow>
          ) : (
            <Table label="Kết quả tra cứu khách hàng" head={["Khách hàng", "SĐT (đã che)", "Email (đã che)", "Hạng", "Hồ sơ", "Tài khoản"]}>
              {rows.map((k) => (
                <tr key={k.maKH} className="hover:bg-surface">
                  <td className={td}>
                    <span className="font-semibold">{k.hoTen}</span>
                    <span className="block text-xs text-muted">Mã {k.maKH} · ĐK {dateVi(k.ngayDangKy)}</span>
                  </td>
                  <td className={`${td} tabular font-mono text-sm`} data-testid="sdt-che">{k.sdt_Che}</td>
                  <td className={`${td} font-mono text-sm`}>{k.email_Che ?? "—"}</td>
                  <td className={td}><span className={k.maHang === "VIP" ? "font-semibold text-accent" : ""}>{tenHang(k.maHang)}</span></td>
                  <td className={td}><Badge tone={k.trangThaiHoSo === "HOAT_DONG" ? "success" : "danger"}>{k.trangThaiHoSo === "HOAT_DONG" ? "Hoạt động" : "Đã xóa"}</Badge></td>
                  <td className={td}>
                    {k.maTK ? <Badge tone={toneTrangThaiTK(k.trangThaiTaiKhoan)}>{TRANG_THAI_TK[k.trangThaiTaiKhoan ?? ""] ?? k.trangThaiTaiKhoan}</Badge> : <Badge>Chưa có</Badge>}
                  </td>
                </tr>
              ))}
            </Table>
          )}
        </Panel>
      )}
    </>
  );
}
