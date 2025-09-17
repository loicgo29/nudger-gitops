import os
import mysql.connector
import pytest

MYSQL_HOST = os.getenv("MYSQL_HOST", "mysql-xwiki-clusterip.ns-open4goods-recette.svc.cluster.local")
MYSQL_ROOT_PASSWORD = os.getenv("MYSQL_ROOT_PASSWORD", "changeme")

def test_mysql_connection_and_persistence():
    conn = mysql.connector.connect(
        host=MYSQL_HOST, user="root", password=MYSQL_ROOT_PASSWORD
    )
    cur = conn.cursor()
    cur.execute("CREATE DATABASE IF NOT EXISTS smoketest")
    cur.execute("USE smoketest")
    cur.execute("CREATE TABLE IF NOT EXISTS t (id INT)")
    cur.execute("INSERT INTO t VALUES (1)")
    conn.commit()

    cur.execute("SELECT COUNT(*) FROM t")
    assert cur.fetchone()[0] >= 1
    conn.close()
