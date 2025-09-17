import mysql.connector
import time
import pytest

MYSQL_HOST = "mysql-xwiki-clusterip.ns-open4goods-recette.svc.cluster.local"
MYSQL_ROOT_PASSWORD = "changeme"

@pytest.fixture(scope="session")
def mysql_conn():
    conn = mysql.connector.connect(
        host=MYSQL_HOST,
        user="root",
        password=MYSQL_ROOT_PASSWORD
    )
    yield conn
    conn.close()

def test_insert_and_select(mysql_conn):
    cursor = mysql_conn.cursor()
    cursor.execute("CREATE DATABASE IF NOT EXISTS testdb;")
    cursor.execute("USE testdb;")
    cursor.execute("CREATE TABLE IF NOT EXISTS persistence (id INT PRIMARY KEY, name VARCHAR(50));")
    cursor.execute("INSERT INTO persistence (id, name) VALUES (1, 'hello') ON DUPLICATE KEY UPDATE name='hello';")
    mysql_conn.commit()

    cursor.execute("SELECT name FROM persistence WHERE id=1;")
    result = cursor.fetchone()
    assert result[0] == "hello"
