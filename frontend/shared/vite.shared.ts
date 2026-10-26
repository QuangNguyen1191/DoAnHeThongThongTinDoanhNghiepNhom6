import path from "node:path";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import type { UserConfig } from "vite";

/**
 * Cấu hình Vite dùng chung cho web-crm và web-admin.
 * Dev: proxy /api tới đúng cổng của API (README backend mục 4.1), cùng origin nên không cần CORS.
 * API kiểm header Origin ở mọi request ghi; trình duyệt gửi Origin của máy chủ Vite (vd. :5173)
 * nên proxy đổi Origin thành địa chỉ API để khớp kiểm tra cùng máy chủ.
 */
export function defineCrmApp(appDir: string, port: number, apiTarget: string): UserConfig {
  return {
    root: appDir,
    envDir: path.resolve(appDir, ".."),
    plugins: [react(), tailwindcss()],
    resolve: { alias: { "@shared": path.resolve(appDir, "../shared/src") } },
    server: {
      port,
      strictPort: true,
      proxy: {
        "/api": {
          target: apiTarget,
          changeOrigin: true,
          configure: (proxy) => {
            proxy.on("proxyReq", (proxyReq) => {
              if (proxyReq.getHeader("origin")) proxyReq.setHeader("origin", apiTarget);
            });
          },
        },
      },
    },
    preview: { port, strictPort: true },
    build: {
      outDir: "dist",
      emptyOutDir: true,
      rollupOptions: {
        output: {
          manualChunks: {
            react: ["react", "react-dom", "react-router"],
            data: ["@tanstack/react-query", "react-hook-form", "@hookform/resolvers", "zod"],
          },
        },
      },
    },
  };
}
