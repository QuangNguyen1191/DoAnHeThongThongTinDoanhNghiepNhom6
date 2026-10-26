import { useEffect, useMemo, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Plus, Save, Undo2 } from "lucide-react";
import { api } from "@shared/api/client";
import { fieldErrors, isApiError } from "@shared/api/errors";
import { useAuth } from "@shared/auth/AuthProvider";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { Alert } from "@shared/ui/Alert";
import { Button } from "@shared/ui/Button";
import { Badge, Panel, TextArea, errText } from "@shared/ui/data";
import { Field, Select, TextInput } from "@shared/ui/Field";
import { Modal } from "@shared/ui/Modal";
import { useToast } from "@shared/ui/Toast";
import { CONG, useRoles, type VaiTro } from "./common";

/** Vai trò khách hàng cố định (khách chỉ thao tác dữ liệu của chính mình): chỉ xem, không sửa ở đây. */
const PORTALS = ["ADMIN", "QUAN_LY"] as const;
type Grants = Record<string, Set<string>>;

const toGrants = (rows: { maVT: string; maQuyen: string; duocCap: boolean }[]): Grants => {
  const g: Grants = {};
  for (const r of rows) {
    g[r.maVT] ??= new Set();
    if (r.duocCap) g[r.maVT].add(r.maQuyen);
  }
  return g;
};
const sameSet = (a?: Set<string>, b?: Set<string>) => (a?.size ?? 0) === (b?.size ?? 0) && [...(a ?? [])].every((x) => b?.has(x));

/** A7. Ma trận Vai trò × Quyền theo từng cổng (checkbox), tạo vai trò mới cho cổng Quản trị hoặc Quản lý. */
export function RolesPage() {
  const { session } = useAuth();
  const qc = useQueryClient();
  const toast = useToast();
  const q = useRoles();
  const saved = useMemo(() => toGrants(q.data?.quyen ?? []), [q.data]);
  const [grants, setGrants] = useState<Grants>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [creating, setCreating] = useState(false);
  useEffect(() => setGrants(toGrants(q.data?.quyen ?? [])), [q.data]);

  const dirty = Object.keys(grants).filter((vt) => !sameSet(grants[vt], saved[vt]));

  const save = useMutation({
    mutationFn: async () => {
      const failed: Record<string, string> = {};
      for (const maVT of dirty) {
        try {
          await api.put(`/api/admin/roles/${maVT}/permissions`, { dsQuyen: [...grants[maVT]].sort() });
        } catch (e) {
          failed[maVT] = errText(e);
        }
      }
      return failed;
    },
    onSuccess: (failed) => {
      setErrors(failed);
      const ok = dirty.length - Object.keys(failed).length;
      if (ok > 0) toast("success", `Đã lưu quyền cho ${ok} vai trò. Người dùng thấy thay đổi ngay ở lần tải trang tiếp theo.`);
      if (Object.keys(failed).length) toast("error", "Có vai trò chưa lưu được, xem thông báo bên dưới ma trận.");
      void qc.invalidateQueries({ queryKey: ["admin", "roles"] });
    },
  });

  const toggle = (maVT: string, maQuyen: string) =>
    setGrants((g) => {
      const s = new Set(g[maVT]);
      if (s.has(maQuyen)) s.delete(maQuyen);
      else s.add(maQuyen);
      return { ...g, [maVT]: s };
    });

  if (q.isError) return <ErrorState error={q.error} onRetry={() => q.refetch()} />;
  if (q.isPending) return <Skeleton className="h-96" />;
  const { vaiTro, quyen } = q.data;

  return (
    <>
      <PageHeader
        title="Vai trò và quyền"
        description="Phân quyền theo vai trò: tick quyền cho từng vai trò rồi bấm Lưu. Mỗi tài khoản nhận quyền theo vai trò của nó."
        actions={<Button icon={<Plus className="size-4" aria-hidden="true" />} onClick={() => setCreating(true)}>Tạo vai trò</Button>}
      />

      <div className="flex flex-col gap-6">
        {PORTALS.map((cong) => {
          const roles = vaiTro.filter((v) => v.congTruyCap === cong);
          const perms = [...new Map(quyen.filter((x) => x.congTruyCap === cong).map((x) => [x.maQuyen, x.tenQuyen])).entries()];
          return (
            <Panel key={cong} title={`${CONG[cong]} (${cong})`} bodyClass="">
              <div className="overflow-x-auto">
                <table className="w-full min-w-[560px] border-collapse text-[14.5px]" aria-label={`Ma trận quyền ${CONG[cong]}`}>
                  <thead>
                    <tr className="border-b border-line text-left">
                      <th scope="col" className="px-5 py-3 text-xs font-semibold uppercase tracking-wider text-muted">Quyền</th>
                      {roles.map((v) => (
                        <th key={v.maVT} scope="col" className="px-4 py-3 text-center align-bottom">
                          <span className="block font-semibold">{v.tenVT}</span>
                          <span className="block font-mono text-xs font-normal text-muted">{v.maVT} · {v.soTaiKhoan} TK</span>
                          {dirty.includes(v.maVT) && <Badge tone="accent">Chưa lưu</Badge>}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-line">
                    {perms.map(([maQuyen, tenQuyen]) => (
                      <tr key={maQuyen} className="hover:bg-surface">
                        <th scope="row" className="px-5 py-2.5 text-left font-normal">
                          {tenQuyen}
                          <span className="block font-mono text-xs text-muted">{maQuyen}</span>
                        </th>
                        {roles.map((v) => {
                          // Không cho tự gỡ quyền phân quyền khỏi vai trò của chính mình (CSDL cũng chặn, lỗi 52094).
                          const selfLock = maQuyen === "AD_PHAN_QUYEN" && v.maVT === session?.maVT;
                          return (
                            <td key={v.maVT} className="px-4 py-2.5 text-center">
                              <input
                                type="checkbox"
                                className="size-[18px] accent-[var(--color-ink)]"
                                aria-label={`${tenQuyen} cho ${v.tenVT}`}
                                checked={grants[v.maVT]?.has(maQuyen) ?? false}
                                disabled={selfLock}
                                title={selfLock ? "Không tự gỡ quyền phân quyền khỏi vai trò của chính mình" : undefined}
                                onChange={() => toggle(v.maVT, maQuyen)}
                              />
                            </td>
                          );
                        })}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Panel>
          );
        })}

        {Object.entries(errors).map(([maVT, msg]) => (
          <Alert key={maVT} tone="error" title={`Chưa lưu được vai trò ${maVT}`}>{msg}</Alert>
        ))}

        <div className="sticky bottom-4 flex flex-wrap items-center justify-end gap-3 rounded-md border border-line bg-bg px-5 py-3 shadow-[0_8px_24px_rgb(0_0_0/0.08)]">
          <span className="mr-auto text-sm text-muted" aria-live="polite">
            {dirty.length ? `${dirty.length} vai trò có thay đổi chưa lưu` : "Không có thay đổi"}
          </span>
          <Button variant="ghost" disabled={!dirty.length} icon={<Undo2 className="size-4" aria-hidden="true" />} onClick={() => { setGrants(saved); setErrors({}); }}>Hoàn tác</Button>
          <Button loading={save.isPending} disabled={!dirty.length} icon={<Save className="size-4" aria-hidden="true" />} onClick={() => save.mutate()}>Lưu thay đổi</Button>
        </div>

        <RoleList roles={vaiTro.filter((v) => v.congTruyCap === "KHACH_HANG")} />
      </div>

      {creating && <CreateRoleModal onClose={() => setCreating(false)} />}
    </>
  );
}

function RoleList({ roles }: { roles: VaiTro[] }) {
  if (!roles.length) return null;
  return (
    <p className="text-sm text-muted">
      Vai trò cổng Khách hàng ({roles.map((r) => `${r.tenVT}: ${r.soTaiKhoan} tài khoản`).join(", ")}) cố định quyền hồ sơ, phản hồi, khảo sát và không chỉnh ở đây.
    </p>
  );
}

function CreateRoleModal({ onClose }: { onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [v, setV] = useState({ maVT: "", tenVT: "", congTruyCap: "QUAN_LY", moTa: "" });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);
  const set = (k: keyof typeof v) => (e: { target: { value: string } }) => setV((x) => ({ ...x, [k]: e.target.value }));

  const create = useMutation({
    mutationFn: () => api.post("/api/admin/roles", { maVT: v.maVT.trim(), tenVT: v.tenVT.trim(), congTruyCap: v.congTruyCap, moTa: v.moTa.trim() || null }),
    onSuccess: () => {
      toast("success", `Đã tạo vai trò ${v.maVT}. Vai trò mới chưa có quyền nào: tick quyền trong ma trận rồi Lưu.`);
      void qc.invalidateQueries({ queryKey: ["admin", "roles"] });
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
    if (!/^[A-Z0-9_]{2,20}$/.test(v.maVT.trim())) err.maVT = "Mã vai trò 2–20 ký tự IN HOA, số hoặc gạch dưới.";
    if (!v.tenVT.trim()) err.tenVT = "Tên vai trò là bắt buộc.";
    setErrors(err);
    setFormError(null);
    if (!Object.keys(err).length) create.mutate();
  };

  return (
    <Modal
      open
      onClose={onClose}
      title="Tạo vai trò mới"
      className="w-[min(520px,calc(100vw-32px))]"
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>Hủy</Button>
          <Button loading={create.isPending} onClick={submit}>Tạo vai trò</Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        <Field label="Mã vai trò" required error={errors.maVT} hint="Ví dụ: NV_KHAO_SAT">
          <TextInput value={v.maVT} onChange={(e) => setV((x) => ({ ...x, maVT: e.target.value.toUpperCase() }))} maxLength={20} spellCheck={false} />
        </Field>
        <Field label="Tên vai trò" required error={errors.tenVT}>
          <TextInput value={v.tenVT} onChange={set("tenVT")} maxLength={50} />
        </Field>
        <Field label="Cổng truy cập" required error={errors.congTruyCap} hint="Quyết định tài khoản đăng nhập ở trang nào và được gán quyền của cổng nào.">
          <Select value={v.congTruyCap} onChange={set("congTruyCap")}>
            <option value="QUAN_LY">Cổng Quản lý (trang chung)</option>
            <option value="ADMIN">Cổng Quản trị (trang Admin)</option>
          </Select>
        </Field>
        <Field label="Mô tả">
          <TextArea value={v.moTa} onChange={set("moTa")} maxLength={200} rows={2} className="min-h-16" />
        </Field>
        {formError && <Alert tone="error">{formError}</Alert>}
      </div>
    </Modal>
  );
}
