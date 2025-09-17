package main

import (
	"database/sql"
	"fmt"
	"os"

	_ "github.com/go-sql-driver/mysql"
)

func main() {
	pass := os.Getenv("MYSQL_PASS")
	host := os.Getenv("MYSQL_HOST")

	dsn := fmt.Sprintf("root:%s@tcp(%s:3306)/mysql", pass, host)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		panic(err)
	}
	defer db.Close()

	var result int
	if err := db.QueryRow("SELECT 1").Scan(&result); err != nil {
		panic(err)
	}
	if result == 1 {
		fmt.Println("✅ MySQL OK")
	} else {
		fmt.Println("❌ MySQL KO")
	}
}
