import { z } from "zod";

/** Ràng buộc khớp API (Models/Validation.cs) và CHECK trong CSDL. */
export const tenDangNhap = z
  .string()
  .trim()
  .min(1, "Nhập tên đăng nhập.")
  .regex(/^\S{4,50}$/, "Tên đăng nhập 4–50 ký tự, không có khoảng trắng.");

export const PASSWORD_RULES = [
  { id: "len", label: "Ít nhất 8 ký tự", test: (v: string) => v.length >= 8 && v.length <= 128 },
  { id: "letter", label: "Có chữ cái", test: (v: string) => /\p{L}/u.test(v) },
  { id: "digit", label: "Có chữ số", test: (v: string) => /\d/.test(v) },
] as const;

export const matKhauMoi = z
  .string()
  .min(1, "Nhập mật khẩu.")
  .refine((v) => PASSWORD_RULES.every((r) => r.test(v)), "Mật khẩu phải có ít nhất 8 ký tự, gồm cả chữ và số.");

export const loginSchema = z.object({
  tenDangNhap,
  matKhau: z.string().min(1, "Nhập mật khẩu.").max(128, "Mật khẩu tối đa 128 ký tự."),
});
export type LoginValues = z.infer<typeof loginSchema>;

export const changePasswordSchema = z
  .object({
    matKhauCu: z.string().min(1, "Nhập mật khẩu hiện tại."),
    matKhauMoi,
    nhapLai: z.string().min(1, "Nhập lại mật khẩu mới."),
  })
  .refine((v) => v.matKhauMoi === v.nhapLai, { path: ["nhapLai"], message: "Mật khẩu nhập lại không khớp." })
  .refine((v) => v.matKhauMoi !== v.matKhauCu, { path: ["matKhauMoi"], message: "Mật khẩu mới phải khác mật khẩu cũ." });
export type ChangePasswordValues = z.infer<typeof changePasswordSchema>;

const today = () => new Date().toISOString().slice(0, 10);

export const registerSchema = z
  .object({
    hoTen: z.string().trim().min(1, "Nhập họ tên.").max(100, "Họ tên tối đa 100 ký tự."),
    sdt: z.string().trim().regex(/^0\d{9}$/, "Số điện thoại gồm đúng 10 chữ số, bắt đầu bằng 0."),
    gioiTinh: z.enum(["NAM", "NU", "KHAC"]).nullable(),
    ngaySinh: z
      .string()
      .refine((v) => !v || (v >= "1900-01-01" && v <= today()), "Ngày sinh phải từ năm 1900 đến hôm nay."),
    email: z.union([z.literal(""), z.email("Email không hợp lệ.").max(100, "Email tối đa 100 ký tự.")]),
    maTinh: z.string(),
    dsLoaiQuanTam: z.array(z.number()),
    tenDangNhap,
    matKhau: matKhauMoi,
    nhapLai: z.string().min(1, "Nhập lại mật khẩu."),
  })
  .refine((v) => v.matKhau === v.nhapLai, { path: ["nhapLai"], message: "Mật khẩu nhập lại không khớp." });
export type RegisterValues = z.infer<typeof registerSchema>;

export const forgotPasswordSchema = z.object({
  tenDangNhap,
  email: z.string().trim().min(1, "Nhập email.").pipe(z.email("Email không hợp lệ.").max(100, "Email tối đa 100 ký tự.")),
});
export type ForgotPasswordValues = z.infer<typeof forgotPasswordSchema>;

export const resetPasswordSchema = z
  .object({ matKhauMoi, nhapLai: z.string().min(1, "Nhập lại mật khẩu mới.") })
  .refine((v) => v.matKhauMoi === v.nhapLai, { path: ["nhapLai"], message: "Mật khẩu nhập lại không khớp." });
export type ResetPasswordValues = z.infer<typeof resetPasswordSchema>;

/** Mã đặt lại trong liên kết email: 32 byte base64url (khớp ResetPasswordRequest của API). */
export const RESET_TOKEN = /^[A-Za-z0-9_-]{43}$/;
