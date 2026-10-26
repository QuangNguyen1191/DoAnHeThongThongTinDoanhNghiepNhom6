using System.Diagnostics;
using CrmUniqlo.Api.Auth;
using CrmUniqlo.Api.Data;
using CrmUniqlo.Api.Models;
using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CrmUniqlo.Api.Controllers.Admin;

/// <summary>A0 dashboard, A15 nhật ký, A16 tình trạng hệ thống.</summary>
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminSystemController : CrmControllerBase
{
    private readonly SqlConnectionFactory _factory;

    public AdminSystemController(CrmDb db, SqlConnectionFactory factory) : base(db) => _factory = factory;

    /// <summary>A0. Tổng quan: số tài khoản theo trạng thái/loại và nhật ký trong <paramref name="khoang"/> ngày gần đây.</summary>
    [HttpGet("dashboard")]
    public async Task<object> Dashboard([FromQuery] int khoang = 7, CancellationToken ct = default)
    {
        khoang = Math.Clamp(khoang, 1, 365);
        var accountsTask = TryBlock(async () =>
            (await Db.ExecAsync("api_admin.usp_DanhSachTaiKhoan",
                new { TuKhoa = (string?)null, LoaiTK = (string?)null, MaVT = (string?)null, TrangThai = (string?)null }, ct)).Rows());
        var logsTask = TryBlock(async () =>
            (await Db.ExecAsync("api_admin.usp_XemNhatKy", new
            {
                TuNgay = DateTime.Today.AddDays(-khoang), DenNgay = (DateTime?)null, HanhDong = (string?)null, MaTK = (int?)null,
                Trang = 1, SoDong = 20
            }, ct)).Rows());
        await Task.WhenAll(accountsTask, logsTask);
        var (accounts, accountsError) = accountsTask.Result;
        var (logs, logsError) = logsTask.Result;

        return new
        {
            khoang,
            taiKhoan = accounts is null ? null : new
            {
                tong = accounts.Count,
                hoatDong = accounts.Count(a => a.Get<string>("TrangThai") == "HOAT_DONG"),
                daKhoa = accounts.Count(a => a.Get<string>("TrangThai") == "DA_KHOA"),
                nhanVien = accounts.Count(a => a.Get<string>("LoaiTK") == "NV"),
                khachHang = accounts.Count(a => a.Get<string>("LoaiTK") == "KH"),
                phaiDoiMatKhau = accounts.Count(a => a.Get<bool>("PhaiDoiMatKhau"))
            },
            nhatKyGanDay = logs is null ? null : PagedResult.From(logs, 1, 20),
            loi = new { taiKhoan = accountsError, nhatKy = logsError }
        };
    }

    /// <summary>A15. Nhật ký hệ thống (phân trang, tối đa 500 dòng).</summary>
    [HttpGet("audit-logs")]
    public async Task<PagedResult> AuditLogs([FromQuery] AuditLogQuery q, CancellationToken ct)
    {
        var r = await Db.ExecAsync("api_admin.usp_XemNhatKy", new
        {
            TuNgay = CrmDb.ToDbDate(q.TuNgay), DenNgay = CrmDb.ToDbDate(q.DenNgay), q.HanhDong, q.MaTK, q.Trang, q.SoDong
        }, ct);
        return PagedResult.From(r.Rows(), q.Trang, q.SoDong);
    }

    /// <summary>A16. Kiểm tra 3 kết nối cổng (SELECT 1) và phiên bản máy chủ.</summary>
    [HttpGet("system")]
    public async Task<object> SystemStatus(CancellationToken ct)
    {
        var checks = await Task.WhenAll(Enum.GetValues<Cong>().Select(async cong =>
        {
            var sw = Stopwatch.StartNew();
            try
            {
                await using var conn = await _factory.OpenAnonymousAsync(cong, ct);
                await conn.ExecuteScalarAsync<int>(new CommandDefinition("SELECT 1;", cancellationToken: ct));
                return new { cong = cong.ToDb(), ok = true, thoiGianMs = sw.ElapsedMilliseconds, loi = (string?)null, phienBan = (string?)conn.ServerVersion };
            }
            catch (Exception ex)
            {
                return new { cong = cong.ToDb(), ok = false, thoiGianMs = sw.ElapsedMilliseconds, loi = (string?)ex.GetType().Name, phienBan = (string?)null };
            }
        }));
        return new { ketNoi = checks, thoiGianApi = DateTimeOffset.Now };
    }
}
