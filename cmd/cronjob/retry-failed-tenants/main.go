package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"batch-samples/app/frameworks/dbsets"
	"batch-samples/app/frameworks/logger"
	"batch-samples/app/frameworks/repositories"
	"batch-samples/app/frameworks/tracer"
	"batch-samples/app/interface-adapters/cronjob/handlers"
	"batch-samples/config"
)

func main() {
	// Logger の初期化
	log := logger.NewLogger()
	log.Info("Starting Retry Failed Tenants Batch Job Service")

	// Config の初期化
	conf := config.NewConfig()
	dbConf := config.NewDBConfig()
	log.Info(fmt.Sprintf("Environment: %s, Batch Name: retry-failed-tenants", conf.Environment))
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

	// 失敗したテナントを取得
	logRepo := repositories.NewJobExecutionLogRepository(dbSets.GeneralDB)

	// 過去24時間以内に失敗したテナントを取得
	since := time.Now().Add(-24 * time.Hour)
	failedLogs, err := logRepo.FindFailedTenantsByJobName(ctx, handlers.SampleJobName, since)
	if err != nil {
		log.Error(fmt.Errorf("failed to get failed tenants: %w", err))
		os.Exit(1)
	}

	if len(failedLogs) == 0 {
		log.Info("No failed tenants found in the last 24 hours")
		return
	}

	log.Info(fmt.Sprintf("Found %d failed tenant executions", len(failedLogs)))

	// 失敗したテナントのマップを作成（重複排除）
	failedTenantIDs := make(map[int64]bool)
	for _, failedLog := range failedLogs {
		failedTenantIDs[failedLog.TenantID] = true
	}

	log.Info(fmt.Sprintf("Retrying %d unique tenants", len(failedTenantIDs)))

	// 再実行用のDBセットを作成
	var retryDBSets []*dbsets.DBSet
	for tenantID := range failedTenantIDs {
		// 該当するDBSetを探す
		for _, dbSet := range dbSets.DBSets {
			if dbSet.Tenant.ID == tenantID {
				retryDBSets = append(retryDBSets, dbSet)
				break
			}
		}
	}

	if len(retryDBSets) == 0 {
		log.Info("No valid tenants to retry")
		return
	}

	// Tracer の初期化
	tr := tracer.NewTracer()

	// 再実行用のHandler（失敗したテナントのみ実行）
	handler := &handlers.RetryFailedTenantsHandler{
		Tracer:      tr,
		Logger:      log,
		DBSets:      dbSets,
		RetryDBSets: retryDBSets,
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

	log.Info("Retry Failed Tenants Batch Job Service stopped successfully")
}
