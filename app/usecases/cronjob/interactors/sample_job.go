package interactors

import (
	"context"
	"fmt"

	"github.com/jmoiron/sqlx"

	"batch-samples/app/domain/entities"
	"batch-samples/app/usecases/port"
)

// SampleJob はサンプルバッチジョブのユースケース
type SampleJob struct {
	Tracer port.Tracer
	Logger port.Logger
	Master *sqlx.DB
	Slave  *sqlx.DB
	Tenant *entities.Tenant
}

// Execute はサンプルバッチジョブを実行する
func (s *SampleJob) Execute(ctx context.Context) error {
	span, ctx := s.Tracer.StartSpanFromContext(ctx, "SampleJob.Execute")
	defer span.Finish()

	s.Logger.Info(fmt.Sprintf("=== SampleJob.Execute: Starting job for tenant %s (DB: %s) ===",
		s.Tenant.Code, s.Tenant.DBName))

	// エラー処理の例
	select {
	case <-ctx.Done():
		return fmt.Errorf("job cancelled: %w", ctx.Err())
	default:
	}

	// TODO: 実際のバッチ処理ロジックを実装する
	s.Logger.Info(fmt.Sprintf("[%s] Step 1 - Initialize resources", s.Tenant.Code))

	// 例: DBからデータを取得
	s.Logger.Info(fmt.Sprintf("[%s] Step 2 - Query data from DB: %s", s.Tenant.Code, s.Tenant.DBName))
	// var count int
	// err := s.Slave.GetContext(ctx, &count, "SELECT COUNT(*) FROM some_table")
	// if err != nil {
	//     return fmt.Errorf("failed to query data: %w", err)
	// }

	s.Logger.Info(fmt.Sprintf("[%s] Step 3 - Process data", s.Tenant.Code))

	// 例: DBにデータを書き込み
	s.Logger.Info(fmt.Sprintf("[%s] Step 4 - Write data to DB", s.Tenant.Code))
	// _, err = s.Master.ExecContext(ctx, "INSERT INTO some_table (col1) VALUES (?)", value)
	// if err != nil {
	//     return fmt.Errorf("failed to insert data: %w", err)
	// }

	s.Logger.Info(fmt.Sprintf("[%s] Step 5 - Cleanup", s.Tenant.Code))

	s.Logger.Info(fmt.Sprintf("=== SampleJob.Execute: Completed successfully for tenant %s ===",
		s.Tenant.Code))

	return nil
}
