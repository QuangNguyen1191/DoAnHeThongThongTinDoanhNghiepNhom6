import { useState, type ReactNode } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useNavigate, useParams } from "react-router";
import { ArrowLeft, KeyRound, Lock, LockOpen, Pencil, Trash2 } from "lucide-react";
import { api } from "@shared/api/client";
import { isApiError } from "@shared/api/errors";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { Alert } from "@shared/ui/Alert";
import { Button } from "@shared/ui/Button";
import { Field, TextInput } from "@shared/ui/Field";
import { Modal } from "@shared/ui/Modal";
import { useToast } from "@shared/ui/Toast";
import {
  Badge, EmptyRow, GIOI_TINH, LOAI_PH, MUC_DICH_KS, Panel, Table, TextArea, TRANG_THAI_PH, dateTimeVi, dateVi, td, toneTrangThaiPH, useCan, vnd,
} from "./common";
import { AccountBadge, type KhachHangRow } from "./CustomersPage";
import { TempPasswordBox, type TempPassword } from "./CustomerFormPage";

export interface CustomerProfile {
  hoSo: KhachHangRow & {
    ngaySinh: string | null;
    maTinh: string | null;
    chiTieuRong: number;
    soHoaDon: number;
    lanMuaCuoi: string | null;
    ngayXoa: string | null;
    maTK: number | null;
  };
  soThich: { maLoai: number; tenLoai: string }[];
  hoaDon: { maHD: number; soHoaDon: string; ngayLap: string; kenhBan: string; tenCH: string | null; thanhTien: number }[];
  doiTra: { maDT: number; soHoaDon: string; tenSP: string; soLuong: number; lyDo: string | null; ngayDoiTra: string; giaTriHoan: number }[];
  phanHoi: { maPH: number; tenSP: string; loaiPH: string; diemDanhGia: number | null; noiDung: string; ngayGui: string; trangThai: string }[];
  khaoSat: { maKS: number; tieuDe: string; mucDich: string; ngayGui: string; ngayHoanThanh: string | null; trangThai: string }[];
  voucher: { maCode: string; phanTramGiam: number; hanDung: string; trangThai: string }[];
  lichSuHang: { thoiGian: string; maHangCu: string | null; maHangMoi: string; lyDo: string | null }[];
}

type Dialog = "lock" | "unlock" | "delete" | "account" | null;

function Info({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div>
      <dt className="text-xs font-medium uppercase tracking-wider text-muted">{label}</dt>
      <dd className="mt-0.5 text-[15px]">{children ?? "—"}</dd>
    </div>
  );
}

/** Q2. Hồ sơ 360° + các thao tác QL-2 (xóa), QL-3 (khóa/mở khóa), Q4 (sửa), Q5 (cấp tài khoản). */
export function CustomerDetailPage() {
  const { maKH } = useParams();
  const id = Number(maKH);
  const can = useCan();
  const nav = useNavigate();
  const qc = useQueryClient();
  const toast = useToast();
  const [dialog, setDialog] = useState<Dialog>(null);
  const [lyDo, setLyDo] = useState("");
  const [tenDangNhap, setTenDangNhap] = useState("");
  const [dialogError, setDialogError] = useState<string | null>(null);
  const [temp, setTemp] = useState<TempPassword | null>(null);

  const q = useQuery({ queryKey: ["manager", "customer", id], queryFn: () => api.get<CustomerProfile>(`/api/manager/customers/${id}`) });

  const open = (d: Dialog) => {
    setLyDo("");
    setTenDangNhap("");
    setDialogError(null);
    setDialog(d);
  };
  const done = (msg: string) => {
    toast("success", msg);
    setDialog(null);
    void qc.invalidateQueries({ queryKey: ["manager"] });
  };
  const fail = (e: unknown) => setDialogError(isApiError(e) ? e.userMessage : "Đã có lỗi xảy ra.");

  const lock = useMutation({
    mutationFn: (khoa: boolean) => api.patch(`/api/manager/customers/${id}/lock`, { khoa, lyDo: lyDo.trim() || null }),
    onSuccess: (_, khoa) => done(khoa ? "Đã khóa tài khoản khách hàng." : "Đã mở khóa tài khoản khách hàng."),
    onError: fail,
  });
  const del = useMutation({
    mutationFn: () => api.delete(`/api/manager/customers/${id}`, { lyDo: lyDo.trim() }),
    onSuccess: () => done("Đã xóa khách hàng. Lịch sử mua hàng, phản hồi và khảo sát vẫn được giữ cho báo cáo."),
    onError: fail,
  });
  const grant = useMutation({
    mutationFn: () => api.post<{ tenDangNhap: string; matKhauTam: string }>(`/api/manager/customers/${id}/account`, { tenDangNhap: tenDangNhap.trim() }),
    onSuccess: (r) => {
      setTemp({ tenDangNhap: r.tenDangNhap, matKhauTam: r.matKhauTam });
      done("Đã cấp tài khoản.");
    },
    onError: fail,
  });

  if (q.isError) return <ErrorState error={q.error} onRetry={() => q.refetch()} />;
  if (q.isPending) return <Skeleton className="h-96" />;
  const { hoSo: h, ...d } = q.data;
  const active = h.trangThaiHoSo === "HOAT_DONG";
  const hasAccount = !!h.tenDangNhap;
  const locked = h.trangThaiTaiKhoan === "DA_KHOA";

  return (
    <>
      <Link to="/manager/customers" className="mb-3 inline-flex items-center gap-1.5 text-sm font-medium text-ink-soft hover:text-ink">
        <ArrowLeft className="size-4" aria-hidden="true" /> Về danh sách
      </Link>
      <PageHeader
        title={h.hoTen}
        description={<span className="inline-flex flex-wrap items-center gap-2">Mã {h.maKH} · {h.tenHang} · <AccountBadge k={h} /></span>}
        actions={
          active && (
            <div className="flex flex-wrap gap-2">
              {can("QL_KH_SUA") && <Button variant="secondary" size="sm" icon={<Pencil className="size-4" aria-hidden="true" />} onClick={() => nav(`/manager/customers/${id}/edit`)}>Sửa</Button>}
              {can("QL_KH_THEM") && !hasAccount && <Button variant="secondary" size="sm" icon={<KeyRound className="size-4" aria-hidden="true" />} onClick={() => open("account")}>Cấp tài khoản</Button>}
              {can("QL_KH_KHOA") && hasAccount && (locked ? (
                <Button variant="secondary" size="sm" icon={<LockOpen className="size-4" aria-hidden="true" />} onClick={() => open("unlock")}>Mở khóa tài khoản</Button>
              ) : (
                <Button variant="secondary" size="sm" icon={<Lock className="size-4" aria-hidden="true" />} onClick={() => open("lock")}>Khóa tài khoản</Button>
              ))}
              {can("QL_KH_XOA") && <Button variant="danger" size="sm" icon={<Trash2 className="size-4" aria-hidden="true" />} onClick={() => open("delete")}>Xóa khách hàng</Button>}
            </div>
          )
        }
      />

      <div className="flex flex-col gap-5">
        {temp && <TempPasswordBox value={temp} />}
        {!active && <Alert tone="warning" title="Hồ sơ đã bị xóa">Xóa lúc {dateTimeVi(h.ngayXoa)}. Tài khoản đã bị khóa; dữ liệu lịch sử được giữ cho báo cáo.</Alert>}
        {active && locked && <Alert tone="warning">Tài khoản đang bị khóa: khách không đăng nhập được và không nhận khảo sát mới.</Alert>}

        <Panel title="Thông tin">
          <dl className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <Info label="Số điện thoại"><span className="tabular">{h.sdt}</span></Info>
            <Info label="Email">{h.email}</Info>
            <Info label="Giới tính">{GIOI_TINH[h.gioiTinh ?? ""] ?? "Không rõ"}</Info>
            <Info label="Ngày sinh · tuổi">{h.ngaySinh ? `${dateVi(h.ngaySinh)} · ${h.tuoi} tuổi (${h.nhomTuoi})` : "Không rõ"}</Info>
            <Info label="Tỉnh/thành">{h.tenTinh}</Info>
            <Info label="Ngày đăng ký">{dateVi(h.ngayDangKy)}</Info>
            <Info label="Điểm · chi tiêu"><span className="tabular">{h.diem.toLocaleString("vi-VN")} điểm · {vnd(h.chiTieuRong)}</span></Info>
            <Info label="Tên đăng nhập">{h.tenDangNhap ? <span className="font-mono">{h.tenDangNhap}</span> : "Chưa có"}</Info>
            <Info label="Sở thích">{d.soThich.length ? d.soThich.map((s) => s.tenLoai).join(", ") : "Chưa khai báo"}</Info>
          </dl>
        </Panel>

        <div className="grid gap-5 xl:grid-cols-2">
          <Panel title={`Phản hồi (${d.phanHoi.length})`} bodyClass="">
            {d.phanHoi.length === 0 ? <EmptyRow>Chưa có phản hồi.</EmptyRow> : (
              <ul className="divide-y divide-line">
                {d.phanHoi.map((p) => (
                  <li key={p.maPH} className="px-5 py-3 text-sm">
                    <div className="flex flex-wrap items-center gap-2">
                      <Badge tone={toneTrangThaiPH(p.trangThai)}>{TRANG_THAI_PH[p.trangThai]}</Badge>
                      <span className="font-medium">{LOAI_PH[p.loaiPH]}</span>
                      <span className="text-muted">· {p.tenSP} · {dateVi(p.ngayGui)}</span>
                    </div>
                    <p className="mt-1 text-ink-soft">{p.noiDung}</p>
                  </li>
                ))}
              </ul>
            )}
          </Panel>
          <Panel title={`Khảo sát đã nhận (${d.khaoSat.length})`} bodyClass="">
            {d.khaoSat.length === 0 ? <EmptyRow>Chưa nhận khảo sát nào.</EmptyRow> : (
              <ul className="divide-y divide-line">
                {d.khaoSat.map((k) => (
                  <li key={k.maKS} className="flex flex-wrap items-center justify-between gap-2 px-5 py-3 text-sm">
                    <span>
                      <span className="block font-medium">{k.tieuDe}</span>
                      <span className="text-muted">{MUC_DICH_KS[k.mucDich]} · gửi {dateVi(k.ngayGui)}</span>
                    </span>
                    {k.ngayHoanThanh ? <Badge tone="success">Đã trả lời {dateVi(k.ngayHoanThanh)}</Badge> : <Badge>Chưa trả lời</Badge>}
                  </li>
                ))}
              </ul>
            )}
          </Panel>
        </div>

        <Panel title={`Hóa đơn (${d.hoaDon.length})`} bodyClass="">
          {d.hoaDon.length === 0 ? <EmptyRow>Chưa có hóa đơn.</EmptyRow> : (
            <Table label="Hóa đơn của khách" head={["Số hóa đơn", "Ngày", "Kênh / cửa hàng", "Thành tiền"]}>
              {d.hoaDon.map((x) => (
                <tr key={x.maHD}>
                  <td className={`${td} font-mono text-sm`}>{x.soHoaDon}</td>
                  <td className={td}>{dateVi(x.ngayLap)}</td>
                  <td className={td}>{x.kenhBan === "ONLINE" ? "Trực tuyến" : x.tenCH ?? "Cửa hàng"}</td>
                  <td className={`${td} tabular text-right`}>{vnd(x.thanhTien)}</td>
                </tr>
              ))}
            </Table>
          )}
        </Panel>

        {d.voucher.length > 0 && (
          <Panel title={`Voucher (${d.voucher.length})`} bodyClass="">
            <ul className="divide-y divide-line">
              {d.voucher.map((v) => (
                <li key={v.maCode} className="flex flex-wrap justify-between gap-2 px-5 py-3 text-sm">
                  <span className="font-mono">{v.maCode}</span>
                  <span>Giảm {v.phanTramGiam}% · hạn {dateVi(v.hanDung)} · {v.trangThai === "CON_HAN" ? "Còn hạn" : v.trangThai === "DA_DUNG" ? "Đã dùng" : "Hết hạn"}</span>
                </li>
              ))}
            </ul>
          </Panel>
        )}
      </div>

      <Modal
        open={dialog === "lock" || dialog === "unlock"}
        onClose={() => setDialog(null)}
        role="alertdialog"
        title={dialog === "lock" ? "Khóa tài khoản khách hàng?" : "Mở khóa tài khoản?"}
        footer={
          <>
            <Button variant="ghost" onClick={() => setDialog(null)}>Hủy</Button>
            <Button
              variant={dialog === "lock" ? "danger" : "primary"}
              loading={lock.isPending}
              disabled={dialog === "lock" && !lyDo.trim()}
              onClick={() => lock.mutate(dialog === "lock")}
            >
              {dialog === "lock" ? "Khóa tài khoản" : "Mở khóa"}
            </Button>
          </>
        }
      >
        <p>{dialog === "lock" ? `${h.hoTen} sẽ bị đăng xuất và không đăng nhập được cho tới khi mở khóa.` : `${h.hoTen} sẽ đăng nhập lại được.`}</p>
        {dialog === "lock" && (
          <Field label="Lý do khóa" required className="mt-4">
            <TextInput value={lyDo} onChange={(e) => setLyDo(e.target.value)} maxLength={200} />
          </Field>
        )}
        {dialogError && <Alert tone="error" className="mt-3">{dialogError}</Alert>}
      </Modal>

      <Modal
        open={dialog === "delete"}
        onClose={() => setDialog(null)}
        role="alertdialog"
        title="Xóa khách hàng?"
        footer={
          <>
            <Button variant="ghost" onClick={() => setDialog(null)}>Hủy</Button>
            <Button variant="danger" loading={del.isPending} disabled={!lyDo.trim()} onClick={() => del.mutate()}>Xóa khách hàng</Button>
          </>
        }
      >
        <p>Hồ sơ của <strong>{h.hoTen}</strong> chuyển sang trạng thái Đã xóa và tài khoản bị khóa. Lịch sử mua hàng, phản hồi, kết quả khảo sát vẫn được giữ cho báo cáo.</p>
        <Field label="Lý do xóa" required className="mt-4">
          <TextArea value={lyDo} onChange={(e) => setLyDo(e.target.value)} maxLength={200} rows={2} className="min-h-16" />
        </Field>
        {dialogError && <Alert tone="error" className="mt-3">{dialogError}</Alert>}
      </Modal>

      <Modal
        open={dialog === "account"}
        onClose={() => setDialog(null)}
        title="Cấp tài khoản đăng nhập"
        footer={
          <>
            <Button variant="ghost" onClick={() => setDialog(null)}>Hủy</Button>
            <Button loading={grant.isPending} disabled={!/^\S{4,50}$/.test(tenDangNhap.trim())} onClick={() => grant.mutate()}>Cấp tài khoản</Button>
          </>
        }
      >
        <p>Hệ thống sinh mật khẩu tạm; khách phải đổi ở lần đăng nhập đầu.</p>
        <Field label="Tên đăng nhập" required hint="4–50 ký tự, không có khoảng trắng." className="mt-4">
          <TextInput value={tenDangNhap} onChange={(e) => setTenDangNhap(e.target.value)} autoComplete="off" spellCheck={false} />
        </Field>
        {dialogError && <Alert tone="error" className="mt-3">{dialogError}</Alert>}
      </Modal>
    </>
  );
}
