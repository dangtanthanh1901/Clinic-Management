USE clinic_management;

-- Chay file nay SAU khi da chay CreateTables, Functions, Procedures, Triggers
-- (de trigger tu tru ton kho va tu chuyen lich sang 'da kham').

-- 1. Benh nhan
INSERT INTO BenhNhan (hoten, ngaysinh, gioitinh, sdt, diachi) VALUES
('Nguyễn Văn An', '2000-05-10', 'Nam', '0901000001', 'Tây Ninh'),
('Trần Thị Bình', '1998-08-20', 'Nữ',  '0901000002', 'Long An'),
('Lê Văn Cường',  '1995-03-15', 'Nam', '0901000003', 'TP. Hồ Chí Minh');

-- 2. Ho so suc khoe (moi benh nhan dung 1 ho so)
INSERT INTO HoSoSucKhoe (benhnhan_id, ngaylap)
SELECT id, CURRENT_DATE FROM BenhNhan
WHERE sdt IN ('0901000001', '0901000002', '0901000003');

-- 3. Bac si
INSERT INTO BacSi (hoten, chuyenkhoa, sdt) VALUES
('Nguyễn Minh Đức', 'Nội tổng quát', '0911000001'),
('Phạm Thị Lan',    'Nhi khoa',      '0911000002');

-- 4. Lich kham (cac lich cua cung bac si cach nhau tu 30 phut tro len)
INSERT INTO LichKham (bacsi_id, ngaygio, trangthai) VALUES
(1, '2026-11-01 08:00:00', 'đã đặt'),   -- id 1
(1, '2026-11-01 09:00:00', 'đã đặt'),   -- id 2 (de lai de demo lap benh an tren GUI)
(2, '2026-11-01 08:30:00', 'đã đặt'),   -- id 3
(1, '2026-11-05 08:00:00', 'đã đặt');   -- id 4 (lich tai kham)

-- 5. Benh an. Quan he tai kham: benhan_goc_id = NULL la benh goc.
-- Trigger trg_CapNhatTrangThaiLich chuyen lich co benh an sang 'da kham'.
-- Cay tai kham cua benh nhan 1 (ho so 1) minh hoa dung Muc 5 cua bao cao:
INSERT INTO BenhAn (hososuckhoe_id, lichkham_id, benhan_goc_id, ngaykham, chuandoan, ghichu) VALUES
(1, 1,    NULL, '2026-11-01', 'Viêm họng',          'Tái khám nếu còn triệu chứng'),  -- id 1: benh goc 1
(1, 4,    1,    '2026-11-05', 'Viêm họng',          'Tái khám lần 1 - bệnh 1'),       -- id 2
(1, NULL, 1,    '2026-11-08', 'Viêm họng',          'Tái khám lần 2 - bệnh 1'),       -- id 3
(1, NULL, 1,    '2026-11-10', 'Viêm họng',          'Tái khám lần 3 - bệnh 1'),       -- id 4
(1, NULL, NULL, '2026-11-10', 'Dị ứng thời tiết',   'Bệnh mới 2 (bệnh gốc độc lập)'), -- id 5
(1, NULL, 5,    '2026-11-12', 'Dị ứng thời tiết',   'Tái khám bệnh 2'),               -- id 6
(1, NULL, 1,    '2026-11-13', 'Viêm họng',          'Quay lại bệnh 1'),               -- id 7
(1, NULL, NULL, '2026-11-14', 'Đau dạ dày',         'Bệnh mới 3 (bệnh gốc độc lập)'); -- id 8
-- Benh nhan 2 (ho so 2): kham 1 lan
INSERT INTO BenhAn (hososuckhoe_id, lichkham_id, benhan_goc_id, ngaykham, chuandoan, ghichu) VALUES
(2, 3, NULL, '2026-11-01', 'Cảm cúm', 'Nghỉ ngơi và uống đủ nước');                   -- id 9

-- 6. Thuoc
INSERT INTO Thuoc (ten, donvi, giaban, tonkho, dinhmuccanhbao) VALUES
('Paracetamol', 'Viên', 2000,  100, 20),
('Vitamin C',   'Viên', 1500,  80,  15),
('Siro ho',     'Chai', 25000, 30,  5);

-- 7. Don thuoc
INSERT INTO DonThuoc (benhan_id, ngaylap) VALUES
(1, '2026-11-01'),   -- don 1 cho benh an 1
(9, '2026-11-01');   -- don 2 cho benh an 9

-- 8. Chi tiet don thuoc (trigger tu tru ton kho)
INSERT INTO ChiTietDonThuoc (donthuoc_id, thuoc_id, soluong, lieudung) VALUES
(1, 1, 10, 'Ngày uống 2 lần, mỗi lần 1 viên'),
(1, 2, 5,  'Ngày uống 1 lần, mỗi lần 1 viên'),
(2, 3, 1,  'Uống theo hướng dẫn');

-- 9. Hoa don cho cac lich kham da co benh an
INSERT INTO HoaDon (lichkham_id, phikham, tienthuoc, tongtien, trangthaithanhtoan) VALUES
(1, 150000, 27500, 177500, 'chưa thanh toán'),
(3, 150000, 25000, 175000, 'đã thanh toán');

-- 10. Kiem tra nhanh
SELECT * FROM BenhNhan;
SELECT * FROM HoSoSucKhoe;
SELECT * FROM BacSi;
SELECT * FROM LichKham;
SELECT id, hososuckhoe_id, lichkham_id, benhan_goc_id, ngaykham, chuandoan FROM BenhAn;
SELECT * FROM Thuoc;
SELECT * FROM DonThuoc;
SELECT * FROM ChiTietDonThuoc;
SELECT * FROM HoaDon;
SELECT * FROM CanhBaoTonKho;
