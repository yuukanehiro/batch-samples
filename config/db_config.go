package config

import "fmt"

// DBConfig はDB接続設定
type DBConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	MaxConns int
}

// NewDBConfig はDB設定を作成する
func NewDBConfig() *DBConfig {
	return &DBConfig{
		Host:     getEnv("DB_HOST", "localhost"),
		Port:     getEnv("DB_PORT", "3306"),
		User:     getEnv("DB_USER", "root"),
		Password: getEnv("DB_PASSWORD", "password"),
		MaxConns: 10,
	}
}

// GetDSN はテナントのDB名を使ってDSNを生成する
func (c *DBConfig) GetDSN(dbName string) string {
	return fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&charset=utf8mb4",
		c.User,
		c.Password,
		c.Host,
		c.Port,
		dbName,
	)
}
