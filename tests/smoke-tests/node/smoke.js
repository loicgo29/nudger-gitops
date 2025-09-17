const mysql = require("mysql2/promise");

(async () => {
  try {
    const conn = await mysql.createConnection({
      host: process.env.MYSQL_HOST || "localhost",
      user: "root",
      password: process.env.MYSQL_PASS || "changeme",
      database: "mysql"
    });

    const [rows] = await conn.query("SELECT 1");
    if (rows[0]["1"] === 1) {
      console.log("✅ MySQL OK");
    } else {
      console.error("❌ MySQL KO");
    }

    await conn.end();
  } catch (err) {
    console.error("❌ Connexion MySQL échouée:", err.message);
    process.exit(1);
  }
})();
