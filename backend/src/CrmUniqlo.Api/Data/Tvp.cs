using System.Data;
using Dapper;

namespace CrmUniqlo.Api.Data;

/// <summary>Dựng 5 kiểu bảng (table-valued parameter) đã khai báo trong CSDL.</summary>
public static class Tvp
{
    /// <summary>api_chung.DanhSachMa(Ma INT PK).</summary>
    public static SqlMapper.ICustomQueryParameter DanhSachMa(IEnumerable<int>? values)
    {
        var table = new DataTable();
        table.Columns.Add("Ma", typeof(int));
        foreach (var v in (values ?? []).Distinct()) table.Rows.Add(v);
        return table.AsTableValuedParameter("api_chung.DanhSachMa");
    }

    /// <summary>api_kh.BangTraLoi(MaCauHoi, MaLC, DiemSo, NoiDungTuLuan).</summary>
    public static SqlMapper.ICustomQueryParameter BangTraLoi(IEnumerable<(int MaCauHoi, int? MaLC, byte? DiemSo, string? NoiDungTuLuan)> rows)
    {
        var table = new DataTable();
        table.Columns.Add("MaCauHoi", typeof(int));
        table.Columns.Add("MaLC", typeof(int));
        table.Columns.Add("DiemSo", typeof(byte));
        table.Columns.Add("NoiDungTuLuan", typeof(string));
        foreach (var r in rows)
            table.Rows.Add(r.MaCauHoi, (object?)r.MaLC ?? DBNull.Value, (object?)r.DiemSo ?? DBNull.Value,
                (object?)r.NoiDungTuLuan ?? DBNull.Value);
        return table.AsTableValuedParameter("api_kh.BangTraLoi");
    }

    /// <summary>api_ql.DanhSachLuaChon(ThuTu SMALLINT PK, NoiDung). Thứ tự đánh số 1..n theo danh sách.</summary>
    public static SqlMapper.ICustomQueryParameter DanhSachLuaChon(IEnumerable<string>? luaChon)
    {
        var table = new DataTable();
        table.Columns.Add("ThuTu", typeof(short));
        table.Columns.Add("NoiDung", typeof(string));
        short thuTu = 1;
        foreach (var noiDung in luaChon ?? []) table.Rows.Add(thuTu++, noiDung);
        return table.AsTableValuedParameter("api_ql.DanhSachLuaChon");
    }

    /// <summary>api_admin.DanhSachMaQuyen(MaQuyen VARCHAR(30) PK).</summary>
    public static SqlMapper.ICustomQueryParameter DanhSachMaQuyen(IEnumerable<string>? maQuyen)
    {
        var table = new DataTable();
        table.Columns.Add("MaQuyen", typeof(string));
        foreach (var q in (maQuyen ?? []).Distinct(StringComparer.OrdinalIgnoreCase)) table.Rows.Add(q);
        return table.AsTableValuedParameter("api_admin.DanhSachMaQuyen");
    }

    /// <summary>api_admin.BangChiTietHoaDon(MaSKU PK, SoLuong, DonGiaBan).</summary>
    public static SqlMapper.ICustomQueryParameter BangChiTietHoaDon(IEnumerable<(string MaSKU, int SoLuong, decimal DonGiaBan)> rows)
    {
        var table = new DataTable();
        table.Columns.Add("MaSKU", typeof(string));
        table.Columns.Add("SoLuong", typeof(int));
        table.Columns.Add("DonGiaBan", typeof(decimal));
        foreach (var r in rows) table.Rows.Add(r.MaSKU, r.SoLuong, r.DonGiaBan);
        return table.AsTableValuedParameter("api_admin.BangChiTietHoaDon");
    }
}
