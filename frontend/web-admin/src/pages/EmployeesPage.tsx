import { useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link } from "react-router";
import { Pencil, Plus, Search, UserPlus } from "lucide-react";
import { api } from "@shared/api/client";
import { fieldErrors, isApiError } from "@shared/api/errors";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { Alert } from "@shared/ui/Alert";
import { Button } from "@shared/ui/Button";
import { Badge, EmptyRow, Panel, Table, dateVi, td, useCan } from "@shared/ui/data";
import { Field, Select, TextInput } from "@shared/ui/Field";
import { Modal } from "@shared/ui/Modal";
import { useToast } from "@shared/ui/Toast";
import { TRANG_THAI_NV, useLookups, type NhanVien } from "./common";

interface Filters { tuKhoa: string; maCV: string; maCH: string; trangThai: string }
const EMPTY: Filters = { tuKhoa: "", maCV: "", maCH: "", trangThai: "" };

/** A10. Hồ sơ nhân viên: xem (AD_TRA_CUU), thêm/sửa (AD_DANH_MUC). Nhân viên nghỉ việc → CSDL tự khóa tài khoản. */
export function EmployeesPage() {
  const can = useCan();
  const [draft, setDraft] = useState<Filters>(EMPTY);
  const [filters, setFilters] = useState<Filters>(EMPTY);
  const [editing, setEditing] = useState<NhanVien | "new" | null>(null);
  const lookups = useLookups();
  const q = useQuery({
    queryKey: ["admin", "employees", filters],
    queryFn: () => api.get<NhanVien[]>("/api/admin/employees", { query: { ...filters } }),
  });
  const set = (k: keyof Filters) => (e: { target: { value: string } }) => setDraft((d) => ({ ...d, [k]: e.target.value }));
  const apply = (e: FormEvent) => {
    e.preventDefault();
    setFilters(draft);
  };
  const canEdit = can("AD_DANH_MUC");
  const canCreateAccount = can("AD_TAI_KHOAN") && can("AD_PHAN_QUYEN");
  const rows = q.data ?? [];

  return (
    <>
      <PageHeader
        title="Nhân viên"
        description="Hồ sơ nhân viên của các cửa hàng và văn phòng. Thêm nhân viên trước, sau đó tạo tài khoản đăng nhập cho họ."
        actions={canEdit && <Button icon={<Plus className="size-4" aria-hidden="true" />} onClick={() => setEditing("new")}>Thêm nhân viên</Button>}
      />

      <form onSubmit={apply} noValidate className="mb-5 rounded-md border border-line bg-bg p-4">
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <Field label="Từ khóa" className="sm:col-span-2">
            <TextInput value={draft.tuKhoa} onChange={set("tuKhoa")} placeholder="Họ tên, email hoặc số điện thoại" />
          </Field>
          <Field label="Chức vụ">
            <Select value={draft.maCV} onChange={set("maCV")}>
              <option value="">Tất cả</option>
              {lookups.data?.chucVu.map((c) => <option key={c.maCV} value={c.maCV}>{c.tenCV}</option>)}
            </Select>
          </Field>
          <Field label="Cửa hàng">
            <Select value={draft.maCH} onChange={set("maCH")}>
              <option value="">Tất cả</option>
              {lookups.data?.cuaHang.map((c) => <option key={c.maCH} value={c.maCH}>{c.tenCH}</option>)}
            </Select>
          </Field>
          <Field label="Trạng thái">
            <Select value={draft.trangThai} onChange={set("trangThai")}>
              <option value="">Tất cả</option>
              {Object.entries(TRANG_THAI_NV).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
            </Select>
          </Field>
          <div className="flex items-end gap-2 sm:col-span-2 lg:col-span-5 lg:justify-end">
            <Button type="submit" variant="dark" icon={<Search className="size-4" aria-hidden="true" />}>Tìm kiếm</Button>
            <Button type="button" variant="ghost" onClick={() => { setDraft(EMPTY); setFilters(EMPTY); }}>Xóa bộ lọc</Button>
          </div>
        </div>
      </form>

      {q.isError ? (
        <ErrorState error={q.error} onRetry={() => q.refetch()} />
      ) : q.isPending ? (
        <Skeleton className="h-80" />
      ) : (
        <Panel title={<span aria-live="polite">{rows.length} nhân viên</span>} bodyClass="">
          {rows.length === 0 ? (
            <EmptyRow>Không có nhân viên nào khớp bộ lọc.</EmptyRow>
          ) : (
            <Table label="Danh sách nhân viên" head={["Nhân viên", "Chức vụ · Nơi làm", "Liên hệ", "Vào làm", "Trạng thái", "Tài khoản", ""]}>
              {rows.map((e) => (
                <tr key={e.maNV} className="hover:bg-surface" data-testid={`nv-${e.maNV}`}>
                  <td className={td}>
                    <span className="font-semibold">{e.hoTen}</span>
                    <span className="block text-xs text-muted">Mã NV {e.maNV}</span>
                  </td>
                  <td className={td}>
                    {e.tenCV}
                    <span className="block text-xs text-muted">{e.tenCH ?? "Văn phòng"}</span>
                  </td>
                  <td className={td}>
                    <span className="tabular block">{e.sdt}</span>
                    <span className="block text-xs text-muted">{e.email}</span>
                  </td>
                  <td className={`${td} tabular`}>{dateVi(e.ngayVaoLam)}</td>
                  <td className={td}><Badge tone={e.trangThai === "DANG_LAM" ? "success" : "neutral"}>{TRANG_THAI_NV[e.trangThai]}</Badge></td>
                  <td className={td}>
                    {e.tenDangNhap ? (
                      <>
                        <span className="font-mono text-sm">{e.tenDangNhap}</span>
                        <span className="block font-mono text-xs text-muted">{e.maVT}</span>
                      </>
                    ) : e.trangThai === "DANG_LAM" && canCreateAccount ? (
                      <Link to={`/admin/accounts?tao=1&maNV=${e.maNV}`} className="inline-flex items-center gap-1 text-sm font-medium underline-offset-2 hover:underline">
                        <UserPlus className="size-4" aria-hidden="true" /> Tạo tài khoản
                      </Link>
                    ) : (
                      <span className="text-sm text-muted">Chưa có</span>
                    )}
                  </td>
                  <td className={td}>
                    {canEdit && (
                      <Button size="sm" variant="ghost" icon={<Pencil className="size-4" aria-hidden="true" />} onClick={() => setEditing(e)} aria-label={`Sửa ${e.hoTen}`}>Sửa</Button>
                    )}
                  </td>
                </tr>
              ))}
            </Table>
          )}
        </Panel>
      )}

      {editing && <EmployeeModal value={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
    </>
  );
}

function EmployeeModal({ value, onClose }: { value: NhanVien | null; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const lookups = useLookups();
  const [v, setV] = useState({
    hoTen: value?.hoTen ?? "",
    maCV: value?.maCV ?? "",
    maCH: value?.maCH != null ? String(value.maCH) : "",
    sdt: value?.sdt ?? "",
    email: value?.email ?? "",
    ngayVaoLam: value?.ngayVaoLam?.slice(0, 10) ?? new Date().toISOString().slice(0, 10),
    trangThai: value?.trangThai ?? "DANG_LAM",
  });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);
  const set = (k: keyof typeof v) => (e: { target: { value: string } }) => setV((x) => ({ ...x, [k]: e.target.value }));
  const quitting = !!value && value.trangThai === "DANG_LAM" && v.trangThai === "DA_NGHI";

  const save = useMutation({
    mutationFn: () => {
      const body = {
        hoTen: v.hoTen.trim(), maCV: v.maCV, maCH: v.maCH ? Number(v.maCH) : null, sdt: v.sdt.trim(), email: v.email.trim(),
        ngayVaoLam: v.ngayVaoLam, trangThai: v.trangThai,
      };
      return value ? api.put(`/api/admin/employees/${value.maNV}`, body) : api.post("/api/admin/employees", body);
    },
    onSuccess: () => {
      toast("success", value ? (quitting && value.tenDangNhap ? `Đã lưu. Tài khoản ${value.tenDangNhap} đã bị khóa vì nhân viên nghỉ việc.` : "Đã lưu hồ sơ nhân viên.") : "Đã thêm nhân viên. Có thể tạo tài khoản cho nhân viên này ở cột Tài khoản.");
      void qc.invalidateQueries({ queryKey: ["admin"] });
      onClose();
    },
    onError: (e) => {
      if (!isApiError(e)) return setFormError("Đã có lỗi xảy ra.");
      const f = fieldErrors(e);
      setErrors(f);
      setFormError(Object.keys(f).length ? null : e.userMessage);
    },
  });
  const submit = () => {
    const err: Record<string, string> = {};
    if (!v.hoTen.trim()) err.hoTen = "Họ tên là bắt buộc.";
    if (!v.maCV) err.maCV = "Cần chọn chức vụ.";
    if (!/^0\d{9}$/.test(v.sdt.trim())) err.sdt = "Số điện thoại gồm đúng 10 chữ số, bắt đầu bằng 0.";
    if (!/^\S+@\S+\.\S+$/.test(v.email.trim())) err.email = "Email không hợp lệ.";
    if (!v.ngayVaoLam) err.ngayVaoLam = "Ngày vào làm là bắt buộc.";
    setErrors(err);
    setFormError(null);
    if (!Object.keys(err).length) save.mutate();
  };

  return (
    <Modal
      open
      onClose={onClose}
      title={value ? `Sửa nhân viên: ${value.hoTen}` : "Thêm nhân viên"}
      className="w-[min(600px,calc(100vw-32px))]"
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>Hủy</Button>
          <Button loading={save.isPending} onClick={submit}>{value ? "Lưu thay đổi" : "Thêm nhân viên"}</Button>
        </>
      }
    >
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Họ tên" required error={errors.hoTen} className="sm:col-span-2">
          <TextInput value={v.hoTen} onChange={set("hoTen")} maxLength={100} />
        </Field>
        <Field label="Chức vụ" required error={errors.maCV}>
          <Select value={v.maCV} onChange={set("maCV")}>
            <option value="">Chọn chức vụ</option>
            {lookups.data?.chucVu.map((c) => <option key={c.maCV} value={c.maCV}>{c.tenCV}</option>)}
          </Select>
        </Field>
        <Field label="Nơi làm việc" error={errors.maCH}>
          <Select value={v.maCH} onChange={set("maCH")}>
            <option value="">Văn phòng</option>
            {lookups.data?.cuaHang.map((c) => <option key={c.maCH} value={c.maCH}>{c.tenCH}</option>)}
          </Select>
        </Field>
        <Field label="Số điện thoại" required error={errors.sdt}>
          <TextInput value={v.sdt} onChange={set("sdt")} inputMode="numeric" maxLength={10} />
        </Field>
        <Field label="Email" required error={errors.email}>
          <TextInput type="email" value={v.email} onChange={set("email")} maxLength={100} />
        </Field>
        <Field label="Ngày vào làm" required error={errors.ngayVaoLam}>
          <TextInput type="date" value={v.ngayVaoLam} onChange={set("ngayVaoLam")} />
        </Field>
        <Field label="Trạng thái" error={errors.trangThai}>
          <Select value={v.trangThai} onChange={set("trangThai")}>
            {Object.entries(TRANG_THAI_NV).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
          </Select>
        </Field>
        {quitting && (
          <Alert tone="warning" className="sm:col-span-2" title="Nhân viên chuyển sang Đã nghỉ">
            {value?.tenDangNhap
              ? <>Khi lưu, tài khoản <strong className="font-mono">{value.tenDangNhap}</strong> sẽ tự động bị khóa và không mở lại được khi nhân viên còn ở trạng thái Đã nghỉ.</>
              : "Nhân viên này chưa có tài khoản; sau khi nghỉ sẽ không tạo tài khoản được."}
          </Alert>
        )}
        {formError && <Alert tone="error" className="sm:col-span-2">{formError}</Alert>}
      </div>
    </Modal>
  );
}
