
USE clinic_management;

DELIMITER $$

-- 1. Tinh tong tien thuoc cua mot don thuoc
DROP FUNCTION IF EXISTS fn_TinhTienThuoc$$

CREATE FUNCTION fn_TinhTienThuoc(
    p_donthuoc_id INT
)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_tongtien DECIMAL(12,2) DEFAULT 0;

    SELECT COALESCE(SUM(ct.soluong * t.giaban), 0)
    INTO v_tongtien
    FROM ChiTietDonThuoc ct
    JOIN Thuoc t ON t.id = ct.thuoc_id
    WHERE ct.donthuoc_id = p_donthuoc_id;

    RETURN v_tongtien;
END$$


-- 2. Tinh tong tien hoa don theo phi kham va tien thuoc
DROP FUNCTION IF EXISTS fn_TinhTongTienHoaDon$$

CREATE FUNCTION fn_TinhTongTienHoaDon(
    p_lichkham_id INT
)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_phikham DECIMAL(12,2) DEFAULT 0;
    DECLARE v_tienthuoc DECIMAL(12,2) DEFAULT 0;
    DECLARE v_tongtien DECIMAL(12,2) DEFAULT 0;

    SELECT phikham, tienthuoc
    INTO v_phikham, v_tienthuoc
    FROM HoaDon
    WHERE lichkham_id = p_lichkham_id;

    SET v_tongtien = v_phikham + v_tienthuoc;

    RETURN v_tongtien;
END$$


-- 3. Dem so loai thuoc trong mot don thuoc
DROP FUNCTION IF EXISTS fn_DemThuocTrongDon$$

CREATE FUNCTION fn_DemThuocTrongDon(
    p_donthuoc_id INT
)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_soluong INT DEFAULT 0;

    SELECT COUNT(*)
    INTO v_soluong
    FROM ChiTietDonThuoc
    WHERE donthuoc_id = p_donthuoc_id;

    RETURN v_soluong;
END$$


-- 4. Lay so luong ton kho cua mot thuoc
DROP FUNCTION IF EXISTS fn_TonKhoThuoc$$

CREATE FUNCTION fn_TonKhoThuoc(
    p_thuoc_id INT
)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_tonkho INT DEFAULT 0;

    SELECT tonkho
    INTO v_tonkho
    FROM Thuoc
    WHERE id = p_thuoc_id;

    RETURN v_tonkho;
END$$

DELIMITER ;
