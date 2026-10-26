HỆ THỐNG CRM – CHUỖI BÁN LẺ THỜI TRANG UNIQLO (ĐỒ ÁN HTTTDN – SGU, HK1 2026-2027)
BỘ SCRIPT SQL SERVER – HƯỚNG DẪN NHANH TRIỂN KHAI VÀ KIỂM THỬ (bản 19/10/2026)
=====================================================================
Hướng dẫn đầy đủ (từng bước, cách đọc PASS/FAIL, xử lý lỗi): tài liệu
"Hướng dẫn chạy thử và kiểm thử CSDL CRM Uniqlo" gửi kèm.

TRẠNG THÁI: đã rà soát tĩnh (cú pháp, thứ tự phụ thuộc, tên bảng/cột/tham số,
dữ liệu mẫu so với ràng buộc). CHƯA chạy trên SQL Server thật. Chỉ coi là
HOÀN THÀNH khi có kết quả chạy thật: 08b "KET LUAN: DAT" và 7 tệp 12–17, 19
đều "KET LUAN: DAT" (187/187 ca PASS).
Bản 19/10/2026: thêm script 18 (quên mật khẩu L5, lịch sử mua hàng của khách)
và 19 (22 ca kiểm thử cho phần thêm). 18 + 19 + 08b đã chạy thật trên
SQL Server 2025 (Linux): 08b 79/79 PASS, 19 22/22 PASS.

1. YÊU CẦU
   - SQL Server 2017 trở lên (khuyến nghị 2019/2022; Express/Developer đều được).
   - Bật "SQL Server and Windows Authentication mode", khởi động lại dịch vụ.
   - SSMS 19+ và/hoặc sqlcmd. Tài khoản chạy script có quyền sysadmin.

2. DANH SÁCH SCRIPT (đúng thứ tự)
   01_TaoCSDL_Schema.sql        Tạo CSDL CRM_Uniqlo (Vietnamese_100_CI_AS) + 7 schema
   02_TaoBang.sql               27 bảng, 27 PK, 39 FK, 24 UNIQUE, 54 CHECK, 25 DEFAULT, 1 trigger
   03_ChiMuc_View.sql           37 chỉ mục IX_/UX_, 20 view
   04_BaoMat_ThuTucNoiBo.sql    5 kiểu bảng TVP, 7 hàm sec, thủ tục nội bộ
   05a_API_Chung_KhachHang.sql  api_chung (4) + api_kh (9 thủ tục)
   05b_API_QuanLy.sql           api_ql (21 thủ tục)
   05c_API_Admin.sql            api_admin (24 thủ tục)
   06_PhanQuyen_RLS.sql         3 login/user/role, GRANT/DENY, RLS 21 vị từ / 7 bảng
   07_DuLieuHeThong.sql         Vai trò, 20 quyền, hạng, chức vụ, tỉnh/thành
   08_DuLieuMau.sql             Dữ liệu demo (chỉ chạy khi CSDL chưa có tài khoản)
   18_BoSung_QuenMatKhau_LichSuMuaHang.sql  MỚI – chỉ THÊM: bảng YEU_CAU_DAT_LAI_MK,
                                sec (1), api_chung (2), api_kh (1 thủ tục). Chạy lại được.
   08b_KiemTra_SauTrienKhai.sql Tự kiểm tra đối tượng, bảo mật, dữ liệu (chỉ đọc; cần đã chạy 18)
   09_TruyVanBaoCao.sql         Truy vấn báo cáo minh họa
   10_SaoLuu.sql / 10b_PhucHoi.sql   Sao lưu / phục hồi (sang CSDL mới)
   11_TaoBanSaoKiemThu.sql      Tạo CRM_Uniqlo_Test từ bản sao lưu COPY_ONLY
   12 … 17 _KiemThu_*.sql       165 ca kiểm thử (36 + 34 + 41 + 10 + 33 + 11)
   19_KiemThu_BoSung.sql        MỚI – 22 ca cho quên mật khẩu + lịch sử mua hàng
   99_XoaCSDL_ThuNghiem.sql     NGUY HIỂM – xóa CSDL thử nghiệm để cài lại; phải gõ xác nhận
   00_TronBo_TrienKhai.sql      Gộp sẵn 01 -> 08 và 18 (nội dung giống hệt tệp lẻ)
   chay_trien_khai_va_kiem_thu.ps1   Chạy tự động toàn bộ (trừ 99)

2b. NÂNG CẤP CSDL ĐÃ CÓ (đã chạy 01–08 trước ngày 19/10/2026)
   Không cần tạo lại CSDL: chỉ chạy 18_BoSung_QuenMatKhau_LichSuMuaHang.sql
   (SSMS hoặc sqlcmd -I), rồi 08b để kiểm tra. Dữ liệu cũ giữ nguyên.

3. CHẠY TỰ ĐỘNG (khuyến nghị)
   powershell -ExecutionPolicy Bypass -File .\chay_trien_khai_va_kiem_thu.ps1 -Server "localhost\SQLEXPRESS"
   (dùng SQL login sa: thêm -SqlUser sa -SqlPassword "...")
   Kết quả: thư mục ketqua\<ngày_giờ>\ (mỗi script 1 tệp .txt + TongKet.txt).

4. CHẠY BẰNG SSMS
   Mở và Execute lần lượt 01 -> 08, 18 (mỗi tệp chạy hết, không bôi đen một phần),
   rồi 08b, 10, 11. Mỗi tệp 12 -> 17 và 19: mở trong một cửa sổ truy vấn MỚI
   (File > New > Query with Current Connection hoặc Ctrl+N), chọn CSDL
   CRM_Uniqlo_Test, Execute.

5. ĐỌC KẾT QUẢ
   PASS  = kết quả thực tế đúng như mong đợi (kể cả ca mong đợi "bị từ chối").
   FAIL  = khác mong đợi; cột ChiTiet/THỰC TẾ ghi mã lỗi thật.
   Dòng cuối tab Messages:  TONG KET <CSDL>: x/y PASS, z FAIL (du kien N ca)
                            KET LUAN: DAT | KHONG DAT
   DAT chỉ khi z = 0 VÀ y = N. Không thấy 2 dòng này = script dừng giữa chừng.
   Nhiều ca CỐ Ý gây lỗi (50001, 50003, 52xxx, 229, 33504) để chứng minh hệ thống
   từ chối đúng; các lỗi này đã được TRY/CATCH bắt và ghi vào cột ChiTiet, nên
   KHÔNG hiện "Msg" đỏ. Thấy "Msg" đỏ ở 12–17 = lỗi nằm ngoài ca kiểm thử -> báo lại.

6. TÀI KHOẢN DEMO (mật khẩu chung Demo@2026 – CSDL chỉ lưu bcrypt)
   Admin: admin.it, it.mai (QTV_TAI_KHOAN)   Quản lý: gd.minh, ql.lan, cskh.hoa (NV_CSKH)
   Khách: kh.an, kh.binh (VIP), kh.chau, kh.dung, kh.ha, kh.khanh, kh.lananh, kh.phong,
          kh.thao; kh.quyen (bị khóa); kh.nam (hồ sơ đã xóa)

7. MÃ LỖI NGHIỆP VỤ
   50001 chưa đăng nhập   50003 không có quyền chức năng   50010–50013 ngữ cảnh/cổng/khóa
   51001–51002 trigger đổi trả   52001 dữ liệu không hợp lệ   52002/52003/52004 trùng SĐT/email/tên ĐN
   52020–52099 vi phạm quy tắc nghiệp vụ (52098: mã đặt lại mật khẩu sai/hết hạn/đã dùng)   229 SQL Server từ chối quyền   33504 RLS chặn ghi
