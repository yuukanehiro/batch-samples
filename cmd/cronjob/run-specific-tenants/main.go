package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"strings"
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
	log.Info("Starting Run Specific Tenants Batch Job Service")

	// Config の初期化
	conf := config.NewConfig()
	dbConf := config.NewDBConfig()
	log.Info(fmt.Sprintf("Environment: %s, Batch Name: run-specific-tenants", conf.Environment))
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

	// テナントコードの取得（コマンドライン引数 or 環境変数）
	var tenantCodes []string

	// コマンドライン引数から取得
	if len(os.Args) > 1 {
		tenantCodes = os.Args[1:]
		log.Info(fmt.Sprintf("Tenant codes from command line arguments: %v", tenantCodes))
	} else {
		// 環境変数から取得（カンマ区切り）
		tenantsEnv := os.Getenv("TENANTS")
		if tenantsEnv != "" {
			tenantCodes = strings.Split(tenantsEnv, ",")
			// トリミング
			for i := range tenantCodes {
				tenantCodes[i] = strings.TrimSpace(tenantCodes[i])
			}
			log.Info(fmt.Sprintf("Tenant codes from TENANTS environment variable: %v", tenantCodes))
		}
	}

	if len(tenantCodes) == 0 {
		log.Error(fmt.Errorf("no tenant codes specified. Use command line arguments or TENANTS environment variable"))
		log.Info("Usage: ./run-specific-tenants <tenant_code1> <tenant_code2> ...")
		log.Info("   or: TENANTS=<tenant_code1>,<tenant_code2> ./run-specific-tenants")
		log.Info("Example: ./run-specific-tenants acme techcorp")
		log.Info("Example: TENANTS=acme,techcorp ./run-specific-tenants")
		os.Exit(1)
	}

	// テナントコードのマップを作成
	tenantCodeMap := make(map[string]bool)
	for _, code := range tenantCodes {
		tenantCodeMap[code] = true
	}

	// 指定されたテナントのDBSetを抽出
	var specificDBSets []*dbsets.DBSet
	for _, dbSet := range dbSets.DBSets {
		if tenantCodeMap[dbSet.Tenant.Code] {
			specificDBSets = append(specificDBSets, dbSet)
			log.Info(fmt.Sprintf("Selected tenant: %s (ID: %d, DB: %s)",
				dbSet.Tenant.Code, dbSet.Tenant.ID, dbSet.Tenant.DBName))
		}
	}

	if len(specificDBSets) == 0 {
		log.Error(fmt.Errorf("no valid tenants found for specified codes: %v", tenantCodes))
		log.Info("Available tenant codes:")
		for _, dbSet := range dbSets.DBSets {
			log.Info(fmt.Sprintf("  - %s (ID: %d, Name: %s)", dbSet.Tenant.Code, dbSet.Tenant.ID, dbSet.Tenant.Name))
		}
		os.Exit(1)
	}

	log.Info(fmt.Sprintf("Processing %d out of %d tenants", len(specificDBSets), dbSets.Count()))

	// Tracer の初期化
	tr := tracer.NewTracer()

	// 指定テナント用のHandler
	handler := &handlers.RunSpecificTenantsHandler{
		Tracer:         tr,
		Logger:         log,
		DBSets:         dbSets,
		SpecificDBSets: specificDBSets,
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

	log.Info("Run Specific Tenants Batch Job Service stopped successfully")
}
