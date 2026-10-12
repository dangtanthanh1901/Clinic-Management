
const express = require("express");
const router = express.Router();
const db = require("../db");

// Kiem tra ID hop le
function idHopLe(id) {
    return /^\d+$/.test(id) && Number(id) > 0;
}

// 1. GET: Xem chi tiet mot benh nhan
router.get("/:id", async (req, res) => {
    const id = req.params.id;

    if (!idHopLe(id)) {
        return res.status(400).json({
            message: "ID benh nhan khong hop le"
        });
    }

    try {
        const [rows] = await db.query(
            "SELECT id, hoten, ngaysinh, gioitinh, sdt, diachi FROM BenhNhan WHERE id = ?",
            [id]
        );

        if (rows.length === 0) {
            return res.status(404).json({
                message: "Khong tim thay benh nhan"
            });
        }

        res.json(rows[0]);
    } catch (error) {
        console.error(error.message);
        res.status(500).json({
            message: "Loi khi lay thong tin benh nhan"
        });
    }
});

// 2. POST: Them benh nhan
router.post("/", async (req, res) => {
    const { hoten, ngaysinh, gioitinh, sdt, diachi } = req.body;

    if (
        typeof hoten !== "string" || !hoten.trim() ||
        typeof gioitinh !== "string" ||
        typeof sdt !== "string" || !sdt.trim()
    ) {
        return res.status(400).json({
            message: "Ho ten, gioi tinh va so dien thoai la bat buoc"
        });
    }

    if (!["Nam", "Nữ", "Khác"].includes(gioitinh)) {
        return res.status(400).json({
            message: "Gioi tinh phai la Nam, Nữ hoac Khác"
        });
    }

    try {
        const [result] = await db.query(
            `INSERT INTO BenhNhan
                (hoten, ngaysinh, gioitinh, sdt, diachi)
             VALUES (?, ?, ?, ?, ?)`,
            [
                hoten.trim(),
                ngaysinh || null,
                gioitinh,
                sdt.trim(),
                diachi || null
            ]
        );

        res.status(201).json({
            message: "Them benh nhan thanh cong",
            id: result.insertId
        });
    } catch (error) {
        if (error.code === "ER_DUP_ENTRY") {
            return res.status(409).json({
                message: "So dien thoai da ton tai"
            });
        }

        if (error.code === "ER_NO_REFERENCED_ROW_2") {
            return res.status(400).json({
                message: "Du lieu tham chieu khong hop le"
            });
        }

        console.error(error.message);
        res.status(500).json({
            message: "Loi khi them benh nhan"
        });
    }
});

// 3. PUT: Cap nhat thong tin benh nhan
router.put("/:id", async (req, res) => {
    const id = req.params.id;
    const { hoten, ngaysinh, gioitinh, sdt, diachi } = req.body;

    if (!idHopLe(id)) {
        return res.status(400).json({
            message: "ID benh nhan khong hop le"
        });
    }

    if (
        typeof hoten !== "string" || !hoten.trim() ||
        typeof gioitinh !== "string" ||
        typeof sdt !== "string" || !sdt.trim()
    ) {
        return res.status(400).json({
            message: "Ho ten, gioi tinh va so dien thoai la bat buoc"
        });
    }

    if (!["Nam", "Nữ", "Khác"].includes(gioitinh)) {
        return res.status(400).json({
            message: "Gioi tinh phai la Nam, Nữ hoac Khác"
        });
    }

    try {
        const [result] = await db.query(
            `UPDATE BenhNhan
             SET hoten = ?, ngaysinh = ?, gioitinh = ?,
                 sdt = ?, diachi = ?
             WHERE id = ?`,
            [
                hoten.trim(),
                ngaysinh || null,
                gioitinh,
                sdt.trim(),
                diachi || null,
                id
            ]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({
                message: "Khong tim thay benh nhan"
            });
        }

        res.json({
            message: "Cap nhat benh nhan thanh cong"
        });
    } catch (error) {
        if (error.code === "ER_DUP_ENTRY") {
            return res.status(409).json({
                message: "So dien thoai da duoc benh nhan khac su dung"
            });
        }

        console.error(error.message);
        res.status(500).json({
            message: "Loi khi cap nhat benh nhan"
        });
    }
});

// 4. DELETE: Xoa benh nhan
router.delete("/:id", async (req, res) => {
    const id = req.params.id;

    if (!idHopLe(id)) {
        return res.status(400).json({
            message: "ID benh nhan khong hop le"
        });
    }

    try {
        const [result] = await db.query(
            "DELETE FROM BenhNhan WHERE id = ?",
            [id]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({
                message: "Khong tim thay benh nhan"
            });
        }

        res.json({
            message: "Xoa benh nhan thanh cong"
        });
    } catch (error) {
        if (error.code === "ER_ROW_IS_REFERENCED_2") {
            return res.status(409).json({
                message: "Khong the xoa benh nhan vi du lieu dang duoc bang khac su dung"
            });
        }

        console.error(error.message);
        res.status(500).json({
            message: "Loi khi xoa benh nhan"
        });
    }
});

module.exports = router;
