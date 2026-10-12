USE clinic_management;

DELIMITER $$

CREATE TRIGGER trg_KiemTraTonKho
BEFORE INSERT ON ChiTietDonThuoc
FOR EACH ROW
BEGIN
    DECLARE v_tonkho INT;
    SELECT tonkho INTO v_tonkho FROM Thuoc WHERE id = NEW.thuoc_id;
    IF v_tonkho IS NULL OR NEW.soluong > v_tonkho THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vượt tồn kho';
    END IF;
END$$

CREATE TRIGGER trg_TruTonKho
AFTER INSERT ON ChiTietDonThuoc
FOR EACH ROW
BEGIN
    UPDATE Thuoc SET tonkho = tonkho - NEW.soluong WHERE id = NEW.thuoc_id;
END$$

CREATE TRIGGER trg_HoanTonKhoXoa
AFTER DELETE ON ChiTietDonThuoc
FOR EACH ROW
BEGIN
    UPDATE Thuoc SET tonkho = tonkho + OLD.soluong WHERE id = OLD.thuoc_id;
END$$

CREATE TRIGGER trg_DieuChinhTonKhoSua
BEFORE UPDATE ON ChiTietDonThuoc
FOR EACH ROW
BEGIN
    DECLARE v_tonkho INT;
    DECLARE v_chenhlech INT;

    IF NEW.thuoc_id <> OLD.thuoc_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không được đổi loại thuốc của dòng chi tiết';
    END IF;

    SET v_chenhlech = NEW.soluong - OLD.soluong;
    IF v_chenhlech <> 0 THEN
        SELECT tonkho INTO v_tonkho FROM Thuoc WHERE id = OLD.thuoc_id;
        IF v_chenhlech > v_tonkho THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vượt tồn kho';
        END IF;
        UPDATE Thuoc SET tonkho = tonkho - v_chenhlech WHERE id = OLD.thuoc_id;
    END IF;
END$$

CREATE TRIGGER trg_CanhBaoTonKho
AFTER UPDATE ON Thuoc
FOR EACH ROW
BEGIN
    IF NEW.tonkho < NEW.dinhmuccanhbao AND OLD.tonkho >= NEW.dinhmuccanhbao THEN
        INSERT INTO CanhBaoTonKho (thuoc_id, tonkho, dinhmuccanhbao)
        VALUES (NEW.id, NEW.tonkho, NEW.dinhmuccanhbao);
    END IF;
END$$

CREATE TRIGGER trg_ChanTrungLich_Them
BEFORE INSERT ON LichKham
FOR EACH ROW
BEGIN
    IF NEW.trangthai <> 'đã hủy' AND EXISTS (
        SELECT 1 FROM LichKham
        WHERE bacsi_id = NEW.bacsi_id
          AND trangthai <> 'đã hủy'
          AND ABS(TIMESTAMPDIFF(MINUTE, ngaygio, NEW.ngaygio)) < 30
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bác sĩ đã có lịch khám trùng giờ';
    END IF;
END$$

CREATE TRIGGER trg_ChanTrungLich_Sua
BEFORE UPDATE ON LichKham
FOR EACH ROW
BEGIN
    IF NEW.trangthai <> 'đã hủy'
       AND (NEW.ngaygio <> OLD.ngaygio OR NEW.bacsi_id <> OLD.bacsi_id)
       AND EXISTS (
            SELECT 1 FROM LichKham
            WHERE bacsi_id = NEW.bacsi_id
              AND id <> OLD.id
              AND trangthai <> 'đã hủy'
              AND ABS(TIMESTAMPDIFF(MINUTE, ngaygio, NEW.ngaygio)) < 30
       ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bác sĩ đã có lịch khám trùng giờ';
    END IF;
END$$

CREATE TRIGGER trg_ChanDoiTrangThaiLich
BEFORE UPDATE ON LichKham
FOR EACH ROW
BEGIN
    IF OLD.trangthai = 'đã khám' AND NEW.trangthai <> 'đã khám' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lịch đã khám không được đổi trạng thái';
    END IF;
END$$

CREATE TRIGGER trg_KiemTraBenhAnCha_Them
BEFORE INSERT ON BenhAn
FOR EACH ROW
BEGIN
    DECLARE v_goc INT;
    DECLARE v_hoso INT;
    DECLARE v_ngay DATE;

    IF NEW.benhan_goc_id IS NOT NULL THEN
        SELECT benhan_goc_id, hososuckhoe_id, ngaykham
        INTO v_goc, v_hoso, v_ngay
        FROM BenhAn WHERE id = NEW.benhan_goc_id;

        IF v_hoso IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bệnh án cha không tồn tại';
        ELSEIF v_goc IS NOT NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bệnh án cha phải là bệnh gốc';
        ELSEIF v_hoso <> NEW.hososuckhoe_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bệnh án cha phải cùng hồ sơ sức khỏe';
        ELSEIF NEW.ngaykham < v_ngay THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ngày tái khám không được sớm hơn bệnh án cha';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_KiemTraBenhAnCha_Sua
BEFORE UPDATE ON BenhAn
FOR EACH ROW
BEGIN
    DECLARE v_goc INT;
    DECLARE v_hoso INT;
    DECLARE v_ngay DATE;

    IF NEW.benhan_goc_id IS NOT NULL THEN
        IF NEW.benhan_goc_id = OLD.id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bệnh án không được là tái khám của chính nó';
        END IF;

        IF EXISTS (SELECT 1 FROM BenhAn WHERE benhan_goc_id = OLD.id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bệnh án đang là bệnh gốc của các lần tái khám khác';
        END IF;

        SELECT benhan_goc_id, hososuckhoe_id, ngaykham
        INTO v_goc, v_hoso, v_ngay
        FROM BenhAn WHERE id = NEW.benhan_goc_id;

        IF v_hoso IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bệnh án cha không tồn tại';
        ELSEIF v_goc IS NOT NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bệnh án cha phải là bệnh gốc';
        ELSEIF v_hoso <> NEW.hososuckhoe_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bệnh án cha phải cùng hồ sơ sức khỏe';
        ELSEIF NEW.ngaykham < v_ngay THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ngày tái khám không được sớm hơn bệnh án cha';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_CapNhatTrangThaiLich
AFTER INSERT ON BenhAn
FOR EACH ROW
BEGIN
    IF NEW.lichkham_id IS NOT NULL THEN
        UPDATE LichKham SET trangthai = 'đã khám' WHERE id = NEW.lichkham_id;
    END IF;
END$$

CREATE TRIGGER trg_TinhTongTien
BEFORE UPDATE ON HoaDon
FOR EACH ROW
BEGIN
    SET NEW.tongtien = NEW.phikham + NEW.tienthuoc;
END$$

CREATE TRIGGER trg_ChanSuaHoaDon
BEFORE UPDATE ON HoaDon
FOR EACH ROW
PRECEDES trg_TinhTongTien
BEGIN
    IF OLD.trangthaithanhtoan = 'đã thanh toán'
       AND (NEW.phikham <> OLD.phikham
            OR NEW.tienthuoc <> OLD.tienthuoc
            OR NEW.tongtien <> OLD.tongtien) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hóa đơn đã thanh toán không được sửa';
    END IF;
END$$

DELIMITER ;