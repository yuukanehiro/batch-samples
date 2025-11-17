package port

import "context"

// Tracer はトレーサーのインターフェース
type Tracer interface {
	StartSpanFromContext(ctx context.Context, operationName string) (Span, context.Context)
}

// Span はトレーシングのスパンを表すインターフェース
type Span interface {
	Finish()
}
