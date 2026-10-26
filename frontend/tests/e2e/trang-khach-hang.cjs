// Kiểm thử đầu cuối trang Khách hàng (5 chức năng của khách hàng, đề III.4) trên giao diện thật + API thật + CSDL dữ liệu mẫu.
//   1 Đăng ký tài khoản · 8 Đăng nhập · 2 Chỉnh sửa thông tin · 3 Gửi phản hồi về sản phẩm · 4 Nhận khảo sát và thực hiện
// Cần: API chạy ở 5000 (Development) + máy chủ Vite web-crm (npm run dev:crm, cổng 5173).
// Chạy: npm i --no-save playwright && npx playwright install chromium && node tests/e2e/trang-khach-hang.cjs
// LƯU Ý: kịch bản GHI dữ liệu (đăng ký khách mới, gửi phản hồi, tạo/gửi/đóng khảo sát, nộp khảo sát) – chỉ chạy trên CSDL thử nghiệm.
const { chromium } = require("playwright");
const path = require("node:path");
const fs = require("node:fs");
const CRM = process.env.CRM_URL || "http://localhost:5173";
const SHOTS = path.join(__dirname, "../../docs/anh-chup/khach-hang") + "/";
fs.mkdirSync(SHOTS, { recursive: true });

const results = [];
const ok = (name, cond, extra = "") => results.push(`${cond ? "PASS" : "FAIL"}  ${name}${extra ? "  — " + extra : ""}`);
const shot = (page, name) => page.screenshot({ path: SHOTS + name + ".png", fullPage: true });

async function login(page, u, p = "Demo@2026") {
  await page.goto(CRM + "/login");
  await page.locator("input[autocomplete=username]").fill(u);
  await page.locator("input[autocomplete=current-password]").fill(p);
  await page.getByRole("button", { name: /^Đăng nhập$/i }).click();
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

const errorOf = async (page, label) => {
  const ids = (await page.getByLabel(label).getAttribute("aria-describedby")) ?? "";
  return ids ? page.locator("#" + ids.split(" ")[0]).innerText().catch(() => "") : "";
};

(async () => {
  const browser = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  const newCtx = () => browser.newContext({ locale: "vi-VN", viewport: { width: 1440, height: 900 } });
  const errors = [];
  const watch = (p) => p.on("pageerror", (e) => errors.push(e.message));
  const stamp = Date.now().toString().slice(-7);
  const user = "kh.e2e" + stamp;
  const sdt = "098" + stamp;

  // ===== CN1. Đăng ký tài khoản khách hàng =====
  const ctx = await newCtx();
  const page = await ctx.newPage();
  watch(page);
  await page.goto(CRM + "/login");
  await page.getByRole("link", { name: /Đăng ký/ }).first().click();
  await page.waitForURL(CRM + "/register");
  ok("CN1: trang đăng nhập có liên kết sang Đăng ký", true);
  await page.getByText("Áo khoác").first().waitFor();
  await page.getByRole("button", { name: "Tạo tài khoản" }).click();
  ok("CN1: để trống → báo lỗi tại ô", (await page.getByText("Nhập họ tên.").count()) === 1);
  await page.getByLabel("Họ và tên").fill("Lê Kiểm Thử Khách");
  await page.getByLabel("Số điện thoại").fill("0901000001");
  await page.getByLabel("Ngày sinh").fill("1931-05-20"); // tuổi > 90: để quản lý gửi khảo sát riêng cho khách này
  await page.getByLabel("Tỉnh / thành phố").selectOption({ index: 1 });
  await page.getByRole("button", { name: "Áo thun" }).click();
  await page.locator("input[autocomplete=username]").fill(user);
  await page.locator("input[autocomplete=new-password]").nth(0).fill("KiemThu2026");
  await page.locator("input[autocomplete=new-password]").nth(1).fill("KiemThu2027");
  await page.getByRole("button", { name: "Tạo tài khoản" }).click();
  ok("CN1: mật khẩu nhập lại không khớp → báo lỗi", (await page.getByText("Mật khẩu nhập lại không khớp.").count()) === 1);
  await page.locator("input[autocomplete=new-password]").nth(1).fill("KiemThu2026");
  await page.getByRole("button", { name: "Tạo tài khoản" }).click();
  await page.waitForTimeout(1200);
  const dupErr = await errorOf(page, "Số điện thoại");
  ok("CN1: SĐT đã có hồ sơ → báo lỗi tại ô SĐT", dupErr.length > 0, dupErr);
  await page.getByLabel("Số điện thoại").fill(sdt);
  await shot(page, "01_dang-ky");
  await page.getByRole("button", { name: "Tạo tài khoản" }).click();
  await page.waitForURL(CRM + "/customer", { timeout: 8000 }).catch(() => {});
  ok("CN1: đăng ký thành công → tự đăng nhập, vào trang khách hàng", page.url() === CRM + "/customer", user);
  await page.getByText("Xin chào, Lê Kiểm Thử Khách").waitFor();
  ok("CN1: khách mới hạng Thường, 0 điểm", (await page.getByText("Thường", { exact: true }).count()) >= 1);

  // Menu chỉ còn các chức năng của đề
  const nav = page.getByRole("navigation").filter({ has: page.getByRole("link", { name: "Trang chủ" }) }).first();
  const links = (await nav.getByRole("link").allInnerTexts()).map((s) => s.trim()).filter(Boolean);
  ok("Menu khách: Trang chủ, Thông tin cá nhân, Phản hồi sản phẩm, Khảo sát, Đổi mật khẩu", ["Thông tin cá nhân", "Phản hồi sản phẩm", "Khảo sát", "Đổi mật khẩu"].every((x) => links.includes(x)) && !links.some((x) => /Voucher của tôi|Lịch sử mua hàng/.test(x)), links.join(", "));
  ok("Trang chủ: 3 lối tắt chức năng", (await page.getByRole("navigation", { name: "Chức năng khách hàng" }).getByRole("link").count()) === 3);
  await shot(page, "02_trang-chu");

  // ===== CN8. Đăng nhập (đăng xuất rồi đăng nhập lại bằng tài khoản vừa tạo) =====
  await page.getByRole("button", { name: "Đăng xuất" }).first().click();
  await page.getByRole("dialog").getByRole("button", { name: "Đăng xuất" }).click();
  await page.waitForURL(/\/login/);
  await login(page, user, "SaiMatKhau9");
  await page.getByRole("alert").first().waitFor();
  ok("CN8: sai mật khẩu → thông báo chung", /Sai tên đăng nhập hoặc mật khẩu/.test(await page.locator("#login-error").innerText()));
  await login(page, user, "KiemThu2026");
  await page.waitForURL(CRM + "/customer");
  ok("CN8: đăng nhập đúng → vào /customer", true);
  await page.goto(CRM + "/manager");
  await page.getByText("Bạn không có quyền truy cập trang này").waitFor();
  ok("CN8: khách gõ URL /manager → không có quyền", true);
  await page.goto(CRM + "/customer/orders");
  await page.getByText(/Không tìm thấy trang/i).first().waitFor({ timeout: 4000 }).catch(() => {});
  ok("Trang thừa /customer/orders đã gỡ → 404", (await page.getByText(/Không tìm thấy trang/i).count()) > 0);

  // ===== CN2. Chỉnh sửa thông tin =====
  await page.goto(CRM + "/customer/profile");
  await page.getByTestId("ho-so").waitFor();
  ok("CN2: xem hồ sơ đúng thông tin đăng ký", (await page.getByTestId("ho-so").innerText()).includes(sdt));
  await page.getByRole("button", { name: "Chỉnh sửa thông tin" }).click();
  await page.getByLabel("Số điện thoại").fill("12345");
  await page.getByRole("button", { name: "Lưu thay đổi" }).click();
  ok("CN2: SĐT sai định dạng → lỗi tại ô", (await errorOf(page, "Số điện thoại")).includes("10 chữ số"));
  await page.getByLabel("Số điện thoại").fill("0901000002");
  await page.getByRole("button", { name: "Lưu thay đổi" }).click();
  await page.waitForTimeout(1000);
  const dup2 = await errorOf(page, "Số điện thoại");
  ok("CN2: SĐT trùng khách khác → lỗi từ CSDL tại ô SĐT", dup2.length > 0, dup2);
  await page.getByLabel("Số điện thoại").fill(sdt);
  await page.getByLabel("Họ tên").fill("Lê Kiểm Thử Đã Sửa");
  await page.getByLabel("Email").fill(user + "@example.com");
  await page.getByLabel("Giới tính").selectOption("NAM");
  await page.getByRole("button", { name: "Áo khoác" }).click();
  await page.getByRole("button", { name: "Quần jeans" }).click();
  await page.getByRole("button", { name: "Áo thun" }).click(); // bỏ chọn
  await shot(page, "03_sua-thong-tin");
  await page.getByRole("button", { name: "Lưu thay đổi" }).click();
  await page.getByText("Đã lưu thông tin cá nhân.").waitFor();
  await page.reload();
  await page.getByTestId("ho-so").waitFor();
  const hs = await page.getByTestId("ho-so").innerText();
  const st = await page.getByRole("list", { name: "Sở thích đã chọn" }).innerText();
  ok("CN2: lưu và tải lại → họ tên, email, giới tính mới", hs.includes("Lê Kiểm Thử Đã Sửa") && hs.includes(user + "@example.com") && hs.includes("Nam"));
  ok("CN2: sở thích mới (Áo khoác, Quần jeans; bỏ Áo thun)", st.includes("Áo khoác") && st.includes("Quần jeans") && !st.includes("Áo thun"), st.replace(/\n/g, ", "));
  ok("CN2: tên mới hiện trên trang chủ", await page.goto(CRM + "/customer").then(() => page.getByText("Xin chào, Lê Kiểm Thử Đã Sửa").waitFor().then(() => true, () => false)));

  // ===== CN3. Gửi phản hồi về sản phẩm =====
  await page.goto(CRM + "/customer/feedback");
  await page.getByText("Bạn chưa gửi phản hồi nào.").waitFor();
  await page.getByRole("button", { name: "Gửi phản hồi" }).click();
  ok("CN3: để trống → báo lỗi từng mục", (await page.getByText("Chọn sản phẩm cần phản hồi.").count()) === 1 && (await page.getByText("Chấm điểm từ 1 đến 5 sao.").count()) === 1);
  const opts = await page.getByLabel("Sản phẩm").locator("option").allInnerTexts();
  ok("CN3: không cho phản hồi sản phẩm Sắp ra mắt", !opts.some((o) => o.includes("lông cừu nhân tạo 2026")), `${opts.length - 1} sản phẩm`);
  await page.getByLabel("Sản phẩm").selectOption({ label: "Quần jeans ống rộng nữ" });
  await page.getByRole("radio", { name: "Góp ý" }).click();
  await page.getByRole("radio", { name: /^4 sao/ }).click();
  const fbText = "E2E " + stamp + ": mong có thêm size dài cho quần jeans.";
  await page.getByLabel("Nội dung").fill(fbText);
  await shot(page, "04_gui-phan-hoi");
  await page.getByRole("button", { name: "Gửi phản hồi" }).click();
  await page.getByText("Đã gửi phản hồi. Cảm ơn bạn đã góp ý!").waitFor();
  const mine = page.getByRole("list", { name: "Phản hồi của tôi" });
  await mine.getByText(fbText).waitFor();
  ok("CN3: phản hồi hiện trong danh sách, trạng thái Đã gửi", (await mine.locator("li").first().innerText()).includes("Đã gửi"));

  // Quản lý thấy và trả lời → khách thấy câu trả lời
  const qlCtx = await newCtx();
  const ql = await qlCtx.newPage();
  watch(ql);
  await login(ql, "ql.lan");
  await ql.waitForURL(CRM + "/manager");
  const fbList = await apiCall(ql, "GET", "/api/manager/feedback?trangThai=MOI&soDong=100");
  const ph = (fbList.json.items ?? fbList.json).find((x) => x.noiDung === fbText);
  ok("CN3: phản hồi tới trang Quản lý (tab Mới)", !!ph, ph ? `mã ${ph.maPH}` : JSON.stringify(fbList.json).slice(0, 120));
  if (ph) {
    const rep = await apiCall(ql, "POST", `/api/manager/feedback/${ph.maPH}/reply`, { noiDungTraLoi: "Cảm ơn bạn, size dài sẽ có từ tháng 12." });
    ok("CN3: quản lý trả lời (API)", rep.status === 200 || rep.status === 204, String(rep.status));
  }
  await page.reload();
  await mine.getByText("Cảm ơn bạn, size dài sẽ có từ tháng 12.").waitFor({ timeout: 5000 }).catch(() => {});
  ok("CN3: khách thấy câu trả lời của cửa hàng, trạng thái Đã trả lời", (await mine.locator("li").first().innerText()).includes("Đã trả lời") && (await mine.getByText("Uniqlo trả lời").count()) === 1);
  await shot(page, "05_phan-hoi-da-tra-loi");

  // ===== CN4. Nhận được khảo sát và thực hiện =====
  await page.goto(CRM + "/customer/surveys");
  await page.getByText("Hiện không có khảo sát nào chờ bạn.").waitFor();
  ok("CN4: khách mới chưa có khảo sát", true);
  // Quản lý tạo khảo sát đủ 4 loại câu hỏi, voucher 12%, gửi cho khách trên 90 tuổi (chỉ khách vừa đăng ký)
  const han = new Date(Date.now() + 7 * 864e5).toISOString();
  const ks = (await apiCall(ql, "POST", "/api/manager/surveys", { tieuDe: "E2E khảo sát khách " + stamp, mucDich: "DO_HAI_LONG", hanTraLoi: han, moTa: "Khảo sát kiểm thử", phanTramVoucher: 12, soNgayHieuLucVoucher: 30 })).json;
  const maKS = ks.maKS;
  for (const q of [
    { noiDung: "Bạn hài lòng với chất lượng sản phẩm ở mức nào?", loaiCauHoi: "THANG_DIEM", batBuoc: true },
    { noiDung: "Bạn thường mua sắm qua kênh nào?", loaiCauHoi: "MOT_LUA_CHON", batBuoc: true, luaChon: ["Tại cửa hàng", "Online", "Cả hai"] },
    { noiDung: "Bạn muốn cải thiện điều gì?", loaiCauHoi: "NHIEU_LUA_CHON", batBuoc: true, luaChon: ["Thêm size", "Thêm màu", "Giao nhanh hơn"] },
    { noiDung: "Góp ý thêm cho Uniqlo", loaiCauHoi: "TU_LUAN", batBuoc: false },
  ]) await apiCall(ql, "POST", `/api/manager/surveys/${maKS}/questions`, q);
  const sent = await apiCall(ql, "POST", `/api/manager/surveys/${maKS}/send`, { tuoiTu: 90 });
  ok("CN4: quản lý gửi khảo sát tới tài khoản khách", sent.status === 200, JSON.stringify(sent.json));

  await page.reload();
  const cho = page.getByRole("list", { name: "Khảo sát chờ thực hiện" });
  await cho.waitFor();
  ok("CN4: khách nhận được khảo sát (Chờ thực hiện, voucher 12%)", (await cho.innerText()).includes("E2E khảo sát khách " + stamp) && (await cho.innerText()).includes("12%"));
  await page.goto(CRM + "/customer");
  ok("CN4: trang chủ báo khảo sát chờ", await page.getByText("E2E khảo sát khách " + stamp).waitFor().then(() => true, () => false));
  await page.getByText("E2E khảo sát khách " + stamp).click();
  await page.waitForURL(CRM + `/customer/surveys/${maKS}`);
  await page.getByRole("heading", { name: "E2E khảo sát khách " + stamp }).waitFor();
  ok("CN4: mở khảo sát hiện đủ 4 câu hỏi", (await page.getByTestId("cau-hoi").count()) === 4);
  await page.getByRole("button", { name: "Gửi bài khảo sát" }).click();
  ok("CN4: nộp khi chưa trả lời → báo 3 câu bắt buộc", (await page.getByText("Còn 3 câu bắt buộc chưa trả lời.").count()) === 1 && (await page.getByText("Câu này bắt buộc trả lời.").count()) === 3);
  await page.getByRole("radio", { name: /^4 – Hài lòng/ }).click();
  await page.getByRole("radio", { name: "Online" }).check();
  await page.getByRole("checkbox", { name: "Thêm size" }).check();
  await page.getByRole("checkbox", { name: "Giao nhanh hơn" }).check();
  await page.getByLabel("Góp ý thêm cho Uniqlo").fill("Mong có thêm size lớn.");
  ok("CN4: đếm số câu đã trả lời", (await page.getByText("Đã trả lời 4/4 câu").count()) === 1);
  await shot(page, "06_lam-khao-sat");
  await page.getByRole("button", { name: "Gửi bài khảo sát" }).click();
  await page.getByText("Cảm ơn bạn đã hoàn thành khảo sát!").waitFor();
  const vc = await page.getByTestId("voucher-moi").innerText();
  ok("CN4: nộp xong nhận voucher 12%", vc.includes("-12%") && new RegExp(`V${maKS}-`).test(vc), vc.replace(/\n/g, " "));
  await shot(page, "07_nhan-voucher");
  await page.reload();
  await page.getByText("Bạn đã hoàn thành khảo sát này").waitFor();
  ok("CN4: mở lại → xem câu trả lời đã gửi, không sửa được", (await page.getByRole("radio", { name: "Online" }).isChecked()) && (await page.getByRole("radio", { name: "Online" }).isDisabled()) && (await page.getByRole("button", { name: "Gửi bài khảo sát" }).count()) === 0);
  const again = await apiCall(page, "POST", `/api/customer/surveys/${maKS}/submit`, { traLoi: [{ maCauHoi: 1, diemSo: 5 }] });
  ok("CN4: nộp lần 2 (gọi thẳng API) → bị từ chối", again.status >= 400, String(again.status));
  await page.goto(CRM + "/customer/surveys");
  const vlist = page.getByRole("list", { name: "Voucher của tôi" });
  await vlist.waitFor();
  ok("CN4: voucher hiện trong mục Khảo sát → Voucher, Còn hạn", (await vlist.innerText()).includes("Còn hạn") && (await vlist.innerText()).includes("-12%"));
  ok("CN4: khảo sát chuyển sang Đã hoàn thành", (await page.getByRole("list", { name: "Khảo sát đã hoàn thành hoặc đã đóng" }).innerText()).includes("Đã hoàn thành"));
  await shot(page, "08_danh-sach-khao-sat");
  const stats = await apiCall(ql, "GET", `/api/manager/surveys/${maKS}/stats`);
  // (chạy lại nhiều lần thì khách >90 tuổi của lần trước cũng nhận khảo sát, nên chỉ chắc chắn số hoàn thành = 1)
  ok("CN4: kết quả về trang Quản lý (hoàn thành 1)", stats.json.tongQuan.soNguoiNhan >= 1 && stats.json.tongQuan.soHoanThanh === 1, JSON.stringify(stats.json.tongQuan));

  // Khảo sát đã đóng: không làm được nữa
  const ks2 = (await apiCall(ql, "POST", "/api/manager/surveys", { tieuDe: "E2E khảo sát đóng " + stamp, mucDich: "DO_HAI_LONG", hanTraLoi: han, phanTramVoucher: 0, soNgayHieuLucVoucher: 30 })).json.maKS;
  await apiCall(ql, "POST", `/api/manager/surveys/${ks2}/questions`, { noiDung: "Điểm hài lòng?", loaiCauHoi: "THANG_DIEM", batBuoc: true });
  await apiCall(ql, "POST", `/api/manager/surveys/${ks2}/send`, { tuoiTu: 90 });
  await apiCall(ql, "POST", `/api/manager/surveys/${ks2}/close`);
  await page.goto(CRM + `/customer/surveys/${ks2}`);
  await page.getByText("Khảo sát đã đóng").first().waitFor();
  ok("CN4: khảo sát quản lý đã đóng → khách không làm được", (await page.getByRole("button", { name: "Gửi bài khảo sát" }).count()) === 0);
  const other = await apiCall(page, "GET", "/api/customer/surveys/2");
  await page.goto(CRM + "/customer/surveys/2");
  const notFound = await page.getByText("Không tìm thấy khảo sát").first().waitFor().then(() => true, () => false);
  ok("CN4: khảo sát không gửi cho mình → API 404, giao diện báo không tìm thấy", other.status === 404 && notFound, String(other.status));

  // Khách có sẵn dữ liệu mẫu: kh.an làm khảo sát mẫu số 2 trên điện thoại
  const mCtx = await browser.newContext({ locale: "vi-VN", viewport: { width: 390, height: 844 }, isMobile: true });
  const m = await mCtx.newPage();
  watch(m);
  await login(m, "kh.an");
  await m.waitForURL(CRM + "/customer");
  await m.goto(CRM + "/customer/surveys");
  await m.getByRole("list", { name: "Khảo sát chờ thực hiện" }).waitFor();
  await shot(m, "09_khao-sat_mobile");
  const noOverflow = await m.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1);
  ok("Mobile: danh sách khảo sát không tràn ngang", noOverflow);
  await m.goto(CRM + "/customer/surveys/2");
  await m.getByTestId("cau-hoi").first().waitFor();
  if (await m.getByText("Bạn đã hoàn thành khảo sát này").count()) {
    ok("kh.an (dữ liệu mẫu): khảo sát số 2 đã làm ở lần chạy trước → chỉ xem lại", true);
  } else {
    const n2 = await m.getByTestId("cau-hoi").count();
    for (let i = 0; i < n2; i++) {
      const block = m.getByTestId("cau-hoi").nth(i);
      if (await block.getByRole("radio", { name: /^5 – / }).count()) await block.getByRole("radio", { name: /^5 – / }).click();
      else if (await block.locator("input[type=radio]").count()) await block.locator("input[type=radio]").first().check();
      else if (await block.locator("input[type=checkbox]").count()) await block.locator("input[type=checkbox]").first().check();
      else await block.locator("textarea").fill("Áo rất nhẹ.");
    }
    await m.getByRole("button", { name: "Gửi bài khảo sát" }).click();
    await m.getByText("Cảm ơn bạn đã hoàn thành khảo sát!").waitFor({ timeout: 5000 }).catch(() => {});
    ok("kh.an (dữ liệu mẫu) làm khảo sát số 2 trên điện thoại → voucher 5%", (await m.getByTestId("voucher-moi").innerText().catch(() => "")).includes("-5%"));
  }
  await shot(m, "10_nop-khao-sat_mobile");

  ok("Không có lỗi JavaScript trên trang", errors.length === 0, errors.join(" | "));
  await browser.close();

  const out = results.join("\n");
  console.log(out);
  const fail = results.filter((r) => r.startsWith("FAIL")).length;
  console.log(`\n${results.length - fail}/${results.length} PASS`);
  fs.writeFileSync(path.join(__dirname, "../../docs/KetQua_E2E_KhachHang.txt"), out + `\n\n${results.length - fail}/${results.length} PASS\n`);
  process.exit(fail ? 1 : 0);
})().catch((e) => {
  console.error(results.join("\n"));
  console.error(e);
  process.exit(1);
});
