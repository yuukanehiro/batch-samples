# ビルドステージ
FROM golang:1.22.5-alpine AS builder

WORKDIR /app

# 依存関係をキャッシュするため、まずgo.modとgo.sumをコピー
COPY go.mod go.sum* ./
RUN go mod download

# ソースコードをコピー
COPY . .

# 全てのバイナリをビルド
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o sample-batch ./cmd/cronjob/sample-batch
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o retry-failed-tenants ./cmd/cronjob/retry-failed-tenants
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o run-specific-tenants ./cmd/cronjob/run-specific-tenants

# sample-batch 実行ステージ
FROM alpine:latest AS sample-batch

# タイムゾーンとCA証明書をインストール
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /root/

# ビルドステージからバイナリをコピー
COPY --from=builder /app/sample-batch .

# 実行
CMD ["./sample-batch"]

# retry-failed-tenants 実行ステージ
FROM alpine:latest AS retry-failed-tenants

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /root/

COPY --from=builder /app/retry-failed-tenants .

CMD ["./retry-failed-tenants"]

# run-specific-tenants 実行ステージ
FROM alpine:latest AS run-specific-tenants

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /root/

COPY --from=builder /app/run-specific-tenants .

ENTRYPOINT ["./run-specific-tenants"]
