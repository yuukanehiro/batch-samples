package dbsets

import (
	"context"
	"fmt"

	_ "github.com/go-sql-driver/mysql"
	"github.com/jmoiron/sqlx"

	"batch-samples/app/domain/entities"
	"batch-samples/app/frameworks/repositories"
	"batch-samples/config"
)

// DBSet は1つのテナントのマスター/スレーブDB接続を表す
type DBSet struct {
	Master *sqlx.DB
	Slave  *sqlx.DB
	Tenant *entities.Tenant
}

// AppDBs は全テナントのDBセットを管理する
type AppDBs struct {
	GeneralDB *sqlx.DB // 共通DB（0_general）
	DBSets    []*DBSet
}

// NewAppDBsByTenant は全テナントのDBセットを初期化する
func NewAppDBsByTenant(dbConfig *config.DBConfig) (*AppDBs, error) {
	// 共通DB（0_general）に接続
	generalDSN := dbConfig.GetDSN("0_general")
	generalDB, err := sqlx.Connect("mysql", generalDSN)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to general DB: %w", err)
	}
	generalDB.SetMaxOpenConns(dbConfig.MaxConns)

	// テナント一覧を取得
	tenantRepo := repositories.NewTenantRepository(generalDB)
	tenants, err := tenantRepo.FindAll(context.Background())
	if err != nil {
		generalDB.Close()
		return nil, fmt.Errorf("failed to fetch tenants: %w", err)
	}

	dbSets := make([]*DBSet, 0, len(tenants))
	for _, tenant := range tenants {
		if !tenant.Active {
			continue
		}

		// マスターDB接続
		masterDSN := dbConfig.GetDSN(tenant.DBName)
		masterDB, err := sqlx.Connect("mysql", masterDSN)
		if err != nil {
			return nil, fmt.Errorf("failed to connect to master DB for tenant %s: %w", tenant.Code, err)
		}
		masterDB.SetMaxOpenConns(dbConfig.MaxConns)

		// スレーブDB接続（この例では同じDBを使用）
		slaveDSN := dbConfig.GetDSN(tenant.DBName)
		slaveDB, err := sqlx.Connect("mysql", slaveDSN)
		if err != nil {
			masterDB.Close()
			return nil, fmt.Errorf("failed to connect to slave DB for tenant %s: %w", tenant.Code, err)
		}
		slaveDB.SetMaxOpenConns(dbConfig.MaxConns)

		dbSet := &DBSet{
			Master: masterDB,
			Slave:  slaveDB,
			Tenant: tenant,
		}
		dbSets = append(dbSets, dbSet)
	}

	return &AppDBs{
		GeneralDB: generalDB,
		DBSets:    dbSets,
	}, nil
}

// EachLinear は各テナントのDBセットに対して指定された関数を実行
func (a *AppDBs) EachLinear(fn func(master, slave *sqlx.DB, tenant *entities.Tenant)) {
	for _, dbSet := range a.DBSets {
		fn(dbSet.Master, dbSet.Slave, dbSet.Tenant)
	}
}

// Count はDBセットの数を返す
func (a *AppDBs) Count() int {
	return len(a.DBSets)
}

// Close は全てのDB接続を閉じる
func (a *AppDBs) Close() error {
	// 共通DBを閉じる
	if a.GeneralDB != nil {
		a.GeneralDB.Close()
	}

	// 各テナントのDBを閉じる
	for _, dbSet := range a.DBSets {
		if dbSet.Master != nil {
			dbSet.Master.Close()
		}
		if dbSet.Slave != nil {
			dbSet.Slave.Close()
		}
	}
	return nil
}
