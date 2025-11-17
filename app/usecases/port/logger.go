package port

// Logger はロガーのインターフェース
type Logger interface {
	Info(msg string)
	Warn(msg string)
	Error(err error)
}
