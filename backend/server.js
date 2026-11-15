require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  user: process.env.DB_USER || 'myuser',
  password: process.env.DB_PASSWORD || '19012006',
    database: process.env.DB_NAME || 'clinic_management',
  charset: 'utf8mb4',
  dateStrings: true,
  waitForConnections: true,
  connectionLimit: 10,
});

const app = express();
app.use(cors());
app.use(express.json());
// Tự dò thư mục giao diện: backend/public (chạy riêng) hoặc ../frontend (đúng bố cục repo)
const staticDir = [path.join(__dirname, 'public'), path.join(__dirname, '..', 'frontend')].find((d) => fs.existsSync(d)) || path.join(__dirname, 'public');
app.use(express.static(staticDir));

const q = (sql, params = []) => pool.query(sql, params).then(([r]) => r);
const tx = async (fn) => {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const out = await fn(conn);
    await conn.commit();
    return out;
  } catch (e) { await conn.rollback(); throw e; } finally { conn.release(); }
};

// Trigger báo lỗi bằng SIGNAL SQLSTATE '45000' -> trả nguyên thông báo cho GUI
function toHttpError(e) {
  if (e.sqlState === '45000') return [400, e.sqlMessage];
  const map = {
    ER_DUP_ENTRY: [409, 'Dữ liệu bị trùng (vi phạm ràng buộc UNIQUE).'],
    ER_ROW_IS_REFERENCED_2: [409, 'Không thể xóa vì dữ liệu đang được sử dụng ở bảng khác.'],
    ER_NO_REFERENCED_ROW_2: [400, 'Mã tham chiếu không tồn tại.'],
    ER_CHECK_CONSTRAINT_VIOLATED: [400, 'Giá trị vi phạm ràng buộc CHECK (giá bán > 0, tồn kho ≥ 0, số lượng > 0...).'],
    ER_BAD_NULL_ERROR: [400, 'Thiếu dữ liệu bắt buộc.'],
  };
  return map[e.code] || [500, e.sqlMessage || e.message];
}
const h = (fn) => async (req, res) => {
  try { await fn(req, res); } catch (e) {
    console.error(e);
    const [code, error] = toHttpError(e);
    res.status(code).json({ error });
  }
};

// ---------- CRUD: BenhNhan (kèm HoSoSucKhoe 1–1), BacSi, Thuoc ----------
const bnCols = ['hoten', 'ngaysinh', 'gioitinh', 'sdt', 'diachi'];
app.get('/api/benhnhan', h(async (req, res) => {
  const k = `%${req.query.q || ''}%`;
  res.json(await q('SELECT * FROM BenhNhan WHERE hoten LIKE ? OR sdt LIKE ? ORDER BY id DESC', [k, k]));
}));
app.post('/api/benhnhan', h(async (req, res) => {
  const id = await tx(async (c) => {
    const [r] = await c.query(`INSERT INTO BenhNhan (${bnCols.join(',')}) VALUES (?,?,?,?,?)`, bnCols.map((k) => req.body[k] || null));
    await c.query('INSERT INTO HoSoSucKhoe (benhnhan_id, ngaylap) VALUES (?, CURDATE())', [r.insertId]);
    return r.insertId;
  });
  res.status(201).json({ id });
}));
app.put('/api/benhnhan/:id', h(async (req, res) => {
  await q(`UPDATE BenhNhan SET ${bnCols.map((k) => `${k}=?`).join(',')} WHERE id=?`, [...bnCols.map((k) => req.body[k] || null), req.params.id]);
  res.json({ ok: true });
}));
app.delete('/api/benhnhan/:id', h(async (req, res) => {
  await tx(async (c) => {
    await c.query('DELETE FROM HoSoSucKhoe WHERE benhnhan_id=?', [req.params.id]);
    await c.query('DELETE FROM BenhNhan WHERE id=?', [req.params.id]);
  });
  res.json({ ok: true });
}));

function crud(route, table, cols) {
  app.get(`/api/${route}`, h(async (req, res) => res.json(await q(`SELECT * FROM ${table} ORDER BY id DESC`))));
  app.post(`/api/${route}`, h(async (req, res) => {
    const r = await q(`INSERT INTO ${table} (${cols.join(',')}) VALUES (${cols.map(() => '?').join(',')})`, cols.map((c) => req.body[c] ?? null));
    res.status(201).json({ id: r.insertId });
  }));
  app.put(`/api/${route}/:id`, h(async (req, res) => {
    await q(`UPDATE ${table} SET ${cols.map((c) => `${c}=?`).join(',')} WHERE id=?`, [...cols.map((c) => req.body[c] ?? null), req.params.id]);
    res.json({ ok: true });
  }));
  app.delete(`/api/${route}/:id`, h(async (req, res) => {
    await q(`DELETE FROM ${table} WHERE id=?`, [req.params.id]);
    res.json({ ok: true });
  }));
}
crud('bacsi', 'BacSi', ['hoten', 'chuyenkhoa', 'sdt']);
crud('thuoc', 'Thuoc', ['ten', 'donvi', 'giaban', 'tonkho', 'dinhmuccanhbao']);

app.get('/api/thuoc/ton-kho', h(async (req, res) =>
  res.json(await q('SELECT id, ten, donvi, tonkho, dinhmuccanhbao FROM Thuoc ORDER BY tonkho ASC'))));
const canhBao = h(async (req, res) => res.json(await q('SELECT * FROM CanhBaoTonKho ORDER BY 1 DESC LIMIT 30')));
app.get('/api/canhbao', canhBao);
app.get('/api/canhbao-tonkho', canhBao);

// ---------- Lịch khám ----------
// Khung giờ còn trống (ca 30 phút, 08:00–17:00, nghỉ trưa 12:00–13:30)
app.get('/api/bacsi/:id/lich-trong', h(async (req, res) => {
  const { ngay } = req.query;
  if (!ngay) return res.status(400).json({ error: 'Thiếu tham số ngay (YYYY-MM-DD).' });
  const busy = await q(
    `SELECT TIME_FORMAT(ngaygio,'%H:%i') AS g FROM LichKham WHERE bacsi_id=? AND DATE(ngaygio)=? AND trangthai <> 'đã hủy'`,
    [req.params.id, ngay]);
  const taken = new Set(busy.map((b) => b.g));
  const slots = [];
  for (let m = 480; m < 1020; m += 30) {
    if (m >= 720 && m < 810) continue;
    const g = `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
    slots.push({ gio: g, trong: !taken.has(g) });
  }
  res.json(slots);
}));

app.get('/api/lichkham', h(async (req, res) => res.json(await q(
  `SELECT lk.*, bs.hoten AS bacsi, ba.id AS benhan_id, bn.hoten AS benhnhan
   FROM LichKham lk JOIN BacSi bs ON bs.id = lk.bacsi_id
   LEFT JOIN BenhAn ba ON ba.lichkham_id = lk.id
   LEFT JOIN HoSoSucKhoe hs ON hs.id = ba.hososuckhoe_id
   LEFT JOIN BenhNhan bn ON bn.id = hs.benhnhan_id
   ORDER BY lk.ngaygio DESC`))));

// trg_ChanTrungLich_Them chặn trùng giờ của cùng bác sĩ.
// Lịch đã hủy vẫn giữ UNIQUE(bacsi_id, ngaygio) nên xóa dòng đã hủy cùng giờ trước khi đặt lại.
app.post('/api/lichkham', h(async (req, res) => {
  const { bacsi_id, ngaygio } = req.body;
  const id = await tx(async (c) => {
    await c.query("DELETE FROM LichKham WHERE bacsi_id=? AND ngaygio=? AND trangthai='đã hủy'", [bacsi_id, ngaygio]);
    const [r] = await c.query('INSERT INTO LichKham (bacsi_id, ngaygio) VALUES (?, ?)', [bacsi_id, ngaygio]);
    return r.insertId;
  });
  res.status(201).json({ id });
}));
app.put('/api/lichkham/:id/huy', h(async (req, res) => {
  await q("UPDATE LichKham SET trangthai='đã hủy' WHERE id=?", [req.params.id]);
  res.json({ ok: true });
}));

// ---------- Bệnh án ----------
app.get('/api/benhan', h(async (req, res) => {
  const where = req.query.benhnhan_id ? 'WHERE bn.id = ?' : '';
  res.json(await q(
    `SELECT ba.*, bn.id AS benhnhan_id, bn.hoten AS benhnhan
     FROM BenhAn ba JOIN HoSoSucKhoe hs ON hs.id = ba.hososuckhoe_id JOIN BenhNhan bn ON bn.id = hs.benhnhan_id
     ${where} ORDER BY ba.id DESC`, req.query.benhnhan_id ? [req.query.benhnhan_id] : []));
}));
// Tái khám: gửi kèm benhan_goc_id (trg_KiemTraBenhAnCha_Them kiểm tra); trg_CapNhatTrangThaiLich chuyển lịch sang 'đã khám'
app.post('/api/benhan', h(async (req, res) => {
  const { benhnhan_id, lichkham_id, benhan_goc_id, ngaykham, chuandoan, ghichu } = req.body;
  const hs = await q('SELECT id FROM HoSoSucKhoe WHERE benhnhan_id=?', [benhnhan_id]);
  if (!hs.length) return res.status(400).json({ error: 'Bệnh nhân chưa có hồ sơ sức khỏe.' });
  const r = await q(
    'INSERT INTO BenhAn (hososuckhoe_id, lichkham_id, benhan_goc_id, ngaykham, chuandoan, ghichu) VALUES (?,?,?,?,?,?)',
    [hs[0].id, lichkham_id || null, benhan_goc_id || null, ngaykham || new Date().toISOString().slice(0, 10), chuandoan || null, ghichu || null]);
  res.status(201).json({ id: r.insertId });
}));
app.get('/api/benhan/:id/tai-kham', h(async (req, res) =>
  res.json(await q('SELECT * FROM BenhAn WHERE benhan_goc_id=? ORDER BY ngaykham, id', [req.params.id]))));

// ---------- Đơn thuốc ----------
app.get('/api/donthuoc', h(async (req, res) => res.json(await q(
  `SELECT dt.id, dt.ngaylap, dt.benhan_id, bn.hoten AS benhnhan,
          COUNT(c.thuoc_id) AS so_loai, COALESCE(SUM(c.soluong * t.giaban), 0) AS tien
   FROM DonThuoc dt
   JOIN BenhAn ba ON ba.id = dt.benhan_id
   JOIN HoSoSucKhoe hs ON hs.id = ba.hososuckhoe_id
   JOIN BenhNhan bn ON bn.id = hs.benhnhan_id
   LEFT JOIN ChiTietDonThuoc c ON c.donthuoc_id = dt.id
   LEFT JOIN Thuoc t ON t.id = c.thuoc_id
   GROUP BY dt.id, dt.ngaylap, dt.benhan_id, bn.hoten ORDER BY dt.id DESC`))));
app.get('/api/donthuoc/:id', h(async (req, res) => res.json(await q(
  `SELECT t.ten, t.donvi, t.giaban, c.soluong, c.lieudung
   FROM ChiTietDonThuoc c JOIN Thuoc t ON t.id = c.thuoc_id WHERE c.donthuoc_id=?`, [req.params.id]))));
// sp_TaoDonThuoc chạy trong TRANSACTION: vượt tồn kho thì rollback cả đơn
app.post('/api/donthuoc', h(async (req, res) => {
  const { benhan_id, items } = req.body;
  if (!Array.isArray(items) || !items.length) return res.status(400).json({ error: 'Đơn thuốc phải có ít nhất 1 loại thuốc.' });
  await q('CALL sp_TaoDonThuoc(?, ?)', [benhan_id, JSON.stringify(items)]);
  res.status(201).json({ ok: true });
}));

// ---------- Hóa đơn ----------
const hdSelect = `SELECT hd.*, lk.ngaygio, bs.hoten AS bacsi, bn.hoten AS benhnhan
  FROM HoaDon hd JOIN LichKham lk ON lk.id = hd.lichkham_id JOIN BacSi bs ON bs.id = lk.bacsi_id
  LEFT JOIN BenhAn ba ON ba.lichkham_id = lk.id
  LEFT JOIN HoSoSucKhoe hs ON hs.id = ba.hososuckhoe_id
  LEFT JOIN BenhNhan bn ON bn.id = hs.benhnhan_id`;
app.get('/api/hoadon', h(async (req, res) => res.json(await q(`${hdSelect} ORDER BY hd.id DESC`))));
// Lấy/tính hóa đơn của một lịch khám (gọi sp_TinhVienPhi nếu chưa thanh toán)
app.get('/api/hoadon/:lichkham_id', h(async (req, res) => {
  let r = await q(`${hdSelect} WHERE hd.lichkham_id=?`, [req.params.lichkham_id]);
  if (!r.length) return res.status(404).json({ error: 'Lịch khám này chưa có hóa đơn.' });
  if (r[0].trangthaithanhtoan !== 'đã thanh toán') {
    await q('CALL sp_TinhVienPhi(?)', [req.params.lichkham_id]);
    r = await q(`${hdSelect} WHERE hd.lichkham_id=?`, [req.params.lichkham_id]);
  }
  res.json(r[0]);
}));
app.post('/api/hoadon', h(async (req, res) => {
  const { lichkham_id, phikham = 0 } = req.body;
  await tx(async (c) => {
    await c.query('INSERT INTO HoaDon (lichkham_id, phikham, tienthuoc, tongtien) VALUES (?, ?, 0, ?)', [lichkham_id, phikham, phikham]);
    await c.query('CALL sp_TinhVienPhi(?)', [lichkham_id]);
  });
  res.status(201).json({ ok: true });
}));
app.post('/api/hoadon/:lichkham_id/tinh', h(async (req, res) => {
  await q('CALL sp_TinhVienPhi(?)', [req.params.lichkham_id]);
  res.json({ ok: true });
}));
app.post('/api/hoadon/:id/thanhtoan', h(async (req, res) => {
  await q("UPDATE HoaDon SET trangthaithanhtoan='đã thanh toán' WHERE id=?", [req.params.id]);
  res.json({ ok: true });
}));

// ---------- Thống kê doanh thu: gọi sp_ThongKeDoanhThu / sp_ThongKeDoanhThuTheoBacSi ----------
const thongKe = h(async (req, res) => {
  const tu = req.query.tu || req.query.tungay, den = req.query.den || req.query.denngay;
  if (!tu || !den) return res.status(400).json({ error: 'Cần tu và den (YYYY-MM-DD).' });
  const theoBacSi = req.query.kieu === 'bacsi';
  const rs = await q(`CALL ${theoBacSi ? 'sp_ThongKeDoanhThuTheoBacSi' : 'sp_ThongKeDoanhThu'}(?, ?)`, [tu, den]);
  const rows = Array.isArray(rs) && Array.isArray(rs[0]) ? rs[0] : [];
  res.json(rows.map((r) => ({ nhom: theoBacSi ? r.bacsi : r.ngay, so_hoa_don: r.so_hoa_don, doanh_thu: r.doanh_thu })));
});
app.get('/api/thongke', thongKe);
app.get('/api/baocao/doanh-thu', thongKe);

// ---------- Tổng quan ----------
app.get('/api/tongquan', h(async (req, res) => {
  const r = await q(`SELECT
    (SELECT COUNT(*) FROM BenhNhan) AS benhnhan,
    (SELECT COUNT(*) FROM LichKham WHERE DATE(ngaygio)=CURDATE() AND trangthai <> 'đã hủy') AS lich_homnay,
    (SELECT COUNT(*) FROM Thuoc WHERE tonkho < dinhmuccanhbao) AS thuoc_thap,
    (SELECT COUNT(*) FROM HoaDon WHERE trangthaithanhtoan = 'chưa thanh toán') AS cho_thanh_toan,
    (SELECT COALESCE(SUM(hd.tongtien),0) FROM HoaDon hd JOIN LichKham lk ON lk.id = hd.lichkham_id
      WHERE hd.trangthaithanhtoan = 'đã thanh toán' AND DATE_FORMAT(lk.ngaygio,'%Y-%m') = DATE_FORMAT(CURDATE(),'%Y-%m')) AS doanhthu_thang`);
  res.json(r[0]);
}));

app.get('/api/health', (req, res) => res.json({ message: 'Clinic Management API đang hoạt động' }));
app.get('/api/db-test', h(async (req, res) => res.json({ message: 'Kết nối MySQL thành công', data: await q('SELECT 1 AS ket_noi') })));

const PORT = process.env.PORT || 3000;
app.listen(PORT, async () => {
  console.log(`Clinic API chạy tại http://localhost:${PORT}  (giao diện: ${staticDir})`);
  try {
    await q('SELECT 1');
    console.log('Kết nối MySQL thành công.');
  } catch (e) {
    console.error('KHÔNG kết nối được MySQL:', e.sqlMessage || e.message);
    console.error('Kiểm tra file .env (DB_USER, DB_PASSWORD, DB_NAME) và MySQL đã chạy chưa.');
  }
});
