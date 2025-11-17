package repositories

import (
	"context"
	"time"

	"github.com/jmoiron/sqlx"

	"batch-samples/app/domain/entities"
)

// JobExecutionLogRepository はジョブ実行履歴のリポジトリ
type JobExecutionLogRepository struct {
	db *sqlx.DB
}

// NewJobExecutionLogRepository はJobExecutionLogRepositoryを生成する
func NewJobExecutionLogRepository(db *sqlx.DB) *JobExecutionLogRepository {
	return &JobExecutionLogRepository{db: db}
}

// Create はジョブ実行履歴を作成する
func (r *JobExecutionLogRepository) Create(ctx context.Context, log *entities.JobExecutionLog) error {
	query := `
		INSERT INTO job_execution_logs (
			job_name, tenant_id, tenant_code, status, started_at, completed_at, error_message
		) VALUES (
			:job_name, :tenant_id, :tenant_code, :status, :started_at, :completed_at, :error_message
		)
	`
	result, err := r.db.NamedExecContext(ctx, query, log)
	if err != nil {
		return err
	}

	id, err := result.LastInsertId()
	if err != nil {
		return err
	}
	log.ID = id
	return nil
}

// UpdateStatus はジョブ実行履歴のステータスを更新する
func (r *JobExecutionLogRepository) UpdateStatus(
	ctx context.Context,
	id int64,
	status entities.JobExecutionStatus,
	completedAt *time.Time,
	errorMessage *string,
) error {
	query := `
		UPDATE job_execution_logs
		SET status = ?, completed_at = ?, error_message = ?, updated_at = NOW()
		WHERE id = ?
	`
	_, err := r.db.ExecContext(ctx, query, status, completedAt, errorMessage, id)
	return err
}

// FindFailedTenantsByJobName は指定されたジョブ名で失敗したテナント一覧を取得する
func (r *JobExecutionLogRepository) FindFailedTenantsByJobName(
	ctx context.Context,
	jobName string,
	since time.Time,
) ([]entities.JobExecutionLog, error) {
	query := `
		SELECT * FROM job_execution_logs
		WHERE job_name = ? AND status = ? AND started_at >= ?
		ORDER BY started_at DESC
	`
	var logs []entities.JobExecutionLog
	err := r.db.SelectContext(ctx, &logs, query, jobName, entities.JobExecutionStatusFailed, since)
	return logs, err
}

// FindLatestByJobNameAndTenant は指定されたジョブ名とテナントの最新の実行履歴を取得する
func (r *JobExecutionLogRepository) FindLatestByJobNameAndTenant(
	ctx context.Context,
	jobName string,
	tenantID int64,
) (*entities.JobExecutionLog, error) {
	query := `
		SELECT * FROM job_execution_logs
		WHERE job_name = ? AND tenant_id = ?
		ORDER BY started_at DESC
		LIMIT 1
	`
	var log entities.JobExecutionLog
	err := r.db.GetContext(ctx, &log, query, jobName, tenantID)
	if err != nil {
		return nil, err
	}
	return &log, nil
}
