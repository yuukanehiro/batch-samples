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
	SampleJobName = "sample-job"
)

// SampleJobHandler はサンプルジョブのハンドラー
type SampleJobHandler struct {
	Tracer port.Tracer
	Logger port.Logger
	DBSets *dbsets.AppDBs
}

// Start はジョブを開始する
func (h *SampleJobHandler) Start(ctx context.Context) error {
	h.Logger.Info("Starting sample job handler...")

	h.Logger.Info("Executing scheduled sample job...")

	// ジョブ実行時間制限（1時間）
	jobCtx, cancel := context.WithTimeout(ctx, 1*time.Hour)
	defer cancel()

	err := h.ExecuteJob(jobCtx)
	if err != nil {
		h.Logger.Info("Sample job encountered an error: " + err.Error())
		return fmt.Errorf("sample job execution error: %w", err)
	}
	h.Logger.Info("Sample job completed successfully")

	return nil
}

// ExecuteJob はサンプルジョブを実行する（マルチテナント並行処理）
func (h *SampleJobHandler) ExecuteJob(ctx context.Context) error {
	h.Logger.Info("executeJob: Starting sample job execution for all tenants (concurrent mode)")

	// 並行処理(ワーカー数制限)
	// CPU数に基づいてワーカー数を決定 idle状態を避けるために2倍
	// 最小2、最大10に制限
	maxWorkers := runtime.NumCPU() * 2
	if maxWorkers < 2 {
		maxWorkers = 2
	}
	if maxWorkers > 10 {
		maxWorkers = 10
	}
	h.Logger.Info(fmt.Sprintf("executeJob: Max workers = %d (CPU cores = %d)", maxWorkers, runtime.NumCPU()))
	semaphore := make(chan struct{}, maxWorkers)

	var wg sync.WaitGroup

	// カウンター（スレッドセーフ）
	var tenantCount int32
	var successCount int32
	var errorCount int32

	// 各テナントを並行処理
	h.DBSets.EachLinear(func(master, slave *sqlx.DB, tenant *entities.Tenant) {
		atomic.AddInt32(&tenantCount, 1)
		currentTenantNum := atomic.LoadInt32(&tenantCount)

		// 並行処理のワーカ数を制限
		wg.Add(1)
		semaphore <- struct{}{}

		go func(m, s *sqlx.DB, t *entities.Tenant, tenantNum int32) {
			// ワーカー完了通知
			defer wg.Done()
			defer func() { <-semaphore }()

			// キャンセルチェック
			select {
			case <-ctx.Done():
				h.Logger.Warn(fmt.Sprintf("Job cancelled for tenant: %s (ID: %d)", t.Name, t.ID))
				return
			default:
			}

			h.Logger.Info(fmt.Sprintf("[Tenant %d] Processing job for tenant: %s (ID: %d, DB: %s)",
				tenantNum, t.Name, t.ID, t.DBName))

			if err := h.executeJobForTenant(ctx, m, s, t); err != nil {
				// 1つのテナントで失敗しても他のテナントは処理を続ける
				atomic.AddInt32(&errorCount, 1)
				h.Logger.Error(fmt.Errorf("job error for tenant %s (ID: %d): %w", t.Name, t.ID, err))
			} else {
				atomic.AddInt32(&successCount, 1)
				h.Logger.Info(fmt.Sprintf("[Tenant %d] Job completed for tenant: %s",
					tenantNum, t.Name))
			}
		}(master, slave, tenant, currentTenantNum)
	})

	// 全てのgoroutineの完了を待つ
	wg.Wait()

	h.Logger.Info(fmt.Sprintf("executeJob: Finished processing all tenants (Total: %d, Success: %d, Error: %d)",
		tenantCount, successCount, errorCount))

	return nil
}

// executeJobForTenant は特定のテナントのジョブ処理を実行する
func (h *SampleJobHandler) executeJobForTenant(
	ctx context.Context,
	master, slave *sqlx.DB,
	tenant *entities.Tenant,
) error {
	// ジョブ実行ログリポジトリ
	logRepo := repositories.NewJobExecutionLogRepository(h.DBSets.GeneralDB)

	// 実行ログを作成（running状態）
	startedAt := time.Now()
	log := &entities.JobExecutionLog{
		JobName:    SampleJobName,
		TenantID:   tenant.ID,
		TenantCode: tenant.Code,
		Status:     entities.JobExecutionStatusRunning,
		StartedAt:  startedAt,
	}

	if err := logRepo.Create(ctx, log); err != nil {
		h.Logger.Error(fmt.Errorf("failed to create job execution log for tenant %s: %w", tenant.Code, err))
		// ログ作成に失敗してもジョブは実行する
	}

	// ジョブ Interactor の作成
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
		h.Logger.Error(fmt.Errorf("failed to update job execution log for tenant %s: %w", tenant.Code, updateErr))
	}

	return err
}
