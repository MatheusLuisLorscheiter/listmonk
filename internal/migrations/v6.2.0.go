package migrations

import (
	"log"

	"github.com/jmoiron/sqlx"
	"github.com/knadh/koanf/v2"
	"github.com/knadh/stuffbin"
)

func V6_2_0(db *sqlx.DB, fs stuffbin.FileSystem, ko *koanf.Koanf, lo *log.Logger) error {
    _, err := db.Exec(`
        ALTER TABLE lists
        ADD COLUMN IF NOT EXISTS default_messenger TEXT NULL
    `)
    return err
}
