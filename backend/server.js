
require("dotenv").config();
const benhNhanRoutes = require("./routes/benhnhan");
const express = require("express");
const cors = require("cors");
const db = require("./db");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use("/api/benhnhan", benhNhanRoutes);

// Kiem tra API
app.get("/api/health", (req, res) => {
    res.json({
        message: "Clinic Management API dang hoat dong"
    });
});

// Kiem tra ket noi MySQL
app.get("/api/db-test", async (req, res) => {
    try {
        const [rows] = await db.query("SELECT 1 AS ket_noi");

        res.json({
            message: "Ket noi MySQL thanh cong",
            data: rows
        });
    } catch (error) {
        console.error("Loi ket noi MySQL:", error.message);

        res.status(500).json({
            message: "Ket noi MySQL that bai",
            error: error.message
        });
    }
});

app.listen(PORT, () => {
    console.log(`Server dang chay tai http://localhost:${PORT}`);
});

app.get("/api/benhnhan", async (req, res) => {
    try {
        const [rows] = await db.query(
            "SELECT id, hoten, ngaysinh, gioitinh, sdt, diachi FROM BenhNhan ORDER BY id"
        );

        res.json({
            message: "Lay danh sach benh nhan thanh cong",
            data: rows
        });
    } catch (error) {
        console.error("Loi lay benh nhan:", error.message);

        res.status(500).json({
            message: "Khong the lay danh sach benh nhan"
        });
    }
});
