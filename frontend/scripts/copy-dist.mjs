// Chép bản build vào wwwroot của API để API tự phục vụ theo cổng (README backend mục 4.1):
//   web-crm/dist  → <backend>/src/CrmUniqlo.Api/wwwroot/web-crm   (cổng 5000)
//   web-admin/dist → <backend>/src/CrmUniqlo.Api/wwwroot/web-admin (cổng 5001)
// Dùng: npm run build && npm run publish:api [-- <đường dẫn thư mục backend>]
import { cpSync, existsSync, rmSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const backend = path.resolve(process.argv[2] ?? path.join(root, "..", "backend"));
const wwwroot = path.join(backend, "src", "CrmUniqlo.Api", "wwwroot");

if (!existsSync(path.join(backend, "src", "CrmUniqlo.Api"))) {
  console.error(`Không thấy dự án API trong ${backend}. Truyền đường dẫn thư mục backend làm tham số.`);
  process.exit(1);
}
for (const app of ["web-crm", "web-admin"]) {
  const src = path.join(root, app, "dist");
  if (!existsSync(path.join(src, "index.html"))) {
    console.error(`Chưa có bản build ${app}. Chạy "npm run build" trước.`);
    process.exit(1);
  }
  const dest = path.join(wwwroot, app);
  rmSync(dest, { recursive: true, force: true });
  cpSync(src, dest, { recursive: true });
  console.log(`✓ ${app}/dist → ${path.relative(root, dest)}`);
}
