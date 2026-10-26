import { useMemo, useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useSearchParams } from "react-router";
import { MessageSquareReply, Star } from "lucide-react";
import { api } from "@shared/api/client";
import { isApiError } from "@shared/api/errors";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { Alert } from "@shared/ui/Alert";
import { Button } from "@shared/ui/Button";
import { cn } from "@shared/ui/cn";
import { Field, Select } from "@shared/ui/Field";
import { useToast } from "@shared/ui/Toast";
import { Badge, EmptyRow, LOAI_PH, Panel, TextArea, dateTimeVi, dateVi, toneTrangThaiPH, useProducts } from "../manager/common";

interface MyFeedback {
  maPH: number;
  maSP: number;
  tenSP: string;
  loaiPH: string;
  diemDanhGia: number;
  noiDung: string;
  ngayGui: string;
  trangThai: string;
  noiDungTraLoi: string | null;
  ngayTraLoi: string | null;
}
interface PurchaseLines { chiTiet: { maSP: number; tenSP: string }[] }

/** Trạng thái theo cách khách hiểu (khác nhãn nội bộ của nhân viên). */
const TRANG_THAI_KH: Record<string, string> = { MOI: "Đã gửi", DANG_XU_LY: "Đang xử lý", DA_XU_LY: "Đã trả lời" };
const DIEM = ["Rất tệ", "Chưa tốt", "Bình thường", "Tốt", "Rất tốt"];
const MAX = 2000;

function Stars({ value, size = "size-4" }: { value: number; size?: string }) {
  return (
    <span className="inline-flex" aria-label={`${value} trên 5 sao`}>
      {Array.from({ length: 5 }, (_, i) => (
        <Star key={i} className={cn(size, i < value ? "fill-ink text-ink" : "text-line-strong")} aria-hidden="true" />
      ))}
    </span>
  );
}

/** K6–K7 (KH-3). Gửi phản hồi về sản phẩm và theo dõi câu trả lời của cửa hàng. */
export function FeedbackPage() {
  const qc = useQueryClient();
  const toast = useToast();
  const [params] = useSearchParams();
  const products = useProducts();
  // Sản phẩm khách đã mua được đưa lên đầu danh sách chọn (đọc lịch sử mua hàng của chính khách).
  const purchases = useQuery({ queryKey: ["customer", "purchases"], queryFn: () => api.get<PurchaseLines>("/api/customer/purchases") });
  const list = useQuery({ queryKey: ["customer", "feedback"], queryFn: () => api.get<MyFeedback[]>("/api/customer/feedback") });

  const [maSP, setMaSP] = useState(params.get("maSP") ?? "");
  const [loaiPH, setLoaiPH] = useState("");
  const [diem, setDiem] = useState(0);
  const [noiDung, setNoiDung] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);

  const clear = (k: string) => setErrors(({ [k]: _, ...rest }) => rest);

  const { bought, others } = useMemo(() => {
    const ids = new Set(purchases.data?.chiTiet.map((c) => c.maSP));
    // Sản phẩm sắp ra mắt chưa bán nên chưa nhận phản hồi.
    const all = (products.data ?? []).filter((p) => p.trangThai !== "SAP_RA_MAT");
    return { bought: all.filter((p) => ids.has(p.maSP)), others: all.filter((p) => !ids.has(p.maSP)) };
  }, [products.data, purchases.data]);

  const send = useMutation({
    mutationFn: () => api.post<{ maPH: number }>("/api/customer/feedback", { maSP: Number(maSP), loaiPH, diemDanhGia: diem, noiDung: noiDung.trim() }),
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ["customer"] });
      setMaSP("");
      setLoaiPH("");
      setDiem(0);
      setNoiDung("");
      toast("success", "Đã gửi phản hồi. Cảm ơn bạn đã góp ý!");
    },
    onError: (e) => setFormError(isApiError(e) ? e.userMessage : "Đã có lỗi xảy ra."),
  });

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setFormError(null);
    const errs: Record<string, string> = {};
    if (!maSP) errs.maSP = "Chọn sản phẩm cần phản hồi.";
    if (!loaiPH) errs.loaiPH = "Chọn loại phản hồi.";
    if (!diem) errs.diem = "Chấm điểm từ 1 đến 5 sao.";
    if (!noiDung.trim()) errs.noiDung = "Nhập nội dung phản hồi.";
    setErrors(errs);
    if (Object.keys(errs).length) return setFormError("Vui lòng kiểm tra các ô được đánh dấu.");
    send.mutate();
  };

  return (
    <>
      <PageHeader title="Phản hồi về sản phẩm" description="Khen, góp ý hoặc khiếu nại về sản phẩm. Cửa hàng sẽ tiếp nhận và trả lời tại đây." />
      <div className="grid items-start gap-5 xl:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
        <Panel title="Gửi phản hồi mới">
          <form onSubmit={submit} noValidate className="flex flex-col gap-5" aria-label="Gửi phản hồi mới">
            {formError && <Alert tone="error">{formError}</Alert>}
            <Field label="Sản phẩm" required error={errors.maSP} hint={bought.length ? "Sản phẩm bạn đã mua được xếp lên đầu." : undefined}>
              <Select value={maSP} onChange={(e) => { setMaSP(e.target.value); clear("maSP"); }} disabled={products.isPending}>
                <option value="">{products.isError ? "Không tải được danh sách sản phẩm" : "Chọn sản phẩm"}</option>
                {bought.length > 0 && (
                  <optgroup label="Sản phẩm bạn đã mua">
                    {bought.map((p) => <option key={p.maSP} value={p.maSP}>{p.tenSP}</option>)}
                  </optgroup>
                )}
                <optgroup label={bought.length ? "Sản phẩm khác" : "Tất cả sản phẩm"}>
                  {others.map((p) => <option key={p.maSP} value={p.maSP}>{p.tenSP}</option>)}
                </optgroup>
              </Select>
            </Field>
            <div className="flex flex-col gap-1.5">
              <span id="loai-label" className="text-sm font-medium">Loại phản hồi<span className="ml-0.5 text-accent" aria-hidden="true">*</span></span>
              <div role="radiogroup" aria-labelledby="loai-label" className="grid grid-cols-3 gap-2 sm:max-w-md">
                {Object.entries(LOAI_PH).map(([k, l]) => (
                  <button
                    key={k}
                    type="button"
                    role="radio"
                    aria-checked={loaiPH === k}
                    onClick={() => { setLoaiPH(k); clear("loaiPH"); }}
                    className={cn("h-11 rounded-md border text-[15px] transition-colors", loaiPH === k ? "border-ink bg-ink font-semibold text-white" : "border-line-strong hover:border-ink")}
                  >
                    {l}
                  </button>
                ))}
              </div>
              {errors.loaiPH && <p className="text-[13px] text-danger">{errors.loaiPH}</p>}
            </div>
            <div className="flex flex-col gap-1.5">
              <span id="diem-label" className="text-sm font-medium">Đánh giá<span className="ml-0.5 text-accent" aria-hidden="true">*</span></span>
              <div className="flex items-center gap-3">
                <div role="radiogroup" aria-labelledby="diem-label" className="flex">
                  {DIEM.map((l, i) => (
                    <button
                      key={i}
                      type="button"
                      role="radio"
                      aria-checked={diem === i + 1}
                      aria-label={`${i + 1} sao – ${l}`}
                      onClick={() => { setDiem(i + 1); clear("diem"); }}
                      className="grid size-10 place-items-center rounded-md hover:bg-surface"
                    >
                      <Star className={cn("size-6", i < diem ? "fill-ink text-ink" : "text-line-strong")} aria-hidden="true" />
                    </button>
                  ))}
                </div>
                <span className="text-sm text-muted" aria-live="polite">{diem ? DIEM[diem - 1] : "Chưa chấm"}</span>
              </div>
              {errors.diem && <p className="text-[13px] text-danger">{errors.diem}</p>}
            </div>
            <Field label="Nội dung" required error={errors.noiDung} hint={`${noiDung.length}/${MAX} ký tự`}>
              <TextArea value={noiDung} onChange={(e) => { setNoiDung(e.target.value); clear("noiDung"); }} maxLength={MAX} rows={5} placeholder="Chia sẻ trải nghiệm của bạn về chất liệu, kích cỡ, độ bền…" />
            </Field>
            <div>
              <Button type="submit" loading={send.isPending}>Gửi phản hồi</Button>
            </div>
          </form>
        </Panel>

        <Panel title="Phản hồi của tôi" bodyClass="">
          {list.isError ? (
            <div className="p-5"><ErrorState error={list.error} onRetry={() => list.refetch()} /></div>
          ) : list.isPending ? (
            <div className="p-5"><Skeleton className="h-40" /></div>
          ) : list.data.length === 0 ? (
            <EmptyRow>Bạn chưa gửi phản hồi nào.</EmptyRow>
          ) : (
            <ul className="divide-y divide-line" aria-label="Phản hồi của tôi">
              {list.data.map((p) => (
                <li key={p.maPH} className="flex flex-col gap-2 px-5 py-4">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <span className="font-semibold">{p.tenSP}</span>
                    <Badge tone={toneTrangThaiPH(p.trangThai)}>{TRANG_THAI_KH[p.trangThai] ?? p.trangThai}</Badge>
                  </div>
                  <div className="flex flex-wrap items-center gap-3 text-sm text-muted">
                    <Badge>{LOAI_PH[p.loaiPH] ?? p.loaiPH}</Badge>
                    <Stars value={p.diemDanhGia} />
                    <span className="tabular">{dateTimeVi(p.ngayGui)}</span>
                  </div>
                  <p className="whitespace-pre-line text-[15px]">{p.noiDung}</p>
                  {p.noiDungTraLoi && (
                    <div className="mt-1 rounded-md border border-line bg-surface p-3 text-[15px]">
                      <p className="mb-1 flex items-center gap-1.5 text-sm font-semibold">
                        <MessageSquareReply className="size-4" aria-hidden="true" /> Uniqlo trả lời · <span className="tabular font-normal text-muted">{dateVi(p.ngayTraLoi)}</span>
                      </p>
                      <p className="whitespace-pre-line">{p.noiDungTraLoi}</p>
                    </div>
                  )}
                </li>
              ))}
            </ul>
          )}
        </Panel>
      </div>
    </>
  );
}
