package main

import (
	"database/sql"
	"fmt"
	"os"
	"os/exec"
	"testing"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/cucumber/godog"
)

var db *sql.DB

func aMySQLDatabaseIsAvailable() error {
	var err error
	dsn := fmt.Sprintf("root:%s@tcp(%s:3306)/mysql", os.Getenv("MYSQL_ROOT_PASSWORD"), os.Getenv("MYSQL_HOST"))
	db, err = sql.Open("mysql", dsn)
	if err != nil {
		return err
	}
	return db.Ping()
}

func iCreateATableAndInsertARow() error {
	_, err := db.Exec("CREATE TABLE IF NOT EXISTS bdd_test (id INT PRIMARY KEY, val VARCHAR(50));")
	if err != nil {
		return err
	}
	_, err = db.Exec("INSERT INTO bdd_test VALUES (1,'persistant') ON DUPLICATE KEY UPDATE val='persistant';")
	return err
}

func iDeleteTheMySQLPod() error {
	cmd := exec.Command("kubectl", "-n", "ns-open4goods-recette", "delete", "pod", "-l", "app=mysql-xwiki")
	return cmd.Run()
}

func theRowShouldStillExist() error {
	time.Sleep(30 * time.Second)
	var val string
	err := db.QueryRow("SELECT val FROM bdd_test WHERE id=1").Scan(&val)
	if err != nil {
		return err
	}
	if val != "persistant" {
		return fmt.Errorf("expected 'persistant', got %s", val)
	}
	return nil
}

func InitializeScenario(ctx *godog.ScenarioContext) {
	ctx.Step(`^une base MySQL disponible$`, aMySQLDatabaseIsAvailable)
	ctx.Step(`^je crée une table "bdd_test" et insère une ligne$`, iCreateATableAndInsertARow)
	ctx.Step(`^je supprime le pod MySQL$`, iDeleteTheMySQLPod)
	ctx.Step(`^la ligne est toujours présente après redémarrage$`, theRowShouldStillExist)
}

func TestFeatures(t *testing.T) {
	opts := godog.Options{
		Format: "pretty",
		Paths:  []string{"../features"},
	}
	if st := godog.TestSuite{Name: "bdd", ScenarioInitializer: InitializeScenario, Options: &opts}.Run(); st != 0 {
		t.Fail()
	}
}
