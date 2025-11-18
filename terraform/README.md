# Terraform for Batch Samples

このディレクトリには、バッチ処理システムをAWS上にデプロイするためのTerraform設定が含まれています。

## アーキテクチャ

このプロジェクトでは3つの実行方式を提供しています：

### 1. EventBridge + ECS Fargate（シンプル構成）
- 直接ECSタスクを実行
- セットアップが簡単
- 小〜中規模のバッチに最適

### 2. EventBridge + AWS Batch (Fargate)（スケーラブル構成）
- ジョブキューによる管理
- 自動リトライ機能
- 大規模・長時間バッチに最適

### 3. EventBridge + Lambda + AWS Batch（柔軟構成）
- Lambdaで動的にパラメータ制御
- テナント単位での実行が容易
- APIやイベント駆動との連携に最適

### 4. Step Functions + AWS Batch（ワークフロー構成）
- 複数ジョブの連携・依存関係を管理
- エラー処理・リトライの可視化
- 複雑なバッチパイプラインに最適

### 共通コンポーネント
- **RDS MySQL**: 単一インスタンス内に複数データベース（0_general, 1_acme, 2_techcorp, 3_finserv, 4_healthsys, 5_edutech）
- **環境**: dev環境のみ（必要に応じてstg, prodを追加可能）

## 構成リソース

### ネットワーク
- VPC
- パブリックサブネット × 2 (Multi-AZ)
- プライベートサブネット × 2 (Multi-AZ)
- インターネットゲートウェイ
- NATゲートウェイ

### データベース
- RDS MySQL 8.0 (db.t3.micro - ミニマムサイズ)
- ストレージ: 20GB (gp3)
- 自動バックアップ: 7日間保持
- CloudWatch Logsエクスポート有効

### コンテナ
- ECR リポジトリ × 3 (sample-batch, retry-failed-tenants, run-specific-tenants)
- ECS Fargate クラスター
- ECS タスク定義 × 3 (CPU: 256, Memory: 512MB - ミニマムサイズ)

### スケジューリング
- EventBridge ルール × 2 (ECS用)
  - sample-batch: 毎日午前2時 (UTC)
  - retry-failed-tenants: 毎日午前3時 (UTC)
- EventBridge ルール × 2 (AWS Batch用・初期状態は無効)

### AWS Batch
- Compute Environment (Fargate)
- Job Queue
- Job Definition × 3

### Lambda
- Lambda Function (batch-trigger)
- EventBridge ルール（スケジュールトリガー）
- IAM Role（Batch SubmitJob権限）

### Step Functions
- State Machine × 2 (batch-workflow, specific-tenants-workflow)
- EventBridge ルール（スケジュールトリガー）
- IAM Role（Batch/Lambda実行権限）

### Bastion
- EC2 t3.micro (Amazon Linux 2023)
- MySQL クライアント (mariadb105)
- RDS への SSH トンネル用

### ログ・セキュリティ
- CloudWatch Logs ロググループ × 3
- Secrets Manager (DB パスワード)
- IAM ロール・ポリシー

## 前提条件

1. **Terraform**: バージョン 1.0以上
2. **AWS CLI**: 設定済みのAWSクレデンシャル
3. **権限**: 以下のAWSリソースを作成できる権限
   - VPC, Subnet, RouteTable
   - RDS
   - ECR
   - ECS
   - EventBridge
   - IAM
   - CloudWatch Logs
   - Secrets Manager

## セットアップ手順

### 1. terraform.tfvars の作成

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` を編集し、以下を設定：
- `db_master_password`: セキュアなパスワードに変更（必須）
- `bastion_public_key`: SSH公開鍵（必須）
- `sample_batch_schedule`: 必要に応じてスケジュールを調整
- `retry_batch_schedule`: 必要に応じてスケジュールを調整

SSH鍵の生成例：
```bash
ssh-keygen -t ed25519 -f ~/.ssh/batch-samples-bastion -N "" -C "batch-samples-bastion"
cat ~/.ssh/batch-samples-bastion.pub  # この内容をbastion_public_keyに設定
```

### 2. Terraform の初期化

```bash
terraform init
```

### 3. 実行プランの確認

```bash
terraform plan
```

### 4. リソースの作成

```bash
terraform apply
```

確認プロンプトで `yes` を入力してリソースを作成します。

**注意**: 初回適用時の所要時間は約15-20分です（RDSの起動に時間がかかります）。

### 5. 出力値の確認

```bash
terraform output
```

重要な出力値:
- `rds_endpoint`: データベース接続エンドポイント
- `ecr_sample_batch_url`: sample-batch用ECRリポジトリURL
- `ecr_retry_batch_url`: retry-failed-tenants用ECRリポジトリURL
- `ecr_specific_batch_url`: run-specific-tenants用ECRリポジトリURL

## データベース初期化

Terraformでリソースを作成した後、Bastionホスト経由でデータベースの初期化が必要です。

### 方法1: Makefileを使用（推奨）

```bash
cd ..  # プロジェクトルートへ移動
make aws-db-init
```

### 方法2: 手動でBastionからSQLを実行

```bash
# Bastion IPとRDSエンドポイントを取得
BASTION_IP=$(terraform output -raw bastion_public_ip)
RDS_HOST=$(terraform output -raw rds_address)

# SQLファイルをBastion経由で実行
cat ../docker/mysql/init/00_create_general_database.sql | \
  ssh -i ~/.ssh/batch-samples-bastion ec2-user@$BASTION_IP \
  "mysql -h $RDS_HOST -u admin -pYourSecurePassword123!"

cat ../docker/mysql/init/01_create_databases.sql | \
  ssh -i ~/.ssh/batch-samples-bastion ec2-user@$BASTION_IP \
  "mysql -h $RDS_HOST -u admin -pYourSecurePassword123!"

cat ../docker/mysql/init/02_insert_sample_data.sql | \
  ssh -i ~/.ssh/batch-samples-bastion ec2-user@$BASTION_IP \
  "mysql -h $RDS_HOST -u admin -pYourSecurePassword123!"
```

### データベース確認

```bash
ssh -i ~/.ssh/batch-samples-bastion ec2-user@$BASTION_IP \
  "mysql -h $RDS_HOST -u admin -pYourSecurePassword123! -e 'SHOW DATABASES;'"
```

## Dockerイメージのビルド & プッシュ

### 方法1: Makefileを使用（推奨）

```bash
cd ..  # プロジェクトルートへ移動

# ECRログイン + ビルド + プッシュを一括実行
make ecr-deploy

# 個別に実行する場合
make ecr-login   # ECRにログイン
make ecr-build   # 全イメージをビルド（linux/amd64）
make ecr-push    # 全イメージをプッシュ
```

### 方法2: 手動でビルド & プッシュ

#### 1. ECRにログイン

```bash
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin $(terraform output -raw ecr_sample_batch_url | cut -d/ -f1)
```

#### 2. イメージのビルド（linux/amd64プラットフォーム指定）

**注意**: Apple Silicon (M1/M2) Macでは `--platform linux/amd64` が必須です。

```bash
cd ..  # プロジェクトルートへ移動

# sample-batch
docker build --platform linux/amd64 --target sample-batch -t sample-batch .

# retry-failed-tenants
docker build --platform linux/amd64 --target retry-failed-tenants -t retry-failed-tenants .

# run-specific-tenants
docker build --platform linux/amd64 --target run-specific-tenants -t run-specific-tenants .
```

#### 3. タグ付け & プッシュ

```bash
# sample-batch
docker tag sample-batch:latest $(cd terraform && terraform output -raw ecr_sample_batch_url):latest
docker push $(cd terraform && terraform output -raw ecr_sample_batch_url):latest

# retry-failed-tenants
docker tag retry-failed-tenants:latest $(cd terraform && terraform output -raw ecr_retry_batch_url):latest
docker push $(cd terraform && terraform output -raw ecr_retry_batch_url):latest

# run-specific-tenants
docker tag run-specific-tenants:latest $(cd terraform && terraform output -raw ecr_specific_batch_url):latest
docker push $(cd terraform && terraform output -raw ecr_specific_batch_url):latest
```

## バッチの手動実行

### Makefileを使用（推奨）

```bash
cd ..  # プロジェクトルートへ移動

# sample-batch を実行
make ecs-run-sample

# retry-failed-tenants を実行
make ecs-run-retry

# run-specific-tenants を実行（テナント指定）
make ecs-run-specific TENANTS=acme,techcorp
```

### AWS CLIを直接使用

#### sample-batch の手動実行

```bash
aws ecs run-task \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --task-definition $(terraform output -raw ecs_task_definition_sample_batch_arn) \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$(terraform output -json private_subnet_ids | jq -r '.[0]')],securityGroups=[$(terraform output -raw ecs_task_security_group_id)],assignPublicIp=DISABLED}"
```

#### retry-failed-tenants の手動実行

```bash
aws ecs run-task \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --task-definition $(terraform output -raw ecs_task_definition_retry_batch_arn) \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$(terraform output -json private_subnet_ids | jq -r '.[0]')],securityGroups=[$(terraform output -raw ecs_task_security_group_id)],assignPublicIp=DISABLED}"
```

#### run-specific-tenants の手動実行（特定テナント指定）

```bash
aws ecs run-task \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --task-definition $(terraform output -raw ecs_task_definition_specific_batch_arn) \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$(terraform output -json private_subnet_ids | jq -r '.[0]')],securityGroups=[$(terraform output -raw ecs_task_security_group_id)],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"specific-batch","command":["acme","techcorp"]}]}'
```

## AWS Batch での実行

AWS Batchを使用する場合は以下のコマンドを使用します。

### Makefileを使用（推奨）

```bash
cd ..  # プロジェクトルートへ移動

# sample-batch を実行
make batch-run-sample

# retry-failed-tenants を実行
make batch-run-retry

# run-specific-tenants を実行（テナント指定）
make batch-run-specific TENANTS=acme,techcorp

# ジョブ一覧を表示
make batch-list-jobs
```

### AWS CLIを直接使用

```bash
# sample-batch ジョブを送信
aws batch submit-job \
  --job-name "manual-sample-batch" \
  --job-queue $(terraform output -raw batch_job_queue_name) \
  --job-definition $(terraform output -raw batch_job_definition_sample_arn)

# ジョブ一覧を確認
aws batch list-jobs \
  --job-queue $(terraform output -raw batch_job_queue_name) \
  --job-status RUNNING
```

### ECS vs AWS Batch の選択

| 項目 | ECS Fargate | AWS Batch |
|------|-------------|-----------|
| セットアップ | シンプル | やや複雑 |
| ジョブキュー | なし | あり |
| 自動リトライ | なし | あり |
| 適用シーン | 小〜中規模バッチ | 大規模・長時間バッチ |
| EventBridge状態 | 有効 | 無効（手動で有効化） |

AWS Batchを使用する場合は、AWSコンソールまたはCLIでEventBridgeルールを有効化してください：
```bash
aws events enable-rule --name batch-samples-dev-batch-sample-schedule
aws events enable-rule --name batch-samples-dev-batch-retry-schedule
```

## Lambda + AWS Batch での実行

Lambdaを経由してAWS Batchを実行することで、動的なパラメータ制御が可能です。

### アーキテクチャ

```
EventBridge → Lambda → AWS Batch (run-specific-tenants)
                ↓
    tenant_codes.json から読み込み
    カンマ区切り文字列で渡す
```

### テナントリストの管理

テナントリストは `terraform/lambda/src/tenant_codes.json` で管理します：

```json
{
  "tenant_codes": [
    "acme",
    "techcorp",
    "finserv",
    "healthsys",
    "edutech"
  ]
}
```

テナントを追加・変更した場合は、Lambda を再デプロイします：
```bash
cd terraform
terraform apply
```

**スケーラビリティ**: カンマ区切り文字列形式により、**数千テナント**まで対応可能です（AWS Batch containerOverrides の 8192 文字制限を効率的に使用）。

### Makefileを使用（推奨）

```bash
cd ..  # プロジェクトルートへ移動

# tenant_codes.json のテナントを全て実行
aws lambda invoke \
  --function-name batch-samples-dev-batch-trigger \
  --payload '{}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/response.json && cat /tmp/response.json

# Lambdaのログを表示
make lambda-logs
```

### AWS CLIを直接使用

```bash
# tenant_codes.json から読み込んで実行（推奨）
aws lambda invoke \
  --function-name $(terraform output -raw lambda_batch_trigger_name) \
  --payload '{}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/response.json && cat /tmp/response.json

# イベントで上書き指定も可能
aws lambda invoke \
  --function-name $(terraform output -raw lambda_batch_trigger_name) \
  --payload '{"tenant_codes": ["acme", "techcorp"]}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/response.json && cat /tmp/response.json

# カンマ区切り文字列でも可
aws lambda invoke \
  --function-name $(terraform output -raw lambda_batch_trigger_name) \
  --payload '{"tenant_codes": "acme,techcorp,finserv"}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/response.json && cat /tmp/response.json
```

### EventBridgeによる自動実行

Lambda用のEventBridgeルールを有効化：
```bash
aws events enable-rule --name batch-samples-dev-lambda-batch-trigger
```

### ユースケース

1. **定期バッチ実行**: EventBridge で毎日特定テナントを処理
2. **API Gateway連携**: API経由でテナント指定のバッチ実行
3. **SNS/SQS連携**: メッセージ駆動でのバッチ実行
4. **Step Functions連携**: ワークフローの一部としてのバッチ実行

## Step Functions での実行

Step Functions を使用すると、複数のバッチジョブを連携させたワークフローを構築できます。

### ワークフロー

#### 1. batch-workflow（全テナント処理）
```
sample-batch → 失敗チェック → retry-failed-tenants（必要な場合）
```

#### 2. specific-tenants-workflow（指定テナント処理）
```
Lambda → AWS Batch → 完了待ち → 結果確認
```

### Makefileを使用（推奨）

```bash
cd ..  # プロジェクトルートへ移動

# 全テナントワークフローを実行
make sfn-run-workflow

# 指定テナントワークフローを実行
make sfn-run-specific TENANTS=acme,techcorp

# 実行一覧を表示
make sfn-list-executions

# ログを表示
make sfn-logs
```

### AWS CLIを直接使用

```bash
# batch-workflowを実行
aws stepfunctions start-execution \
  --state-machine-arn $(terraform output -raw step_functions_batch_workflow_arn) \
  --name "manual-execution-$(date +%Y%m%d-%H%M%S)"

# specific-tenants-workflowを実行
aws stepfunctions start-execution \
  --state-machine-arn $(terraform output -raw step_functions_specific_tenants_workflow_arn) \
  --name "manual-specific-$(date +%Y%m%d-%H%M%S)" \
  --input '{"tenant_codes": ["acme", "techcorp"]}'

# 実行状況を確認
aws stepfunctions describe-execution \
  --execution-arn <execution-arn>
```

### EventBridgeによる自動実行

Step Functions用のEventBridgeルールを有効化：
```bash
aws events enable-rule --name batch-samples-dev-sfn-batch-workflow
```

### ユースケース

1. **エラーハンドリング**: sample-batch失敗時に自動でretry-batchを実行
2. **依存関係管理**: 複数ジョブの順序制御
3. **可視化**: AWS コンソールで実行状況をグラフィカルに確認
4. **監査**: 実行履歴の保持とトレーサビリティ

## ログの確認

CloudWatch Logsでバッチの実行ログを確認できます。

### ECS用（Makefileを使用）

```bash
cd ..  # プロジェクトルートへ移動

make logs-sample    # sample-batch のログ
make logs-retry     # retry-failed-tenants のログ
make logs-specific  # run-specific-tenants のログ
```

### AWS Batch用

```bash
make batch-logs-sample    # sample-batch のログ
make batch-logs-retry     # retry-failed-tenants のログ
make batch-logs-specific  # run-specific-tenants のログ
```

### AWS CLIを直接使用

```bash
# ECS用ログ
aws logs tail /ecs/batch-samples-dev/sample-batch --follow

# AWS Batch用ログ
aws logs tail /aws/batch/batch-samples-dev/sample-batch --follow
```

## コスト試算（dev環境・ミニマム構成）

| リソース | スペック | 月額概算 (東京リージョン) |
|---------|---------|----------------------|
| RDS MySQL | db.t3.micro, 20GB | $15-20 |
| NAT Gateway | 1台 | $35-40 |
| EC2 Bastion | t3.micro | $8-10 |
| ECS Fargate | 実行時のみ課金 | $1-5 (1日2回×5分実行) |
| ECR | ストレージ | $1未満 |
| CloudWatch Logs | ログ保存 | $1-3 |
| Secrets Manager | 1シークレット | $0.40 |
| **合計** | | **約$61-80/月** |

**注意**: NAT Gatewayが最もコストがかかります。開発環境では削除するか、パブリックサブネットでの実行も検討してください。

## リソースの削除

```bash
terraform destroy
```

確認プロンプトで `yes` を入力してリソースを削除します。

**注意**:
- RDSのスナップショットは保持されません（dev環境の場合）
- ECRのイメージは削除されません（手動削除が必要）

## トラブルシューティング

### RDS接続エラー

セキュリティグループの設定を確認：
```bash
terraform output rds_security_group_id
terraform output ecs_task_security_group_id
```

### ECSタスクが起動しない

1. ECRにイメージがプッシュされているか確認
2. IAMロールに適切な権限があるか確認
3. CloudWatch Logsでエラーログを確認

### EventBridgeが実行されない

1. EventBridgeルールが有効化されているか確認
2. cronスケジュールが正しいか確認（UTC時刻）
3. IAMロールに適切な権限があるか確認

## 次のステップ

1. ✅ Terraformでインフラ構築
2. ✅ データベース初期化
3. ✅ Dockerイメージビルド & ECRプッシュ
4. ✅ バッチの手動実行テスト
5. ⏭ EventBridgeによる自動実行確認
6. ⏭ CloudWatch Alarmsの設定（エラー通知）
7. ⏭ Step Functionsの導入（高度なワークフロー制御）

## ファイル構成

```
terraform/
├── README.md                    # このファイル
├── main.tf                      # メイン設定（参照用）
├── versions.tf                  # Terraformバージョン設定
├── provider.tf                  # AWSプロバイダー設定
├── variables.tf                 # 入力変数定義
├── outputs.tf                   # 出力値定義
├── terraform.tfvars.example     # 変数設定例
├── vpc.tf                       # VPC・ネットワーク
├── security_groups.tf           # セキュリティグループ
├── rds.tf                       # RDS MySQL
├── ecr.tf                       # ECR リポジトリ
├── ecs.tf                       # ECS クラスター・タスク定義
├── iam.tf                       # IAM ロール・ポリシー
├── eventbridge.tf               # EventBridge ルール
├── cloudwatch.tf                # CloudWatch Logs
├── secrets.tf                   # Secrets Manager
├── bastion.tf                   # Bastion ホスト
├── batch.tf                     # AWS Batch
├── lambda.tf                    # Lambda + EventBridge
├── step_functions.tf            # Step Functions
└── lambda/
    └── src/
        ├── index.py             # Lambda 関数コード
        └── tenant_codes.json    # テナントコード設定
```

## Makefileコマンド一覧

プロジェクトルートのMakefileに以下のAWS関連コマンドが含まれています：

| コマンド | 説明 |
|---------|------|
| `make ecr-login` | ECRにログイン |
| `make ecr-build` | 全イメージをビルド（linux/amd64） |
| `make ecr-push` | 全イメージをECRにプッシュ |
| `make ecr-deploy` | ログイン + ビルド + プッシュを一括実行 |
| `make ecs-run-sample` | sample-batch ECSタスクを実行 |
| `make ecs-run-retry` | retry-failed-tenants ECSタスクを実行 |
| `make ecs-run-specific TENANTS=...` | 指定テナントのみ実行 |
| `make logs-sample` | sample-batch のログを表示 |
| `make logs-retry` | retry-failed-tenants のログを表示 |
| `make logs-specific` | run-specific-tenants のログを表示 |
| `make tf-init` | Terraform初期化 |
| `make tf-plan` | Terraformプラン |
| `make tf-apply` | Terraform適用 |
| `make tf-output` | Terraform出力値を表示 |
| `make aws-db-init` | RDSデータベースを初期化（Bastion経由） |
| `make batch-run-sample` | sample-batch AWS Batchジョブを実行 |
| `make batch-run-retry` | retry-failed-tenants AWS Batchジョブを実行 |
| `make batch-run-specific TENANTS=...` | 指定テナントのみAWS Batchで実行 |
| `make batch-logs-sample` | AWS Batch sample-batch のログを表示 |
| `make batch-logs-retry` | AWS Batch retry-failed-tenants のログを表示 |
| `make batch-logs-specific` | AWS Batch run-specific-tenants のログを表示 |
| `make batch-list-jobs` | AWS Batchジョブ一覧を表示 |
| `make lambda-invoke TENANTS=...` | Lambda経由で指定テナントのバッチを実行 |
| `make lambda-invoke-single TENANT=...` | Lambda経由で単一テナントのバッチを実行 |
| `make lambda-logs` | Lambda関数のログを表示 |
| `make lambda-update` | Lambda関数のコードを更新 |
| `make sfn-run-workflow` | Step Functions バッチワークフローを実行 |
| `make sfn-run-specific TENANTS=...` | Step Functions 指定テナントワークフローを実行 |
| `make sfn-list-executions` | Step Functions 実行一覧を表示 |
| `make sfn-logs` | Step Functions のログを表示 |
