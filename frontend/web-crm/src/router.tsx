import { createBrowserRouter, Navigate } from "react-router";
import {
  ClipboardList, Settings, FileBarChart2, House, LayoutDashboard, MessageSquareText, UserRound, UsersRound,
} from "lucide-react";
import { AppRoot } from "@shared/app/AppRoot";
import { useAuth } from "@shared/auth/AuthProvider";
import { PublicOnly, RequirePermission, RequirePortal, RequireSession } from "@shared/auth/guards";
import { destinationAfterLogin, homeHref } from "@shared/auth/redirect";
import { PortalLayout, type NavItem } from "@shared/layouts/PortalLayout";
import { AccountPage } from "@shared/pages/AccountPage";
import { ForbiddenScreen, FullPageLoader, NotFoundScreen } from "@shared/pages/StatusScreens";
import { ChangePasswordPage } from "@shared/pages/auth/ChangePasswordPage";
import { ForgotPasswordPage } from "@shared/pages/auth/ForgotPasswordPage";
import { LoginPage } from "@shared/pages/auth/LoginPage";
import { ResetPasswordPage } from "@shared/pages/auth/ResetPasswordPage";
import { RegisterPage } from "./pages/auth/RegisterPage";
import { CustomerHome } from "./pages/customer/CustomerHome";
import { FeedbackPage as MyFeedbackPage } from "./pages/customer/FeedbackPage";
import { ProfilePage } from "./pages/customer/ProfilePage";
import { SurveysPage as MySurveysPage } from "./pages/customer/SurveysPage";
import { SurveyTakePage } from "./pages/customer/SurveyTakePage";
import { CustomerDetailPage } from "./pages/manager/CustomerDetailPage";
import { CustomerFormPage } from "./pages/manager/CustomerFormPage";
import { CustomersPage } from "./pages/manager/CustomersPage";
import { FeedbackPage } from "./pages/manager/FeedbackPage";
import { ManagerHome } from "./pages/manager/ManagerHome";
import { ReportsPage } from "./pages/manager/ReportsPage";
import { SurveyDetailPage } from "./pages/manager/SurveyDetailPage";
import { SurveyCreatePage, SurveysPage } from "./pages/manager/SurveysPage";
import { SurveyStatsPage } from "./pages/manager/SurveyStatsPage";

/** Quyền theo bảng route mục 7 của đặc tả FrontEnd. */
const P = {
  khXem: ["QL_KH_XEM"],
  phXem: ["QL_PH_XEM"],
  ks: ["QL_KS_THONG_KE", "QL_KS_QUAN_LY", "QL_KS_GUI"],
  baoCao: ["QL_BAO_CAO"],
  hoSo: ["KH_HO_SO"],
  khaoSat: ["KH_KHAO_SAT"],
  phanHoi: ["KH_PHAN_HOI"],
} as const;

const MANAGER_NAV: NavItem[] = [
  { to: "/manager", label: "Tổng quan", icon: LayoutDashboard, end: true },
  { to: "/manager/customers", label: "Khách hàng", icon: UsersRound, any: P.khXem },
  { to: "/manager/feedback", label: "Phản hồi", icon: MessageSquareText, any: P.phXem },
  { to: "/manager/surveys", label: "Khảo sát", icon: ClipboardList, any: P.ks },
  { to: "/manager/reports", label: "Báo cáo", icon: FileBarChart2, any: P.baoCao },
  { to: "/manager/account", label: "Tài khoản của tôi", icon: UserRound },
];

/** 5 chức năng khách hàng (đề III.4): đăng ký, đăng nhập (trang chung), chỉnh sửa thông tin, gửi phản hồi, thực hiện khảo sát. */
const CUSTOMER_NAV: NavItem[] = [
  { to: "/customer", label: "Trang chủ", icon: House, end: true },
  { to: "/customer/profile", label: "Thông tin cá nhân", icon: UserRound, any: P.hoSo },
  { to: "/customer/feedback", label: "Phản hồi sản phẩm", icon: MessageSquareText, any: P.phanHoi },
  { to: "/customer/surveys", label: "Khảo sát", icon: ClipboardList, any: P.khaoSat },
  { to: "/customer/account", label: "Đổi mật khẩu", icon: Settings },
];

const guard = (any: readonly string[], el: React.ReactNode) => <RequirePermission any={any}>{el}</RequirePermission>;

/** "/" → khu vực của phiên, hoặc /login. */
function HomeRedirect() {
  const { session, status } = useAuth();
  if (status === "loading") return <FullPageLoader />;
  if (!session) return <Navigate to="/login" replace />;
  const dest = destinationAfterLogin(session, null, "crm");
  if (dest.external) {
    window.location.replace(dest.external);
    return <FullPageLoader label="Đang chuyển sang khu vực Quản trị…" />;
  }
  return <Navigate to={dest.internal!} replace />;
}

function ForbiddenRoute() {
  const { session, logout } = useAuth();
  return <ForbiddenScreen homeHref={session ? homeHref(session.cong, "crm") : "/login"} onLogout={session ? () => void logout() : undefined} />;
}

export const router = createBrowserRouter([
  {
    element: <AppRoot app="crm" />,
    children: [
      { path: "/", element: <HomeRedirect /> },
      { path: "/login", element: <PublicOnly><LoginPage /></PublicOnly> },
      { path: "/register", element: <PublicOnly><RegisterPage /></PublicOnly> },
      { path: "/forgot-password", element: <PublicOnly><ForgotPasswordPage /></PublicOnly> },
      { path: "/dat-lai-mat-khau", element: <ResetPasswordPage /> },
      { path: "/change-password", element: <RequireSession><ChangePasswordPage /></RequireSession> },
      { path: "/forbidden", element: <ForbiddenRoute /> },
      {
        path: "/manager",
        element: (
          <RequirePortal cong="QUAN_LY">
            <PortalLayout nav={MANAGER_NAV} accountPath="/manager/account" />
          </RequirePortal>
        ),
        children: [
          { index: true, element: <ManagerHome /> },
          { path: "customers", element: guard(P.khXem, <CustomersPage />) },
          { path: "customers/new", element: guard(["QL_KH_THEM"], <CustomerFormPage />) },
          { path: "customers/:maKH", element: guard(P.khXem, <CustomerDetailPage />) },
          { path: "customers/:maKH/edit", element: guard(["QL_KH_SUA"], <CustomerFormPage />) },
          { path: "feedback", element: guard(P.phXem, <FeedbackPage />) },
          { path: "surveys", element: guard(P.ks, <SurveysPage />) },
          { path: "surveys/new", element: guard(["QL_KS_QUAN_LY"], <SurveyCreatePage />) },
          { path: "surveys/:maKS", element: guard(P.ks, <SurveyDetailPage />) },
          { path: "surveys/:maKS/stats", element: guard(["QL_KS_THONG_KE"], <SurveyStatsPage />) },
          { path: "reports", element: guard(P.baoCao, <ReportsPage />) },
          { path: "account", element: <AccountPage /> },
          { path: "*", element: <NotFoundScreen homeHref="/manager" /> },
        ],
      },
      {
        path: "/customer",
        element: (
          <RequirePortal cong="KHACH_HANG">
            <PortalLayout nav={CUSTOMER_NAV} accountPath="/customer/account" />
          </RequirePortal>
        ),
        children: [
          { index: true, element: <CustomerHome /> },
          { path: "profile", element: guard(P.hoSo, <ProfilePage />) },
          { path: "feedback", element: guard(P.phanHoi, <MyFeedbackPage />) },
          { path: "surveys", element: guard(P.khaoSat, <MySurveysPage />) },
          { path: "surveys/:maKS", element: guard(P.khaoSat, <SurveyTakePage />) },
          { path: "account", element: <AccountPage /> },
          { path: "*", element: <NotFoundScreen homeHref="/customer" /> },
        ],
      },
      { path: "*", element: <NotFoundScreen /> },
    ],
  },
]);
