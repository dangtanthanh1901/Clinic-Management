/* =========================================================
   QUẢN LÝ PHÒNG KHÁM
   DATABASE: quanlyphongkham
   ========================================================= */


/* =========================================================
   1. TẠO DATABASE
   ========================================================= */

CREATE DATABASE IF NOT EXISTS quanlyphongkham;

USE quanlyphongkham;


/* =========================================================
   2. XÓA FUNCTION CŨ
   ========================================================= */

DROP FUNCTION IF EXISTS fn_TinhTienThuoc;
DROP FUNCTION IF EXISTS fn_TinhTongTienHoaDon;
DROP FUNCTION IF EXISTS fn_DemThuocTrongDon;
DROP FUNCTION IF EXISTS fn_TonKhoThuoc;


/* =========================================================
   3. XÓA PROCEDURE CŨ
   ========================================================= */

DROP PROCEDURE IF EXISTS sp_TinhTienHoaDon;
DROP PROCEDURE IF EXISTS sp_ThongKeDoanhThu;
DROP PROCEDURE IF EXISTS sp_ThemChiTietDonThuoc;


/* =========================================================
   4. XÓA BẢNG CŨ
   Xóa theo thứ tự từ bảng phụ -> bảng cha
   ========================================================= */

DROP TABLE IF EXISTS CanhBaoTonKho;
DROP TABLE IF EXISTS ChiTietDonThuoc;
DROP TABLE IF EXISTS DonThuoc;
DROP TABLE IF EXISTS HoaDon;
DROP TABLE IF EXISTS LichKham;
DROP TABLE IF EXISTS Thuoc;
DROP TABLE IF EXISTS BacSi;
DROP TABLE IF EXISTS BenhNhan;


/* =========================================================
   5. TẠO BẢNG BENHNHAN
   ========================================================= */

CREATE TABLE BenhNhan (
    MaBN        INT AUTO_INCREMENT PRIMARY KEY,
    HoTen       VARCHAR(100) NOT NULL,
    NgaySinh    DATE,
    GioiTinh    ENUM('Nam', 'Nữ', 'Khác') NOT NULL,
    SDT         VARCHAR(15) NOT NULL,
    DiaChi      VARCHAR(200),

    CONSTRAINT uq_benhnhan_sdt
        UNIQUE (SDT)
);


/* =========================================================
   6. TẠO BẢNG BACSI
   ========================================================= */

CREATE TABLE BacSi (
    MaBS        INT AUTO_INCREMENT PRIMARY KEY,
    HoTen       VARCHAR(100) NOT NULL,
    ChuyenKhoa  VARCHAR(100) NOT NULL,
    SDT         VARCHAR(15) NOT NULL,

    CONSTRAINT uq_bacsi_sdt
        UNIQUE (SDT)
);


/* =========================================================
   7. TẠO BẢNG LICHKHAM
   ========================================================= */

CREATE TABLE LichKham (
    MaLK        INT AUTO_INCREMENT PRIMARY KEY,
    MaBN        INT NOT NULL,
    MaBS        INT NOT NULL,
    NgayGio     DATETIME NOT NULL,

    TrangThai   ENUM(
        'đã đặt',
        'đã khám',
        'đã hủy'
    ) NOT NULL DEFAULT 'đã đặt',

    CONSTRAINT fk_lichkham_benhnhan
        FOREIGN KEY (MaBN)
        REFERENCES BenhNhan(MaBN),

    CONSTRAINT fk_lichkham_bacsi
        FOREIGN KEY (MaBS)
        REFERENCES BacSi(MaBS)
);


/* =========================================================
   8. TẠO BẢNG THUOC
   ========================================================= */

CREATE TABLE Thuoc (
    MaThuoc         INT AUTO_INCREMENT PRIMARY KEY,
    Ten             VARCHAR(100) NOT NULL,
    DonVi           VARCHAR(20) NOT NULL,
    GiaBan          DECIMAL(10,2) NOT NULL,
    TonKho          INT NOT NULL DEFAULT 0,
    DinhMucCanhBao  INT NOT NULL DEFAULT 0,

    CONSTRAINT chk_giaban
        CHECK (GiaBan > 0),

    CONSTRAINT chk_tonkho
        CHECK (TonKho >= 0),

    CONSTRAINT chk_dinhmuc
        CHECK (DinhMucCanhBao >= 0)
);


/* =========================================================
   9. TẠO BẢNG DONTHUOC
   ========================================================= */

CREATE TABLE DonThuoc (
    MaDT        INT AUTO_INCREMENT PRIMARY KEY,
    MaLK        INT NOT NULL,
    NgayLap     DATE NOT NULL,

    CONSTRAINT fk_donthuoc_lichkham
        FOREIGN KEY (MaLK)
        REFERENCES LichKham(MaLK)
);


/* =========================================================
   10. TẠO BẢNG CHITIETDONTHUOC
   ========================================================= */

CREATE TABLE ChiTietDonThuoc (
    MaDT        INT NOT NULL,
    MaThuoc     INT NOT NULL,
    SoLuong     INT NOT NULL,
    LieuDung    VARCHAR(200),

    PRIMARY KEY (MaDT, MaThuoc),

    CONSTRAINT fk_ctdt_donthuoc
        FOREIGN KEY (MaDT)
        REFERENCES DonThuoc(MaDT),

    CONSTRAINT fk_ctdt_thuoc
        FOREIGN KEY (MaThuoc)
        REFERENCES Thuoc(MaThuoc),

    CONSTRAINT chk_soluong
        CHECK (SoLuong > 0)
);


/* =========================================================
   11. TẠO BẢNG HOADON
   Mỗi lịch khám chỉ có tối đa 1 hóa đơn
   ========================================================= */

CREATE TABLE HoaDon (
    MaHD                INT AUTO_INCREMENT PRIMARY KEY,
    MaLK                INT NOT NULL UNIQUE,

    PhiKham             DECIMAL(10,2) NOT NULL DEFAULT 0,
    TienThuoc           DECIMAL(10,2) NOT NULL DEFAULT 0,
    TongTien            DECIMAL(10,2) NOT NULL DEFAULT 0,

    TrangThaiThanhToan  ENUM(
        'chưa thanh toán',
        'đã thanh toán'
    ) NOT NULL DEFAULT 'chưa thanh toán',

    CONSTRAINT fk_hoadon_lichkham
        FOREIGN KEY (MaLK)
        REFERENCES LichKham(MaLK),

    CONSTRAINT chk_phikham
        CHECK (PhiKham >= 0),

    CONSTRAINT chk_tienthuoc
        CHECK (TienThuoc >= 0),

    CONSTRAINT chk_tongtien
        CHECK (TongTien >= 0)
);


/* =========================================================
   12. BẢNG CẢNH BÁO TỒN KHO
   Dùng để lưu lịch sử thuốc xuống dưới định mức
   ========================================================= */

CREATE TABLE CanhBaoTonKho (
    MaCanhBao      INT AUTO_INCREMENT PRIMARY KEY,
    MaThuoc        INT NOT NULL,
    TonKho         INT NOT NULL,
    DinhMucCanhBao INT NOT NULL,
    ThoiGian       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (MaThuoc)
        REFERENCES Thuoc(MaThuoc)
);


/* =========================================================
   13. TRIGGER
   Không cho bác sĩ có 2 lịch khám cùng thời điểm
   ========================================================= */

DELIMITER $$

CREATE TRIGGER trg_LichKham_CheckTrung
BEFORE INSERT ON LichKham
FOR EACH ROW
BEGIN

    IF EXISTS (
        SELECT 1
        FROM LichKham
        WHERE MaBS = NEW.MaBS
          AND NgayGio = NEW.NgayGio
          AND TrangThai <> 'đã hủy'
    ) THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
        'Loi: Bac si da co lich kham vao thoi diem nay';

    END IF;

END$$

DELIMITER ;


/* =========================================================
   14. TRIGGER
   Kiểm tra khi UPDATE lịch khám
   Không cho đổi sang thời gian bị trùng
   ========================================================= */

DELIMITER $$

CREATE TRIGGER trg_LichKham_CheckTrung_Update
BEFORE UPDATE ON LichKham
FOR EACH ROW
BEGIN

    IF EXISTS (
        SELECT 1
        FROM LichKham
        WHERE MaBS = NEW.MaBS
          AND NgayGio = NEW.NgayGio
          AND MaLK <> OLD.MaLK
          AND TrangThai <> 'đã hủy'
    ) THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
        'Loi: Bac si da co lich kham vao thoi diem nay';

    END IF;

END$$

DELIMITER ;


/* =========================================================
   15. TRIGGER
   Kiểm tra thuốc có đủ tồn kho hay không
   ========================================================= */

DELIMITER $$

CREATE TRIGGER trg_ChiTietDonThuoc_CheckTonKho
BEFORE INSERT ON ChiTietDonThuoc
FOR EACH ROW
BEGIN

    DECLARE v_TonKho INT;

    SELECT TonKho
    INTO v_TonKho
    FROM Thuoc
    WHERE MaThuoc = NEW.MaThuoc;

    IF v_TonKho IS NULL THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
        'Loi: Thuoc khong ton tai';

    ELSEIF v_TonKho < NEW.SoLuong THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
        'Loi: So luong thuoc ke vuot qua ton kho';

    END IF;

END$$

DELIMITER ;


/* =========================================================
   16. TRIGGER
   Sau khi thêm thuốc -> trừ tồn kho
   ========================================================= */

DELIMITER $$

CREATE TRIGGER trg_ChiTietDonThuoc_GiamKho
AFTER INSERT ON ChiTietDonThuoc
FOR EACH ROW
BEGIN

    UPDATE Thuoc
    SET TonKho = TonKho - NEW.SoLuong
    WHERE MaThuoc = NEW.MaThuoc;

END$$

DELIMITER ;


/* =========================================================
   17. TRIGGER
   Kiểm tra khi UPDATE số lượng thuốc
   ========================================================= */

DELIMITER $$

CREATE TRIGGER trg_ChiTietDonThuoc_CheckUpdate
BEFORE UPDATE ON ChiTietDonThuoc
FOR EACH ROW
BEGIN

    DECLARE v_TonKho INT;

    SELECT TonKho
    INTO v_TonKho
    FROM Thuoc
    WHERE MaThuoc = NEW.MaThuoc;


    /* Cùng một loại thuốc */

    IF OLD.MaThuoc = NEW.MaThuoc THEN

        IF v_TonKho + OLD.SoLuong < NEW.SoLuong THEN

            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Loi: So luong thuoc moi vuot qua ton kho';

        END IF;


    /* Đổi sang loại thuốc khác */

    ELSE

        IF v_TonKho < NEW.SoLuong THEN

            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Loi: Thuoc moi khong du ton kho';

        END IF;

    END IF;

END$$

DELIMITER ;


/* =========================================================
   18. TRIGGER
   Sau UPDATE -> điều chỉnh tồn kho
   ========================================================= */

DELIMITER $$

CREATE TRIGGER trg_ChiTietDonThuoc_UpdateKho
AFTER UPDATE ON ChiTietDonThuoc
FOR EACH ROW
BEGIN

    /* Cùng loại thuốc */

    IF OLD.MaThuoc = NEW.MaThuoc THEN

        UPDATE Thuoc
        SET TonKho = TonKho + OLD.SoLuong - NEW.SoLuong
        WHERE MaThuoc = NEW.MaThuoc;


    /* Đổi sang thuốc khác */

    ELSE

        UPDATE Thuoc
        SET TonKho = TonKho + OLD.SoLuong
        WHERE MaThuoc = OLD.MaThuoc;

        UPDATE Thuoc
        SET TonKho = TonKho - NEW.SoLuong
        WHERE MaThuoc = NEW.MaThuoc;

    END IF;

END$$

DELIMITER ;


/* =========================================================
   19. TRIGGER
   Xóa chi tiết đơn thuốc -> hoàn lại tồn kho
   ========================================================= */

DELIMITER $$

CREATE TRIGGER trg_ChiTietDonThuoc_HoanKho
AFTER DELETE ON ChiTietDonThuoc
FOR EACH ROW
BEGIN

    UPDATE Thuoc
    SET TonKho = TonKho + OLD.SoLuong
    WHERE MaThuoc = OLD.MaThuoc;

END$$

DELIMITER ;


/* =========================================================
   20. TRIGGER
   Cảnh báo khi tồn kho <= định mức cảnh báo
   ========================================================= */

DELIMITER $$

CREATE TRIGGER trg_Thuoc_CanhBaoTonKho
AFTER UPDATE ON Thuoc
FOR EACH ROW
BEGIN

    IF NEW.TonKho <= NEW.DinhMucCanhBao
       AND OLD.TonKho > OLD.DinhMucCanhBao THEN

        INSERT INTO CanhBaoTonKho
        (
            MaThuoc,
            TonKho,
            DinhMucCanhBao
        )
        VALUES
        (
            NEW.MaThuoc,
            NEW.TonKho,
            NEW.DinhMucCanhBao
        );

    END IF;

END$$

DELIMITER ;


/* =========================================================
   21. PROCEDURE
   Tính tiền thuốc và tổng tiền hóa đơn
   ========================================================= */

DELIMITER $$

CREATE PROCEDURE sp_TinhTienHoaDon(
    IN p_MaLK INT
)
BEGIN

    DECLARE v_PhiKham DECIMAL(10,2) DEFAULT 0;
    DECLARE v_TienThuoc DECIMAL(10,2) DEFAULT 0;


    /* Lấy phí khám */

    SELECT COALESCE(PhiKham, 0)
    INTO v_PhiKham
    FROM HoaDon
    WHERE MaLK = p_MaLK;


    /* Tính tiền thuốc */

    SELECT COALESCE(
        SUM(ct.SoLuong * t.GiaBan),
        0
    )
    INTO v_TienThuoc
    FROM DonThuoc dt

    JOIN ChiTietDonThuoc ct
        ON dt.MaDT = ct.MaDT

    JOIN Thuoc t
        ON ct.MaThuoc = t.MaThuoc

    WHERE dt.MaLK = p_MaLK;


    /* Cập nhật hóa đơn */

    UPDATE HoaDon
    SET TienThuoc = v_TienThuoc,
        TongTien = v_PhiKham + v_TienThuoc

    WHERE MaLK = p_MaLK;

END$$

DELIMITER ;


/* =========================================================
   22. PROCEDURE
   Thống kê doanh thu
   ========================================================= */

DELIMITER $$

CREATE PROCEDURE sp_ThongKeDoanhThu(
    IN p_TuNgay DATE,
    IN p_DenNgay DATE
)
BEGIN

    SELECT
        DATE(lk.NgayGio) AS Ngay,
        COUNT(hd.MaHD) AS SoHoaDon,
        SUM(hd.TongTien) AS DoanhThu

    FROM HoaDon hd

    JOIN LichKham lk
        ON hd.MaLK = lk.MaLK

    WHERE DATE(lk.NgayGio)
          BETWEEN p_TuNgay AND p_DenNgay

      AND hd.TrangThaiThanhToan = 'đã thanh toán'

    GROUP BY DATE(lk.NgayGio)

    ORDER BY Ngay;

END$$

DELIMITER ;


/* =========================================================
   23. PROCEDURE
   Thêm chi tiết đơn thuốc bằng TRANSACTION
   ========================================================= */

DELIMITER $$

CREATE PROCEDURE sp_ThemChiTietDonThuoc(
    IN p_MaDT INT,
    IN p_MaThuoc INT,
    IN p_SoLuong INT,
    IN p_LieuDung VARCHAR(200)
)
BEGIN

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN

        ROLLBACK;

        RESIGNAL;

    END;


    START TRANSACTION;


    /* Kiểm tra số lượng */

    IF p_SoLuong <= 0 THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
        'Loi: So luong thuoc phai lon hon 0';

    END IF;


    /* Thêm chi tiết */

    INSERT INTO ChiTietDonThuoc
    (
        MaDT,
        MaThuoc,
        SoLuong,
        LieuDung
    )
    VALUES
    (
        p_MaDT,
        p_MaThuoc,
        p_SoLuong,
        p_LieuDung
    );


    COMMIT;

END$$

DELIMITER ;


/* =========================================================
   24. FUNCTION
   Tính tiền thuốc của một lịch khám
   ========================================================= */

DELIMITER $$

CREATE FUNCTION fn_TinhTienThuoc(
    p_MaLK INT
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN

    DECLARE v_TienThuoc DECIMAL(10,2) DEFAULT 0;


    SELECT COALESCE(
        SUM(ct.SoLuong * t.GiaBan),
        0
    )
    INTO v_TienThuoc

    FROM DonThuoc dt

    JOIN ChiTietDonThuoc ct
        ON dt.MaDT = ct.MaDT

    JOIN Thuoc t
        ON ct.MaThuoc = t.MaThuoc

    WHERE dt.MaLK = p_MaLK;


    RETURN v_TienThuoc;

END$$

DELIMITER ;


/* =========================================================
   25. FUNCTION
   Tính tổng tiền hóa đơn
   ========================================================= */

DELIMITER $$

CREATE FUNCTION fn_TinhTongTienHoaDon(
    p_MaLK INT
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN

    DECLARE v_PhiKham DECIMAL(10,2) DEFAULT 0;
    DECLARE v_TienThuoc DECIMAL(10,2) DEFAULT 0;


    SELECT COALESCE(PhiKham, 0)
    INTO v_PhiKham

    FROM HoaDon

    WHERE MaLK = p_MaLK;


    SET v_TienThuoc =
        fn_TinhTienThuoc(p_MaLK);


    RETURN v_PhiKham + v_TienThuoc;

END$$

DELIMITER ;


/* =========================================================
   26. FUNCTION
   Đếm số loại thuốc trong đơn
   ========================================================= */

DELIMITER $$

CREATE FUNCTION fn_DemThuocTrongDon(
    p_MaDT INT
)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN

    DECLARE v_SoLoaiThuoc INT DEFAULT 0;


    SELECT COUNT(*)
    INTO v_SoLoaiThuoc

    FROM ChiTietDonThuoc

    WHERE MaDT = p_MaDT;


    RETURN v_SoLoaiThuoc;

END$$

DELIMITER ;


/* =========================================================
   27. FUNCTION
   Kiểm tra tồn kho thuốc
   ========================================================= */

DELIMITER $$

CREATE FUNCTION fn_TonKhoThuoc(
    p_MaThuoc INT
)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN

    DECLARE v_TonKho INT DEFAULT 0;


    SELECT TonKho
    INTO v_TonKho

    FROM Thuoc

    WHERE MaThuoc = p_MaThuoc;


    RETURN COALESCE(v_TonKho, 0);

END$$

DELIMITER ;


/* =========================================================
   28. DỮ LIỆU MẪU - BỆNH NHÂN
   ========================================================= */

INSERT INTO BenhNhan
(
    HoTen,
    NgaySinh,
    GioiTinh,
    SDT,
    DiaChi
)
VALUES
(
    'Nguyen Van An',
    '2000-05-10',
    'Nam',
    '0901000001',
    'Tan An'
),
(
    'Tran Thi Binh',
    '1999-08-20',
    'Nữ',
    '0901000002',
    'Ben Luc'
),
(
    'Le Van Cuong',
    '2002-01-15',
    'Nam',
    '0901000003',
    'Tan Tru'
),
(
    'Pham Thi Dung',
    '2001-03-25',
    'Nữ',
    '0901000004',
    'Tan An'
);


/* =========================================================
   29. DỮ LIỆU MẪU - BÁC SĨ
   ========================================================= */

INSERT INTO BacSi
(
    HoTen,
    ChuyenKhoa,
    SDT
)
VALUES
(
    'Nguyen Van Minh',
    'Noi khoa',
    '0911000001'
),
(
    'Tran Thi Lan',
    'Nhi khoa',
    '0911000002'
),
(
    'Le Hoang Nam',
    'Da lieu',
    '0911000003'
);


/* =========================================================
   30. DỮ LIỆU MẪU - THUỐC
   ========================================================= */

INSERT INTO Thuoc
(
    Ten,
    DonVi,
    GiaBan,
    TonKho,
    DinhMucCanhBao
)
VALUES
(
    'Paracetamol',
    'Vien',
    2000,
    100,
    20
),
(
    'Amoxicillin',
    'Vien',
    3000,
    50,
    10
),
(
    'Vitamin C',
    'Vien',
    1500,
    30,
    10
),
(
    'Thuoc ho',
    'Chai',
    25000,
    20,
    5
);


/* =========================================================
   31. DỮ LIỆU MẪU - LỊCH KHÁM
   ========================================================= */

INSERT INTO LichKham
(
    MaBN,
    MaBS,
    NgayGio,
    TrangThai
)
VALUES
(
    1,
    1,
    '2026-10-05 08:00:00',
    'đã khám'
),
(
    2,
    1,
    '2026-10-05 09:00:00',
    'đã khám'
),
(
    3,
    2,
    '2026-10-05 08:00:00',
    'đã khám'
),
(
    4,
    3,
    '2026-10-05 10:00:00',
    'đã đặt'
);


/* =========================================================
   32. DỮ LIỆU MẪU - ĐƠN THUỐC
   ========================================================= */

INSERT INTO DonThuoc
(
    MaLK,
    NgayLap
)
VALUES
(
    1,
    '2026-10-05'
),
(
    2,
    '2026-10-05'
);


/* =========================================================
   33. THÊM CHI TIẾT ĐƠN THUỐC HỢP LỆ
   Trigger sẽ tự động trừ tồn kho
   ========================================================= */

CALL sp_ThemChiTietDonThuoc(
    1,
    1,
    10,
    'Ngay uong 2 lan, moi lan 1 vien'
);

CALL sp_ThemChiTietDonThuoc(
    1,
    2,
    5,
    'Ngay uong 2 lan, moi lan 1 vien'
);

CALL sp_ThemChiTietDonThuoc(
    2,
    3,
    10,
    'Ngay uong 1 lan, moi lan 1 vien'
);


/* =========================================================
   34. TẠO HÓA ĐƠN
   ========================================================= */

INSERT INTO HoaDon
(
    MaLK,
    PhiKham
)
VALUES
(
    1,
    100000
),
(
    2,
    120000
);


/* =========================================================
   35. TÍNH TIỀN HÓA ĐƠN
   ========================================================= */

CALL sp_TinhTienHoaDon(1);

CALL sp_TinhTienHoaDon(2);


/* =========================================================
   36. THANH TOÁN HÓA ĐƠN
   ========================================================= */

UPDATE HoaDon

SET TrangThaiThanhToan = 'đã thanh toán'

WHERE MaHD = 1;


/* =========================================================
   37. KIỂM TRA DỮ LIỆU BAN ĐẦU
   ========================================================= */

SELECT * FROM BenhNhan;

SELECT * FROM BacSi;

SELECT * FROM LichKham;

SELECT * FROM Thuoc;

SELECT * FROM DonThuoc;

SELECT * FROM ChiTietDonThuoc;

SELECT * FROM HoaDon;


/* =========================================================
   38. KIỂM THỬ FUNCTION
   ========================================================= */

-- Tính tiền thuốc của lịch khám 1

SELECT
    fn_TinhTienThuoc(1)
    AS TienThuoc;


-- Tính tổng tiền hóa đơn của lịch khám 1

SELECT
    fn_TinhTongTienHoaDon(1)
    AS TongTien;


-- Đếm số loại thuốc trong đơn thuốc 1

SELECT
    fn_DemThuocTrongDon(1)
    AS SoLoaiThuoc;


-- Kiểm tra tồn kho Paracetamol

SELECT
    fn_TonKhoThuoc(1)
    AS TonKho;


/* =========================================================
   39. KIỂM THỬ PROCEDURE THỐNG KÊ DOANH THU
   ========================================================= */

CALL sp_ThongKeDoanhThu(
    '2026-10-01',
    '2026-10-31'
);


/* =========================================================
   40. KIỂM THỬ TRƯỜNG HỢP HỢP LỆ
   Đặt lịch không trùng giờ
   ========================================================= */

INSERT INTO LichKham
(
    MaBN,
    MaBS,
    NgayGio,
    TrangThai
)
VALUES
(
    4,
    1,
    '2026-10-05 10:00:00',
    'đã đặt'
);


/* =========================================================
   41. KIỂM THỬ
   Hai bác sĩ khác nhau cùng một thời điểm
   ========================================================= */

INSERT INTO LichKham
(
    MaBN,
    MaBS,
    NgayGio,
    TrangThai
)
VALUES
(
    1,
    2,
    '2026-10-05 08:00:00',
    'đã đặt'
);


/* =========================================================
   42. KIỂM THỬ
   Kê thuốc còn đủ tồn kho
   ========================================================= */

CALL sp_ThemChiTietDonThuoc(
    2,
    1,
    20,
    'Ngay uong 2 lan, moi lan 1 vien'
);


/* =========================================================
   43. KIỂM TRA TỒN KHO SAU KHI KÊ THUỐC
   ========================================================= */

SELECT
    MaThuoc,
    Ten,
    TonKho
FROM Thuoc
WHERE MaThuoc = 1;


/* =========================================================
   44. KIỂM THỬ UPDATE SỐ LƯỢNG THUỐC
   Tăng từ 20 lên 25
   ========================================================= */

UPDATE ChiTietDonThuoc

SET SoLuong = 25

WHERE MaDT = 2
  AND MaThuoc = 1;


/* =========================================================
   45. KIỂM TRA TỒN KHO SAU UPDATE
   ========================================================= */

SELECT
    MaThuoc,
    Ten,
    TonKho
FROM Thuoc
WHERE MaThuoc = 1;


/* =========================================================
   46. KIỂM THỬ DELETE
   Xóa thuốc khỏi đơn -> hoàn kho
   ========================================================= */

DELETE FROM ChiTietDonThuoc

WHERE MaDT = 2
  AND MaThuoc = 1;


/* =========================================================
   47. KIỂM TRA TỒN KHO SAU DELETE
   ========================================================= */

SELECT
    MaThuoc,
    Ten,
    TonKho
FROM Thuoc
WHERE MaThuoc = 1;


/* =========================================================
   48. KIỂM THỬ VI PHẠM
   Trùng lịch bác sĩ
   ========================================================= */

INSERT INTO LichKham
(
    MaBN,
    MaBS,
    NgayGio,
    TrangThai
)
VALUES
(
    2,
    1,
    '2026-10-05 08:00:00',
    'đã đặt'
);


/* =========================================================
   49. KIỂM THỬ VI PHẠM
   Kê thuốc vượt tồn kho
   ========================================================= */

CALL sp_ThemChiTietDonThuoc(
    1,
    1,
    1000,
    'Ngay uong 2 lan'
);


/* =========================================================
   50. KIỂM THỬ VI PHẠM
   Số lượng bằng 0
   ========================================================= */

CALL sp_ThemChiTietDonThuoc(
    1,
    1,
    0,
    'So luong khong hop le'
);


/* =========================================================
   51. KIỂM THỬ VI PHẠM
   Số lượng âm
   ========================================================= */

CALL sp_ThemChiTietDonThuoc(
    1,
    1,
    -5,
    'So luong khong hop le'
);


/* =========================================================
   52. KIỂM THỬ VI PHẠM
   UPDATE vượt tồn kho
   ========================================================= */

UPDATE ChiTietDonThuoc

SET SoLuong = 9999

WHERE MaDT = 1
  AND MaThuoc = 1;


/* =========================================================
   53. KIỂM THỬ CHECK
   Giá thuốc bằng 0
   ========================================================= */

INSERT INTO Thuoc
(
    Ten,
    DonVi,
    GiaBan,
    TonKho,
    DinhMucCanhBao
)
VALUES
(
    'Thuoc Test Gia Bang 0',
    'Vien',
    0,
    10,
    2
);


/* =========================================================
   54. KIỂM THỬ CHECK
   Giá thuốc âm
   ========================================================= */

INSERT INTO Thuoc
(
    Ten,
    DonVi,
    GiaBan,
    TonKho,
    DinhMucCanhBao
)
VALUES
(
    'Thuoc Test Gia Am',
    'Vien',
    -5000,
    10,
    2
);


/* =========================================================
   55. KIỂM THỬ CHECK
   Tồn kho âm
   ========================================================= */

INSERT INTO Thuoc
(
    Ten,
    DonVi,
    GiaBan,
    TonKho,
    DinhMucCanhBao
)
VALUES
(
    'Thuoc Test Ton Am',
    'Vien',
    5000,
    -10,
    2
);


/* =========================================================
   56. KIỂM THỬ UNIQUE
   Bệnh nhân trùng số điện thoại
   ========================================================= */

INSERT INTO BenhNhan
(
    HoTen,
    NgaySinh,
    GioiTinh,
    SDT,
    DiaChi
)
VALUES
(
    'Benh Nhan Test',
    '2001-01-01',
    'Nam',
    '0901000001',
    'Tan An'
);


/* =========================================================
   57. KIỂM THỬ UNIQUE
   Bác sĩ trùng số điện thoại
   ========================================================= */

INSERT INTO BacSi
(
    HoTen,
    ChuyenKhoa,
    SDT
)
VALUES
(
    'Bac Si Test',
    'Noi khoa',
    '0911000001'
);


/* =========================================================
   58. KIỂM THỬ FOREIGN KEY
   Mã bệnh nhân không tồn tại
   ========================================================= */

INSERT INTO LichKham
(
    MaBN,
    MaBS,
    NgayGio,
    TrangThai
)
VALUES
(
    9999,
    1,
    '2026-10-06 08:00:00',
    'đã đặt'
);


/* =========================================================
   59. KIỂM THỬ FOREIGN KEY
   Mã bác sĩ không tồn tại
   ========================================================= */

INSERT INTO LichKham
(
    MaBN,
    MaBS,
    NgayGio,
    TrangThai
)
VALUES
(
    1,
    9999,
    '2026-10-06 09:00:00',
    'đã đặt'
);


/* =========================================================
   60. KIỂM THỬ CẢNH BÁO TỒN KHO
   Giảm tồn kho xuống dưới định mức
   ========================================================= */

UPDATE Thuoc

SET TonKho = 20

WHERE MaThuoc = 2;


/* =========================================================
   61. KIỂM TRA CẢNH BÁO TỒN KHO
   ========================================================= */

SELECT *
FROM CanhBaoTonKho;


/* =========================================================
   62. KIỂM TRA CUỐI CÙNG
   ========================================================= */

SELECT * FROM BenhNhan;

SELECT * FROM BacSi;

SELECT * FROM LichKham;

SELECT * FROM Thuoc;

SELECT * FROM DonThuoc;

SELECT * FROM ChiTietDonThuoc;

SELECT * FROM HoaDon;

SELECT * FROM CanhBaoTonKho;


/* =========================================================
   KẾT THÚC
   ========================================================= */