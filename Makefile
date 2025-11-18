.PHONY: help build run test clean docker-build docker-run db-up db-down db-logs db-reset db-shell build-retry run-retry build-specific run-specific lambda-invoke lambda-invoke-single lambda-logs lambda-update sfn-run-workflow sfn-run-specific sfn-list-executions sfn-logs

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

# =============================================================================
# AWS/ECR関連コマンド
# =============================================================================

# AWS変数
AWS_REGION := ap-northeast-1
AWS_ACCOUNT_ID := 925948485307
ECR_BASE := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/batch-samples-dev
PLATFORM := linux/amd64

## ecr-login: ECRにログイン
ecr-login:
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

## ecr-build: 全Dockerイメージをビルド（ECR用・linux/amd64）
ecr-build: ecr-build-sample ecr-build-retry ecr-build-specific

ecr-build-sample:
	docker build --platform $(PLATFORM) --target sample-batch -t sample-batch .

ecr-build-retry:
	docker build --platform $(PLATFORM) --target retry-failed-tenants -t retry-failed-tenants .

ecr-build-specific:
	docker build --platform $(PLATFORM) --target run-specific-tenants -t run-specific-tenants .

## ecr-push: 全イメージをECRにプッシュ
ecr-push: ecr-push-sample ecr-push-retry ecr-push-specific

ecr-push-sample:
	docker tag sample-batch:latest $(ECR_BASE)/sample-batch:latest
	docker push $(ECR_BASE)/sample-batch:latest

ecr-push-retry:
	docker tag retry-failed-tenants:latest $(ECR_BASE)/retry-failed-tenants:latest
	docker push $(ECR_BASE)/retry-failed-tenants:latest

ecr-push-specific:
	docker tag run-specific-tenants:latest $(ECR_BASE)/run-specific-tenants:latest
	docker push $(ECR_BASE)/run-specific-tenants:latest

## ecr-deploy: ECRビルド＆プッシュ（ecr-login + ecr-build + ecr-push）
ecr-deploy: ecr-login ecr-build ecr-push
	@echo "ECR deploy completed"

## ecs-run-sample: sample-batch ECSタスクを手動実行
ecs-run-sample:
	@cd terraform && aws ecs run-task \
		--cluster $$(terraform output -raw ecs_cluster_name) \
		--task-definition $$(terraform output -raw ecs_task_definition_sample_batch_arn) \
		--launch-type FARGATE \
		--network-configuration "awsvpcConfiguration={subnets=[$$(terraform output -json private_subnet_ids | jq -r '.[0]')],securityGroups=[$$(terraform output -raw ecs_task_security_group_id)],assignPublicIp=DISABLED}"

## ecs-run-retry: retry-failed-tenants ECSタスクを手動実行
ecs-run-retry:
	@cd terraform && aws ecs run-task \
		--cluster $$(terraform output -raw ecs_cluster_name) \
		--task-definition $$(terraform output -raw ecs_task_definition_retry_batch_arn) \
		--launch-type FARGATE \
		--network-configuration "awsvpcConfiguration={subnets=[$$(terraform output -json private_subnet_ids | jq -r '.[0]')],securityGroups=[$$(terraform output -raw ecs_task_security_group_id)],assignPublicIp=DISABLED}"

## ecs-run-specific: run-specific-tenants ECSタスクを手動実行（例: make ecs-run-specific TENANTS=acme,techcorp）
ecs-run-specific:
	@if [ -z "$(TENANTS)" ]; then \
		echo "Error: TENANTS is not specified."; \
		echo "Usage: make ecs-run-specific TENANTS=acme,techcorp"; \
		exit 1; \
	fi
	@cd terraform && aws ecs run-task \
		--cluster $$(terraform output -raw ecs_cluster_name) \
		--task-definition $$(terraform output -raw ecs_task_definition_specific_batch_arn) \
		--launch-type FARGATE \
		--network-configuration "awsvpcConfiguration={subnets=[$$(terraform output -json private_subnet_ids | jq -r '.[0]')],securityGroups=[$$(terraform output -raw ecs_task_security_group_id)],assignPublicIp=DISABLED}" \
		--overrides '{"containerOverrides":[{"name":"specific-batch","command":[$(shell echo $(TENANTS) | sed 's/,/","/g' | sed 's/^/"/;s/$$/"/;')]}]}'

## logs-sample: sample-batchのCloudWatchログを表示
logs-sample:
	aws logs tail /ecs/batch-samples-dev/sample-batch --follow

## logs-retry: retry-failed-tenantsのCloudWatchログを表示
logs-retry:
	aws logs tail /ecs/batch-samples-dev/retry-failed-tenants --follow

## logs-specific: run-specific-tenantsのCloudWatchログを表示
logs-specific:
	aws logs tail /ecs/batch-samples-dev/run-specific-tenants --follow

# =============================================================================
# Terraform関連コマンド
# =============================================================================

## tf-init: Terraform初期化
tf-init:
	cd terraform && source .envrc && terraform init

## tf-plan: Terraformプラン
tf-plan:
	cd terraform && source .envrc && terraform plan

## tf-apply: Terraform適用
tf-apply:
	cd terraform && source .envrc && terraform apply

## tf-apply-auto: Terraform適用（確認なし）
tf-apply-auto:
	cd terraform && source .envrc && terraform apply -auto-approve

## tf-destroy: Terraformリソース削除（確認あり）
tf-destroy:
	cd terraform && source .envrc && terraform destroy

## tf-destroy-auto: Terraformリソース削除（確認なし）
tf-destroy-auto:
	cd terraform && source .envrc && terraform destroy -auto-approve

## tf-destroy-target: 特定リソースのみ削除（例: make tf-destroy-target TARGET=aws_instance.bastion）
tf-destroy-target:
	@if [ -z "$(TARGET)" ]; then \
		echo "Error: TARGET is not specified."; \
		echo "Usage: make tf-destroy-target TARGET=aws_instance.bastion"; \
		exit 1; \
	fi
	cd terraform && source .envrc && terraform destroy -target=$(TARGET) -auto-approve

## tf-output: Terraform出力値を表示
tf-output:
	cd terraform && source .envrc && terraform output

## tf-whoami: 現在使用中のAWS認証情報を表示
tf-whoami:
	cd terraform && source .envrc && aws sts get-caller-identity

## aws-db-init: AWS RDSのデータベースを初期化（Bastion経由）
aws-db-init:
	@BASTION_IP=$$(cd terraform && terraform output -raw bastion_public_ip) && \
	RDS_HOST=$$(cd terraform && terraform output -raw rds_address) && \
	cat docker/mysql/init/00_create_general_database.sql | ssh -i ~/.ssh/batch-samples-bastion ec2-user@$$BASTION_IP "mysql -h $$RDS_HOST -u admin -pYourSecurePassword123!" && \
	cat docker/mysql/init/01_create_databases.sql | ssh -i ~/.ssh/batch-samples-bastion ec2-user@$$BASTION_IP "mysql -h $$RDS_HOST -u admin -pYourSecurePassword123!" && \
	cat docker/mysql/init/02_insert_sample_data.sql | ssh -i ~/.ssh/batch-samples-bastion ec2-user@$$BASTION_IP "mysql -h $$RDS_HOST -u admin -pYourSecurePassword123!"
	@echo "Database initialization completed"

# =============================================================================
# AWS Batch関連コマンド
# =============================================================================

## batch-run-sample: sample-batch AWS Batchジョブを手動実行
batch-run-sample:
	@cd terraform && aws batch submit-job \
		--job-name "manual-sample-batch-$$(date +%Y%m%d-%H%M%S)" \
		--job-queue $$(terraform output -raw batch_job_queue_name) \
		--job-definition $$(terraform output -raw batch_job_definition_sample_arn)

## batch-run-retry: retry-failed-tenants AWS Batchジョブを手動実行
batch-run-retry:
	@cd terraform && aws batch submit-job \
		--job-name "manual-retry-batch-$$(date +%Y%m%d-%H%M%S)" \
		--job-queue $$(terraform output -raw batch_job_queue_name) \
		--job-definition $$(terraform output -raw batch_job_definition_retry_arn)

## batch-run-specific: run-specific-tenants AWS Batchジョブを手動実行（例: make batch-run-specific TENANTS=acme,techcorp）
batch-run-specific:
	@if [ -z "$(TENANTS)" ]; then \
		echo "Error: TENANTS is not specified."; \
		echo "Usage: make batch-run-specific TENANTS=acme,techcorp"; \
		exit 1; \
	fi
	@cd terraform && aws batch submit-job \
		--job-name "manual-specific-batch-$$(date +%Y%m%d-%H%M%S)" \
		--job-queue $$(terraform output -raw batch_job_queue_name) \
		--job-definition $$(terraform output -raw batch_job_definition_specific_arn) \
		--container-overrides '{"command":[$(shell echo $(TENANTS) | sed 's/,/","/g' | sed 's/^/"/;s/$$/"/;')]}'

## batch-logs-sample: sample-batch AWS BatchのCloudWatchログを表示
batch-logs-sample:
	aws logs tail /aws/batch/batch-samples-dev/sample-batch --follow

## batch-logs-retry: retry-failed-tenants AWS BatchのCloudWatchログを表示
batch-logs-retry:
	aws logs tail /aws/batch/batch-samples-dev/retry-failed-tenants --follow

## batch-logs-specific: run-specific-tenants AWS BatchのCloudWatchログを表示
batch-logs-specific:
	aws logs tail /aws/batch/batch-samples-dev/run-specific-tenants --follow

## batch-list-jobs: AWS Batchジョブ一覧を表示
batch-list-jobs:
	@cd terraform && aws batch list-jobs \
		--job-queue $$(terraform output -raw batch_job_queue_name) \
		--job-status RUNNING && \
	aws batch list-jobs \
		--job-queue $$(terraform output -raw batch_job_queue_name) \
		--job-status SUCCEEDED | head -50

# =============================================================================
# Lambda関連コマンド
# =============================================================================

## lambda-invoke: Lambda関数を手動実行（例: make lambda-invoke TENANTS=acme,techcorp）
lambda-invoke:
	@if [ -z "$(TENANTS)" ]; then \
		echo "Error: TENANTS is not specified."; \
		echo "Usage: make lambda-invoke TENANTS=acme,techcorp"; \
		exit 1; \
	fi
	@cd terraform && aws lambda invoke \
		--function-name $$(terraform output -raw lambda_batch_trigger_name) \
		--payload "$$(echo '{"tenant_codes": "$(TENANTS)"}' | base64)" \
		--cli-binary-format raw-in-base64-out \
		/tmp/lambda-response.json && \
	cat /tmp/lambda-response.json && \
	echo ""

## lambda-invoke-single: 単一テナントでLambda実行（例: make lambda-invoke-single TENANT=acme）
lambda-invoke-single:
	@if [ -z "$(TENANT)" ]; then \
		echo "Error: TENANT is not specified."; \
		echo "Usage: make lambda-invoke-single TENANT=acme"; \
		exit 1; \
	fi
	@cd terraform && aws lambda invoke \
		--function-name $$(terraform output -raw lambda_batch_trigger_name) \
		--payload "$$(echo '{"tenant_code": "$(TENANT)"}' | base64)" \
		--cli-binary-format raw-in-base64-out \
		/tmp/lambda-response.json && \
	cat /tmp/lambda-response.json && \
	echo ""

## lambda-logs: Lambda関数のCloudWatchログを表示
lambda-logs:
	aws logs tail /aws/lambda/batch-samples-dev-batch-trigger --follow

## lambda-update: Lambda関数のコードを更新（terraform applyを使用）
lambda-update:
	cd terraform && terraform apply -target=aws_lambda_function.batch_trigger -auto-approve

# =============================================================================
# Step Functions関連コマンド
# =============================================================================

## sfn-run-workflow: バッチワークフロー（sample-batch → retry）を実行
sfn-run-workflow:
	@cd terraform && aws stepfunctions start-execution \
		--state-machine-arn $$(terraform output -raw step_functions_batch_workflow_arn) \
		--name "manual-batch-workflow-$$(date +%Y%m%d-%H%M%S)"

## sfn-run-specific: 指定テナントワークフローを実行（例: make sfn-run-specific TENANTS=acme,techcorp）
sfn-run-specific:
	@if [ -z "$(TENANTS)" ]; then \
		echo "Error: TENANTS is not specified."; \
		echo "Usage: make sfn-run-specific TENANTS=acme,techcorp"; \
		exit 1; \
	fi
	@cd terraform && aws stepfunctions start-execution \
		--state-machine-arn $$(terraform output -raw step_functions_specific_tenants_workflow_arn) \
		--name "manual-specific-workflow-$$(date +%Y%m%d-%H%M%S)" \
		--input "{\"tenant_codes\": [\"$$(echo $(TENANTS) | sed 's/,/\",\"/g')\"]}"

## sfn-list-executions: Step Functions実行一覧を表示
sfn-list-executions:
	@cd terraform && aws stepfunctions list-executions \
		--state-machine-arn $$(terraform output -raw step_functions_batch_workflow_arn) \
		--max-results 10

## sfn-logs: Step Functionsのログを表示
sfn-logs:
	aws logs tail /aws/vendedlogs/states/batch-samples-dev-batch-workflow --follow
