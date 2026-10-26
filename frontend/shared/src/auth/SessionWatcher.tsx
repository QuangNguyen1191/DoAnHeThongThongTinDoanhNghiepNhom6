import { useEffect, useState } from "react";
import { SESSION_WARNING_MINUTES } from "../config";
import { Button } from "../ui/Button";
import { Modal } from "../ui/Modal";
import { useAuth } from "./AuthProvider";
import { sessionClock } from "./sessionClock";

/**
 * Hết phiên do không thao tác: cảnh báo trước 2 phút, hết giờ thì đăng xuất và về /login?het-phien=1.
 * Phiên vẫn được API kiểm ở mọi request (401 → cùng luồng), đây chỉ là lớp trải nghiệm.
 */
export function SessionWatcher() {
  const { session, expire, refresh, logout } = useAuth();
  const [left, setLeft] = useState<number | null>(null);
  const [reason, setReason] = useState<"idle" | "max">("idle");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!session) {
      setLeft(null);
      return;
    }
    const tick = () => {
      const exp = sessionClock.expiresAt();
      if (!exp) return setLeft(null);
      const ms = exp.at - Date.now();
      setReason(exp.reason);
      if (ms <= 0) {
        setLeft(null);
        void expire();
      } else setLeft(ms <= SESSION_WARNING_MINUTES * 60_000 ? ms : null);
    };
    tick();
    const id = window.setInterval(tick, 1000);
    const onStorage = (e: StorageEvent) => e.key === sessionClock.key && tick();
    window.addEventListener("storage", onStorage);
    return () => {
      window.clearInterval(id);
      window.removeEventListener("storage", onStorage);
    };
  }, [session, expire]);

  const secs = left === null ? 0 : Math.ceil(left / 1000);
  const mmss = `${Math.floor(secs / 60)}:${String(secs % 60).padStart(2, "0")}`;

  return (
    <Modal
      open={left !== null}
      role="alertdialog"
      onClose={() => {}}
      title="Phiên làm việc sắp kết thúc"
      footer={
        <>
          <Button variant="secondary" onClick={() => void logout()}>
            Đăng xuất
          </Button>
          {reason === "idle" && (
            <Button
              loading={busy}
              onClick={async () => {
                setBusy(true);
                try {
                  await refresh();
                } finally {
                  setBusy(false);
                }
              }}
            >
              Tiếp tục làm việc
            </Button>
          )}
        </>
      }
    >
      {reason === "idle" ? (
        <p>
          Bạn đã không thao tác trong một thời gian. Để bảo vệ dữ liệu khách hàng, hệ thống sẽ tự đăng xuất sau{" "}
          <strong className="tabular text-ink">{mmss}</strong>.
        </p>
      ) : (
        <p>
          Phiên đăng nhập đã gần đạt thời hạn tối đa 8 giờ và sẽ kết thúc sau <strong className="tabular text-ink">{mmss}</strong>.
          Hãy lưu công việc rồi đăng nhập lại.
        </p>
      )}
    </Modal>
  );
}
