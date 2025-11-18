package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"batch-samples/app/frameworks/dbsets"
	"batch-samples/app/frameworks/logger"
	"batch-samples/app/frameworks/tracer"
	"batch-samples/app/interface-adapters/cronjob/handlers"
	"batch-samples/config"
)

func main() {
	// Logger の初期化
	log := logger.NewLogger()
	log.Info("Starting Sample Batch Job Service (Multi-Tenant)")

	// Config の初期化
	conf := config.NewConfig()
	dbConf := config.NewDBConfig()
	log.Info(fmt.Sprintf("Environment: %s, Batch Name: %s", conf.Environment, conf.BatchName))
	log.Info(fmt.Sprintf("DB Config: Host=%s, Port=%s, User=%s", dbConf.Host, dbConf.Port, dbConf.User))

	// Context の作成
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// シグナルハンドリング（グレースフルシャットダウン）
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	// 全テナントのDBセットを初期化
	log.Info("Initializing database connections for all tenants...")
	dbSets, err := dbsets.NewAppDBsByTenant(dbConf)
	if err != nil {
		log.Error(fmt.Errorf("failed to initialize database connections: %w", err))
		os.Exit(1)
	}
	defer dbSets.Close()
	log.Info(fmt.Sprintf("Database connections initialized for %d tenants", dbSets.Count()))

	// Tracer の初期化
	tr := tracer.NewTracer()

	// Handler の初期化
	handler := &handlers.SampleJobHandler{
		Tracer: tr,
		Logger: log,
		DBSets: dbSets,
	}

	// シグナル受信時のグレースフルシャットダウン
	go func() {
		sig := <-sigCh
		log.Info(fmt.Sprintf("Received signal: %v. Shutting down gracefully...", sig))
		cancel() // コンテキストをキャンセル
	}()

	// ジョブの実行
	if err := handler.Start(ctx); err != nil {
		if err != context.Canceled {
			log.Error(fmt.Errorf("job execution error: %w", err))
			os.Exit(1)
		}
	}

	log.Info("Sample Batch Job Service stopped successfully")
}
