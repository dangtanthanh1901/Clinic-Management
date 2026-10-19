
require("dotenv").config();

const express = require("express");
const cors = require("cors");
const db = require("./db");
const benhNhanRoutes = require("./routes/benhnhan");

const app = express();
const PORT = process.env.PORT || 3000;

// Cau hinh middleware
app.use(cors());
app.use(express.json());

// API quan ly benh nhan
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
            message: "Ket noi MySQL that bai"
        });
    }
});

// Khoi dong server
app.listen(PORT, () => {
    console.log(`Server dang chay tai http://localhost:${PORT}`);
});
