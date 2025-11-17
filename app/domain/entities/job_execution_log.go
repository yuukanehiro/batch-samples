package entities

import "time"

// JobExecutionStatus はジョブ実行ステータスを表す型
type JobExecutionStatus string

// JobExecutionStatus の定義
const (
	JobExecutionStatusRunning JobExecutionStatus = "running"
	JobExecutionStatusSuccess JobExecutionStatus = "success"
	JobExecutionStatusFailed  JobExecutionStatus = "failed"
)

// JobExecutionLog はジョブ実行履歴を表すエンティティ
type JobExecutionLog struct {
	ID           int64              `db:"id" json:"id"`
	JobName      string             `db:"job_name" json:"job_name"`
	TenantID     int64              `db:"tenant_id" json:"tenant_id"`
	TenantCode   string             `db:"tenant_code" json:"tenant_code"`
	Status       JobExecutionStatus `db:"status" json:"status"`
	StartedAt    time.Time          `db:"started_at" json:"started_at"`
	CompletedAt  *time.Time         `db:"completed_at" json:"completed_at,omitempty"`
	ErrorMessage *string            `db:"error_message" json:"error_message,omitempty"`
	CreatedAt    time.Time          `db:"created_at" json:"created_at"`
	UpdatedAt    time.Time          `db:"updated_at" json:"updated_at"`
}

// IsSuccess はジョブが成功したかどうかを判定する
func (l *JobExecutionLog) IsSuccess() bool {
	return l.Status == JobExecutionStatusSuccess
}

// IsFailed はジョブが失敗したかどうかを判定する
func (l *JobExecutionLog) IsFailed() bool {
	return l.Status == JobExecutionStatusFailed
}
