// Kiểm thử đầu cuối: trang đăng nhập chung (Khách hàng, Quản lý) và trang đăng nhập Admin riêng, đăng xuất, hết phiên,
// phân quyền theo cổng/quyền, 401/403/428, quên và đặt lại mật khẩu, lịch sử mua hàng.
// Cần: API chạy ở 5000/5001 (Development) trên CSDL có dữ liệu mẫu (script 08) và script 18 + 2 máy chủ Vite (npm run dev:crm, npm run dev:admin).
// Chạy: npm i -D playwright && npx playwright install chromium && node tests/e2e/dang-nhap-phan-quyen.cjs
// LƯU Ý: kịch bản có ghi dữ liệu (khóa/mở ql.lan, đặt mật khẩu tạm cho kh.chau, đăng ký khách mới) – chỉ chạy trên CSDL thử nghiệm.
// Giới hạn 30 lần gọi đăng nhập / 15 phút / IP: khởi động lại API giữa các lần chạy liên tiếp.
// Thư đặt lại mật khẩu được đọc từ thư mục .mail của API (Email:PickupDirectory ở Development); đổi bằng biến MAIL_DIR.
const { chromium } = require("playwright");
const CRM = "http://localhost:5173", ADM = "http://localhost:5174";
const SHOTS = require("node:path").join(__dirname, "anh-chup") + "/";
require("node:fs").mkdirSync(SHOTS, { recursive: true });
const MAIL_DIR = process.env.MAIL_DIR || require("node:path").join(__dirname, "../../../backend/src/CrmUniqlo.Api/.mail");
const fs = require("fs");

/** Lấy mã đặt lại mật khẩu trong thư mới nhất gửi tới `to` (API ở Development ghi thư ra tệp .eml). */
function latestResetToken(to) {
  if (!fs.existsSync(MAIL_DIR)) return null;
  const files = fs.readdirSync(MAIL_DIR).map((f) => MAIL_DIR + "/" + f).sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
  for (const f of files) {
    const raw = fs.readFileSync(f, "utf8");
    if (!raw.toLowerCase().includes(to.toLowerCase())) continue;
    let body = raw.slice(raw.search(/\r?\n\r?\n/));
    if (/Content-Transfer-Encoding: base64/i.test(raw)) body = Buffer.from(body.replace(/\s+/g, ""), "base64").toString("utf8");
    else body = body.replace(/=\r?\n/g, "").replace(/=3D/gi, "=");
    const m = body.match(/token=([A-Za-z0-9_-]{43})/);
    if (m) return m[1];
  }
  return null;
}
const results = [];
const ok = (name, cond, extra = "") => { results.push(`${cond ? "PASS" : "FAIL"}  ${name}${extra ? "  — " + extra : ""}`); };

async function fill(page, u, p) {
  await page.locator("input[autocomplete=username]").fill(u);
  await page.locator("input[autocomplete=current-password]").fill(p);
  await page.getByRole("button", { name: /^Đăng nhập( quản trị)?$/i }).click();
}

(async () => {
  const browser = await chromium.launch();
  const newCtx = (opts = {}) => browser.newContext({ locale: "vi-VN", viewport: { width: 1440, height: 900 }, ...opts });
  const errors = [];
  const watch = (p) => p.on("pageerror", (e) => errors.push(e.message));

  // 1. Trang đăng nhập + lỗi sai thông tin
  let ctx = await newCtx(); let page = await ctx.newPage(); watch(page);
  await page.goto(CRM + "/login");
  await page.waitForSelector("h1");
  await page.waitForTimeout(600);
  await page.screenshot({ path: SHOTS + "01_login_desktop.png" });
  ok("Trang đăng nhập chung không còn ô tài khoản demo", (await page.getByText("Tài khoản demo").count()) === 0);
  ok("Trang đăng nhập chung không nhắc đến khu vực Quản trị", (await page.getByText(/Quản trị hệ thống|Admin/).count()) === 0);
  await fill(page, "admin.it", "Demo@2026");
  await page.getByRole("alert").first().waitFor();
  ok("admin.it đăng nhập ở trang chung → bị từ chối như sai mật khẩu", /Sai tên đăng nhập hoặc mật khẩu/.test(await page.locator("#login-error").innerText()) && page.url().startsWith(CRM + "/login"));
  await fill(page, "ql.lan", "SaiMatKhau1");
  await page.getByRole("alert").first().waitFor();
  const alertText = await page.locator("#login-error").innerText();
  ok("Sai mật khẩu → thông báo chung", /Sai tên đăng nhập hoặc mật khẩu/.test(alertText), alertText.replace(/\n/g, " "));
  ok("Sai mật khẩu → xóa ô mật khẩu, giữ tên", (await page.locator("input[autocomplete=current-password]").inputValue()) === "" && (await page.locator("input[autocomplete=username]").inputValue()) === "ql.lan");
  await page.screenshot({ path: SHOTS + "02_login_error.png" });
  await fill(page, "khongtontai", "abc12345");
  await page.waitForTimeout(800);
  ok("Tên không tồn tại → cùng thông báo", /Sai tên đăng nhập hoặc mật khẩu/.test(await page.locator("#login-error").innerText()));
  await fill(page, "kh.quyen", "Demo@2026");
  await page.waitForTimeout(800);
  const locked = await page.locator("#login-error").innerText();
  ok("Tài khoản bị khóa → thông báo khóa (403)", /khóa/i.test(locked), locked.replace(/\n/g, " "));
  await fill(page, "kh.nam", "Demo@2026");
  await page.waitForTimeout(800);
  ok("Hồ sơ đã xóa → không vào được", page.url().includes("/login"), (await page.locator("#login-error").innerText()).replace(/\n/g, " "));

  // 2. Quản lý: đăng nhập, điều hướng, chặn URL khác
  await fill(page, "ql.lan", "Demo@2026");
  await page.waitForURL(CRM + "/manager");
  await page.getByText("Khách hàng đang hoạt động").waitFor();
  await page.waitForTimeout(400);
  await page.screenshot({ path: SHOTS + "03_manager_home.png" });
  ok("ql.lan → /manager, dashboard có số liệu thật", (await page.locator("text=Khách hàng đăng ký gần đây").count()) === 1);
  await page.goto(CRM + "/customer/profile");
  await page.getByText("Bạn không có quyền truy cập trang này").waitFor();
  ok("ql.lan gõ URL /customer/profile → 403", true);
  await page.screenshot({ path: SHOTS + "04_forbidden.png" });
  await page.goto(CRM + "/admin/accounts");
  await page.getByText("Không tìm thấy trang").waitFor();
  ok("ql.lan gõ URL /admin/accounts ở web-crm → 404 (không có khu vực Quản trị)", true);
  await page.goto(CRM + "/login");
  await page.waitForURL(CRM + "/manager");
  ok("Đang đăng nhập mà vào /login → về /manager", true);
  // Đăng xuất
  await page.getByRole("button", { name: "Đăng xuất" }).first().click();
  await page.getByRole("dialog").getByRole("button", { name: "Đăng xuất" }).click();
  await page.waitForURL(/\/login\?da-dang-xuat=1/);
  ok("Đăng xuất → /login?da-dang-xuat=1", true);
  await page.goBack();
  await page.waitForTimeout(800);
  ok("Back sau đăng xuất không hiện dữ liệu", !page.url().endsWith("/manager") && (await page.locator("text=Khách hàng đăng ký gần đây").count()) === 0, page.url());
  const me = await page.evaluate(() => fetch("/api/auth/me").then((r) => r.status));
  ok("Sau đăng xuất /api/auth/me → 401", me === 401);

  // 3. NV CSKH: menu theo quyền + chặn route thiếu quyền
  await page.goto(CRM + "/manager/reports");
  await page.waitForURL(/\/login\?quay-lai=/);
  ok("Chưa đăng nhập vào /manager/reports → /login?quay-lai", true);
  await fill(page, "cskh.hoa", "Demo@2026");
  await page.waitForURL(CRM + "/manager/reports");
  await page.getByText("Không có quyền truy cập").waitFor();
  ok("cskh.hoa quay lại /manager/reports → trạng thái 403", true);
  ok("cskh.hoa không thấy menu Báo cáo", (await page.getByRole("navigation").getByRole("link", { name: "Báo cáo" }).count()) === 0);
  await page.goto(CRM + "/manager");
  await page.getByText("Khảo sát đang mở").waitFor();
  await page.waitForTimeout(400);
  await page.screenshot({ path: SHOTS + "05_cskh_home.png" });
  ok("cskh.hoa dashboard: khối thiếu quyền hiện lý do", (await page.getByText("Vai trò của bạn không có quyền xem mục này.").count()) >= 1);
  await ctx.close();

  // 4. Khách hàng
  ctx = await newCtx({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true }); page = await ctx.newPage(); watch(page);
  await page.goto(CRM + "/login");
  await page.waitForSelector("h1");
  await page.waitForTimeout(600);
  await page.screenshot({ path: SHOTS + "06_login_mobile.png", fullPage: true });
  await fill(page, "kh.an", "Demo@2026");
  await page.waitForURL(CRM + "/customer");
  await page.getByText("Hạng thành viên").waitFor();
  await page.screenshot({ path: SHOTS + "07_customer_home_mobile.png", fullPage: true });
  ok("kh.an → /customer", true);
  await page.goto(CRM + "/manager/customers");
  await page.getByText("Bạn không có quyền truy cập trang này").waitFor();
  ok("kh.an gõ URL /manager/customers → 403", true);
  const apiAdmin = await page.evaluate(() => fetch("/api/manager/customers").then((r) => r.status));
  ok("Cookie khách gọi API Quản lý → 403", apiAdmin === 403, String(apiAdmin));
  // Lịch sử mua hàng không còn là trang riêng (ngoài 5 chức năng khách hàng): API được dùng để đưa sản phẩm đã mua lên đầu form phản hồi.
  await page.goto(CRM + "/customer/feedback");
  await page.locator("main optgroup[label='Sản phẩm bạn đã mua']").waitFor({ state: "attached" });
  await page.screenshot({ path: SHOTS + "15_feedback_mobile.png", fullPage: true });
  ok("Lịch sử mua hàng (/api/customer/purchases) → sản phẩm đã mua trong form phản hồi", (await page.locator("main optgroup[label='Sản phẩm bạn đã mua'] option").count()) > 0);
  await ctx.close();

  // 5. Admin: trang đăng nhập riêng ở web-admin
  ctx = await newCtx(); page = await ctx.newPage(); watch(page);
  await page.goto(ADM + "/admin/audit-log");
  await page.waitForURL(ADM + "/login?quay-lai=%2Fadmin%2Faudit-log");
  await page.waitForSelector("h1");
  ok("web-admin chưa đăng nhập → /login của chính web-admin", (await page.locator("h1").innerText()) === "Đăng nhập quản trị");
  await page.waitForTimeout(600);
  await page.screenshot({ path: SHOTS + "08_admin_login_desktop.png" });
  ok("Trang đăng nhập Admin không có đăng ký thành viên", (await page.getByText("Đăng ký thành viên").count()) === 0);
  for (const u of ["kh.an", "ql.lan"]) {
    await fill(page, u, "Demo@2026");
    await page.getByRole("alert").first().waitFor();
    await page.waitForTimeout(300);
    ok(`${u} đăng nhập ở trang Admin → bị từ chối như sai mật khẩu`, /Sai tên đăng nhập hoặc mật khẩu/.test(await page.locator("#login-error").innerText()) && page.url().includes("/login"));
  }
  await page.screenshot({ path: SHOTS + "09_admin_login_error.png" });
  await fill(page, "admin.it", "Demo@2026");
  await page.waitForURL(ADM + "/admin/audit-log");
  ok("admin.it đăng nhập ở trang Admin → quay lại /admin/audit-log", true);
  await page.goto(ADM + "/admin");
  await page.getByText("Tổng tài khoản").waitFor();
  await page.waitForTimeout(400);
  await page.screenshot({ path: SHOTS + "10_admin_home.png" });
  await page.goto(ADM + "/admin/roles");
  await page.getByRole("heading", { name: "Vai trò và quyền", exact: true }).waitFor();
  ok("admin.it vào /admin/roles", true);
  // Cùng trình duyệt: phiên Quản lý ở web-crm và phiên Admin ở web-admin không ghi đè nhau (cookie riêng).
  const crmTab = await ctx.newPage(); watch(crmTab);
  await crmTab.goto(CRM + "/login");
  await fill(crmTab, "ql.lan", "Demo@2026");
  await crmTab.waitForURL(CRM + "/manager");
  const adminMe = await page.evaluate(() => fetch("/api/auth/me").then((r) => r.json()).then((j) => j.tenDangNhap));
  const crmMe = await crmTab.evaluate(() => fetch("/api/auth/me").then((r) => r.json()).then((j) => j.tenDangNhap));
  ok("Admin và Quản lý đăng nhập cùng trình duyệt, 2 phiên độc lập", adminMe === "admin.it" && crmMe === "ql.lan", `${adminMe} / ${crmMe}`);
  await crmTab.close();
  await page.getByRole("button", { name: "Đăng xuất" }).first().click();
  await page.getByRole("dialog").getByRole("button", { name: "Đăng xuất" }).click();
  await page.waitForURL(ADM + "/login?da-dang-xuat=1");
  ok("Đăng xuất ở web-admin → /login của web-admin", true);
  await ctx.close();

  // Mobile
  ctx = await newCtx({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true }); page = await ctx.newPage(); watch(page);
  await page.goto(ADM + "/login");
  await page.waitForSelector("h1");
  await page.waitForTimeout(600);
  await page.screenshot({ path: SHOTS + "11_admin_login_mobile.png", fullPage: true });
  await ctx.close();

  // 6. QTV tài khoản: thiếu quyền phân quyền
  ctx = await newCtx(); page = await ctx.newPage(); watch(page);
  await page.goto(ADM + "/login");
  await fill(page, "it.mai", "Demo@2026");
  await page.waitForURL(ADM + "/admin");
  await page.goto(ADM + "/admin/roles");
  await page.getByText("Không có quyền truy cập").waitFor();
  ok("it.mai /admin/roles → 403 trong khung", (await page.getByRole("navigation").getByRole("link", { name: "Vai trò và quyền" }).count()) === 0);
  await ctx.close();
  // Quản lý đã đăng nhập ở web-crm gõ URL web-admin → phải đăng nhập Admin, API Admin trả 401
  ctx = await newCtx(); page = await ctx.newPage(); watch(page);
  await page.goto(CRM + "/login");
  await fill(page, "ql.lan", "Demo@2026");
  await page.waitForURL(CRM + "/manager");
  const qlPage = page;
  page = await ctx.newPage(); watch(page);
  await page.goto(ADM + "/admin");
  await page.waitForURL(/5174\/login\?quay-lai=/);
  ok("ql.lan gõ URL web-admin → trang đăng nhập Admin, không vào được", true);
  const st = await page.evaluate(() => fetch("/api/admin/accounts").then((r) => r.status));
  ok("Phiên Quản lý không dùng được ở /api/admin (401)", st === 401, String(st));
  await page.close();
  page = qlPage;

  // 7. Bị khóa giữa phiên → 401 → /login?het-phien=1
  const adminCtx = await newCtx(); const ap = await adminCtx.newPage();
  await ap.goto(ADM + "/login"); await fill(ap, "admin.it", "Demo@2026"); await ap.waitForURL(ADM + "/admin");
  const lockRes = await ap.evaluate(async () => {
    const t = (await (await fetch("/api/auth/antiforgery")).json()).xsrfToken;
    return (await fetch("/api/admin/accounts/3/lock", { method: "PATCH", headers: { "Content-Type": "application/json", "X-XSRF-TOKEN": t }, body: JSON.stringify({ khoa: true, lyDo: "Kiểm thử E2E" }) })).status;
  });
  await page.goto(CRM + "/manager");
  await page.waitForURL(/\/login\?het-phien=1/, { timeout: 8000 }).catch(() => {});
  ok("Khóa tài khoản đang đăng nhập → request kế tiếp về /login?het-phien=1", page.url().includes("het-phien=1"), `lock=${lockRes} url=${page.url()}`);
  await page.screenshot({ path: SHOTS + "12_session_expired.png" });
  await ap.evaluate(async () => {
    const t = (await (await fetch("/api/auth/antiforgery")).json()).xsrfToken;
    await fetch("/api/admin/accounts/3/lock", { method: "PATCH", headers: { "Content-Type": "application/json", "X-XSRF-TOKEN": t }, body: JSON.stringify({ khoa: false }) });
  });

  // 8. Mật khẩu tạm → bắt buộc đổi (428)
  const tmp = await ap.evaluate(async () => {
    const t = (await (await fetch("/api/auth/antiforgery")).json()).xsrfToken;
    const accs = await (await fetch("/api/admin/accounts?tuKhoa=kh.chau")).json();
    const acc = accs.find((a) => a.tenDangNhap === "kh.chau");
    const r = await fetch(`/api/admin/accounts/${acc.maTK}/reset-password`, { method: "POST", headers: { "X-XSRF-TOKEN": t } });
    return (await r.json()).matKhauTam;
  });
  await page.goto(CRM + "/login");
  await fill(page, "kh.chau", tmp);
  await page.waitForURL(/\/change-password\?batbuoc=1/);
  await page.screenshot({ path: SHOTS + "13_change_password_forced.png" });
  await page.goto(CRM + "/customer");
  await page.waitForURL(/\/change-password\?batbuoc=1/);
  ok("Mật khẩu tạm → mọi route khu vực chuyển về /change-password", true);
  const s428 = await page.evaluate(() => fetch("/api/customer/profile").then((r) => r.status));
  ok("API nghiệp vụ khi phải đổi mật khẩu → 428", s428 === 428, String(s428));
  await page.locator("input[autocomplete=current-password]").fill(tmp);
  await page.locator("input[autocomplete=new-password]").nth(0).fill("Chau@2026x");
  await page.locator("input[autocomplete=new-password]").nth(1).fill("Chau@2026x");
  await page.getByRole("button", { name: "Lưu và tiếp tục" }).click();
  await page.waitForURL(CRM + "/customer");
  ok("Đổi mật khẩu xong → vào /customer", true);
  await adminCtx.close(); await ctx.close();

  // 9. Đăng ký
  ctx = await newCtx(); page = await ctx.newPage(); watch(page);
  await page.goto(CRM + "/register");
  await page.getByText("Áo khoác").first().waitFor();
  await page.waitForTimeout(600);
  await page.screenshot({ path: SHOTS + "14_register.png", fullPage: true });
  await page.getByRole("button", { name: "Tạo tài khoản" }).click();
  ok("Đăng ký trống → lỗi tại trường", (await page.getByText("Nhập họ tên.").count()) === 1);
  await page.getByLabel("Họ và tên").fill("Trần Kiểm Thử");
  await page.getByLabel("Số điện thoại").fill("0901000001");
  await page.locator("input[autocomplete=username]").fill("kt.e2e" + Date.now() % 100000);
  await page.locator("input[autocomplete=new-password]").nth(0).fill("KiemThu2026");
  await page.locator("input[autocomplete=new-password]").nth(1).fill("KiemThu2026");
  await page.getByRole("button", { name: "Tạo tài khoản" }).click();
  await page.waitForTimeout(1200);
  const sdtErr = await page.locator("#" + (await page.getByLabel("Số điện thoại").getAttribute("aria-describedby")).split(" ")[0]).innerText().catch(() => "");
  ok("Đăng ký trùng SĐT → lỗi tại ô SĐT", sdtErr.length > 0, sdtErr);
  await page.screenshot({ path: SHOTS + "15_register_dup.png" });
  const newUser = await page.locator("input[autocomplete=username]").inputValue();
  const newEmail = newUser + "@example.com";
  await page.getByLabel(/^Email/).fill(newEmail);
  await page.getByLabel("Số điện thoại").fill("09" + String(Date.now()).slice(-8));
  await page.getByRole("button", { name: "Áo thun" }).click();
  await page.getByRole("button", { name: "Tạo tài khoản" }).click();
  await page.waitForURL(CRM + "/customer", { timeout: 8000 }).catch(() => {});
  ok("Đăng ký mới → tự đăng nhập, vào /customer", page.url() === CRM + "/customer", page.url());

  // 10. Hết phiên do không thao tác
  await page.getByText("Hạng thành viên").waitFor(); await page.waitForTimeout(800);
  await page.evaluate(() => {
    const c = JSON.parse(localStorage.getItem("crm.sessionClock"));
    c.issuedAt = Date.now() - 29 * 60_000; localStorage.setItem("crm.sessionClock", JSON.stringify(c));
  });
  await page.getByRole("alertdialog").waitFor({ timeout: 4000 }).catch(() => {});
  ok("Còn ≤2 phút → hiện cảnh báo sắp hết phiên", (await page.getByText("Phiên làm việc sắp kết thúc").count()) === 1);
  await page.screenshot({ path: SHOTS + "16_idle_warning.png" });
  await page.evaluate(() => {
    const c = JSON.parse(localStorage.getItem("crm.sessionClock"));
    c.issuedAt = Date.now() - 31 * 60_000; localStorage.setItem("crm.sessionClock", JSON.stringify(c));
  });
  await page.waitForURL(/het-phien=1/, { timeout: 5000 }).catch(() => {});
  ok("Hết giờ → đăng xuất, /login?het-phien=1", page.url().includes("het-phien=1"), page.url());
  const me2 = await page.evaluate(() => fetch("/api/auth/me").then((r) => r.status));
  ok("Sau hết phiên cookie đã bị xóa (me → 401)", me2 === 401);

  // 11. Quên mật khẩu → email → đặt lại → đăng nhập bằng mật khẩu mới
  await page.goto(CRM + "/login");
  await page.getByRole("link", { name: "Quên mật khẩu?" }).click();
  await page.waitForURL(CRM + "/forgot-password");
  await page.waitForTimeout(600);
  await page.screenshot({ path: SHOTS + "17_forgot.png" });
  await page.locator("input[autocomplete=username]").fill(newUser);
  await page.locator("input[autocomplete=email]").fill(newEmail);
  await page.getByRole("button", { name: "Gửi liên kết đặt lại" }).click();
  await page.getByRole("heading", { name: "Kiểm tra email của bạn" }).waitFor();
  await page.screenshot({ path: SHOTS + "18_forgot_sent.png" });
  ok("Quên mật khẩu → thông báo chung, không lộ tài khoản", (await page.getByText("Nếu tên đăng nhập và email khớp").count()) === 1);
  let token = null;
  for (let i = 0; i < 20 && !token; i++) { await page.waitForTimeout(300); token = latestResetToken(newEmail); }
  ok("API gửi email có liên kết đặt lại", !!token);
  await page.goto(CRM + "/dat-lai-mat-khau#token=" + token);
  await page.getByRole("heading", { name: "Đặt mật khẩu mới" }).waitFor();
  ok("Mã đặt lại được xóa khỏi thanh địa chỉ", !page.url().includes("token="), page.url());
  await page.locator("input[autocomplete=new-password]").nth(0).fill("DatLai2026x");
  await page.locator("input[autocomplete=new-password]").nth(1).fill("DatLai2026x");
  await page.waitForTimeout(600);
  await page.screenshot({ path: SHOTS + "19_reset.png" });
  await page.getByRole("button", { name: "Lưu mật khẩu mới" }).click();
  await page.waitForURL(CRM + "/login?da-dat-lai=1");
  await fill(page, newUser, "DatLai2026x");
  await page.waitForURL(CRM + "/customer");
  ok("Đặt lại mật khẩu → đăng nhập bằng mật khẩu mới", true);
  await page.getByRole("button", { name: "Đăng xuất" }).first().click();
  await page.getByRole("dialog").getByRole("button", { name: "Đăng xuất" }).click();
  await page.waitForURL(/da-dang-xuat=1/);
  await page.goto(CRM + "/dat-lai-mat-khau#token=" + token);
  await page.getByRole("heading", { name: "Liên kết không còn hiệu lực" }).waitFor({ timeout: 2000 }).catch(async () => {
    await page.locator("input[autocomplete=new-password]").nth(0).fill("DatLai2026y");
    await page.locator("input[autocomplete=new-password]").nth(1).fill("DatLai2026y");
    await page.getByRole("button", { name: "Lưu mật khẩu mới" }).click();
    await page.getByRole("heading", { name: "Liên kết không còn hiệu lực" }).waitFor();
  });
  await page.screenshot({ path: SHOTS + "20_reset_invalid.png" });
  ok("Dùng lại liên kết đã dùng → báo liên kết không còn hiệu lực", true);
  await ctx.close();

  ok("Không có lỗi JavaScript trên trang", errors.length === 0, errors.join(" | "));
  await browser.close();
  console.log(results.join("\n"));
})().catch((e) => { console.log(results.join("\n")); console.error(e); process.exit(1); });
