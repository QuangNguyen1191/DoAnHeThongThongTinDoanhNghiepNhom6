import { createBrowserRouter, Navigate } from "react-router";
import { BriefcaseBusiness, FileText, KeyRound, LayoutDashboard, ScrollText, Search, ServerCog, UserRound, UsersRound } from "lucide-react";
import { AppRoot } from "@shared/app/AppRoot";
import { useAuth } from "@shared/auth/AuthProvider";
import { PublicOnly, RequirePermission, RequirePortal, RequireSession } from "@shared/auth/guards";
import { homeHref } from "@shared/auth/redirect";
import { PortalLayout, type NavItem } from "@shared/layouts/PortalLayout";
import { AccountPage } from "@shared/pages/AccountPage";
import { ChangePasswordPage } from "@shared/pages/auth/ChangePasswordPage";
import { ForgotPasswordPage } from "@shared/pages/auth/ForgotPasswordPage";
import { LoginPage } from "@shared/pages/auth/LoginPage";
import { ResetPasswordPage } from "@shared/pages/auth/ResetPasswordPage";
import { ForbiddenScreen, NotFoundScreen } from "@shared/pages/StatusScreens";
import { AccountsPage } from "./pages/AccountsPage";
import { AdminHome } from "./pages/AdminHome";
import { AuditLogPage } from "./pages/AuditLogPage";
import { CustomerLookupPage } from "./pages/CustomerLookupPage";
import { EmployeesPage } from "./pages/EmployeesPage";
import { InvoiceFormPage } from "./pages/InvoiceFormPage";
import { InvoicesPage } from "./pages/InvoicesPage";
import { RolesPage } from "./pages/RolesPage";
import { SystemPage } from "./pages/SystemPage";

const NAV: NavItem[] = [
  { to: "/admin", label: "Tổng quan", icon: LayoutDashboard, end: true },
  { to: "/admin/accounts", label: "Tài khoản", icon: UsersRound, any: ["AD_TAI_KHOAN"] },
  { to: "/admin/roles", label: "Vai trò và quyền", icon: KeyRound, any: ["AD_PHAN_QUYEN"] },
  { to: "/admin/employees", label: "Nhân viên", icon: BriefcaseBusiness, any: ["AD_TRA_CUU"] },
  { to: "/admin/customers", label: "Tra cứu khách hàng", icon: Search, any: ["AD_TRA_CUU"] },
  { to: "/admin/invoices", label: "Hóa đơn, đổi trả", icon: FileText, any: ["AD_NAP_GIAO_DICH"] },
  { to: "/admin/audit-log", label: "Nhật ký", icon: ScrollText, any: ["AD_NHAT_KY"] },
  { to: "/admin/system", label: "Trạng thái hệ thống", icon: ServerCog },
  { to: "/admin/account", label: "Tài khoản của tôi", icon: UserRound },
];

const guard = (any: string[], el: React.ReactNode) => <RequirePermission any={any}>{el}</RequirePermission>;

function ForbiddenRoute() {
  const { session, logout } = useAuth();
  return <ForbiddenScreen homeHref={session ? homeHref(session.cong, "admin") : "/login"} onLogout={session ? () => void logout() : undefined} />;
}

export const router = createBrowserRouter([
  {
    element: <AppRoot app="admin" />,
    children: [
      { path: "/", element: <Navigate to="/admin" replace /> },
      // Trang đăng nhập riêng của Admin: API ở cổng web-admin chỉ nhận tài khoản Admin.
      { path: "/login", element: <PublicOnly><LoginPage /></PublicOnly> },
      { path: "/forgot-password", element: <PublicOnly><ForgotPasswordPage /></PublicOnly> },
      { path: "/dat-lai-mat-khau", element: <ResetPasswordPage /> },
      { path: "/change-password", element: <RequireSession><ChangePasswordPage /></RequireSession> },
      { path: "/forbidden", element: <ForbiddenRoute /> },
      {
        path: "/admin",
        element: (
          <RequirePortal cong="ADMIN">
            <PortalLayout nav={NAV} accountPath="/admin/account" />
          </RequirePortal>
        ),
        children: [
          { index: true, element: <AdminHome /> },
          { path: "accounts", element: guard(["AD_TAI_KHOAN"], <AccountsPage />) },
          { path: "roles", element: guard(["AD_PHAN_QUYEN"], <RolesPage />) },
          { path: "employees", element: guard(["AD_TRA_CUU"], <EmployeesPage />) },
          { path: "customers", element: guard(["AD_TRA_CUU"], <CustomerLookupPage />) },
          { path: "invoices", element: guard(["AD_NAP_GIAO_DICH"], <InvoicesPage />) },
          { path: "invoices/new", element: guard(["AD_NAP_GIAO_DICH"], <InvoiceFormPage />) },
          { path: "audit-log", element: guard(["AD_NHAT_KY"], <AuditLogPage />) },
          { path: "system", element: <SystemPage /> },
          { path: "account", element: <AccountPage /> },
          { path: "*", element: <NotFoundScreen homeHref="/admin" /> },
        ],
      },
      { path: "*", element: <NotFoundScreen homeHref="/admin" /> },
    ],
  },
]);
