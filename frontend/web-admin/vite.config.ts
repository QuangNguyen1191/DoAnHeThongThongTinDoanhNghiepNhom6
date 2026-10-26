import { defineConfig } from "vite";
import { defineCrmApp } from "../shared/vite.shared";

// web-admin: chỉ khu vực Quản trị → API cổng 5001 (/api/admin/* chỉ trả lời ở cổng này)
export default defineConfig(defineCrmApp(__dirname, 5174, process.env.ADMIN_API ?? "http://localhost:5001"));
