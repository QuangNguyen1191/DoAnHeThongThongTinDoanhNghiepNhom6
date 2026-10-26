// Kiểm thử đầu cuối trang Admin (đề II.2 "Admin thêm, xóa, phân quyền cho account" + quản lý tổng bộ)
// trên giao diện thật + API thật + CSDL dữ liệu mẫu.
//   Tài khoản: tạo cho nhân viên, khóa/mở, đặt lại mật khẩu, đổi vai trò, xóa · Vai trò và ma trận quyền
//   Nhân viên (nghỉ việc → khóa tài khoản) · Tra cứu khách hàng (che SĐT) · Nạp hóa đơn, đổi trả, xét hạng
//   Nhật ký · Trạng thái hệ thống · Phân quyền QTV tài khoản (it.mai).
// Cần: API chạy ở 5000 + 5001 (Development), máy chủ Vite web-admin (5174) và web-crm (5173).
// Chạy: npm i --no-save playwright && npx playwright install chromium && node tests/e2e/trang-admin.cjs
// LƯU Ý: kịch bản GHI dữ liệu (thêm nhân viên, tài khoản, vai trò, hóa đơn) – chỉ chạy trên CSDL thử nghiệm.
const { chromium } = require("playwright");
const path = require("node:path");
const fs = require("node:fs");
const ADMIN = process.env.ADMIN_URL || "http://localhost:5174";
const CRM = process.env.CRM_URL || "http://localhost:5173";
const SHOTS = path.join(__dirname, "../../docs/anh-chup/admin") + "/";
fs.mkdirSync(SHOTS, { recursive: true });

const results = [];
const ok = (name, cond, extra = "") => results.push(`${cond ? "PASS" : "FAIL"}  ${name}${extra ? "  — " + extra : ""}`);
const shot = (page, name) => page.screenshot({ path: SHOTS + name + ".png", fullPage: true });

async function login(page, base, u, p = "Demo@2026") {
  await page.goto(base + "/login");
  await page.locator("input[autocomplete=username]").fill(u);
  await page.locator("input[autocomplete=current-password]").fill(p);
  await page.getByRole("button", { name: /^Đăng nhập( quản trị)?$/i }).click();
}

/** Gọi API bằng cookie của trang (kèm X-XSRF-TOKEN cho request ghi). */
async function apiCall(page, method, url, body) {
  return page.evaluate(async ({ method, url, body }) => {
    const headers = { "Content-Type": "application/json", Accept: "application/json" };
    if (method !== "GET") headers["X-XSRF-TOKEN"] = (await (await fetch("/api/auth/antiforgery")).json()).xsrfToken;
    const r = await fetch(url, { method, headers, body: body ? JSON.stringify(body) : undefined });
    const text = await r.text();
    return { status: r.status, json: text ? JSON.parse(text) : null };
  }, { method, url, body });
}

/** Ô datetime-local cách hiện tại n giờ (giờ máy). */
const hoursAgo = (n) => {
  const d = new Date(Date.now() - n * 3600_000);
  const p = (x) => String(x).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
};

(async () => {
  const browser = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  const newCtx = () => browser.newContext({ locale: "vi-VN", viewport: { width: 1440, height: 900 } });
  const errors = [];
  const watch = (p) => p.on("pageerror", (e) => errors.push(e.message));
  const stamp = Date.now().toString().slice(-7);

  /** Đăng nhập web-crm trong context riêng, trả về URL sau đăng nhập và câu thông báo (nếu có). */
  async function tryCrmLogin(u, p) {
    const c = await newCtx();
    const pg = await c.newPage();
    await login(pg, CRM, u, p);
    await pg.waitForTimeout(1500);
    const url = pg.url();
    const alert = (await pg.getByRole("alert").allInnerTexts()).join(" ");
    await c.close();
    return { url, alert };
  }

  // 0. Đăng nhập Admin, tổng quan có lối tắt 8 chức năng
  const ctx = await newCtx();
  const page = await ctx.newPage();
  watch(page);
  await login(page, ADMIN, "admin.it");
  await page.waitForURL(ADMIN + "/admin");
  const fnNav = page.getByRole("navigation", { name: "Chức năng quản trị" });
  await fnNav.waitFor();
  ok("Tổng quan: đủ 8 lối tắt chức năng", (await fnNav.getByRole("link").count()) === 8);
  await page.getByText("Tổng tài khoản").waitFor();
  await page.waitForTimeout(400);
  await shot(page, "01_tong-quan");

  // 1. Danh sách tài khoản
  await page.goto(ADMIN + "/admin/accounts");
  const table = page.getByRole("table", { name: "Danh sách tài khoản" });
  await table.waitFor();
  const total = Number((await page.getByText(/^\d+ tài khoản$/).innerText()).split(" ")[0]);
  ok("Danh sách tài khoản đọc API thật", total >= 15, `${total} tài khoản`);
  ok("Không có cột mật khẩu / chuỗi băm", !(await table.innerText()).match(/\$2[aby]\$|mật khẩu hash/i));
  ok("Dòng của chính mình không có nút thao tác", (await page.getByTestId("tk-admin.it").getByRole("button").count()) === 0
    && (await page.getByTestId("tk-admin.it").getByText("Tài khoản của bạn").count()) === 1);
  ok("Tài khoản KH không có nút Vai trò (chỉ có vai trò Khách hàng)", (await page.getByTestId("tk-kh.chau").getByRole("button", { name: "Vai trò" }).count()) === 0
    && (await page.getByTestId("tk-ql.lan").getByRole("button", { name: "Vai trò" }).count()) === 1);
  await page.getByLabel("Loại tài khoản").selectOption("NV");
  await page.getByRole("button", { name: "Tìm kiếm" }).click();
  await page.waitForTimeout(600);
  const nv = Number((await page.getByText(/^\d+ tài khoản$/).innerText()).split(" ")[0]);
  ok("Lọc theo loại Nhân viên", nv > 0 && nv < total, `${nv} tài khoản NV`);
  await shot(page, "02_danh-sach-tai-khoan");

  // 2. Thêm nhân viên mới
  await page.goto(ADMIN + "/admin/employees");
  await page.getByRole("table", { name: "Danh sách nhân viên" }).waitFor();
  await page.getByRole("button", { name: "Thêm nhân viên" }).click();
  let dlg = page.locator("dialog[open]");
  await dlg.getByRole("button", { name: "Thêm nhân viên" }).click();
  ok("Nhân viên: thiếu thông tin → báo lỗi tại ô", (await dlg.getByText("Họ tên là bắt buộc.").count()) === 1 && (await dlg.getByText("Cần chọn chức vụ.").count()) === 1);
  const tenNV = "Nhân Viên E2E " + stamp;
  await dlg.getByLabel("Họ tên").fill(tenNV);
  await dlg.getByLabel("Chức vụ").selectOption("NV_CSKH");
  await dlg.getByLabel("Nơi làm việc").selectOption({ label: "Cửa hàng Quận 1" });
  await dlg.getByLabel("Số điện thoại").fill("0912000001"); // trùng SĐT gd.minh
  await dlg.getByLabel("Email").fill(`e2e.${stamp}@nv.example.com`);
  await shot(page, "03_them-nhan-vien");
  await dlg.getByRole("button", { name: "Thêm nhân viên" }).click();
  await dlg.getByText(/đã tồn tại/).waitFor();
  ok("Nhân viên: SĐT trùng → báo lỗi", true);
  await dlg.getByLabel("Số điện thoại").fill("093" + stamp);
  await dlg.getByRole("button", { name: "Thêm nhân viên" }).click();
  await page.getByText(tenNV).waitFor();
  const nvRow = page.getByRole("row").filter({ hasText: tenNV });
  ok("Nhân viên mới có trong danh sách, chưa có tài khoản", (await nvRow.getByRole("link", { name: "Tạo tài khoản" }).count()) === 1);
  await shot(page, "04_danh-sach-nhan-vien");

  // 3. Tạo tài khoản cho nhân viên mới (từ cột Tài khoản)
  await nvRow.getByRole("link", { name: "Tạo tài khoản" }).click();
  dlg = page.locator("dialog[open]");
  await dlg.getByText("Tạo tài khoản nhân viên").waitFor();
  await page.waitForTimeout(500);
  const user = "nv.e2e" + stamp;
  ok("Tạo TK: nhân viên được chọn sẵn", (await dlg.getByLabel("Nhân viên").inputValue()) !== "");
  await dlg.getByRole("button", { name: "Tạo tài khoản" }).click();
  ok("Tạo TK: thiếu tên đăng nhập/vai trò → báo lỗi", (await dlg.getByText("Cần chọn vai trò.").count()) === 1);
  await dlg.getByLabel("Tên đăng nhập").fill("admin.it");
  await dlg.getByLabel("Vai trò").selectOption("NV_CSKH");
  await dlg.getByRole("button", { name: "Tạo tài khoản" }).click();
  await dlg.getByText("Tên đăng nhập đã tồn tại.").waitFor();
  ok("Tạo TK: tên đăng nhập trùng → lỗi tại ô", true);
  await dlg.getByLabel("Tên đăng nhập").fill(user);
  await dlg.getByRole("button", { name: "Tạo tài khoản" }).click();
  await dlg.getByTestId("mat-khau-tam").waitFor();
  const temp1 = await dlg.getByTestId("mat-khau-tam").innerText();
  ok("Tạo TK: hiện mật khẩu tạm một lần", temp1.length >= 10, user);
  await shot(page, "05_tao-tai-khoan-mat-khau-tam");
  await dlg.getByRole("button", { name: "Xong" }).click();
  let r = await tryCrmLogin(user, temp1);
  ok("Tài khoản mới đăng nhập web Quản lý → bắt buộc đổi mật khẩu", r.url.includes("/change-password"), r.url.replace(CRM, ""));

  // 4. Phân quyền: đổi vai trò NV_CSKH → QUAN_LY
  await page.goto(ADMIN + "/admin/accounts");
  const row = () => page.getByTestId(`tk-${user}`);
  await row().waitFor();
  await row().getByRole("button", { name: "Vai trò" }).click();
  dlg = page.locator("dialog[open]");
  await dlg.getByLabel("Vai trò mới").selectOption("QUAN_LY");
  await shot(page, "06_doi-vai-tro");
  await dlg.getByRole("button", { name: "Lưu vai trò" }).click();
  await page.waitForTimeout(800);
  ok("Đổi vai trò → cột vai trò hiện QUAN_LY", (await row().innerText()).includes("QUAN_LY"));

  // 5. Khóa (bắt buộc lý do) → không đăng nhập được; mở khóa
  await row().getByRole("button", { name: "Khóa" }).click();
  dlg = page.locator("dialog[open]");
  ok("Khóa cần lý do (nút bị khóa khi trống)", await dlg.getByRole("button", { name: "Khóa tài khoản" }).isDisabled());
  await dlg.getByLabel("Lý do khóa").fill("Kiểm thử E2E");
  await dlg.getByRole("button", { name: "Khóa tài khoản" }).click();
  await page.waitForTimeout(800);
  ok("Khóa → trạng thái Đã khóa, hiện lý do", (await row().innerText()).includes("Đã khóa") && (await row().innerText()).includes("Kiểm thử E2E"));
  await shot(page, "07_da-khoa");
  r = await tryCrmLogin(user, temp1);
  ok("Tài khoản bị khóa không đăng nhập được", !r.url.includes("/manager") && !r.url.includes("/change-password"), r.alert.replace(/\s+/g, " ").slice(0, 70));
  await row().getByRole("button", { name: "Mở khóa" }).click();
  await page.locator("dialog[open]").getByRole("button", { name: "Mở khóa" }).click();
  await page.waitForTimeout(800);
  ok("Mở khóa → Hoạt động", (await row().innerText()).includes("Hoạt động"));

  // 6. Đặt lại mật khẩu
  await row().getByRole("button", { name: "Đặt lại MK" }).click();
  dlg = page.locator("dialog[open]");
  await dlg.getByRole("button", { name: "Đặt lại mật khẩu" }).click();
  await dlg.getByTestId("mat-khau-tam").waitFor();
  const temp2 = await dlg.getByTestId("mat-khau-tam").innerText();
  await shot(page, "08_dat-lai-mat-khau");
  await dlg.getByRole("button", { name: "Xong" }).click();
  r = await tryCrmLogin(user, temp1);
  const r2 = await tryCrmLogin(user, temp2);
  ok("Đặt lại MK: mật khẩu cũ hết hiệu lực, mật khẩu tạm mới đăng nhập được", !r.url.includes("/change-password") && r2.url.includes("/change-password"));

  // 7. Nhân viên nghỉ việc → tài khoản tự khóa, không mở lại được
  await page.goto(ADMIN + "/admin/employees");
  await page.getByText(tenNV).waitFor();
  await page.getByRole("button", { name: `Sửa ${tenNV}` }).click();
  dlg = page.locator("dialog[open]");
  await dlg.getByLabel("Trạng thái").selectOption("DA_NGHI");
  ok("Nghỉ việc: cảnh báo tài khoản sẽ bị khóa trước khi lưu", (await dlg.getByText(/sẽ tự động bị khóa/).count()) === 1);
  await shot(page, "09_nhan-vien-nghi-viec");
  await dlg.getByRole("button", { name: "Lưu thay đổi" }).click();
  await page.waitForTimeout(800);
  await page.goto(ADMIN + "/admin/accounts");
  await row().waitFor();
  ok("Nghỉ việc → tài khoản Đã khóa (lý do: nghỉ việc)", (await row().innerText()).includes("Nhân viên đã nghỉ việc"));
  await row().getByRole("button", { name: "Mở khóa" }).click();
  dlg = page.locator("dialog[open]");
  await dlg.getByRole("button", { name: "Mở khóa" }).click();
  await dlg.getByText(/nhân viên đã nghỉ/).waitFor();
  ok("Không mở khóa được tài khoản của nhân viên đã nghỉ", true);
  await dlg.getByRole("button", { name: "Hủy" }).click();

  // 8. Xóa tài khoản (hồ sơ giữ lại)
  await row().getByRole("button", { name: "Xóa" }).click();
  dlg = page.locator("dialog[open]");
  ok("Xóa: hộp xác nhận ghi rõ hồ sơ và lịch sử vẫn được giữ", (await dlg.getByText(/vẫn được giữ/).count()) === 1);
  await shot(page, "10_xoa-tai-khoan");
  await dlg.getByRole("button", { name: "Xóa tài khoản" }).click();
  await page.waitForTimeout(800);
  ok("Xóa → tài khoản biến khỏi danh sách", (await row().count()) === 0);
  await page.goto(ADMIN + "/admin/employees");
  await page.getByText(tenNV).waitFor();
  ok("Xóa → hồ sơ nhân viên vẫn còn", (await page.getByRole("row").filter({ hasText: tenNV }).getByText("Chưa có").count()) === 1);

  // 9. Vai trò và quyền: ma trận, sửa quyền NV_CSKH → cskh.hoa có/mất menu Báo cáo
  await page.goto(ADMIN + "/admin/roles");
  await page.getByRole("table", { name: /Ma trận quyền Cổng Quản lý/ }).waitFor();
  ok("Ma trận: 2 cổng (Quản trị, Quản lý)", (await page.getByRole("table", { name: /Ma trận quyền/ }).count()) === 2);
  ok("Không tự gỡ quyền Phân quyền khỏi vai trò của mình", await page.getByLabel("Phân quyền cho Quản trị hệ thống").isDisabled());
  const baoCao = page.getByLabel("Xem báo cáo tổng hợp cho Nhân viên CSKH");
  await baoCao.check();
  await page.getByRole("button", { name: "Lưu thay đổi" }).click();
  await page.getByText("Không có thay đổi").waitFor();
  await shot(page, "11_ma-tran-quyen");
  const ctxHoa = await newCtx();
  const hoa = await ctxHoa.newPage();
  await login(hoa, CRM, "cskh.hoa");
  await hoa.waitForURL(CRM + "/manager");
  await hoa.waitForTimeout(500);
  ok("Cấp QL_BAO_CAO → cskh.hoa thấy menu Báo cáo", (await hoa.getByRole("link", { name: "Báo cáo", exact: true }).count()) === 1);
  await baoCao.uncheck();
  await page.getByRole("button", { name: "Lưu thay đổi" }).click();
  await page.getByText("Không có thay đổi").waitFor();
  await hoa.reload();
  await hoa.waitForTimeout(1200);
  ok("Gỡ QL_BAO_CAO → cskh.hoa mất menu Báo cáo", (await hoa.getByRole("link", { name: "Báo cáo", exact: true }).count()) === 0);
  await ctxHoa.close();

  // Tạo vai trò mới
  const maVT = "E2E_" + stamp.slice(-5);
  await page.getByRole("button", { name: "Tạo vai trò" }).click();
  dlg = page.locator("dialog[open]");
  await dlg.getByLabel("Mã vai trò").fill(maVT);
  await dlg.getByLabel("Tên vai trò").fill("Vai trò E2E " + stamp);
  await dlg.getByRole("button", { name: "Tạo vai trò" }).click();
  await page.getByText(maVT + " · 0 TK").waitFor();
  ok("Tạo vai trò mới → có cột trong ma trận", true, maVT);

  // 10. Tra cứu khách hàng (che SĐT/email, không có nút sửa)
  await page.goto(ADMIN + "/admin/customers");
  await page.getByRole("table", { name: "Kết quả tra cứu khách hàng" }).waitFor();
  const masked = await page.getByTestId("sdt-che").allInnerTexts();
  ok("Tra cứu KH: SĐT đều đã che", masked.length >= 10 && masked.every((s) => /x{3,}/.test(s)), masked[0]);
  ok("Tra cứu KH: chỉ xem (không có nút trong bảng)", (await page.getByRole("table", { name: "Kết quả tra cứu khách hàng" }).getByRole("button").count()) === 0);
  await shot(page, "12_tra-cuu-khach-hang");

  // 11. Nạp hóa đơn cho kh.ha (AK-001 1.290.000 đ + AT-001) → VIP; trùng số hóa đơn → lỗi tại ô
  const soHD = "E2E" + stamp;
  await page.goto(ADMIN + "/admin/invoices/new");
  await page.getByLabel("Số hóa đơn").fill(soHD);
  const khOpt = await page.getByLabel("Khách hàng").locator("option", { hasText: "Hoàng Thu Hà" }).getAttribute("value");
  await page.getByLabel("Khách hàng").selectOption(khOpt);
  await page.getByLabel("Ngày lập").fill(hoursAgo(26));
  await page.getByLabel("Cửa hàng").selectOption({ label: "Cửa hàng Quận 1" });
  await page.waitForTimeout(500);
  await page.getByLabel("Nhân viên bán").selectOption({ index: 1 });
  await page.getByLabel("Sản phẩm dòng 1").selectOption("AK-001");
  ok("Chọn SKU → điền sẵn giá niêm yết", (await page.getByLabel("Đơn giá bán (₫)").first().inputValue()) === "1290000");
  await page.getByRole("button", { name: "Thêm dòng" }).click();
  await page.getByLabel("Sản phẩm dòng 2").selectOption("AT-001");
  await shot(page, "13_nap-hoa-don");
  await page.getByRole("button", { name: "Nạp hóa đơn" }).click();
  await page.getByTestId("hang-sau-khi-nap").waitFor();
  const hang = await page.getByTestId("hang-sau-khi-nap").innerText();
  ok("Nạp hóa đơn kh.ha → hạng VIP", hang === "VIP", hang);
  await shot(page, "14_ket-qua-nap-hoa-don");
  await page.getByRole("button", { name: "Nạp hóa đơn khác" }).click();
  await page.getByLabel("Số hóa đơn").fill(soHD);
  await page.getByLabel("Khách hàng").selectOption(khOpt);
  await page.getByLabel("Ngày lập").fill(hoursAgo(26));
  await page.getByLabel("Kênh bán").selectOption("ONLINE");
  ok("Kênh Online → ẩn cửa hàng và nhân viên", (await page.getByLabel("Cửa hàng").count()) === 0);
  await page.getByLabel("Sản phẩm dòng 1").selectOption("AT-001");
  await page.getByRole("button", { name: "Nạp hóa đơn" }).click();
  await page.getByText("Số hóa đơn đã được nạp trước đó.").waitFor();
  ok("Trùng số hóa đơn → lỗi tại ô Số hóa đơn", true);

  const ctxHa = await newCtx();
  const ha = await ctxHa.newPage();
  await login(ha, CRM, "kh.ha");
  await ha.waitForURL(CRM + "/customer");
  await ha.waitForTimeout(800);
  ok("kh.ha đăng nhập web Khách thấy hạng VIP", (await ha.getByText("VIP").count()) > 0);
  await ctxHa.close();

  // 12. Danh sách hóa đơn → chi tiết → nạp đổi trả; xét lại hạng
  await page.goto(ADMIN + "/admin/invoices");
  await page.getByLabel("Số hóa đơn").fill(soHD);
  await page.getByRole("button", { name: "Tìm" }).click();
  await page.getByRole("button", { name: soHD }).click();
  dlg = page.locator("dialog[open]");
  await dlg.getByRole("table", { name: "Dòng hàng" }).waitFor();
  ok("Chi tiết hóa đơn có 2 dòng hàng", (await dlg.getByRole("table", { name: "Dòng hàng" }).getByRole("row").count()) === 3);
  await dlg.getByLabel("Sản phẩm trả").selectOption("AT-001");
  await dlg.getByLabel("Số lượng").fill("2");
  ok("Đổi trả: số lượng vượt phần còn lại → chặn", await dlg.getByRole("button", { name: "Nạp đổi trả" }).isDisabled());
  await dlg.getByLabel("Số lượng").fill("1");
  await dlg.getByLabel("Ngày đổi trả").fill(hoursAgo(10));
  await shot(page, "15_doi-tra");
  await dlg.getByRole("button", { name: "Nạp đổi trả" }).click();
  await page.getByText(/Đã nạp đổi trả/).waitFor();
  await page.waitForTimeout(600);
  ok("Nạp đổi trả → cột Đã đổi trả cập nhật", (await dlg.getByRole("table", { name: "Dòng hàng" }).getByRole("row").filter({ hasText: "AT-001" }).innerText()).trim().endsWith("1"));
  await dlg.getByRole("button", { name: "Đóng" }).click();
  await page.getByRole("button", { name: "Xét lại hạng" }).click();
  dlg = page.locator("dialog[open]");
  await dlg.getByRole("button", { name: "Xét hạng" }).click();
  await dlg.getByText(/khách hàng đổi hạng/).waitFor();
  ok("Xét lại hạng toàn bộ → báo số khách đổi hạng", true, await dlg.getByText(/khách hàng đổi hạng/).innerText());
  await dlg.getByRole("button", { name: "Xong" }).click();
  await shot(page, "16_danh-sach-hoa-don");

  // 13. Nhật ký
  await page.goto(ADMIN + "/admin/audit-log");
  await page.getByLabel("Hành động").selectOption("TAO_TK");
  await page.getByRole("button", { name: "Lọc", exact: true }).click();
  await page.waitForTimeout(800);
  ok("Nhật ký: lọc Tạo tài khoản thấy tài khoản vừa tạo", (await page.getByText(`Tạo tài khoản ${user}`).count()) === 1);
  await page.getByLabel("Hành động").selectOption("");
  await page.getByRole("button", { name: "Lọc", exact: true }).click();
  await page.waitForTimeout(800);
  const logText = await page.getByRole("table", { name: "Nhật ký hệ thống" }).innerText();
  ok("Nhật ký ghi đủ: đổi vai trò, khóa, xóa TK, cập nhật quyền, nạp hóa đơn",
    ["DOI_VAI_TRO", "KHOA_TK", "XOA_TK", "CAP_NHAT_QUYEN", "NAP_HOA_DON"].every((h) => logText.includes(h)));
  await shot(page, "17_nhat-ky");

  // 14. Trạng thái hệ thống
  await page.goto(ADMIN + "/admin/system");
  await page.getByTestId("ket-noi-ADMIN").waitFor();
  ok("Trạng thái hệ thống: 3 kết nối đều tốt", (await page.getByText("Kết nối tốt").count()) === 3);
  await shot(page, "18_trang-thai-he-thong");

  // 15. QTV tài khoản it.mai: chỉ Tài khoản + Tra cứu; không leo quyền
  const ctxMai = await newCtx();
  const mai = await ctxMai.newPage();
  watch(mai);
  await login(mai, ADMIN, "it.mai");
  await mai.waitForURL(ADMIN + "/admin");
  const menu = (await mai.getByRole("navigation").first().innerText());
  ok("it.mai: menu không có Vai trò và quyền, Hóa đơn, Nhật ký",
    !menu.includes("Vai trò và quyền") && !menu.includes("Hóa đơn") && !menu.includes("Nhật ký") && menu.includes("Tài khoản") && menu.includes("Tra cứu khách hàng"));
  await mai.goto(ADMIN + "/admin/accounts");
  await mai.getByRole("table", { name: "Danh sách tài khoản" }).waitFor();
  ok("it.mai: không có nút Tạo tài khoản nhân viên", (await mai.getByRole("button", { name: "Tạo tài khoản nhân viên" }).count()) === 0);
  ok("it.mai: tài khoản NV không có nút Vai trò / Đặt lại MK", (await mai.getByTestId("tk-ql.lan").getByRole("button", { name: /Vai trò|Đặt lại MK/ }).count()) === 0);
  ok("it.mai: tài khoản KH có nút Đặt lại MK", (await mai.getByTestId("tk-kh.chau").getByRole("button", { name: "Đặt lại MK" }).count()) === 1);
  await shot(mai, "19_it-mai-tai-khoan");
  await mai.goto(ADMIN + "/admin/roles");
  await mai.getByText("Không có quyền truy cập").waitFor();
  ok("it.mai: gõ URL Vai trò và quyền → không có quyền", true);
  const ql = (await apiCall(mai, "GET", "/api/admin/accounts?tuKhoa=ql.lan")).json[0];
  const esc = await apiCall(mai, "PUT", `/api/admin/accounts/${ql.maTK}/role`, { maVT: "ADMIN" });
  ok("it.mai: gọi thẳng API đổi vai trò → 403 (CSDL chặn 50003)", esc.status === 403, String(esc.status));
  const rs = await apiCall(mai, "POST", `/api/admin/accounts/${ql.maTK}/reset-password`);
  ok("it.mai: đặt lại MK tài khoản nội bộ qua API → 403", rs.status === 403, String(rs.status));
  await ctxMai.close();

  // 16. Tài khoản Quản lý đăng nhập trang Admin → bị từ chối
  const ctxQl = await newCtx();
  const qlp = await ctxQl.newPage();
  await login(qlp, ADMIN, "ql.lan");
  await qlp.getByText("Sai tên đăng nhập hoặc mật khẩu").waitFor();
  ok("ql.lan đăng nhập trang Admin → bị từ chối", qlp.url().includes("/login"));
  await ctxQl.close();

  ok("Không có lỗi JavaScript trên trang", errors.length === 0, errors.slice(0, 2).join(" | "));
  await browser.close();

  const pass = results.filter((x) => x.startsWith("PASS")).length;
  const out = results.join("\n") + `\n\nTỔNG: ${pass}/${results.length} PASS\n`;
  console.log(out);
  fs.writeFileSync(path.join(__dirname, "../../docs/KetQua_E2E_Admin.txt"), out);
  process.exit(pass === results.length ? 0 : 1);
})().catch((e) => {
  console.error(results.join("\n"));
  console.error(e);
  process.exit(2);
});
