package repositories

import (
	"context"

	"github.com/jmoiron/sqlx"

	"batch-samples/app/domain/entities"
)

// TenantRepository はテナントのリポジトリ
type TenantRepository struct {
	db *sqlx.DB
}

// NewTenantRepository はTenantRepositoryを生成する
func NewTenantRepository(db *sqlx.DB) *TenantRepository {
	return &TenantRepository{db: db}
}

// FindAll は全てのアクティブなテナントを取得する
func (r *TenantRepository) FindAll(ctx context.Context) ([]*entities.Tenant, error) {
	query := `
		SELECT id, code, name, db_name, active
		FROM tenants
		WHERE active = TRUE
		ORDER BY id ASC
	`
	var tenants []*entities.Tenant
	err := r.db.SelectContext(ctx, &tenants, query)
	return tenants, err
}

// FindByID はIDでテナントを取得する
func (r *TenantRepository) FindByID(ctx context.Context, id int64) (*entities.Tenant, error) {
	query := `
		SELECT id, code, name, db_name, active
		FROM tenants
		WHERE id = ? AND active = TRUE
	`
	var tenant entities.Tenant
	err := r.db.GetContext(ctx, &tenant, query, id)
	if err != nil {
		return nil, err
	}
	return &tenant, nil
}

// FindByCode はコードでテナントを取得する
func (r *TenantRepository) FindByCode(ctx context.Context, code string) (*entities.Tenant, error) {
	query := `
		SELECT id, code, name, db_name, active
		FROM tenants
		WHERE code = ? AND active = TRUE
	`
	var tenant entities.Tenant
	err := r.db.GetContext(ctx, &tenant, query, code)
	if err != nil {
		return nil, err
	}
	return &tenant, nil
}
