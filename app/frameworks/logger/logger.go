package logger

import (
	"fmt"
	"log"
)

// Logger は標準のロガー実装
type Logger struct{}

func NewLogger() *Logger {
	return &Logger{}
}

func (l *Logger) Info(msg string) {
	log.Printf("[INFO] %s", msg)
}

func (l *Logger) Warn(msg string) {
	log.Printf("[WARN] %s", msg)
}

func (l *Logger) Error(err error) {
	log.Printf("[ERROR] %v", err)
}

func (l *Logger) Errorf(format string, args ...interface{}) {
	log.Printf("[ERROR] %s", fmt.Sprintf(format, args...))
}
