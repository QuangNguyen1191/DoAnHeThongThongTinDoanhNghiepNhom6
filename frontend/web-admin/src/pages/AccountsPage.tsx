import { useMemo, useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useSearchParams } from "react-router";
import { KeyRound, Lock, LockOpen, Plus, Search, Trash2, UserCog } from "lucide-react";
import { api } from "@shared/api/client";
import { fieldErrors, isApiError } from "@shared/api/errors";
import { useAuth } from "@shared/auth/AuthProvider";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { Alert } from "@shared/ui/Alert";
import { Button } from "@shared/ui/Button";
import { Badge, EmptyRow, Panel, Table, TRANG_THAI_TK, dateTimeVi, errText, td, useCan } from "@shared/ui/data";
import { Field, Select, TextInput } from "@shared/ui/Field";
import { Modal } from "@shared/ui/Modal";
import { useToast } from "@shared/ui/Toast";
import {
  LOAI_TK, TempPasswordBox, toneTrangThaiTK, useRoles, type NhanVien, type TaiKhoan, type TempPassword,
} from "./common";

interface Filters { tuKhoa: string; loaiTK: string; maVT: string; trangThai: string }
const EMPTY: Filters = { tuKhoa: "", loaiTK: "", maVT: "", trangThai: "" };

type Dialog = { kind: "lock" | "unlock" | "delete" | "reset" | "role"; tk: TaiKhoan } | { kind: "create" } | null;

/**
 * A3–A6. Danh sách tài khoản; tạo tài khoản cho nhân viên, khóa/mở khóa, xóa, đặt lại mật khẩu, đổi vai trò.
 * Ẩn nút chỉ để gọn: CSDL vẫn kiểm quyền (AD_TAI_KHOAN, AD_PHAN_QUYEN), chặn tự thao tác trên chính mình và giữ Admin cuối cùng.
 */
export function AccountsPage() {
  const can = useCan();
  const { session } = useAuth();
  const qc = useQueryClient();
  const toast = useToast();
  const [params, setParams] = useSearchParams();
  const [draft, setDraft] = useState<Filters>(EMPTY);
  const [filters, setFilters] = useState<Filters>(EMPTY);
  const [dialog, setDialog] = useState<Dialog>(() => (params.get("tao") ? { kind: "create" } : null));
  const [lyDo, setLyDo] = useState("");
  const [maVTMoi, setMaVTMoi] = useState("");
  const [dialogError, setDialogError] = useState<string | null>(null);
  const [temp, setTemp] = useState<TempPassword | null>(null);

  const phanQuyen = can("AD_PHAN_QUYEN");
  const q = useQuery({
    queryKey: ["admin", "accounts", filters],
    queryFn: () => api.get<TaiKhoan[]>("/api/admin/accounts", { query: { ...filters } }),
  });
  const roles = useRoles(phanQuyen);
  // Không có quyền phân quyền thì lấy danh sách vai trò từ chính các tài khoản đang thấy (chỉ để lọc).
  const roleOptions = useMemo(() => {
    if (roles.data) return roles.data.vaiTro.map((v) => ({ maVT: v.maVT, tenVT: v.tenVT, loaiTK: v.loaiTK }));
    const m = new Map<string, { maVT: string; tenVT: string; loaiTK: string }>();
    q.data?.forEach((t) => m.set(t.maVT, { maVT: t.maVT, tenVT: t.tenVT, loaiTK: t.loaiTK }));
    return [...m.values()];
  }, [roles.data, q.data]);

  const set = (k: keyof Filters) => (e: { target: { value: string } }) => setDraft((d) => ({ ...d, [k]: e.target.value }));
  const apply = (e: FormEvent) => {
    e.preventDefault();
    setFilters(draft);
  };

  const open = (d: Dialog) => {
    setLyDo("");
    setMaVTMoi(d && "tk" in d ? d.tk.maVT : "");
    setDialogError(null);
    setTemp(null);
    setDialog(d);
  };
  const close = () => {
    setDialog(null);
    if (params.get("tao")) setParams({}, { replace: true });
  };
  const done = (msg: string, keepOpen = false) => {
    toast("success", msg);
    if (!keepOpen) setDialog(null);
    void qc.invalidateQueries({ queryKey: ["admin"] });
  };
  const fail = (e: unknown) => setDialogError(errText(e));

  const tk = dialog && "tk" in dialog ? dialog.tk : null;
  const lock = useMutation({
    mutationFn: (khoa: boolean) => api.patch(`/api/admin/accounts/${tk!.maTK}/lock`, { khoa, lyDo: lyDo.trim() || null }),
    onSuccess: (_, khoa) => done(khoa ? `Đã khóa tài khoản ${tk!.tenDangNhap}.` : `Đã mở khóa tài khoản ${tk!.tenDangNhap}.`),
    onError: fail,
  });
  const del = useMutation({
    mutationFn: () => api.delete(`/api/admin/accounts/${tk!.maTK}`),
    onSuccess: () => done(`Đã xóa tài khoản ${tk!.tenDangNhap}. Hồ sơ và lịch sử vẫn được giữ.`),
    onError: fail,
  });
  const reset = useMutation({
    mutationFn: () => api.post<{ maTK: number; matKhauTam: string }>(`/api/admin/accounts/${tk!.maTK}/reset-password`),
    onSuccess: (r) => {
      setTemp({ tenDangNhap: tk!.tenDangNhap, matKhauTam: r.matKhauTam });
      done("Đã đặt lại mật khẩu.", true);
    },
    onError: fail,
  });
  const role = useMutation({
    mutationFn: () => api.put(`/api/admin/accounts/${tk!.maTK}/role`, { maVT: maVTMoi }),
    onSuccess: () => done(`Đã đổi vai trò của ${tk!.tenDangNhap}. Quyền mới có hiệu lực ở lần gọi tiếp theo của người đó.`),
    onError: fail,
  });

  const rows = q.data ?? [];
  const nvRoles = roles.data?.vaiTro.filter((v) => v.loaiTK === "NV") ?? [];

  return (
    <>
      <PageHeader
        title="Tài khoản"
        description="Tạo tài khoản cho nhân viên, khóa/mở khóa, xóa, đặt lại mật khẩu và phân quyền (đổi vai trò)."
        actions={can("AD_TAI_KHOAN") && phanQuyen && can("AD_TRA_CUU") && (
          <Button icon={<Plus className="size-4" aria-hidden="true" />} onClick={() => open({ kind: "create" })}>Tạo tài khoản nhân viên</Button>
        )}
      />

      <form onSubmit={apply} noValidate className="mb-5 rounded-md border border-line bg-bg p-4">
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <Field label="Từ khóa" className="sm:col-span-2">
            <TextInput value={draft.tuKhoa} onChange={set("tuKhoa")} placeholder="Tên đăng nhập hoặc tên chủ tài khoản" />
          </Field>
          <Field label="Loại tài khoản">
            <Select value={draft.loaiTK} onChange={set("loaiTK")}>
              <option value="">Tất cả</option>
              {Object.entries(LOAI_TK).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
            </Select>
          </Field>
          <Field label="Vai trò">
            <Select value={draft.maVT} onChange={set("maVT")}>
              <option value="">Tất cả</option>
              {roleOptions.map((r) => <option key={r.maVT} value={r.maVT}>{r.tenVT}</option>)}
            </Select>
          </Field>
          <Field label="Trạng thái">
            <Select value={draft.trangThai} onChange={set("trangThai")}>
              <option value="">Tất cả</option>
              {Object.entries(TRANG_THAI_TK).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
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
        <Panel title={<span aria-live="polite">{rows.length} tài khoản</span>} bodyClass="">
          {rows.length === 0 ? (
            <EmptyRow>Không có tài khoản nào khớp bộ lọc.</EmptyRow>
          ) : (
            <Table label="Danh sách tài khoản" head={["Tên đăng nhập", "Chủ tài khoản", "Vai trò", "Trạng thái", "Đăng nhập cuối", "Thao tác"]}>
              {rows.map((t) => {
                const self = t.maTK === session?.maTK;
                const locked = t.trangThai === "DA_KHOA";
                // Đặt lại mật khẩu tài khoản nội bộ cần thêm AD_PHAN_QUYEN (chống chiếm tài khoản Quản lý/Admin).
                const canReset = can("AD_TAI_KHOAN") && (t.loaiTK === "KH" || phanQuyen);
                return (
                  <tr key={t.maTK} className="hover:bg-surface" data-testid={`tk-${t.tenDangNhap}`}>
                    <td className={td}>
                      <span className="font-mono font-semibold">{t.tenDangNhap}</span>
                      <span className="block text-xs text-muted">Mã {t.maTK} · tạo {dateTimeVi(t.ngayTao)}</span>
                    </td>
                    <td className={td}>
                      {t.chuTaiKhoan ?? "—"}
                      <span className="block text-xs text-muted">{LOAI_TK[t.loaiTK]}{t.maNV ? ` · NV ${t.maNV}` : t.maKH ? ` · KH ${t.maKH}` : ""}</span>
                    </td>
                    <td className={td}>
                      {t.tenVT}
                      <span className="block font-mono text-xs text-muted">{t.maVT}</span>
                    </td>
                    <td className={td}>
                      <span className="flex flex-wrap gap-1">
                        <Badge tone={toneTrangThaiTK(t.trangThai)}>{TRANG_THAI_TK[t.trangThai]}</Badge>
                        {t.phaiDoiMatKhau && <Badge tone="info">Chờ đổi mật khẩu</Badge>}
                      </span>
                      {locked && t.lyDoKhoa && <span className="mt-1 block max-w-[200px] text-xs text-muted">Lý do: {t.lyDoKhoa}</span>}
                    </td>
                    <td className={`${td} tabular text-sm text-ink-soft`}>{dateTimeVi(t.lanDangNhapCuoi)}</td>
                    <td className={td}>
                      {self ? (
                        <span className="text-xs text-muted">Tài khoản của bạn</span>
                      ) : (
                        <div className="flex flex-wrap gap-1">
                          {phanQuyen && t.loaiTK === "NV" && (
                            <Button size="sm" variant="ghost" icon={<UserCog className="size-4" aria-hidden="true" />} onClick={() => open({ kind: "role", tk: t })}>Vai trò</Button>
                          )}
                          {canReset && (
                            <Button size="sm" variant="ghost" icon={<KeyRound className="size-4" aria-hidden="true" />} onClick={() => open({ kind: "reset", tk: t })}>Đặt lại MK</Button>
                          )}
                          {can("AD_TAI_KHOAN") && (locked ? (
                            <Button size="sm" variant="ghost" icon={<LockOpen className="size-4" aria-hidden="true" />} onClick={() => open({ kind: "unlock", tk: t })}>Mở khóa</Button>
                          ) : (
                            <Button size="sm" variant="ghost" icon={<Lock className="size-4" aria-hidden="true" />} onClick={() => open({ kind: "lock", tk: t })}>Khóa</Button>
                          ))}
                          {can("AD_TAI_KHOAN") && (
                            <Button size="sm" variant="ghost" className="text-danger" icon={<Trash2 className="size-4" aria-hidden="true" />} onClick={() => open({ kind: "delete", tk: t })}>Xóa</Button>
                          )}
                        </div>
                      )}
                    </td>
                  </tr>
                );
              })}
            </Table>
          )}
        </Panel>
      )}

      {dialog?.kind === "create" && (
        <CreateAccountModal
          roles={nvRoles}
          preselectMaNV={Number(params.get("maNV")) || undefined}
          onClose={close}
          onCreated={() => void qc.invalidateQueries({ queryKey: ["admin"] })}
        />
      )}

      <Modal
        open={dialog?.kind === "lock" || dialog?.kind === "unlock"}
        onClose={close}
        role="alertdialog"
        title={dialog?.kind === "lock" ? `Khóa tài khoản ${tk?.tenDangNhap}?` : `Mở khóa tài khoản ${tk?.tenDangNhap}?`}
        footer={
          <>
            <Button variant="ghost" onClick={close}>Hủy</Button>
            <Button
              variant={dialog?.kind === "lock" ? "danger" : "primary"}
              loading={lock.isPending}
              disabled={dialog?.kind === "lock" && !lyDo.trim()}
              onClick={() => lock.mutate(dialog?.kind === "lock")}
            >
              {dialog?.kind === "lock" ? "Khóa tài khoản" : "Mở khóa"}
            </Button>
          </>
        }
      >
        <p>{dialog?.kind === "lock" ? "Người dùng bị đăng xuất ở lần gọi tiếp theo và không đăng nhập được cho tới khi mở khóa." : "Người dùng sẽ đăng nhập lại được."}</p>
        {dialog?.kind === "lock" && (
          <Field label="Lý do khóa" required className="mt-4">
            <TextInput value={lyDo} onChange={(e) => setLyDo(e.target.value)} maxLength={200} />
          </Field>
        )}
        {dialogError && <Alert tone="error" className="mt-3">{dialogError}</Alert>}
      </Modal>

      <Modal
        open={dialog?.kind === "delete"}
        onClose={close}
        role="alertdialog"
        title={`Xóa tài khoản ${tk?.tenDangNhap}?`}
        footer={
          <>
            <Button variant="ghost" onClick={close}>Hủy</Button>
            <Button variant="danger" loading={del.isPending} onClick={() => del.mutate()}>Xóa tài khoản</Button>
          </>
        }
      >
        <p>
          Chỉ xóa <strong>tài khoản đăng nhập</strong>. Hồ sơ {tk?.loaiTK === "KH" ? "khách hàng" : "nhân viên"} <strong>{tk?.chuTaiKhoan}</strong> và
          lịch sử (hóa đơn, phản hồi, khảo sát, nhật ký) vẫn được giữ. Có thể cấp tài khoản mới cho hồ sơ này sau.
        </p>
        {dialogError && <Alert tone="error" className="mt-3">{dialogError}</Alert>}
      </Modal>

      <Modal
        open={dialog?.kind === "reset"}
        onClose={close}
        title={`Đặt lại mật khẩu cho ${tk?.tenDangNhap}?`}
        footer={temp ? <Button onClick={close}>Xong</Button> : (
          <>
            <Button variant="ghost" onClick={close}>Hủy</Button>
            <Button loading={reset.isPending} onClick={() => reset.mutate()}>Đặt lại mật khẩu</Button>
          </>
        )}
      >
        {temp ? <TempPasswordBox value={temp} title="Đã đặt lại mật khẩu" /> : <p>Hệ thống sinh mật khẩu tạm mới; mật khẩu cũ hết hiệu lực ngay. Người dùng phải đổi mật khẩu ở lần đăng nhập tới.</p>}
        {dialogError && <Alert tone="error" className="mt-3">{dialogError}</Alert>}
      </Modal>

      <Modal
        open={dialog?.kind === "role"}
        onClose={close}
        title={`Đổi vai trò của ${tk?.tenDangNhap}`}
        footer={
          <>
            <Button variant="ghost" onClick={close}>Hủy</Button>
            <Button loading={role.isPending} disabled={!maVTMoi || maVTMoi === tk?.maVT} onClick={() => role.mutate()}>Lưu vai trò</Button>
          </>
        }
      >
        <p>Vai trò quyết định cổng đăng nhập và các quyền của tài khoản. Ví dụ: thăng chức Nhân viên CSKH lên Quản lý.</p>
        <Field label="Vai trò mới" required className="mt-4">
          <Select value={maVTMoi} onChange={(e) => setMaVTMoi(e.target.value)}>
            {nvRoles.map((v) => <option key={v.maVT} value={v.maVT}>{v.tenVT} ({v.congTruyCap === "ADMIN" ? "cổng Quản trị" : "cổng Quản lý"})</option>)}
          </Select>
        </Field>
        {dialogError && <Alert tone="error" className="mt-3">{dialogError}</Alert>}
      </Modal>
    </>
  );
}

/** A4. Tạo tài khoản cho nhân viên đang làm và chưa có tài khoản; mật khẩu tạm hiện một lần. */
function CreateAccountModal({ roles, preselectMaNV, onClose, onCreated }: {
  roles: { maVT: string; tenVT: string; congTruyCap: string }[];
  preselectMaNV?: number;
  onClose: () => void;
  onCreated: () => void;
}) {
  const [maNV, setMaNV] = useState(preselectMaNV ? String(preselectMaNV) : "");
  const [tenDangNhap, setTenDangNhap] = useState("");
  const [maVT, setMaVT] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [temp, setTemp] = useState<TempPassword | null>(null);

  const employees = useQuery({
    queryKey: ["admin", "employees", "free"],
    queryFn: () => api.get<NhanVien[]>("/api/admin/employees", { query: { trangThai: "DANG_LAM" } }),
  });
  const free = (employees.data ?? []).filter((e) => e.maTK == null);

  const create = useMutation({
    mutationFn: () => api.post<{ maTK: number; tenDangNhap: string; matKhauTam: string }>("/api/admin/accounts", {
      maNV: Number(maNV), tenDangNhap: tenDangNhap.trim(), maVT,
    }),
    onSuccess: (r) => {
      setTemp({ tenDangNhap: r.tenDangNhap, matKhauTam: r.matKhauTam });
      onCreated();
    },
    onError: (e) => {
      if (isApiError(e)) {
        const f = fieldErrors(e);
        setErrors(f);
        setFormError(Object.keys(f).length ? null : e.userMessage);
      } else setFormError("Đã có lỗi xảy ra.");
    },
  });

  const submit = () => {
    const err: Record<string, string> = {};
    if (!maNV) err.maNV = "Cần chọn nhân viên.";
    if (!/^\S{4,50}$/.test(tenDangNhap.trim())) err.tenDangNhap = "Tên đăng nhập 4–50 ký tự, không có khoảng trắng.";
    if (!maVT) err.maVT = "Cần chọn vai trò.";
    setErrors(err);
    setFormError(null);
    if (Object.keys(err).length === 0) create.mutate();
  };

  return (
    <Modal
      open
      onClose={onClose}
      title="Tạo tài khoản nhân viên"
      className="w-[min(520px,calc(100vw-32px))]"
      footer={temp ? <Button onClick={onClose}>Xong</Button> : (
        <>
          <Button variant="ghost" onClick={onClose}>Hủy</Button>
          <Button loading={create.isPending} onClick={submit}>Tạo tài khoản</Button>
        </>
      )}
    >
      {temp ? (
        <TempPasswordBox value={temp} title="Đã tạo tài khoản" />
      ) : (
        <div className="flex flex-col gap-4">
          <p>Chỉ hiện nhân viên đang làm và chưa có tài khoản. Muốn thêm người mới, vào mục Nhân viên trước.</p>
          <Field label="Nhân viên" required error={errors.maNV}>
            <Select value={maNV} onChange={(e) => setMaNV(e.target.value)}>
              <option value="">{employees.isPending ? "Đang tải…" : free.length ? "Chọn nhân viên" : "Không còn nhân viên nào chưa có tài khoản"}</option>
              {free.map((e) => <option key={e.maNV} value={e.maNV}>{e.hoTen} · {e.tenCV}{e.tenCH ? ` · ${e.tenCH}` : ""}</option>)}
            </Select>
          </Field>
          <Field label="Tên đăng nhập" required error={errors.tenDangNhap} hint="4–50 ký tự, không có khoảng trắng. Ví dụ: nv.tung">
            <TextInput value={tenDangNhap} onChange={(e) => setTenDangNhap(e.target.value)} autoComplete="off" spellCheck={false} />
          </Field>
          <Field label="Vai trò" required error={errors.maVT} hint="Vai trò cổng Quản trị đăng nhập ở trang Admin; vai trò cổng Quản lý đăng nhập ở trang chung.">
            <Select value={maVT} onChange={(e) => setMaVT(e.target.value)}>
              <option value="">Chọn vai trò</option>
              {roles.map((v) => <option key={v.maVT} value={v.maVT}>{v.tenVT} ({v.congTruyCap === "ADMIN" ? "cổng Quản trị" : "cổng Quản lý"})</option>)}
            </Select>
          </Field>
          {formError && <Alert tone="error">{formError}</Alert>}
        </div>
      )}
    </Modal>
  );
}
