import { SESSION_IDLE_MINUTES } from "../config";

/**
 * Ước lượng thời điểm cookie phiên hết hạn, mô phỏng đúng cách ASP.NET Core gia hạn cookie trượt:
 * cookie chỉ được phát lại khi đã qua hơn nửa thời hạn (15/30 phút). Cookie là HttpOnly nên giao diện
 * không đọc được hạn thật; ước lượng này chỉ để cảnh báo và đăng xuất khi người dùng bỏ máy.
 * Lưu ở localStorage (chỉ mốc thời gian, không có bí mật) để các tab cùng ứng dụng dùng chung.
 */
const KEY = "crm.sessionClock";
const FULL = SESSION_IDLE_MINUTES * 60_000;
const HALF = FULL / 2;
const MAX_SESSION = 8 * 60 * 60_000;

interface Clock {
  issuedAt: number;
  loginAt: number | null;
}

function read(): Clock | null {
  try {
    const raw = localStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as Clock) : null;
  } catch {
    return null;
  }
}
function write(c: Clock | null) {
  try {
    if (c) localStorage.setItem(KEY, JSON.stringify(c));
    else localStorage.removeItem(KEY);
  } catch {
    /* chế độ riêng tư: bỏ qua, API vẫn trả 401 khi hết phiên */
  }
}

export const sessionClock = {
  /** Vừa đăng nhập / đăng ký / đổi mật khẩu: cookie mới. */
  started(now = Date.now()) {
    write({ issuedAt: now, loginAt: now });
  },
  /** Một request thành công: API gia hạn cookie nếu đã qua nửa thời hạn. */
  activity(now = Date.now()) {
    const c = read();
    if (!c) write({ issuedAt: now - HALF, loginAt: null }); // chưa biết: giả định xấu nhất
    else if (now - c.issuedAt > HALF) write({ ...c, issuedAt: now });
  },
  clear() {
    write(null);
  },
  /** Thời điểm dự kiến hết phiên (trượt 30 phút, tối đa 8 giờ từ lúc đăng nhập). */
  expiresAt(): { at: number; reason: "idle" | "max" } | null {
    const c = read();
    if (!c) return null;
    const idle = c.issuedAt + FULL;
    const max = c.loginAt ? c.loginAt + MAX_SESSION : Infinity;
    return max < idle ? { at: max, reason: "max" } : { at: idle, reason: "idle" };
  },
  key: KEY,
};
