CREATE DATABASE clinic_management CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE clinic_management;

CREATE TABLE BenhNhan (
    id       INT AUTO_INCREMENT PRIMARY KEY,
    hoten    VARCHAR(100) NOT NULL,
    ngaysinh DATE NOT NULL,
    gioitinh ENUM('Nam', 'Nữ', 'Khác') NOT NULL,
    sdt      VARCHAR(15),
    diachi   VARCHAR(255)
) ENGINE = InnoDB;

CREATE TABLE HoSoSucKhoe (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    benhnhan_id INT NOT NULL UNIQUE,
    ngaylap     DATE NOT NULL DEFAULT (CURRENT_DATE),
    FOREIGN KEY (benhnhan_id) REFERENCES BenhNhan (id)
) ENGINE = InnoDB;

CREATE TABLE BacSi (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    hoten      VARCHAR(100) NOT NULL,
    chuyenkhoa VARCHAR(100) NOT NULL,
    sdt        VARCHAR(15)
) ENGINE = InnoDB;

CREATE TABLE LichKham (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    bacsi_id  INT NOT NULL,
    ngaygio   DATETIME NOT NULL,
    trangthai ENUM('đã đặt', 'đã khám', 'đã hủy') NOT NULL DEFAULT 'đã đặt',
    FOREIGN KEY (bacsi_id) REFERENCES BacSi (id),
    UNIQUE (bacsi_id, ngaygio)
) ENGINE = InnoDB;

CREATE TABLE BenhAn (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    hososuckhoe_id INT NOT NULL,
    lichkham_id    INT UNIQUE,
    benhan_goc_id  INT,
    ngaykham       DATE NOT NULL,
    chuandoan      VARCHAR(255),
    ghichu         VARCHAR(500),
    FOREIGN KEY (hososuckhoe_id) REFERENCES HoSoSucKhoe (id),
    FOREIGN KEY (lichkham_id) REFERENCES LichKham (id),
    FOREIGN KEY (benhan_goc_id) REFERENCES BenhAn (id)
) ENGINE = InnoDB;

CREATE TABLE Thuoc (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    ten            VARCHAR(150) NOT NULL,
    donvi          VARCHAR(30) NOT NULL,
    giaban         DECIMAL(12,2) NOT NULL CHECK (giaban > 0),
    tonkho         INT NOT NULL DEFAULT 0 CHECK (tonkho >= 0),
    dinhmuccanhbao INT NOT NULL DEFAULT 0 CHECK (dinhmuccanhbao >= 0)
) ENGINE = InnoDB;

CREATE TABLE DonThuoc (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    benhan_id INT NOT NULL,
    ngaylap   DATE NOT NULL DEFAULT (CURRENT_DATE),
    FOREIGN KEY (benhan_id) REFERENCES BenhAn (id)
) ENGINE = InnoDB;

CREATE TABLE ChiTietDonThuoc (
    donthuoc_id INT NOT NULL,
    thuoc_id    INT NOT NULL,
    soluong     INT NOT NULL CHECK (soluong > 0),
    lieudung    VARCHAR(255),
    PRIMARY KEY (donthuoc_id, thuoc_id),
    FOREIGN KEY (donthuoc_id) REFERENCES DonThuoc (id),
    FOREIGN KEY (thuoc_id) REFERENCES Thuoc (id)
) ENGINE = InnoDB;

CREATE TABLE HoaDon (
    id                 INT AUTO_INCREMENT PRIMARY KEY,
    lichkham_id        INT NOT NULL UNIQUE,
    phikham            DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (phikham >= 0),
    tienthuoc          DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (tienthuoc >= 0),
    tongtien           DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (tongtien >= 0),
    trangthaithanhtoan ENUM('chưa thanh toán', 'đã thanh toán') NOT NULL DEFAULT 'chưa thanh toán',
    FOREIGN KEY (lichkham_id) REFERENCES LichKham (id)
) ENGINE = InnoDB;

CREATE TABLE CanhBaoTonKho (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    thuoc_id       INT NOT NULL,
    tonkho         INT NOT NULL,
    dinhmuccanhbao INT NOT NULL,
    thoigian       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ghichu         VARCHAR(255) DEFAULT 'Cần nhập thêm thuốc',
    FOREIGN KEY (thuoc_id) REFERENCES Thuoc (id)
) ENGINE = InnoDB;