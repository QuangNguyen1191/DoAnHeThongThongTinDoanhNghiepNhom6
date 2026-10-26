using CrmUniqlo.Api.Auth;
using CrmUniqlo.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CrmUniqlo.Api.Controllers.Manager;

/// <summary>Q0: tổng quan cho web Quản lý. Mỗi khối gọi song song trên kết nối riêng; khối thiếu quyền trả null.</summary>
[Route("api/manager/dashboard")]
[Authorize(Policy = Policies.QuanLy)]
public sealed class ManagerDashboardController : CrmControllerBase
{
    public ManagerDashboardController(CrmDb db) : base(db) { }

    [HttpGet]
    public async Task<object> Get(CancellationToken ct)
    {
        var khach = TryBlock(async () => (await Db.ExecAsync("api_ql.usp_TimKhachHang", new
        {
            TuKhoa = (string?)null, MaHang = (string?)null, MaTinh = (string?)null, GioiTinh = (string?)null,
            TuoiTu = (int?)null, TuoiDen = (int?)null, MaLoaiQuanTam = (int?)null,
            TrangThaiHoSo = "HOAT_DONG", SapXep = "NGAY_DK_MOI", Trang = 1, SoDong = 5
        }, ct)).Rows());
        var phanHoi = TryBlock(async () => (await Db.ExecAsync("api_ql.usp_DanhSachPhanHoi", new
        {
            TrangThai = "MOI", LoaiPH = (string?)null, MaSP = (int?)null, TuNgay = (DateTime?)null, DenNgay = (DateTime?)null,
            Trang = 1, SoDong = 5
        }, ct)).Rows());
        var coCau = TryBlock(async () => (await Db.ExecAsync("api_ql.usp_BaoCaoCoCauKhachHang", null, ct)).Rows(3));
        var khaoSat = TryBlock(async () => (await Db.ExecAsync("api_ql.usp_DanhSachKhaoSat",
            new { TrangThai = "DA_GUI", MucDich = (string?)null }, ct)).Rows());
        await Task.WhenAll(khach, phanHoi, coCau, khaoSat);

        return new
        {
            khachMoi = khach.Result.Value is { } k ? PagedResult.From(k, 1, 5) : null,
            phanHoiMoi = phanHoi.Result.Value is { } p ? PagedResult.From(p, 1, 5) : null,
            theoHang = coCau.Result.Value,
            khaoSatDangMo = khaoSat.Result.Value,
            loi = new
            {
                khachMoi = khach.Result.Error, phanHoiMoi = phanHoi.Result.Error, theoHang = coCau.Result.Error,
                khaoSatDangMo = khaoSat.Result.Error
            }
        };
    }
}
