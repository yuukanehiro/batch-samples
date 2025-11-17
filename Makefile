.PHONY: help build run test clean docker-build docker-run db-up db-down db-logs db-reset db-shell build-retry run-retry build-specific run-specific

# 変数定義
APP_NAME := sample-batch
RETRY_APP_NAME := retry-failed-tenants
SPECIFIC_APP_NAME := run-specific-tenants
DOCKER_IMAGE := batch-samples:latest
DOCKER_COMPOSE := docker-compose

# デフォルトターゲット
.DEFAULT_GOAL := help

## help: このヘルプメッセージを表示
help:
	@echo "利用可能なMakeコマンド:"
	@echo ""
	@grep -E '^## ' Makefile | sed 's/## /  /'
	@echo ""

## build: アプリケーションをビルド
build:
	@echo "Building application..."
	go build -o $(APP_NAME) ./cmd/cronjob/sample-batch
	@echo "Build completed: ./$(APP_NAME)"

## run: アプリケーションを実行（DB起動済みを想定）
run: build
	@echo "Running application..."
	./$(APP_NAME)

## build-retry: リトライバッチをビルド
build-retry:
	@echo "Building retry application..."
	go build -o $(RETRY_APP_NAME) ./cmd/cronjob/retry-failed-tenants
	@echo "Build completed: ./$(RETRY_APP_NAME)"

## run-retry: 失敗したテナントを再実行（DB起動済みを想定）
run-retry: build-retry
	@echo "Running retry application..."
	./$(RETRY_APP_NAME)

## build-specific: 指定テナント実行バッチをビルド
build-specific:
	@echo "Building run-specific-tenants application..."
	go build -o $(SPECIFIC_APP_NAME) ./cmd/cronjob/run-specific-tenants
	@echo "Build completed: ./$(SPECIFIC_APP_NAME)"

## run-specific: 指定したテナントのみ実行（例: make run-specific TENANTS=acme,techcorp）
run-specific: build-specific
	@echo "Running run-specific-tenants application..."
	@if [ -z "$(TENANTS)" ]; then \
		echo "Error: TENANTS is not specified."; \
		echo "Usage: make run-specific TENANTS=acme,techcorp"; \
		exit 1; \
	fi
	TENANTS=$(TENANTS) ./$(SPECIFIC_APP_NAME)

## test: テストを実行
test:
	@echo "Running tests..."
	go test -v ./...

## clean: ビルド成果物を削除
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(APP_NAME)
	rm -f $(RETRY_APP_NAME)
	rm -f $(SPECIFIC_APP_NAME)
	rm -f sample-batch
	@echo "Clean completed"

## docker-build: Dockerイメージをビルド
docker-build:
	@echo "Building Docker image..."
	docker build -t $(DOCKER_IMAGE) .
	@echo "Docker image built: $(DOCKER_IMAGE)"

## docker-run: Dockerコンテナで実行（macOS）
docker-run:
	@echo "Running Docker container..."
	docker run --rm \
		-e DB_HOST=host.docker.internal \
		-e DB_PORT=3306 \
		-e DB_USER=root \
		-e DB_PASSWORD=password \
		$(DOCKER_IMAGE)

## docker-run-linux: Dockerコンテナで実行（Linux）
docker-run-linux:
	@echo "Running Docker container (Linux)..."
	docker run --rm --network host \
		-e DB_HOST=localhost \
		-e DB_PORT=3306 \
		-e DB_USER=root \
		-e DB_PASSWORD=password \
		$(DOCKER_IMAGE)

## db-up: MySQL（docker-compose）を起動
db-up:
	@echo "Starting MySQL..."
	$(DOCKER_COMPOSE) up -d
	@echo "Waiting for MySQL to be ready..."
	@sleep 15
	@echo "MySQL is ready"

## db-down: MySQL（docker-compose）を停止
db-down:
	@echo "Stopping MySQL..."
	$(DOCKER_COMPOSE) down

## db-logs: MySQLのログを表示
db-logs:
	$(DOCKER_COMPOSE) logs -f mysql

## db-reset: MySQLを再起動してDBをリセット
db-reset: db-down
	@echo "Removing MySQL volume..."
	$(DOCKER_COMPOSE) down -v
	@echo "Starting fresh MySQL..."
	$(DOCKER_COMPOSE) up -d
	@echo "Waiting for MySQL to initialize..."
	@sleep 20
	@echo "MySQL reset completed"

## db-shell: MySQLにシェルで接続
db-shell:
	@echo "Connecting to MySQL..."
	$(DOCKER_COMPOSE) exec mysql mysql -uroot -ppassword

## db-show: 全テナントのDBを表示
db-show:
	@echo "Listing all databases..."
	$(DOCKER_COMPOSE) exec mysql mysql -uroot -ppassword -e "SHOW DATABASES;"

## db-check: 各テナントのデータを確認
db-check:
	@echo "Checking tenant data..."
	@echo "\n=== 1_acme ==="
	$(DOCKER_COMPOSE) exec mysql mysql -uroot -ppassword -e "USE 1_acme; SELECT * FROM sample_data;"
	@echo "\n=== 2_techcorp ==="
	$(DOCKER_COMPOSE) exec mysql mysql -uroot -ppassword -e "USE 2_techcorp; SELECT * FROM sample_data;"
	@echo "\n=== 3_finserv ==="
	$(DOCKER_COMPOSE) exec mysql mysql -uroot -ppassword -e "USE 3_finserv; SELECT * FROM sample_data;"
	@echo "\n=== 4_healthsys ==="
	$(DOCKER_COMPOSE) exec mysql mysql -uroot -ppassword -e "USE 4_healthsys; SELECT * FROM sample_data;"
	@echo "\n=== 5_edutech ==="
	$(DOCKER_COMPOSE) exec mysql mysql -uroot -ppassword -e "USE 5_edutech; SELECT * FROM sample_data;"

## setup: 初期セットアップ（DB起動 + ビルド）
setup: db-up build
	@echo "Setup completed"

## dev: 開発用（DB起動 + ビルド + 実行）
dev: db-up
	@echo "Waiting for MySQL to be ready..."
	@sleep 15
	@$(MAKE) run

## all: フルビルド（クリーン + ビルド + テスト）
all: clean build test
	@echo "Full build completed"
