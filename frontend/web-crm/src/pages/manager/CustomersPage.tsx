import { useState, type FormEvent } from "react";
import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { Link, useNavigate } from "react-router";
import { Plus, Search } from "lucide-react";
import { api } from "@shared/api/client";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { Button } from "@shared/ui/Button";
import { Field, Select, TextInput } from "@shared/ui/Field";
import {
  Badge, EmptyRow, GIOI_TINH, Pager, Panel, Table, TRANG_THAI_TK, dateVi, td, useCan, useCategories, useProvinces, useTiers, type Paged,
} from "./common";

export interface KhachHangRow {
  maKH: number;
  hoTen: string;
  gioiTinh: string | null;
  tuoi: number | null;
  nhomTuoi: string;
  sdt: string;
  email: string | null;
  tenTinh: string | null;
  maHang: string;
  tenHang: string;
  diem: number;
  soThich: string | null;
  ngayDangKy: string;
  trangThaiHoSo: "HOAT_DONG" | "DA_XOA";
  tenDangNhap: string | null;
  trangThaiTaiKhoan: string | null;
}

interface Filters {
  tuKhoa: string;
  maHang: string;
  maTinh: string;
  gioiTinh: string;
  tuoiTu: string;
  tuoiDen: string;
  maLoaiQuanTam: string;
  trangThaiHoSo: "HOAT_DONG" | "DA_XOA";
  sapXep: "TEN" | "NGAY_DK_MOI" | "DIEM_CAO";
}
const EMPTY: Filters = { tuKhoa: "", maHang: "", maTinh: "", gioiTinh: "", tuoiTu: "", tuoiDen: "", maLoaiQuanTam: "", trangThaiHoSo: "HOAT_DONG", sapXep: "TEN" };
const PAGE_SIZE = 20;

export function AccountBadge({ k }: { k: Pick<KhachHangRow, "tenDangNhap" | "trangThaiTaiKhoan" | "trangThaiHoSo"> }) {
  if (k.trangThaiHoSo === "DA_XOA") return <Badge tone="danger">Hồ sơ đã xóa</Badge>;
  if (!k.tenDangNhap) return <Badge>Chưa có tài khoản</Badge>;
  return <Badge tone={k.trangThaiTaiKhoan === "DA_KHOA" ? "warning" : "success"}>{TRANG_THAI_TK[k.trangThaiTaiKhoan ?? ""] ?? k.trangThaiTaiKhoan}</Badge>;
}

/** Q1. Tìm kiếm khách hàng; từ đây vào hồ sơ để xóa/khóa (QL-2, QL-3) hoặc thêm mới (QL-1). */
export function CustomersPage() {
  const can = useCan();
  const nav = useNavigate();
  const [draft, setDraft] = useState<Filters>(EMPTY);
  const [filters, setFilters] = useState<Filters>(EMPTY);
  const [page, setPage] = useState(1);
  const tiers = useTiers();
  const provinces = useProvinces();
  const categories = useCategories();

  const q = useQuery({
    queryKey: ["manager", "customers", filters, page],
    queryFn: () => api.get<Paged<KhachHangRow>>("/api/manager/customers", { query: { ...filters, trang: page, soDong: PAGE_SIZE } }),
    placeholderData: keepPreviousData,
  });

  const set = (k: keyof Filters) => (e: { target: { value: string } }) => setDraft((d) => ({ ...d, [k]: e.target.value }));
  const apply = (e: FormEvent) => {
    e.preventDefault();
    setPage(1);
    setFilters(draft);
  };
  const badAge = !!draft.tuoiTu && !!draft.tuoiDen && Number(draft.tuoiTu) > Number(draft.tuoiDen);

  return (
    <>
      <PageHeader
        title="Khách hàng"
        description="Tìm kiếm, xem hồ sơ 360°, thêm mới, khóa tài khoản và xóa khách hàng."
        actions={can("QL_KH_THEM") && (
          <Button icon={<Plus className="size-4" aria-hidden="true" />} onClick={() => nav("/manager/customers/new")}>
            Thêm khách hàng
          </Button>
        )}
      />

      <form onSubmit={apply} noValidate className="mb-5 rounded-md border border-line bg-bg p-4">
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Field label="Từ khóa" className="sm:col-span-2">
            <TextInput value={draft.tuKhoa} onChange={set("tuKhoa")} placeholder="Họ tên, số điện thoại hoặc email" />
          </Field>
          <Field label="Hạng thành viên">
            <Select value={draft.maHang} onChange={set("maHang")}>
              <option value="">Tất cả</option>
              {tiers.data?.map((t) => <option key={t.maHang} value={t.maHang}>{t.tenHang}</option>)}
            </Select>
          </Field>
          <Field label="Tỉnh/thành">
            <Select value={draft.maTinh} onChange={set("maTinh")}>
              <option value="">Tất cả</option>
              {provinces.data?.map((p) => <option key={p.maTinh} value={p.maTinh}>{p.tenTinh}</option>)}
            </Select>
          </Field>
          <Field label="Giới tính">
            <Select value={draft.gioiTinh} onChange={set("gioiTinh")}>
              <option value="">Tất cả</option>
              {Object.entries(GIOI_TINH).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
            </Select>
          </Field>
          <div className="grid grid-cols-2 gap-3">
            <Field label="Tuổi từ" error={badAge ? "Tuổi từ phải ≤ tuổi đến." : undefined}>
              <TextInput type="number" min={0} max={150} value={draft.tuoiTu} onChange={set("tuoiTu")} />
            </Field>
            <Field label="Đến">
              <TextInput type="number" min={0} max={150} value={draft.tuoiDen} onChange={set("tuoiDen")} />
            </Field>
          </div>
          <Field label="Quan tâm loại SP">
            <Select value={draft.maLoaiQuanTam} onChange={set("maLoaiQuanTam")}>
              <option value="">Tất cả</option>
              {categories.data?.map((c) => <option key={c.maLoai} value={c.maLoai}>{c.tenLoai}</option>)}
            </Select>
          </Field>
          <Field label="Trạng thái hồ sơ">
            <Select value={draft.trangThaiHoSo} onChange={set("trangThaiHoSo")}>
              <option value="HOAT_DONG">Đang hoạt động</option>
              <option value="DA_XOA">Đã xóa</option>
            </Select>
          </Field>
          <Field label="Sắp xếp">
            <Select value={draft.sapXep} onChange={set("sapXep")}>
              <option value="TEN">Theo tên</option>
              <option value="NGAY_DK_MOI">Đăng ký mới nhất</option>
              <option value="DIEM_CAO">Điểm cao nhất</option>
            </Select>
          </Field>
          <div className="flex items-end gap-2 lg:col-span-2 lg:justify-end">
            <Button type="submit" variant="dark" disabled={badAge} icon={<Search className="size-4" aria-hidden="true" />}>Tìm kiếm</Button>
            <Button type="button" variant="ghost" onClick={() => { setDraft(EMPTY); setFilters(EMPTY); setPage(1); }}>Xóa bộ lọc</Button>
          </div>
        </div>
      </form>

      {q.isError ? (
        <ErrorState error={q.error} onRetry={() => q.refetch()} />
      ) : q.isPending ? (
        <Skeleton className="h-80" />
      ) : (
        <Panel
          title={<span aria-live="polite">{q.data.tongSoDong} khách hàng</span>}
          actions={<Pager page={page} size={PAGE_SIZE} total={q.data.tongSoDong} onPage={setPage} />}
          bodyClass=""
        >
          {q.data.items.length === 0 ? (
            <EmptyRow>Không có khách hàng nào khớp bộ lọc.</EmptyRow>
          ) : (
            <Table label="Danh sách khách hàng" head={["Khách hàng", "Liên hệ", "Tuổi · Giới tính", "Hạng · Điểm", "Sở thích", "Tài khoản"]}>
              {q.data.items.map((k) => (
                <tr key={k.maKH} className="hover:bg-surface">
                  <td className={td}>
                    <Link to={`/manager/customers/${k.maKH}`} className="font-semibold underline-offset-2 hover:underline">{k.hoTen}</Link>
                    <span className="block text-xs text-muted">Mã {k.maKH} · ĐK {dateVi(k.ngayDangKy)}</span>
                  </td>
                  <td className={td}>
                    <span className="tabular block">{k.sdt}</span>
                    <span className="block text-xs text-muted">{k.email ?? "—"}{k.tenTinh ? ` · ${k.tenTinh}` : ""}</span>
                  </td>
                  <td className={td}>{k.tuoi ?? "—"} · {GIOI_TINH[k.gioiTinh ?? ""] ?? "—"}</td>
                  <td className={td}>
                    <span className={k.maHang === "VIP" ? "font-semibold text-accent" : ""}>{k.tenHang}</span>
                    <span className="tabular block text-xs text-muted">{k.diem.toLocaleString("vi-VN")} điểm</span>
                  </td>
                  <td className={`${td} max-w-[220px] text-sm text-ink-soft`}>{k.soThich ?? "—"}</td>
                  <td className={td}>
                    <AccountBadge k={k} />
                    {k.tenDangNhap && <span className="block font-mono text-xs text-muted">{k.tenDangNhap}</span>}
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
