package handlers

import (
	"context"
	"fmt"
	"runtime"
	"sync"
	"sync/atomic"
	"time"

	"github.com/jmoiron/sqlx"

	"batch-samples/app/domain/entities"
	"batch-samples/app/frameworks/dbsets"
	"batch-samples/app/frameworks/repositories"
	"batch-samples/app/usecases/cronjob/interactors"
	"batch-samples/app/usecases/port"
)

const (
	RetryJobName = "retry-failed-tenants"
)

// RetryFailedTenantsHandler は失敗したテナントの再実行ハンドラー
type RetryFailedTenantsHandler struct {
	Tracer      port.Tracer
	Logger      port.Logger
	DBSets      *dbsets.AppDBs
	RetryDBSets []*dbsets.DBSet // 再実行対象のテナントのみ
}

// Start はリトライジョブを開始する
func (h *RetryFailedTenantsHandler) Start(ctx context.Context) error {
	h.Logger.Info("Starting retry failed tenants handler...")

	h.Logger.Info("Executing retry job for failed tenants...")

	// ジョブ実行時間制限（1時間）
	jobCtx, cancel := context.WithTimeout(ctx, 1*time.Hour)
	defer cancel()

	err := h.ExecuteRetryJob(jobCtx)
	if err != nil {
		h.Logger.Info("Retry job encountered an error: " + err.Error())
		return fmt.Errorf("retry job execution error: %w", err)
	}
	h.Logger.Info("Retry job completed successfully")

	return nil
}

// ExecuteRetryJob は失敗したテナントのリトライジョブを実行する（並行処理）
func (h *RetryFailedTenantsHandler) ExecuteRetryJob(ctx context.Context) error {
	h.Logger.Info(fmt.Sprintf("executeRetryJob: Starting retry job for %d failed tenants (concurrent mode)", len(h.RetryDBSets)))

	if len(h.RetryDBSets) == 0 {
		h.Logger.Info("No tenants to retry")
		return nil
	}

	// 並行処理(ワーカー数制限)
	maxWorkers := runtime.NumCPU() * 2
	if maxWorkers < 2 {
		maxWorkers = 2
	}
	if maxWorkers > 10 {
		maxWorkers = 10
	}
	h.Logger.Info(fmt.Sprintf("executeRetryJob: Max workers = %d (CPU cores = %d)", maxWorkers, runtime.NumCPU()))
	semaphore := make(chan struct{}, maxWorkers)

	var wg sync.WaitGroup

	// カウンター（スレッドセーフ）
	var tenantCount int32
	var successCount int32
	var errorCount int32

	// 各テナントを並行処理
	for _, dbSet := range h.RetryDBSets {
		atomic.AddInt32(&tenantCount, 1)
		currentTenantNum := atomic.LoadInt32(&tenantCount)

		// 並行処理のワーカ数を制限
		wg.Add(1)
		semaphore <- struct{}{}

		go func(ds *dbsets.DBSet, tenantNum int32) {
			// ワーカー完了通知
			defer wg.Done()
			defer func() { <-semaphore }()

			// キャンセルチェック
			select {
			case <-ctx.Done():
				h.Logger.Warn(fmt.Sprintf("Retry job cancelled for tenant: %s (ID: %d)", ds.Tenant.Name, ds.Tenant.ID))
				return
			default:
			}

			h.Logger.Info(fmt.Sprintf("[Retry %d] Processing retry job for tenant: %s (ID: %d, DB: %s)",
				tenantNum, ds.Tenant.Name, ds.Tenant.ID, ds.Tenant.DBName))

			if err := h.executeRetryJobForTenant(ctx, ds.Master, ds.Slave, ds.Tenant); err != nil {
				atomic.AddInt32(&errorCount, 1)
				h.Logger.Error(fmt.Errorf("retry job error for tenant %s (ID: %d): %w", ds.Tenant.Name, ds.Tenant.ID, err))
			} else {
				atomic.AddInt32(&successCount, 1)
				h.Logger.Info(fmt.Sprintf("[Retry %d] Retry job completed for tenant: %s",
					tenantNum, ds.Tenant.Name))
			}
		}(dbSet, currentTenantNum)
	}

	// 全てのgoroutineの完了を待つ
	wg.Wait()

	h.Logger.Info(fmt.Sprintf("executeRetryJob: Finished retrying all failed tenants (Total: %d, Success: %d, Error: %d)",
		tenantCount, successCount, errorCount))

	return nil
}

// executeRetryJobForTenant は特定のテナントのリトライジョブを実行する
func (h *RetryFailedTenantsHandler) executeRetryJobForTenant(
	ctx context.Context,
	master, slave *sqlx.DB,
	tenant *entities.Tenant,
) error {
	// ジョブ実行ログリポジトリ
	logRepo := repositories.NewJobExecutionLogRepository(h.DBSets.GeneralDB)

	// 実行ログを作成（running状態）
	startedAt := time.Now()
	log := &entities.JobExecutionLog{
		JobName:    RetryJobName,
		TenantID:   tenant.ID,
		TenantCode: tenant.Code,
		Status:     entities.JobExecutionStatusRunning,
		StartedAt:  startedAt,
	}

	if err := logRepo.Create(ctx, log); err != nil {
		h.Logger.Error(fmt.Errorf("failed to create retry job execution log for tenant %s: %w", tenant.Code, err))
	}

	// ジョブ Interactor の作成（元のジョブと同じロジックを実行）
	jobInteractor := &interactors.SampleJob{
		Tracer: h.Tracer,
		Logger: h.Logger,
		Master: master,
		Slave:  slave,
		Tenant: tenant,
	}

	// ジョブ実行
	err := jobInteractor.Execute(ctx)

	// 実行ログを更新
	completedAt := time.Now()
	var status entities.JobExecutionStatus
	var errorMessage *string

	if err != nil {
		status = entities.JobExecutionStatusFailed
		errMsg := err.Error()
		errorMessage = &errMsg
	} else {
		status = entities.JobExecutionStatusSuccess
	}

	if updateErr := logRepo.UpdateStatus(ctx, log.ID, status, &completedAt, errorMessage); updateErr != nil {
		h.Logger.Error(fmt.Errorf("failed to update retry job execution log for tenant %s: %w", tenant.Code, updateErr))
	}

	return err
}
