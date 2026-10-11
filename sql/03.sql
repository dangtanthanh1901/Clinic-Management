/* ================================================================
   QUAN LY PHONG KHAM - SQL THEO DUNG THIET KE TRONG CLINIC_REPORT.pdf
   MySQL 8.0+
   9 bang nghiep vu + bang log CanhBaoTonKho
   13 trigger, 3 procedure, 4 function

   LUU Y: Script DROP DATABASE quanlyphongkham va tao lai tu dau.
   Hay sao luu du lieu cu truoc khi chay neu database da co du lieu.
   Chay TOAN BO file bang MySQL Command-Line Client (mysql.exe), khong dung
   SQLTools Run Query cho ca file vi SQLTools co the gui DELIMITER toi server.
   ================================================================ */

DROP DATABASE IF EXISTS quanlyphongkham;
CREATE DATABASE quanlyphongkham CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE quanlyphongkham;

/* ============================ 1. TABLES ============================ */

CREATE TABLE BenhNhan (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hoten VARCHAR(100) NOT NULL,
    ngaysinh DATE,
    gioitinh ENUM('Nam', 'Nữ', 'Khác') NOT NULL,
    sdt VARCHAR(15) NOT NULL UNIQUE,
    diachi VARCHAR(200)
) ENGINE=InnoDB;

CREATE TABLE HoSoSucKhoe (
    id INT AUTO_INCREMENT PRIMARY KEY,
    benhnhan_id INT NOT NULL UNIQUE,
    ngaylap DATE NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT fk_hssk_benhnhan FOREIGN KEY (benhnhan_id) REFERENCES BenhNhan(id)
) ENGINE=InnoDB;

CREATE TABLE BacSi (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hoten VARCHAR(100) NOT NULL,
    chuyenkhoa VARCHAR(100) NOT NULL,
    sdt VARCHAR(15) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE LichKham (
    id INT AUTO_INCREMENT PRIMARY KEY,
    bacsi_id INT NOT NULL,
    ngaygio DATETIME NOT NULL,
    trangthai ENUM('đã đặt', 'đã khám', 'đã hủy') NOT NULL DEFAULT 'đã đặt',
    CONSTRAINT fk_lichkham_bacsi FOREIGN KEY (bacsi_id) REFERENCES BacSi(id),
    CONSTRAINT uq_lichkham_bacsi_ngaygio UNIQUE (bacsi_id, ngaygio)
) ENGINE=InnoDB;

CREATE TABLE BenhAn (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hososuckhoe_id INT NOT NULL,
    lichkham_id INT NOT NULL UNIQUE,
    benhan_goc_id INT NULL,
    ngaykham DATE NOT NULL,
    chuandoan VARCHAR(255) NOT NULL,
    ghichu TEXT,
    CONSTRAINT fk_benhan_hssk FOREIGN KEY (hososuckhoe_id) REFERENCES HoSoSucKhoe(id),
    CONSTRAINT fk_benhan_lichkham FOREIGN KEY (lichkham_id) REFERENCES LichKham(id),
    CONSTRAINT fk_benhan_goc FOREIGN KEY (benhan_goc_id) REFERENCES BenhAn(id)
    -- Khong dung CHECK tham chieu cot AUTO_INCREMENT id; MySQL tu choi cau truc nay.
    -- Trigger trg_KiemTraBenhAnCha_Them / _Sua se kiem tra quan he benh an goc.
) ENGINE=InnoDB;

CREATE TABLE Thuoc (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ten VARCHAR(100) NOT NULL,
    donvi VARCHAR(30) NOT NULL,
    giaban DECIMAL(10,2) NOT NULL,
    tonkho INT NOT NULL DEFAULT 0,
    dinhmuccanhbao INT NOT NULL DEFAULT 0,
    CONSTRAINT chk_thuoc_giaban CHECK (giaban > 0),
    CONSTRAINT chk_thuoc_tonkho CHECK (tonkho >= 0),
    CONSTRAINT chk_thuoc_dinhmuc CHECK (dinhmuccanhbao >= 0)
) ENGINE=InnoDB;

CREATE TABLE DonThuoc (
    id INT AUTO_INCREMENT PRIMARY KEY,
    benhan_id INT NOT NULL,
    ngaylap DATE NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT fk_donthuoc_benhan FOREIGN KEY (benhan_id) REFERENCES BenhAn(id)
) ENGINE=InnoDB;

CREATE TABLE ChiTietDonThuoc (
    donthuoc_id INT NOT NULL,
    thuoc_id INT NOT NULL,
    soluong INT NOT NULL,
    lieudung VARCHAR(200),
    PRIMARY KEY (donthuoc_id, thuoc_id),
    CONSTRAINT fk_ctdt_donthuoc FOREIGN KEY (donthuoc_id) REFERENCES DonThuoc(id),
    CONSTRAINT fk_ctdt_thuoc FOREIGN KEY (thuoc_id) REFERENCES Thuoc(id),
    CONSTRAINT chk_ctdt_soluong CHECK (soluong > 0)
) ENGINE=InnoDB;

CREATE TABLE HoaDon (
    id INT AUTO_INCREMENT PRIMARY KEY,
    lichkham_id INT NOT NULL UNIQUE,
    phikham DECIMAL(10,2) NOT NULL DEFAULT 0,
    tienthuoc DECIMAL(10,2) NOT NULL DEFAULT 0,
    tongtien DECIMAL(10,2) NOT NULL DEFAULT 0,
    trangthaithanhtoan ENUM('chưa thanh toán', 'đã thanh toán') NOT NULL DEFAULT 'chưa thanh toán',
    CONSTRAINT fk_hoadon_lichkham FOREIGN KEY (lichkham_id) REFERENCES LichKham(id),
    CONSTRAINT chk_hoadon_phikham CHECK (phikham >= 0),
    CONSTRAINT chk_hoadon_tienthuoc CHECK (tienthuoc >= 0),
    CONSTRAINT chk_hoadon_tongtien CHECK (tongtien >= 0)
) ENGINE=InnoDB;

/* Bang log phu, khong tinh trong 9 bang nghiep vu */
CREATE TABLE CanhBaoTonKho (
    id INT AUTO_INCREMENT PRIMARY KEY,
    thuoc_id INT NOT NULL,
    tonkho INT NOT NULL,
    dinhmuccanhbao INT NOT NULL,
    thoigian DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_canhbao_thuoc FOREIGN KEY (thuoc_id) REFERENCES Thuoc(id)
) ENGINE=InnoDB;

/* ============================ 2. TRIGGERS ============================ */
DELIMITER $$

/* 1. BEFORE INSERT ChiTietDonThuoc: kiem tra ton kho */
CREATE TRIGGER trg_KiemTraTonKho
BEFORE INSERT ON ChiTietDonThuoc
FOR EACH ROW
BEGIN
    DECLARE v_tonkho INT DEFAULT NULL;
    SET v_tonkho = (SELECT tonkho FROM Thuoc WHERE id = NEW.thuoc_id);
    IF v_tonkho IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Thuoc khong ton tai';
    ELSEIF NEW.soluong <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'So luong thuoc phai lon hon 0';
    ELSEIF NEW.soluong > v_tonkho THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vuot ton kho: so luong ke lon hon so luong con';
    END IF;
END$$

/* 2. AFTER INSERT ChiTietDonThuoc: tru kho */
CREATE TRIGGER trg_TruTonKho
AFTER INSERT ON ChiTietDonThuoc
FOR EACH ROW
BEGIN
    UPDATE Thuoc SET tonkho = tonkho - NEW.soluong WHERE id = NEW.thuoc_id;
END$$

/* 3. AFTER DELETE ChiTietDonThuoc: hoan kho */
CREATE TRIGGER trg_HoanTonKhoXoa
AFTER DELETE ON ChiTietDonThuoc
FOR EACH ROW
BEGIN
    UPDATE Thuoc SET tonkho = tonkho + OLD.soluong WHERE id = OLD.thuoc_id;
END$$

/* 4. BEFORE UPDATE ChiTietDonThuoc: kiem tra va dieu chinh kho */
CREATE TRIGGER trg_DieuChinhTonKhoSua
BEFORE UPDATE ON ChiTietDonThuoc
FOR EACH ROW
BEGIN
    DECLARE v_tonkho_moi INT DEFAULT NULL;
    SET v_tonkho_moi = (SELECT tonkho FROM Thuoc WHERE id = NEW.thuoc_id);

    IF NEW.soluong <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'So luong thuoc phai lon hon 0';
    ELSEIF v_tonkho_moi IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Thuoc moi khong ton tai';
    ELSEIF OLD.thuoc_id = NEW.thuoc_id THEN
        IF v_tonkho_moi + OLD.soluong < NEW.soluong THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vuot ton kho khi cap nhat so luong';
        END IF;
        UPDATE Thuoc SET tonkho = tonkho + OLD.soluong - NEW.soluong WHERE id = NEW.thuoc_id;
    ELSE
        IF v_tonkho_moi < NEW.soluong THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Thuoc thay the khong du ton kho';
        END IF;
        UPDATE Thuoc SET tonkho = tonkho + OLD.soluong WHERE id = OLD.thuoc_id;
        UPDATE Thuoc SET tonkho = tonkho - NEW.soluong WHERE id = NEW.thuoc_id;
    END IF;
END$$

/* 5. AFTER UPDATE Thuoc: ghi log khi ton kho chuyen tu tren/du nguong xuong duoi nguong */
CREATE TRIGGER trg_CanhBaoTonKho
AFTER UPDATE ON Thuoc
FOR EACH ROW
BEGIN
    IF NEW.tonkho < NEW.dinhmuccanhbao
       AND OLD.tonkho >= OLD.dinhmuccanhbao THEN
        INSERT INTO CanhBaoTonKho(thuoc_id, tonkho, dinhmuccanhbao)
        VALUES (NEW.id, NEW.tonkho, NEW.dinhmuccanhbao);
    END IF;
END$$

/* 6. BEFORE INSERT LichKham: chan lich bac si bi chong lan trong 30 phut */
CREATE TRIGGER trg_ChanTrungLich_Them
BEFORE INSERT ON LichKham
FOR EACH ROW
BEGIN
    IF NEW.trangthai <> 'đã hủy' AND EXISTS (
        SELECT 1 FROM LichKham lk
        WHERE lk.bacsi_id = NEW.bacsi_id
          AND lk.trangthai <> 'đã hủy'
          AND lk.ngaygio < DATE_ADD(NEW.ngaygio, INTERVAL 30 MINUTE)
          AND DATE_ADD(lk.ngaygio, INTERVAL 30 MINUTE) > NEW.ngaygio
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bac si da co lich kham trung/chong gio trong ca 30 phut';
    END IF;
END$$

/* 7. BEFORE UPDATE LichKham: kiem tra lai khi doi bac si/gio */
CREATE TRIGGER trg_ChanTrungLich_Sua
BEFORE UPDATE ON LichKham
FOR EACH ROW
BEGIN
    IF NEW.trangthai <> 'đã hủy' AND EXISTS (
        SELECT 1 FROM LichKham lk
        WHERE lk.bacsi_id = NEW.bacsi_id
          AND lk.id <> OLD.id
          AND lk.trangthai <> 'đã hủy'
          AND lk.ngaygio < DATE_ADD(NEW.ngaygio, INTERVAL 30 MINUTE)
          AND DATE_ADD(lk.ngaygio, INTERVAL 30 MINUTE) > NEW.ngaygio
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bac si da co lich kham trung/chong gio trong ca 30 phut';
    END IF;
END$$

/* 8. BEFORE INSERT BenhAn: benh an con phai tro den benh an goc hop le */
CREATE TRIGGER trg_KiemTraBenhAnCha_Them
BEFORE INSERT ON BenhAn
FOR EACH ROW
BEGIN
    DECLARE v_ho_so_cha INT DEFAULT NULL;
    DECLARE v_cha_cua_cha INT DEFAULT NULL;
    DECLARE v_ngay_cha DATE DEFAULT NULL;
    IF NEW.benhan_goc_id IS NOT NULL THEN
        IF NEW.benhan_goc_id = NEW.id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Benh an khong the tro den chinh no';
        END IF;
        SET v_ho_so_cha = (SELECT hososuckhoe_id FROM BenhAn WHERE id = NEW.benhan_goc_id);
        SET v_cha_cua_cha = (SELECT benhan_goc_id FROM BenhAn WHERE id = NEW.benhan_goc_id);
        SET v_ngay_cha = (SELECT ngaykham FROM BenhAn WHERE id = NEW.benhan_goc_id);
        IF v_ho_so_cha IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Benh an goc khong ton tai';
        ELSEIF v_cha_cua_cha IS NOT NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Benh an duoc tham chieu phai la benh an goc';
        ELSEIF v_ho_so_cha <> NEW.hososuckhoe_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Benh an goc va benh an tai kham phai cung ho so suc khoe';
        ELSEIF NEW.ngaykham < v_ngay_cha THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ngay tai kham khong duoc som hon ngay benh an goc';
        END IF;
    END IF;
END$$

/* 9. BEFORE UPDATE BenhAn: cung cac kiem tra cha-con khi sua */
CREATE TRIGGER trg_KiemTraBenhAnCha_Sua
BEFORE UPDATE ON BenhAn
FOR EACH ROW
BEGIN
    DECLARE v_ho_so_cha INT DEFAULT NULL;
    DECLARE v_cha_cua_cha INT DEFAULT NULL;
    DECLARE v_ngay_cha DATE DEFAULT NULL;
    IF NEW.benhan_goc_id IS NOT NULL THEN
        IF NEW.benhan_goc_id = OLD.id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Benh an khong the tro den chinh no';
        END IF;
        SET v_ho_so_cha = (SELECT hososuckhoe_id FROM BenhAn WHERE id = NEW.benhan_goc_id);
        SET v_cha_cua_cha = (SELECT benhan_goc_id FROM BenhAn WHERE id = NEW.benhan_goc_id);
        SET v_ngay_cha = (SELECT ngaykham FROM BenhAn WHERE id = NEW.benhan_goc_id);
        IF v_ho_so_cha IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Benh an goc khong ton tai';
        ELSEIF v_cha_cua_cha IS NOT NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Benh an duoc tham chieu phai la benh an goc';
        ELSEIF v_ho_so_cha <> NEW.hososuckhoe_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Benh an goc va benh an tai kham phai cung ho so suc khoe';
        ELSEIF NEW.ngaykham < v_ngay_cha THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ngay tai kham khong duoc som hon ngay benh an goc';
        END IF;
    END IF;
END$$

/* 10. AFTER INSERT BenhAn: chuyen lich kham sang da kham */
CREATE TRIGGER trg_CapNhatTrangThaiLich
AFTER INSERT ON BenhAn
FOR EACH ROW
BEGIN
    UPDATE LichKham SET trangthai = 'đã khám' WHERE id = NEW.lichkham_id;
END$$

/* 11. BEFORE UPDATE LichKham: khong cho lich da kham quay lai dat/huy */
CREATE TRIGGER trg_ChanDoiTrangThaiLich
BEFORE UPDATE ON LichKham
FOR EACH ROW
BEGIN
    IF OLD.trangthai = 'đã khám' AND NEW.trangthai IN ('đã đặt', 'đã hủy') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lich da kham khong the chuyen ve da dat hoac da huy';
    END IF;
END$$

/* 12. BEFORE UPDATE HoaDon: chan sua tien neu da thanh toan */
CREATE TRIGGER trg_ChanSuaHoaDon
BEFORE UPDATE ON HoaDon
FOR EACH ROW
BEGIN
    IF OLD.trangthaithanhtoan = 'đã thanh toán'
       AND (NEW.phikham <> OLD.phikham OR NEW.tienthuoc <> OLD.tienthuoc OR NEW.tongtien <> OLD.tongtien) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hoa don da thanh toan, khong duoc sua cac khoan tien';
    END IF;
END$$

/* 13. BEFORE UPDATE HoaDon: tu tinh tongtien; dat sau trigger chan sua */
CREATE TRIGGER trg_TinhTongTien
BEFORE UPDATE ON HoaDon
FOR EACH ROW FOLLOWS trg_ChanSuaHoaDon
BEGIN
    SET NEW.tongtien = NEW.phikham + NEW.tienthuoc;
END$$

DELIMITER ;

/* ============================ 3. PROCEDURES ============================ */
DELIMITER $$

/* Procedure 1: tinh tien thuoc, cap nhat hoa don theo lich kham */
CREATE PROCEDURE sp_TinhVienPhi(IN p_lichkham_id INT)
BEGIN
    DECLARE v_phikham DECIMAL(10,2) DEFAULT 0;
    DECLARE v_tienthuoc DECIMAL(10,2) DEFAULT 0;
    DECLARE v_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_count FROM HoaDon WHERE lichkham_id = p_lichkham_id;
    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khong tim thay hoa don cua lich kham';
    END IF;

    SELECT phikham INTO v_phikham FROM HoaDon WHERE lichkham_id = p_lichkham_id;
    SELECT COALESCE(SUM(ct.soluong * t.giaban), 0) INTO v_tienthuoc
    FROM BenhAn ba
    JOIN DonThuoc dt ON dt.benhan_id = ba.id
    JOIN ChiTietDonThuoc ct ON ct.donthuoc_id = dt.id
    JOIN Thuoc t ON t.id = ct.thuoc_id
    WHERE ba.lichkham_id = p_lichkham_id;

    UPDATE HoaDon
    SET tienthuoc = v_tienthuoc,
        tongtien = v_phikham + v_tienthuoc
    WHERE lichkham_id = p_lichkham_id;
END$$

/* Procedure 2: thong ke doanh thu hoa don da thanh toan theo ngay */
CREATE PROCEDURE sp_ThongKeDoanhThu(IN p_tungay DATE, IN p_denngay DATE)
BEGIN
    IF p_tungay IS NULL OR p_denngay IS NULL OR p_tungay > p_denngay THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khoang ngay thong ke khong hop le';
    END IF;

    SELECT DATE(lk.ngaygio) AS ngay,
           COUNT(hd.id) AS so_hoa_don,
           COALESCE(SUM(hd.tongtien), 0) AS doanh_thu
    FROM HoaDon hd
    JOIN LichKham lk ON lk.id = hd.lichkham_id
    WHERE lk.ngaygio >= p_tungay
      AND lk.ngaygio < DATE_ADD(p_denngay, INTERVAL 1 DAY)
      AND hd.trangthaithanhtoan = 'đã thanh toán'
    GROUP BY DATE(lk.ngaygio)
    ORDER BY ngay;
END$$

/* Procedure 3: tao don thuoc va cac dong chi tiet tu mang JSON trong mot transaction.
   Dinh dang JSON: [{"thuoc_id":1,"soluong":2,"lieudung":"Ngay 2 lan"}, ...] */
CREATE PROCEDURE sp_TaoDonThuoc(IN p_benhan_id INT, IN p_danhsachthuoc JSON)
BEGIN
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_len INT DEFAULT 0;
    DECLARE v_thuoc_id INT;
    DECLARE v_soluong INT;
    DECLARE v_lieudung VARCHAR(200);
    DECLARE v_donthuoc_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_danhsachthuoc IS NULL OR JSON_TYPE(p_danhsachthuoc) <> 'ARRAY' OR JSON_LENGTH(p_danhsachthuoc) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Danh sach thuoc phai la mang JSON khong rong';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM BenhAn WHERE id = p_benhan_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Benh an khong ton tai';
    END IF;

    START TRANSACTION;
    INSERT INTO DonThuoc(benhan_id, ngaylap) VALUES (p_benhan_id, CURRENT_DATE);
    SET v_donthuoc_id = LAST_INSERT_ID();
    SET v_len = JSON_LENGTH(p_danhsachthuoc);

    WHILE v_i < v_len DO
        SET v_thuoc_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_danhsachthuoc, CONCAT('$[', v_i, '].thuoc_id'))) AS UNSIGNED);
        SET v_soluong = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_danhsachthuoc, CONCAT('$[', v_i, '].soluong'))) AS SIGNED);
        SET v_lieudung = JSON_UNQUOTE(JSON_EXTRACT(p_danhsachthuoc, CONCAT('$[', v_i, '].lieudung')));

        IF v_thuoc_id IS NULL OR v_soluong IS NULL OR v_soluong <= 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Moi dong thuoc can co thuoc_id va soluong hop le';
        END IF;
        INSERT INTO ChiTietDonThuoc(donthuoc_id, thuoc_id, soluong, lieudung)
        VALUES (v_donthuoc_id, v_thuoc_id, v_soluong, v_lieudung);
        SET v_i = v_i + 1;
    END WHILE;

    COMMIT;
    SELECT v_donthuoc_id AS donthuoc_id_moi;
END$$

DELIMITER ;

/* ============================ 4. FUNCTIONS ============================ */
DELIMITER $$

CREATE FUNCTION fn_TinhTienThuoc(p_lichkham_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_tien DECIMAL(10,2) DEFAULT 0;
    SELECT COALESCE(SUM(ct.soluong * t.giaban), 0) INTO v_tien
    FROM BenhAn ba
    JOIN DonThuoc dt ON dt.benhan_id = ba.id
    JOIN ChiTietDonThuoc ct ON ct.donthuoc_id = dt.id
    JOIN Thuoc t ON t.id = ct.thuoc_id
    WHERE ba.lichkham_id = p_lichkham_id;
    RETURN v_tien;
END$$

CREATE FUNCTION fn_TinhTongTienHoaDon(p_lichkham_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_phikham DECIMAL(10,2) DEFAULT 0;
    SELECT COALESCE(MAX(phikham), 0) INTO v_phikham
    FROM HoaDon WHERE lichkham_id = p_lichkham_id;
    RETURN v_phikham + fn_TinhTienThuoc(p_lichkham_id);
END$$

CREATE FUNCTION fn_DemThuocTrongDon(p_donthuoc_id INT)
RETURNS INT
DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_so_loai INT DEFAULT 0;
    SELECT COUNT(*) INTO v_so_loai FROM ChiTietDonThuoc WHERE donthuoc_id = p_donthuoc_id;
    RETURN v_so_loai;
END$$

CREATE FUNCTION fn_TonKhoThuoc(p_thuoc_id INT)
RETURNS INT
DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_tonkho INT DEFAULT 0;
    SELECT COALESCE(MAX(tonkho), 0) INTO v_tonkho FROM Thuoc WHERE id = p_thuoc_id;
    RETURN v_tonkho;
END$$

DELIMITER ;

/* ============================ 5. SAMPLE DATA ============================ */
INSERT INTO BenhNhan(hoten, ngaysinh, gioitinh, sdt, diachi) VALUES
('Nguyen Van An', '2000-05-10', 'Nam', '0901000001', 'Tan An'),
('Tran Thi Binh', '1999-08-20', 'Nữ', '0901000002', 'Ben Luc'),
('Le Van Cuong', '2002-01-15', 'Nam', '0901000003', 'Tan Tru');

INSERT INTO HoSoSucKhoe(benhnhan_id, ngaylap) VALUES (1, '2026-10-01'), (2, '2026-10-01'), (3, '2026-10-01');

INSERT INTO BacSi(hoten, chuyenkhoa, sdt) VALUES
('Nguyen Van Minh', 'Noi khoa', '0911000001'),
('Tran Thi Lan', 'Nhi khoa', '0911000002');

INSERT INTO Thuoc(ten, donvi, giaban, tonkho, dinhmuccanhbao) VALUES
('Paracetamol', 'vien', 2000, 100, 20),
('Amoxicillin', 'vien', 3000, 50, 10),
('Vitamin C', 'vien', 1500, 30, 10);

/* Moi lich cach nhau it nhat 30 phut voi cung mot bac si */
INSERT INTO LichKham(bacsi_id, ngaygio, trangthai) VALUES
(1, '2026-10-12 08:00:00', 'đã đặt'),
(1, '2026-10-12 08:30:00', 'đã đặt'),
(2, '2026-10-12 09:00:00', 'đã đặt'),
(1, '2026-10-13 08:00:00', 'đã đặt'),
(1, '2026-10-13 08:30:00', 'đã đặt');

/* Benh an goc va cac lan tai kham: con tro truc tiep ve benh an goc */
INSERT INTO BenhAn(hososuckhoe_id, lichkham_id, benhan_goc_id, ngaykham, chuandoan, ghichu) VALUES
(1, 1, NULL, '2026-10-12', 'Viem hong', 'Benh an goc 1'),
(1, 2, 1,    '2026-10-12', 'Viem hong dang theo doi', 'Tai kham benh goc 1'),
(2, 3, NULL, '2026-10-12', 'Cam cum', 'Benh an goc 2'),
(1, 4, NULL, '2026-10-13', 'Dau dau', 'Benh moi, benh an goc doc lap'),
(1, 5, 1,    '2026-10-13', 'Viem hong dang theo doi', 'Quay lai benh goc 1');

/* Tao hoa don cho cac lich kham mau; tongtien khi INSERT phai duoc tinh ro rang */
INSERT INTO HoaDon(lichkham_id, phikham, tienthuoc, tongtien, trangthaithanhtoan) VALUES
(1, 150000, 0, 150000, 'chưa thanh toán'),
(2, 150000, 0, 150000, 'chưa thanh toán'),
(3, 120000, 0, 120000, 'đã thanh toán'),
(4, 150000, 0, 150000, 'chưa thanh toán'),
(5, 150000, 0, 150000, 'chưa thanh toán');

/* Tao don thuoc mau va cac chi tiet hop le; trigger tu dong tru kho */
INSERT INTO DonThuoc(benhan_id, ngaylap) VALUES (1, '2026-10-12'), (2, '2026-10-12');
INSERT INTO ChiTietDonThuoc(donthuoc_id, thuoc_id, soluong, lieudung) VALUES
(1, 1, 5, 'Ngay 2 lan'),
(1, 3, 4, 'Ngay 1 lan'),
(2, 2, 3, 'Ngay 3 lan');

/* Cap nhat vien phi cho cac lich co don thuoc */
CALL sp_TinhVienPhi(1);
CALL sp_TinhVienPhi(2);

/* ============================ 6. QUICK TESTS ============================ */
/* Function tests */
SELECT fn_TinhTienThuoc(1) AS tien_thuoc_lich_1;
SELECT fn_TinhTongTienHoaDon(1) AS tong_tien_lich_1;
SELECT fn_DemThuocTrongDon(1) AS so_loai_thuoc_don_1;
SELECT fn_TonKhoThuoc(1) AS ton_kho_paracetamol;

/* Procedure test: doanh thu chi tinh hoa don da thanh toan */
CALL sp_ThongKeDoanhThu('2026-10-01', '2026-10-31');

/* Procedure JSON test - bo comment de chay rieng neu muon tao don thuoc moi:
CALL sp_TaoDonThuoc(3,
 '[{"thuoc_id":1,"soluong":2,"lieudung":"Ngay 2 lan"},
   {"thuoc_id":3,"soluong":1,"lieudung":"Ngay 1 lan"}]');
*/

/* CAC TEST VI PHAM: bo comment va chay tung cau rieng de quan sat SIGNAL.
   1. Trung/chong lich bac si trong 30 phut:
   INSERT INTO LichKham(bacsi_id, ngaygio) VALUES (1, '2026-10-12 08:15:00');

   2. Ke vuot ton kho (vi du ton kho da thay doi, hay chon so luong rat lon):
   INSERT INTO ChiTietDonThuoc(donthuoc_id, thuoc_id, soluong, lieudung) VALUES (1, 1, 999999, 'test');

   3. Benh an tai kham tro den benh an khong phai goc (id=2 la con cua id=1):
   INSERT INTO BenhAn(hososuckhoe_id, lichkham_id, benhan_goc_id, ngaykham, chuandoan)
   VALUES (1, 4, 2, '2026-10-13', 'Test sai benh an goc');

   4. Khong cho sua tien cua hoa don da thanh toan:
   UPDATE HoaDon SET phikham = phikham + 10000 WHERE lichkham_id = 3;
*/
