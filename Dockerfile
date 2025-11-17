# ビルドステージ
FROM golang:1.22.5-alpine AS builder

WORKDIR /app

# 依存関係をキャッシュするため、まずgo.modとgo.sumをコピー
COPY go.mod go.sum* ./
RUN go mod download

# ソースコードをコピー
COPY . .

# バイナリをビルド
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o sample-batch ./cmd/cronjob/sample-batch

# 実行ステージ
FROM alpine:latest

# タイムゾーンとCA証明書をインストール
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /root/

# ビルドステージからバイナリをコピー
COPY --from=builder /app/sample-batch .

# 実行
CMD ["./sample-batch"]
