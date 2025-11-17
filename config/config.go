package config

import "os"

// Config はアプリケーション設定
type Config struct {
	Environment string
	BatchName   string
}

func NewConfig() *Config {
	return &Config{
		Environment: getEnv("ENVIRONMENT", "development"),
		BatchName:   getEnv("BATCH_NAME", "sample-batch"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
