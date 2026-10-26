import { useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useParams } from "react-router";
import { ArrowLeft, Check, Ticket } from "lucide-react";
import { api } from "@shared/api/client";
import { isApiError } from "@shared/api/errors";
import { PageHeader } from "@shared/layouts/PortalLayout";
import { ErrorState, Skeleton } from "@shared/pages/PageStates";
import { Alert } from "@shared/ui/Alert";
import { Button } from "@shared/ui/Button";
import { cn } from "@shared/ui/cn";
import { MUC_DICH_KS, Panel, TextArea, dateTimeVi, dateVi } from "../manager/common";
import { useMySurveys } from "./SurveysPage";

interface Question { maCauHoi: number; thuTu: number; noiDung: string; loaiCauHoi: "MOT_LUA_CHON" | "NHIEU_LUA_CHON" | "THANG_DIEM" | "TU_LUAN"; batBuoc: boolean }
interface Choice { maLC: number; maCauHoi: number; thuTu: number; noiDung: string }
interface MyAnswer { maCauHoi: number; diemSo: number | null; noiDungTuLuan: string | null; maLC: number | null }
interface SurveyContent {
  khaoSat: { maKS: number; tieuDe: string; moTa: string | null; mucDich: string; tenSP: string | null; hanTraLoi: string; phanTramVoucher: number; trangThaiCuaToi: string };
  cauHoi: Question[];
  luaChon: Choice[];
  traLoiCuaToi: MyAnswer[];
}
interface SubmitResult { thongBao: string; voucher: { maCode: string; phanTramGiam: number; hanDung: string } | null }

/** Câu trả lời đang soạn: câu chọn → danh sách mã lựa chọn; thang điểm → điểm; tự luận → chữ. */
type Draft = Record<number, { lc?: number[]; diem?: number; text?: string }>;
type AnswerRow = { maCauHoi: number; maLC?: number; diemSo?: number; noiDungTuLuan?: string };

const answered = (q: Question, d: Draft[number] | undefined) =>
  q.loaiCauHoi === "THANG_DIEM" ? !!d?.diem : q.loaiCauHoi === "TU_LUAN" ? !!d?.text?.trim() : !!d?.lc?.length;

const fromMine = (mine: MyAnswer[]): Draft => {
  const d: Draft = {};
  for (const a of mine) {
    const x = (d[a.maCauHoi] ??= {});
    if (a.maLC != null) x.lc = [...(x.lc ?? []), a.maLC];
    if (a.diemSo != null) x.diem = a.diemSo;
    if (a.noiDungTuLuan != null) x.text = a.noiDungTuLuan;
  }
  return d;
};

const SCALE = ["Rất không hài lòng", "Không hài lòng", "Bình thường", "Hài lòng", "Rất hài lòng"];

function QuestionBlock({ q, n, choices, value, onChange, readOnly, error }: {
  q: Question;
  n: number;
  choices: Choice[];
  value: Draft[number] | undefined;
  onChange: (v: Draft[number]) => void;
  readOnly: boolean;
  error?: string;
}) {
  const id = `q-${q.maCauHoi}`;
  const multi = q.loaiCauHoi === "NHIEU_LUA_CHON";
  return (
    <fieldset className={cn("rounded-md border bg-bg p-5", error ? "border-danger" : "border-line")} aria-describedby={error ? `${id}-err` : undefined} data-testid="cau-hoi">
      <legend className="sr-only">Câu {n}</legend>
      <p className="mb-1 text-xs font-semibold uppercase tracking-wider text-muted">
        Câu {n}{multi && " · chọn một hoặc nhiều"}{!q.batBuoc && " · không bắt buộc"}
      </p>
      <p className="mb-4 text-[16px] font-semibold">
        {q.noiDung}
        {q.batBuoc && <span className="ml-0.5 text-accent" aria-hidden="true">*</span>}
      </p>

      {(q.loaiCauHoi === "MOT_LUA_CHON" || multi) && (
        <div className="flex flex-col gap-2" role={multi ? "group" : "radiogroup"} aria-label={q.noiDung}>
          {choices.map((c) => {
            const on = !!value?.lc?.includes(c.maLC);
            return (
              <label key={c.maLC} className={cn("flex min-h-11 items-center gap-3 rounded-md border px-3.5 py-2 text-[15px]", on ? "border-ink bg-surface" : "border-line-strong", !readOnly && "cursor-pointer hover:border-ink")}>
                <input
                  type={multi ? "checkbox" : "radio"}
                  name={id}
                  className="size-4 accent-[var(--color-ink)]"
                  checked={on}
                  disabled={readOnly}
                  onChange={() =>
                    onChange({ lc: multi ? (on ? value!.lc!.filter((x) => x !== c.maLC) : [...(value?.lc ?? []), c.maLC]) : [c.maLC] })
                  }
                />
                {c.noiDung}
              </label>
            );
          })}
        </div>
      )}

      {q.loaiCauHoi === "THANG_DIEM" && (
        <div>
          <div role="radiogroup" aria-label={q.noiDung} className="grid grid-cols-5 gap-2 sm:max-w-md">
            {[1, 2, 3, 4, 5].map((s) => (
              <button
                key={s}
                type="button"
                role="radio"
                aria-checked={value?.diem === s}
                aria-label={`${s} – ${SCALE[s - 1]}`}
                disabled={readOnly}
                onClick={() => onChange({ diem: s })}
                className={cn(
                  "tabular h-12 rounded-md border text-lg font-semibold transition-colors disabled:cursor-default",
                  value?.diem === s ? "border-ink bg-ink text-white" : "border-line-strong",
                  !readOnly && value?.diem !== s && "hover:border-ink",
                )}
              >
                {s}
              </button>
            ))}
          </div>
          <div className="mt-1.5 flex justify-between text-xs text-muted sm:max-w-md">
            <span>{SCALE[0]}</span>
            <span>{SCALE[4]}</span>
          </div>
        </div>
      )}

      {q.loaiCauHoi === "TU_LUAN" && (
        <TextArea
          aria-label={q.noiDung}
          value={value?.text ?? ""}
          readOnly={readOnly}
          maxLength={2000}
          rows={3}
          placeholder={readOnly ? "(không trả lời)" : "Nhập câu trả lời của bạn"}
          onChange={(e) => onChange({ text: e.target.value })}
        />
      )}
      {error && <p id={`${id}-err`} className="mt-2 text-[13px] text-danger">{error}</p>}
    </fieldset>
  );
}

/** K5 (KH-4). Thực hiện khảo sát được gửi cho tôi; khảo sát đã làm thì xem lại câu trả lời. */
export function SurveyTakePage() {
  const { maKS } = useParams();
  const qc = useQueryClient();
  const list = useMySurveys();
  const q = useQuery({ queryKey: ["customer", "survey", Number(maKS)], queryFn: () => api.get<SurveyContent>(`/api/customer/surveys/${maKS}`) });
  const [draft, setDraft] = useState<Draft>({});
  const [errors, setErrors] = useState<Record<number, string>>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [result, setResult] = useState<SubmitResult | null>(null);

  const submit = useMutation({
    mutationFn: (traLoi: AnswerRow[]) =>
      api.post<SubmitResult>(`/api/customer/surveys/${maKS}/submit`, { traLoi }),
    onSuccess: (r) => {
      setResult(r);
      void qc.invalidateQueries({ queryKey: ["customer"] });
      window.scrollTo({ top: 0 });
    },
    onError: (e) => setFormError(isApiError(e) ? e.userMessage : "Đã có lỗi xảy ra."),
  });

  const back = (
    <Link to="/customer/surveys" className="mb-3 inline-flex items-center gap-1.5 text-sm font-medium text-ink-soft hover:text-ink">
      <ArrowLeft className="size-4" aria-hidden="true" /> Về danh sách khảo sát
    </Link>
  );

  if (q.isError)
    return (
      <>
        {back}
        {isApiError(q.error) && q.error.status === 404
          ? <Alert tone="warning" title="Không tìm thấy khảo sát">Khảo sát không tồn tại hoặc không được gửi tới tài khoản của bạn.</Alert>
          : <ErrorState error={q.error} onRetry={() => q.refetch()} />}
      </>
    );
  if (q.isPending) return <Skeleton className="h-96" />;

  const { khaoSat: ks, cauHoi, luaChon } = q.data;
  const done = ks.trangThaiCuaToi === "DA_HOAN_THANH";
  const meta = list.data?.find((k) => k.maKS === ks.maKS);
  const open = !done && (meta ? meta.coTheThucHien : new Date(ks.hanTraLoi) >= new Date());
  const readOnly = done || !open || !!result;
  const values = done ? fromMine(q.data.traLoiCuaToi) : draft;
  const answeredCount = cauHoi.filter((c) => answered(c, values[c.maCauHoi])).length;

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    setFormError(null);
    const errs: Record<number, string> = {};
    for (const c of cauHoi) if (c.batBuoc && !answered(c, draft[c.maCauHoi])) errs[c.maCauHoi] = "Câu này bắt buộc trả lời.";
    setErrors(errs);
    const first = Object.keys(errs)[0];
    if (first) {
      setFormError(`Còn ${Object.keys(errs).length} câu bắt buộc chưa trả lời.`);
      document.getElementById(`cau-${first}`)?.scrollIntoView({ block: "center" });
      return;
    }
    const traLoi = cauHoi.flatMap((c): AnswerRow[] => {
      const d = draft[c.maCauHoi];
      if (!answered(c, d)) return [];
      if (c.loaiCauHoi === "THANG_DIEM") return [{ maCauHoi: c.maCauHoi, diemSo: d!.diem! }];
      if (c.loaiCauHoi === "TU_LUAN") return [{ maCauHoi: c.maCauHoi, noiDungTuLuan: d!.text!.trim() }];
      return d!.lc!.map((maLC) => ({ maCauHoi: c.maCauHoi, maLC }));
    });
    if (!traLoi.length) return setFormError("Bạn chưa trả lời câu nào.");
    submit.mutate(traLoi);
  };

  return (
    <>
      {back}
      <PageHeader
        title={ks.tieuDe}
        description={[MUC_DICH_KS[ks.mucDich] ?? ks.mucDich, ks.tenSP && `Sản phẩm: ${ks.tenSP}`, `Hạn trả lời ${dateTimeVi(ks.hanTraLoi)}`].filter(Boolean).join(" · ")}
      />
      <div className="flex max-w-3xl flex-col gap-4">
        {result ? (
          <Alert tone="success" title="Cảm ơn bạn đã hoàn thành khảo sát!">
            <p>{result.thongBao}</p>
            {result.voucher && (
              <div className="mt-3 flex flex-wrap items-center gap-3 rounded-md border border-success/30 bg-bg p-3 text-ink" data-testid="voucher-moi">
                <Ticket className="size-6 shrink-0" aria-hidden="true" />
                <span className="tabular text-2xl font-bold">-{result.voucher.phanTramGiam}%</span>
                <span className="flex flex-col">
                  <span className="font-mono font-semibold">{result.voucher.maCode}</span>
                  <span className="text-sm text-muted">Dùng đến {dateVi(result.voucher.hanDung)} · xem lại trong mục Khảo sát → Voucher</span>
                </span>
              </div>
            )}
          </Alert>
        ) : done ? (
          <Alert tone="success" title="Bạn đã hoàn thành khảo sát này">Dưới đây là câu trả lời bạn đã gửi.</Alert>
        ) : !open ? (
          <Alert tone="warning" title="Khảo sát đã đóng">Khảo sát đã hết hạn hoặc đã được cửa hàng đóng, không thể trả lời nữa.</Alert>
        ) : (
          <>
            {ks.moTa && <p className="text-[15px] text-ink-soft">{ks.moTa}</p>}
            {ks.phanTramVoucher > 0 && (
              <Alert tone="info">Hoàn thành khảo sát để nhận ngay voucher giảm <strong>{ks.phanTramVoucher}%</strong>.</Alert>
            )}
          </>
        )}

        <form onSubmit={onSubmit} noValidate className="flex flex-col gap-4" aria-label="Nội dung khảo sát">
          {cauHoi.map((c, i) => (
            <div key={c.maCauHoi} id={`cau-${c.maCauHoi}`}>
              <QuestionBlock
                q={c}
                n={i + 1}
                choices={luaChon.filter((l) => l.maCauHoi === c.maCauHoi)}
                value={values[c.maCauHoi]}
                readOnly={readOnly}
                error={errors[c.maCauHoi]}
                onChange={(v) => {
                  setDraft((d) => ({ ...d, [c.maCauHoi]: v }));
                  setErrors(({ [c.maCauHoi]: _, ...rest }) => rest);
                  setFormError(null);
                }}
              />
            </div>
          ))}
          {!readOnly && (
            <Panel>
              {formError && <Alert tone="error" className="mb-4">{formError}</Alert>}
              <div className="flex flex-wrap items-center justify-between gap-3">
                <span className="tabular text-sm text-muted">Đã trả lời {answeredCount}/{cauHoi.length} câu</span>
                <Button type="submit" loading={submit.isPending} icon={<Check className="size-4" aria-hidden="true" />}>Gửi bài khảo sát</Button>
              </div>
            </Panel>
          )}
        </form>
        {result && (
          <div><Link to="/customer/surveys" className="font-semibold underline underline-offset-4">Về danh sách khảo sát</Link></div>
        )}
      </div>
    </>
  );
}
