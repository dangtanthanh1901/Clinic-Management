
USE clinic_management;

-- 1. Them benh nhan
INSERT INTO BenhNhan (hoten, ngaysinh, gioitinh, sdt, diachi)
VALUES
('Nguyen Van An', '2000-05-10', 'Nam', '0901000001', 'Tay Ninh'),
('Tran Thi Binh', '1998-08-20', 'Nu', '0901000002', 'Long An'),
('Le Van Cuong', '1995-03-15', 'Nam', '0901000003', 'TP HCM');

-- 2. Tao ho so suc khoe
INSERT INTO HoSoSucKhoe (benhnhan_id, ngaylap)
SELECT id, CURRENT_DATE
FROM BenhNhan
WHERE sdt IN ('0901000001', '0901000002', '0901000003');

-- 3. Them bac si
INSERT INTO BacSi (hoten, chuyenkhoa, sdt)
VALUES
('Nguyen Minh Duc', 'Noi tong quat', '0911000001'),
('Pham Thi Lan', 'Nhi khoa', '0911000002');

-- 4. Tao lich kham
-- Hai lich cua bac si 1 cach nhau hon 30 phut
INSERT INTO LichKham (bacsi_id, ngaygio, trangthai)
VALUES
(1, '2026-11-01 08:00:00', 'đã đặt'),
(1, '2026-11-01 09:00:00', 'đã đặt'),
(2, '2026-11-01 08:30:00', 'đã đặt');

-- 5. Tao benh an
-- Trigger se tu dong chuyen lich kham thanh "da kham"
INSERT INTO BenhAn
    (hososuckhoe_id, lichkham_id, benhan_goc_id,
     ngaykham, chuandoan, ghichu)
VALUES
(1, 1, NULL, '2026-11-01', 'Viem hong', 'Tai kham neu con trieu chung'),
(2, 3, NULL, '2026-11-01', 'Cam cum', 'Nghi ngoi va uong du nuoc');

-- 6. Them thuoc
INSERT INTO Thuoc (ten, donvi, giaban, tonkho, dinhmuccanhbao)
VALUES
('Paracetamol', 'Vien', 2000, 100, 20),
('Vitamin C', 'Vien', 1500, 80, 15),
('Siro ho', 'Chai', 25000, 30, 5);

-- 7. Tao don thuoc
INSERT INTO DonThuoc (benhan_id, ngaylap)
VALUES
(1, '2026-11-01'),
(2, '2026-11-01');

-- 8. Them chi tiet don thuoc
-- Trigger tu dong tru ton kho khi them chi tiet
INSERT INTO ChiTietDonThuoc
    (donthuoc_id, thuoc_id, soluong, lieudung)
VALUES
(1, 1, 10, 'Ngay uong 2 lan, moi lan 1 vien'),
(1, 2, 5, 'Ngay uong 1 lan, moi lan 1 vien'),
(2, 3, 1, 'Uong theo huong dan');

-- 9. Tao hoa don cho cac lich kham co benh an
INSERT INTO HoaDon
    (lichkham_id, phikham, tienthuoc, tongtien, trangthaithanhtoan)
VALUES
(1, 150000, 27500, 177500, 'chưa thanh toán'),
(3, 150000, 25000, 175000, 'đã thanh toán');

-- 10. Kiem tra du lieu
SELECT * FROM BenhNhan;
SELECT * FROM HoSoSucKhoe;
SELECT * FROM BacSi;
SELECT * FROM LichKham;
SELECT * FROM BenhAn;
SELECT * FROM Thuoc;
SELECT * FROM DonThuoc;
SELECT * FROM ChiTietDonThuoc;
SELECT * FROM HoaDon;
SELECT * FROM CanhBaoTonKho;
