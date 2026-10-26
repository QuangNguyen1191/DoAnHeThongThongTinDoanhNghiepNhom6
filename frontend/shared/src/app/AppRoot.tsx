import type { ReactNode } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Outlet } from "react-router";
import { isApiError } from "../api/errors";
import { AuthProvider, type AppKind } from "../auth/AuthProvider";
import { SessionWatcher } from "../auth/SessionWatcher";
import { ToastProvider } from "../ui/Toast";

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      // Không thử lại lỗi 4xx (401/403/404/422…): chỉ thử lại lỗi mạng / 5xx.
      retry: (count, e) => (!isApiError(e) || e.isNetwork || e.status >= 500) && count < 2,
    },
  },
});

/** Phần tử gốc của router: Toast → Auth (cần router để điều hướng) → cảnh báo hết phiên. */
export function AppRoot({ app }: { app: AppKind }) {
  return (
    <ToastProvider>
      <AuthProvider app={app}>
        <SessionWatcher />
        <Outlet />
      </AuthProvider>
    </ToastProvider>
  );
}

export function Providers({ children }: { children: ReactNode }) {
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
}
