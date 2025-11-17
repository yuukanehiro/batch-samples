package tracer

import (
	"context"

	"batch-samples/app/usecases/port"
)

// Tracer は標準のトレーサー実装
type Tracer struct{}

func NewTracer() *Tracer {
	return &Tracer{}
}

func (t *Tracer) StartSpanFromContext(ctx context.Context, operationName string) (port.Span, context.Context) {
	return &Span{operationName: operationName}, ctx
}

// Span はトレーシングのスパン実装
type Span struct {
	operationName string
}

func (s *Span) Finish() {
	// No-op for now
}
