const { Given, When, Then } = require('@cucumber/cucumber');
const mysql = require('mysql2/promise');
const { execSync } = require('child_process');

let conn;

Given('une base MySQL disponible', async function () {
  conn = await mysql.createConnection({
    host: process.env.MYSQL_HOST,
    user: "root",
    password: process.env.MYSQL_ROOT_PASSWORD,
    database: "mysql"
  });
});

When('je crée une table {string} et insère une ligne', async function (table) {
  await conn.query(`CREATE TABLE IF NOT EXISTS ${table} (id INT PRIMARY KEY, val VARCHAR(50))`);
  await conn.query(`INSERT INTO ${table} VALUES (1,'persistant') ON DUPLICATE KEY UPDATE val='persistant'`);
});

When('je supprime le pod MySQL', function () {
  execSync("kubectl -n ns-open4goods-recette delete pod -l app=mysql-xwiki");
});

Then('la ligne est toujours présente après redémarrage', async function () {
  await new Promise(r => setTimeout(r, 30000));
  const [rows] = await conn.query("SELECT val FROM bdd_test WHERE id=1");
  if (rows[0].val !== "persistant") {
    throw new Error(`Expected 'persistant' but got ${rows[0].val}`);
  }
  await conn.end();
});
