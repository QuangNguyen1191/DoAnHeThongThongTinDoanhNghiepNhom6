// Kiểm thử đầu cuối trang Quản lý (7 chức năng của người quản lý, đề III.4) trên giao diện thật + API thật + CSDL dữ liệu mẫu.
//   1 Thêm khách hàng · 2 Xóa khách hàng · 3 Khóa tài khoản · 4 Tiếp nhận phản hồi · 5 Báo cáo độ tuổi, sở thích
//   6 Tạo khảo sát và gửi tới tài khoản khách hàng · 7 Thống kê kết quả khảo sát · và phân quyền NV CSKH.
// Cần: API chạy ở 5000 (Development) + máy chủ Vite web-crm (npm run dev:crm, cổng 5173).
// Chạy: npm i --no-save playwright && npx playwright install chromium && node tests/e2e/trang-quan-ly.cjs
// LƯU Ý: kịch bản GHI dữ liệu (thêm/xóa khách, khóa/mở kh.binh, xử lý phản hồi, tạo và gửi khảo sát) – chỉ chạy trên CSDL thử nghiệm.
const { chromium } = require("playwright");
const path = require("node:path");
const fs = require("node:fs");
const CRM = process.env.CRM_URL || "http://localhost:5173";
const SHOTS = path.join(__dirname, "../../docs/anh-chup/quan-ly") + "/";
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

(async () => {
  const browser = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  const newCtx = () => browser.newContext({ locale: "vi-VN", viewport: { width: 1440, height: 900 } });
  const errors = [];
  const watch = (p) => p.on("pageerror", (e) => errors.push(e.message));
  const stamp = Date.now().toString().slice(-8);

  // 0. Đăng nhập Quản lý, trang tổng quan có lối tắt 7 chức năng
  const ctx = await newCtx();
  const page = await ctx.newPage();
  watch(page);
  await login(page, "ql.lan");
  await page.waitForURL(CRM + "/manager");
  await page.getByRole("navigation", { name: "Chức năng quản lý" }).waitFor();
  ok("Tổng quan: đủ 7 lối tắt chức năng", (await page.getByRole("navigation", { name: "Chức năng quản lý" }).getByRole("link").count()) === 7);
  await page.getByText("Khách hàng đang hoạt động").waitFor();
  await page.waitForTimeout(300);
  await shot(page, "01_tong-quan");

  // Danh sách khách hàng + lọc
  await page.goto(CRM + "/manager/customers");
  await page.getByRole("table", { name: "Danh sách khách hàng" }).waitFor();
  const total = Number((await page.getByText(/^\d+ khách hàng$/).innerText()).split(" ")[0]);
  ok("Danh sách khách hàng đọc API thật", total >= 10, `${total} khách`);
  await page.getByLabel("Hạng thành viên").selectOption("VIP");
  await page.getByRole("button", { name: "Tìm kiếm" }).click();
  await page.waitForTimeout(600);
  const vip = Number((await page.getByText(/^\d+ khách hàng$/).innerText()).split(" ")[0]);
  ok("Lọc theo hạng VIP", vip > 0 && vip < total, `${vip} khách VIP`);
  await shot(page, "02_danh-sach-khach-hang");

  // 1. Thêm khách hàng mới (cấp luôn tài khoản)
  const sdt = "09" + stamp;
  const ten = "kh.e2e" + stamp;
  await page.goto(CRM + "/manager/customers/new");
  await page.getByRole("button", { name: "Thêm khách hàng" }).click();
  ok("CN1: thiếu họ tên/SĐT → báo lỗi tại ô", (await page.getByText("Họ tên là bắt buộc.").count()) === 1);
  await page.getByLabel("Họ tên").fill("Khách Kiểm Thử " + stamp);
  await page.getByLabel("Số điện thoại").fill("0901000001");
  await page.getByLabel("Giới tính").selectOption("NU");
  await page.getByLabel("Ngày sinh").fill("1999-05-20");
  await page.getByLabel("Tỉnh/thành").selectOption({ index: 1 });
  await page.getByRole("group", { name: "Loại sản phẩm quan tâm" }).getByRole("button").first().click();
  await page.getByLabel("Tên đăng nhập").fill(ten);
  await page.getByRole("button", { name: "Thêm khách hàng" }).click();
  await page.waitForTimeout(800);
  const dupMsg = await page.locator("text=/Số điện thoại.*(đã|tồn tại)/").count();
  ok("CN1: SĐT trùng khách khác → báo lỗi ở ô SĐT", dupMsg >= 1);
  await page.getByLabel("Số điện thoại").fill(sdt);
  await page.getByRole("button", { name: "Thêm khách hàng" }).click();
  await page.getByText("Đã cấp tài khoản cho khách hàng").waitFor();
  const tempPw = await page.getByTestId("mat-khau-tam").innerText();
  ok("CN1: thêm khách + cấp tài khoản, hiện mật khẩu tạm 1 lần", tempPw.length >= 10, ten);
  await shot(page, "03_them-khach-hang");
  await page.getByRole("button", { name: "Xem hồ sơ" }).click();
  await page.getByRole("heading", { name: "Khách Kiểm Thử " + stamp }).waitFor();
  const newUrl = page.url();
  ok("CN1: hồ sơ 360° của khách mới", (await page.getByText(sdt).count()) === 1);

  // Khách mới đăng nhập bằng mật khẩu tạm → buộc đổi mật khẩu
  const kctx = await newCtx();
  const kpage = await kctx.newPage();
  watch(kpage);
  await login(kpage, ten, tempPw);
  await kpage.waitForURL(/change-password/);
  ok("CN1: khách mới đăng nhập bằng mật khẩu tạm → bắt buộc đổi mật khẩu", true);
  await kctx.close();

  // 3. Khóa tài khoản khách hàng: khóa kh.binh, kh.binh không đăng nhập được, rồi mở lại
  await page.goto(CRM + "/manager/customers");
  await page.getByLabel("Từ khóa").fill("Bình");
  await page.getByRole("button", { name: "Tìm kiếm" }).click();
  await page.waitForTimeout(600);
  await page.getByRole("table", { name: "Danh sách khách hàng" }).getByRole("link").first().click();
  await page.getByRole("button", { name: "Khóa tài khoản" }).click();
  const dlg = page.getByRole("alertdialog");
  ok("CN3: khóa cần lý do (nút bị khóa khi trống)", await dlg.getByRole("button", { name: "Khóa tài khoản" }).isDisabled());
  await dlg.getByLabel("Lý do khóa").fill("Kiểm thử e2e: nghi ngờ lạm dụng voucher");
  await dlg.getByRole("button", { name: "Khóa tài khoản" }).click();
  await page.getByRole("button", { name: "Mở khóa tài khoản" }).waitFor();
  ok("CN3: trạng thái chuyển Đã khóa", (await page.getByText("Tài khoản đang bị khóa").count()) === 1);
  await shot(page, "04_khoa-tai-khoan");
  const bctx = await newCtx();
  const bpage = await bctx.newPage();
  await login(bpage, "kh.binh");
  await bpage.waitForTimeout(1200);
  ok("CN3: kh.binh bị khóa → không đăng nhập được", /khóa/i.test(await bpage.locator("#login-error").innerText().catch(() => "")));
  await page.getByRole("button", { name: "Mở khóa tài khoản" }).click();
  await page.getByRole("alertdialog").getByRole("button", { name: "Mở khóa" }).click();
  await page.getByRole("button", { name: "Khóa tài khoản" }).waitFor();
  await login(bpage, "kh.binh");
  await bpage.waitForURL(CRM + "/customer");
  ok("CN3: mở khóa → kh.binh đăng nhập lại được", true);
  await bctx.close();

  // 2. Xóa khách hàng (xóa mềm) khách vừa tạo
  await page.goto(newUrl);
  await page.getByRole("button", { name: "Xóa khách hàng" }).click();
  const del = page.getByRole("alertdialog");
  await del.getByLabel("Lý do xóa").fill("Kiểm thử e2e: khách yêu cầu xóa dữ liệu");
  await del.getByRole("button", { name: "Xóa khách hàng" }).click();
  await page.getByText("Hồ sơ đã bị xóa").first().waitFor();
  ok("CN2: xóa mềm → hồ sơ Đã xóa, ẩn nút thao tác", (await page.getByRole("button", { name: "Sửa" }).count()) === 0);
  await shot(page, "05_xoa-khach-hang");
  await page.goto(CRM + "/manager/customers");
  await page.getByLabel("Từ khóa").fill(sdt);
  await page.getByRole("button", { name: "Tìm kiếm" }).click();
  await page.waitForTimeout(600);
  ok("CN2: không còn trong danh sách đang hoạt động", (await page.getByText("Không có khách hàng nào khớp bộ lọc.").count()) === 1);
  await page.getByLabel("Trạng thái hồ sơ").selectOption("DA_XOA");
  await page.getByRole("button", { name: "Tìm kiếm" }).click();
  await page.waitForTimeout(600);
  ok("CN2: xuất hiện ở bộ lọc Đã xóa", (await page.getByText("Hồ sơ đã xóa").count()) >= 1);

  // 4. Tiếp nhận phản hồi
  await page.goto(CRM + "/manager/feedback");
  await page.getByText(/^\d+ phản hồi$/).waitFor();
  const moi = Number((await page.getByText(/^\d+ phản hồi$/).innerText()).split(" ")[0]);
  ok("CN4: tab Mới có phản hồi chờ tiếp nhận", moi > 0, `${moi} phản hồi mới`);
  await shot(page, "06_phan-hoi");
  const first = page.locator("[data-testid^=ph-]").first();
  const maPH = (await first.getAttribute("data-testid")).slice(3);
  await first.getByLabel("Phân loại").selectOption("KHIEU_NAI");
  await first.getByRole("button", { name: "Tiếp nhận" }).click();
  await page.waitForTimeout(900);
  ok("CN4: tiếp nhận → rời tab Mới", (await page.locator(`[data-testid=ph-${maPH}]`).count()) === 0);
  await page.getByRole("tab", { name: "Đang xử lý" }).click();
  const item = page.locator(`[data-testid=ph-${maPH}]`);
  await item.waitFor();
  ok("CN4: phân loại lại Khiếu nại", (await item.getByText("Khiếu nại").count()) >= 1);
  await item.getByRole("button", { name: "Trả lời" }).click();
  await item.getByLabel("Nội dung trả lời khách hàng").fill("Cảm ơn anh/chị, cửa hàng sẽ liên hệ đổi sản phẩm trong 24 giờ.");
  await item.getByRole("button", { name: "Gửi trả lời" }).click();
  await page.waitForTimeout(900);
  await page.getByRole("tab", { name: "Đã xử lý" }).click();
  await page.locator(`[data-testid=ph-${maPH}]`).waitFor();
  ok("CN4: trả lời → Đã xử lý, hiện nội dung trả lời", (await page.locator(`[data-testid=ph-${maPH}]`).getByText("cửa hàng sẽ liên hệ").count()) === 1);
  await shot(page, "07_phan-hoi-da-xu-ly");

  // 5. Báo cáo độ tuổi, sở thích
  await page.goto(CRM + "/manager/reports");
  await page.getByRole("list", { name: "Tỷ lệ khách hàng theo nhóm tuổi" }).waitFor();
  const ageRows = await page.getByRole("list", { name: "Tỷ lệ khách hàng theo nhóm tuổi" }).getByRole("listitem").count();
  ok("CN5: tỷ lệ theo nhóm tuổi", ageRows >= 2, `${ageRows} nhóm`);
  await shot(page, "08_bao-cao-do-tuoi");
  const csv = await page.evaluate(async () => {
    const r = await fetch("/api/manager/reports/demographics?format=csv&bang=nhomTuoi");
    return { type: r.headers.get("content-type"), text: await r.text() };
  });
  ok("CN5: tải CSV nhóm tuổi", /text\/csv/.test(csv.type) && /NhomTuoi/.test(csv.text));
  await page.getByRole("tab", { name: "Sở thích" }).click();
  await page.getByRole("list", { name: "Tỷ lệ khách quan tâm từng loại sản phẩm" }).waitFor();
  ok("CN5: sở thích theo loại SP và theo nhóm tuổi", (await page.getByRole("table", { name: "Sở thích theo nhóm tuổi" }).count()) === 1);
  await shot(page, "09_bao-cao-so-thich");

  // 6. Tạo khảo sát, thêm câu hỏi, gửi tới tài khoản khách hàng
  await page.goto(CRM + "/manager/surveys/new");
  const tieuDe = "Khảo sát e2e " + stamp;
  await page.getByLabel("Tiêu đề").fill(tieuDe);
  await page.getByLabel("Voucher tặng khi hoàn thành (%)").fill("10");
  await page.getByRole("button", { name: "Tạo khảo sát nháp" }).click();
  await page.getByRole("heading", { name: tieuDe }).waitFor();
  const maKS = Number(page.url().split("/").pop());
  ok("CN6: tạo khảo sát nháp", maKS > 0, `MaKS ${maKS}`);
  const addQ = async (text, loai, choices = []) => {
    await page.getByLabel("Nội dung câu hỏi").fill(text);
    await page.getByLabel("Loại câu hỏi").selectOption(loai);
    for (let i = 0; i < choices.length; i++) {
      if (i >= 2) await page.getByRole("button", { name: "Thêm lựa chọn" }).click();
      await page.getByLabel(`Lựa chọn ${i + 1}`, { exact: true }).fill(choices[i]);
    }
    await page.getByRole("button", { name: "Thêm câu hỏi" }).click();
    await page.getByText(text).first().waitFor();
    await page.waitForTimeout(300);
  };
  await addQ("Bạn hài lòng với chất lượng sản phẩm ở mức nào?", "THANG_DIEM");
  await addQ("Bạn thường mua sắm qua kênh nào?", "MOT_LUA_CHON", ["Tại cửa hàng", "Trực tuyến", "Cả hai"]);
  await addQ("Góp ý thêm cho Uniqlo", "TU_LUAN");
  ok("CN6: thêm 3 câu hỏi (thang điểm, một lựa chọn, tự luận)", (await page.getByText(/^Câu hỏi \(3\)$/).count()) === 1);
  await shot(page, "10_soan-khao-sat");
  await page.getByLabel("Hạng").selectOption("VIP");
  await page.getByRole("button", { name: "Xem trước số người nhận" }).click();
  await page.getByTestId("so-nguoi-nhan").waitFor();
  const preview = Number((await page.getByTestId("so-nguoi-nhan").innerText()).match(/\d+/)[0]);
  ok("CN6: xem trước số khách VIP sẽ nhận", preview > 0, `${preview} khách`);
  await page.getByRole("button", { name: "Gửi khảo sát" }).click();
  await page.getByText(/Đã gửi khảo sát tới \d+ tài khoản/).waitFor();
  await page.waitForTimeout(500);
  ok("CN6: gửi → trạng thái Đã gửi", (await page.getByText("Đã gửi", { exact: true }).count()) >= 1);
  await shot(page, "11_gui-khao-sat");

  // Khách VIP kh.an thấy khảo sát trong tài khoản và nộp bài (qua API cổng Khách hàng)
  const actx = await newCtx();
  const apage = await actx.newPage();
  await login(apage, "kh.an");
  await apage.waitForURL(CRM + "/customer");
  const mine = await apiCall(apage, "GET", "/api/customer/surveys");
  ok("CN6: khảo sát xuất hiện trong tài khoản kh.an", mine.json.some((s) => s.maKS === maKS));
  const detail = await apiCall(apage, "GET", `/api/customer/surveys/${maKS}`);
  const [c1, c2, c3] = detail.json.cauHoi;
  const lc = detail.json.luaChon.find((l) => l.maCauHoi === c2.maCauHoi);
  const submit = await apiCall(apage, "POST", `/api/customer/surveys/${maKS}/submit`, {
    traLoi: [
      { maCauHoi: c1.maCauHoi, diemSo: 4 },
      { maCauHoi: c2.maCauHoi, maLC: lc.maLC },
      { maCauHoi: c3.maCauHoi, noiDungTuLuan: "Mong có thêm size lớn." },
    ],
  });
  ok("CN6: kh.an nộp khảo sát, nhận voucher", submit.status === 200 && !!submit.json.voucher, submit.json?.voucher?.maCode ?? JSON.stringify(submit.json));
  await actx.close();

  // 7. Thống kê kết quả khảo sát
  await page.goto(`${CRM}/manager/surveys/${maKS}/stats`);
  await page.getByText("Tỷ lệ phản hồi").waitFor();
  const done = await page.locator("text=Đã hoàn thành").locator("xpath=..").innerText();
  ok("CN7: thống kê có 1 người hoàn thành", /^Đã hoàn thành\s+1\s/.test(done), done.replace(/\n/g, " "));
  ok("CN7: điểm trung bình câu thang điểm = 4", (await page.getByText(/^4$/).count()) >= 1);
  ok("CN7: phân bố lựa chọn và câu tự luận", (await page.getByText("“Mong có thêm size lớn.”").count()) === 1);
  await shot(page, "12_thong-ke-khao-sat");
  await page.goto(`${CRM}/manager/surveys/2/stats`);
  await page.getByText("Tỷ lệ phản hồi").waitFor();
  await page.waitForTimeout(400);
  await shot(page, "13_thong-ke-khao-sat-mau");

  // Đóng khảo sát
  await page.goto(`${CRM}/manager/surveys/${maKS}`);
  await page.getByRole("button", { name: "Đóng khảo sát" }).click();
  await page.getByRole("alertdialog").getByRole("button", { name: "Đóng khảo sát" }).click();
  await page.getByText("Khảo sát đã đóng").waitFor();
  ok("CN6: đóng khảo sát", true);
  await ctx.close();

  // Phân quyền: NV CSKH không có Thêm/Xóa/Khóa/Báo cáo nhưng xử lý được phản hồi
  const cctx = await newCtx();
  const cpage = await cctx.newPage();
  watch(cpage);
  await login(cpage, "cskh.hoa");
  await cpage.waitForURL(CRM + "/manager");
  await cpage.goto(CRM + "/manager/customers");
  await cpage.getByRole("table", { name: "Danh sách khách hàng" }).waitFor();
  ok("CSKH: không có nút Thêm khách hàng", (await cpage.getByRole("button", { name: "Thêm khách hàng" }).count()) === 0);
  await cpage.getByRole("table", { name: "Danh sách khách hàng" }).getByRole("link").first().click();
  await cpage.getByText("Thông tin", { exact: true }).waitFor();
  ok("CSKH: hồ sơ không có nút Xóa / Khóa", (await cpage.getByRole("button", { name: /Xóa khách hàng|Khóa tài khoản/ }).count()) === 0);
  ok("CSKH: menu không có Báo cáo", (await cpage.getByRole("navigation", { name: "Điều hướng chính" }).getByText("Báo cáo").count()) === 0);
  await cpage.goto(CRM + "/manager/customers/new");
  await cpage.getByText("Không có quyền truy cập").waitFor({ timeout: 5000 }).catch(() => {});
  ok("CSKH: gõ URL thêm khách → không có quyền", (await cpage.getByText("Không có quyền truy cập").count()) === 1);
  const apiDel = await apiCall(cpage, "DELETE", "/api/manager/customers/1", { lyDo: "thử" });
  ok("CSKH: gọi thẳng API xóa → 403 (CSDL chặn 50003)", apiDel.status === 403, String(apiDel.status));
  await cpage.goto(CRM + "/manager/feedback");
  await cpage.getByText(/^\d+ phản hồi$/).waitFor();
  ok("CSKH: xử lý được phản hồi (có nút Tiếp nhận)", (await cpage.getByRole("button", { name: "Tiếp nhận" }).count()) > 0);
  await cctx.close();

  ok("Không có lỗi JavaScript trên trang", errors.length === 0, errors.join(" | "));
  await browser.close();
  const out = results.join("\n");
  console.log(out);
  const pass = results.filter((r) => r.startsWith("PASS")).length;
  console.log(`\nTỔNG: ${pass}/${results.length} PASS`);
  fs.writeFileSync(path.join(__dirname, "../../docs/KetQua_E2E_QuanLy.txt"), out + `\n\nTỔNG: ${pass}/${results.length} PASS\n`);
  process.exit(pass === results.length ? 0 : 1);
})().catch((e) => {
  console.log(results.join("\n"));
  console.error(e);
  process.exit(1);
});
