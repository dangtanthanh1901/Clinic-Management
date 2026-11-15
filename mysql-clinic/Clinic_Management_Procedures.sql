USE clinic_management;

DELIMITER $$

-- 1. Tinh tien thuoc va tong vien phi cho mot lich kham
DROP PROCEDURE IF EXISTS sp_TinhVienPhi$$

CREATE PROCEDURE sp_TinhVienPhi(
    IN p_lichkham_id INT
)
BEGIN
    DECLARE v_phikham DECIMAL(12,2);
    DECLARE v_tienthuoc DECIMAL(12,2);
    DECLARE v_trangthai VARCHAR(30);
    DECLARE v_soluong INT DEFAULT 0;

    SELECT COUNT(*) INTO v_soluong
    FROM HoaDon
    WHERE lichkham_id = p_lichkham_id;

    IF v_soluong = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không tìm thấy hóa đơn của lịch khám';
    END IF;

    SELECT phikham, trangthaithanhtoan
    INTO v_phikham, v_trangthai
    FROM HoaDon
    WHERE lichkham_id = p_lichkham_id;

    IF v_trangthai = 'đã thanh toán' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Hóa đơn đã thanh toán, không thể tính lại';
    END IF;

    SELECT COALESCE(SUM(ct.soluong * t.giaban), 0)
    INTO v_tienthuoc
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


-- 2. Thong ke doanh thu theo ngay trong khoang [p_tungay, p_denngay]
DROP PROCEDURE IF EXISTS sp_ThongKeDoanhThu$$

CREATE PROCEDURE sp_ThongKeDoanhThu(
    IN p_tungay DATE,
    IN p_denngay DATE
)
BEGIN
    IF p_tungay IS NULL OR p_denngay IS NULL OR p_tungay > p_denngay THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khoảng ngày thống kê không hợp lệ';
    END IF;

    SELECT
        DATE(lk.ngaygio) AS ngay,
        COUNT(hd.id) AS so_hoa_don,
        COALESCE(SUM(hd.tongtien), 0) AS doanh_thu
    FROM HoaDon hd
    JOIN LichKham lk ON lk.id = hd.lichkham_id
    WHERE hd.trangthaithanhtoan = 'đã thanh toán'
      AND lk.ngaygio >= p_tungay
      AND lk.ngaygio < DATE_ADD(p_denngay, INTERVAL 1 DAY)
    GROUP BY DATE(lk.ngaygio)
    ORDER BY ngay;
END$$


-- 2b. Thong ke doanh thu theo bac si trong khoang [p_tungay, p_denngay]
DROP PROCEDURE IF EXISTS sp_ThongKeDoanhThuTheoBacSi$$

CREATE PROCEDURE sp_ThongKeDoanhThuTheoBacSi(
    IN p_tungay DATE,
    IN p_denngay DATE
)
BEGIN
    IF p_tungay IS NULL OR p_denngay IS NULL OR p_tungay > p_denngay THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khoảng ngày thống kê không hợp lệ';
    END IF;

    SELECT
        bs.id AS bacsi_id,
        bs.hoten AS bacsi,
        COUNT(hd.id) AS so_hoa_don,
        COALESCE(SUM(hd.tongtien), 0) AS doanh_thu
    FROM HoaDon hd
    JOIN LichKham lk ON lk.id = hd.lichkham_id
    JOIN BacSi bs ON bs.id = lk.bacsi_id
    WHERE hd.trangthaithanhtoan = 'đã thanh toán'
      AND lk.ngaygio >= p_tungay
      AND lk.ngaygio < DATE_ADD(p_denngay, INTERVAL 1 DAY)
    GROUP BY bs.id, bs.hoten
    ORDER BY doanh_thu DESC;
END$$


-- 3. Tao don thuoc tu danh sach JSON (TRANSACTION + ROLLBACK)
-- JSON mau:
-- [
--   {"thuoc_id": 1, "soluong": 2, "lieudung": "Ngày uống 2 lần"},
--   {"thuoc_id": 2, "soluong": 1, "lieudung": "Uống sau ăn"}
-- ]
DROP PROCEDURE IF EXISTS sp_TaoDonThuoc$$

CREATE PROCEDURE sp_TaoDonThuoc(
    IN p_benhan_id INT,
    IN p_danhsachthuoc JSON
)
BEGIN
    DECLARE v_donthuoc_id INT;
    DECLARE v_tontai INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_danhsachthuoc IS NULL
       OR JSON_TYPE(p_danhsachthuoc) <> 'ARRAY'
       OR JSON_LENGTH(p_danhsachthuoc) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Danh sách thuốc phải là mảng JSON không rỗng';
    END IF;

    SELECT COUNT(*) INTO v_tontai
    FROM BenhAn
    WHERE id = p_benhan_id;

    IF v_tontai = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Bệnh án không tồn tại';
    END IF;

    START TRANSACTION;

    INSERT INTO DonThuoc (benhan_id, ngaylap)
    VALUES (p_benhan_id, CURRENT_DATE);

    SET v_donthuoc_id = LAST_INSERT_ID();

    INSERT INTO ChiTietDonThuoc (donthuoc_id, thuoc_id, soluong, lieudung)
    SELECT v_donthuoc_id, j.thuoc_id, j.soluong, j.lieudung
    FROM JSON_TABLE(
        p_danhsachthuoc,
        '$[*]' COLUMNS (
            thuoc_id INT PATH '$.thuoc_id' ERROR ON EMPTY ERROR ON ERROR,
            soluong INT PATH '$.soluong' ERROR ON EMPTY ERROR ON ERROR,
            lieudung VARCHAR(255) PATH '$.lieudung' NULL ON EMPTY
        )
    ) AS j;

    COMMIT;

    SELECT v_donthuoc_id AS donthuoc_id, 'Tạo đơn thuốc thành công' AS thongbao;
END$$

DELIMITER ;
