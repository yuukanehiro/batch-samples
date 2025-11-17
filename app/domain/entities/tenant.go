package entities

// Tenant は事業者（テナント）を表すエンティティ
type Tenant struct {
	ID     int64  `db:"id" json:"id"`
	Code   string `db:"code" json:"code"`       // 例: "acme", "techcorp", "finserv"
	Name   string `db:"name" json:"name"`       // 例: "Acme Corporation", "Tech Corp", "Financial Services Inc"
	DBName string `db:"db_name" json:"db_name"` // 例: "1_acme", "2_techcorp", "3_finserv"
	Active bool   `db:"active" json:"active"`
}

// GetFullDBName はテナントの完全なDB名を返す
func (t *Tenant) GetFullDBName() string {
	return t.DBName
}
