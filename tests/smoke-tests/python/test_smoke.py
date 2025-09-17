import mysql.connector
import os

def test_mysql_connection():
    conn = mysql.connector.connect(
        host=os.getenv("MYSQL_HOST", "localhost"),
        user="root",
        password=os.getenv("MYSQL_PASS", "changeme"),
        database="mysql"
    )
    cursor = conn.cursor()
    cursor.execute("SELECT 1")
    assert cursor.fetchone()[0] == 1
    conn.close()
