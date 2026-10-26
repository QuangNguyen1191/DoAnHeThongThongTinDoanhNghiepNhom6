import { defineConfig } from "vite";
import { defineCrmApp } from "../shared/vite.shared";

// web-crm: /login, /register, /forgot-password, /change-password, /manager/*, /customer/* → API cổng 5000
export default defineConfig(defineCrmApp(__dirname, 5173, process.env.CRM_API ?? "http://localhost:5000"));
