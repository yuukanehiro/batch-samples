# Batch Samples

バッチ処理のサンプル実装プロジェクト。クリーンアーキテクチャに基づいた構造で、マルチテナント対応、AWS上でのバッチ実行を想定しています。

## アーキテクチャ提案

### 現在
- ECS(Fargate) in Cron

### 提案
- EventBridge + ECS(Fargate)
- EventBridge + AWS Batch(Fargate)
- EventBridge + Lambda + AWS Batch(Fargate)
- EventBridge + StepFunctions(BatchA->失敗していた場合リカバリのBatchB->それでも失敗した処理がある場合はSlack通知)

## プロジェクト構造

```
.
├── cmd/
│   └── cronjob/
│       └── sample-batch/          # バッチのエントリーポイント
│           └── main.go
├── app/
│   ├── domain/
│   │   └── entities/              # ドメインエンティティ
│   │       └── job_status.go
│   ├── usecases/
│   │   ├── port/                  # インターフェース定義
│   │   │   ├── logger.go
│   │   │   └── tracer.go
│   │   └── cronjob/
│   │       └── interactors/       # ビジネスロジック層
│   │           └── sample_job.go
│   ├── interface-adapters/
│   │   └── cronjob/
│   │       └── handlers/          # ハンドラー層
│   │           └── sample_handler.go
│   └── frameworks/                # インフラ層
│       ├── logger/
│       │   └── logger.go
│       └── tracer/
│           └── tracer.go
├── config/                        # 設定
│   └── config.go
└── go.mod
```

## 実装の特徴

- **マルチテナント対応**: 事業者ごとに独立したDB（1_acme, 2_techcorp, 3_finserv, 4_healthsys, 5_edutech）
- **共通DB（0_general）**: テナント情報とジョブ実行履歴を一元管理
- **ジョブ実行ログ**: 全てのジョブ実行履歴を記録（成功/失敗/エラーメッセージ）
- **自動リトライ機能**: 失敗したテナントのみを再実行するバッチを提供
- **並行処理**: CPU数に基づくワーカープール（最小2、最大10）で各テナントを並行処理
- **クリーンアーキテクチャ**: 依存関係の方向を制御し、テスタビリティを向上
- **グレースフルシャットダウン**: SIGINT/SIGTERM シグナルに対応
- **コンテキスト管理**: タイムアウト制御とキャンセル処理
- **構造化ログ**: 標準的なログレベル（INFO/WARN/ERROR）
- **トレーシング対応**: Datadog等のAPMツールと統合可能な設計
- **エラーハンドリング**: 1つのテナントで失敗しても他のテナントは処理を継続

## データベース構成

### 共通DB（0_general）
テナント情報とジョブ実行履歴を一元管理します。

- **tenants**: テナントマスターテーブル
- **job_execution_logs**: 全テナントのジョブ実行履歴

### テナント別DB
このプロジェクトでは、以下の5つのテナントをサンプルとして定義しています：

| ID | Code | Name | DB Name |
|----|------|------|---------|
| 1 | acme | Acme Corporation | 1_acme |
| 2 | techcorp | Tech Corp | 2_techcorp |
| 3 | finserv | Financial Services Inc | 3_finserv |
| 4 | healthsys | Health Systems Ltd | 4_healthsys |
| 5 | edutech | Education Technology Group | 5_edutech |

各テナントは独立したMySQLデータベースを持ち、バッチ処理は並行して実行されます。

## クイックスタート（Makeコマンド）

```bash
# ヘルプを表示
make help

# 初期セットアップ（DB起動 + ビルド）
make setup

# 開発用（DB起動 + ビルド + 実行）
make dev

# ビルドのみ
make build

# 実行のみ（DB起動済みを想定）
make run
```

## セットアップ（手動）

### 1. 環境変数の設定

```bash
cp .env.example .env
# 必要に応じて .env を編集
```

### 2. MySQLの起動

```bash
# Makeコマンドを使う場合
make db-up

# または docker-compose を直接使う場合
docker-compose up -d

# ログの確認
make db-logs
# または
docker-compose logs -f mysql

# DBの確認
make db-show
# または
docker-compose exec mysql mysql -uroot -ppassword -e "SHOW DATABASES;"
```

## ビルド & 実行

### Makeコマンドを使う場合（推奨）

```bash
# ビルド
make build

# 実行（MySQLが起動している必要があります）
make run

# DB起動 + ビルド + 実行を一度に
make dev
```

### 手動でビルド・実行する場合

```bash
# ビルド
go build -o sample-batch ./cmd/cronjob/sample-batch

# 実行（MySQLが起動している必要があります）
./sample-batch

# 環境変数での設定
DB_HOST=localhost DB_PORT=3306 DB_USER=root DB_PASSWORD=password ./sample-batch
```

### Dockerでの実行

```bash
# Makeコマンドを使う場合（推奨）
# イメージのビルド
make docker-build

# コンテナの実行（macOS）
make docker-run

# コンテナの実行（Linux）
make docker-run-linux

# 手動でビルド・実行する場合
# イメージのビルド
docker build -t batch-samples:latest .

# コンテナの実行（ホストのMySQLに接続）
# macOSの場合: host.docker.internal を使用
docker run --rm \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=3306 \
  -e DB_USER=root \
  -e DB_PASSWORD=password \
  batch-samples:latest

# Linuxの場合: --network host を使用
docker run --rm --network host \
  -e DB_HOST=localhost \
  -e DB_PORT=3306 \
  -e DB_USER=root \
  -e DB_PASSWORD=password \
  batch-samples:latest
```

## データベース管理

```bash
# MySQLを起動
make db-up

# MySQLを停止
make db-down

# MySQLのログを表示
make db-logs

# MySQLに接続
make db-shell

# 全DBを表示
make db-show

# 各テナントのデータを確認
make db-check

# DBをリセット（全データ削除 + 再初期化）
make db-reset
```

## 利用可能なMakeコマンド一覧

```bash
make help              # ヘルプを表示
make build             # アプリケーションをビルド
make run               # アプリケーションを実行
make build-retry       # リトライバッチをビルド
make run-retry         # 失敗したテナントを再実行
make build-specific    # 指定テナント実行バッチをビルド
make run-specific      # 指定したテナントのみ実行
make test              # テストを実行
make clean             # ビルド成果物を削除

make docker-build      # Dockerイメージをビルド
make docker-run        # Dockerコンテナで実行（macOS）
make docker-run-linux  # Dockerコンテナで実行（Linux）

make db-up             # MySQLを起動
make db-down           # MySQLを停止
make db-logs           # MySQLのログを表示
make db-shell          # MySQLに接続
make db-show           # 全DBを表示
make db-check          # 各テナントのデータを確認
make db-reset          # DBをリセット

make setup             # 初期セットアップ（DB起動 + ビルド）
make dev               # 開発用（DB起動 + ビルド + 実行）
make all               # フルビルド（クリーン + ビルド + テスト）
```

## ジョブ実行ログの確認

全てのジョブ実行履歴は `0_general` データベースの `job_execution_logs` テーブルに保存されます。

```bash
# ジョブ実行履歴を確認
docker-compose exec mysql mysql -uroot -ppassword -e \
  "USE 0_general; SELECT id, job_name, tenant_code, status, started_at, error_message FROM job_execution_logs ORDER BY id DESC LIMIT 20;"

# 失敗したジョブのみを確認
docker-compose exec mysql mysql -uroot -ppassword -e \
  "USE 0_general; SELECT * FROM job_execution_logs WHERE status = 'failed' ORDER BY started_at DESC;"
```

## リトライバッチの使い方

失敗したテナントのみを再実行するバッチが用意されています。

```bash
# 過去24時間以内に失敗したテナントを再実行
make run-retry

# または直接実行
./retry-failed-tenants
```

### リトライバッチの仕組み

1. `0_general.job_execution_logs` から過去24時間以内に失敗したテナントを取得
2. 失敗したテナントのみを並行処理で再実行
3. 再実行の結果も `job_execution_logs` に記録

### ワークフロー例（Step Functions）

```
sample-job (全テナント実行)
  ↓ 失敗したテナントがある場合
retry-failed-tenants (失敗したテナントのみ再実行)
  ↓ それでも失敗したテナントがある場合
Slack通知
```

## 指定テナントの実行

特定のテナントのみを実行するバッチが用意されています。

```bash
# Makeコマンドを使う場合
make run-specific TENANTS=acme,techcorp

# または直接実行
./run-specific-tenants acme techcorp

# 環境変数で指定することも可能
TENANTS=acme,techcorp ./run-specific-tenants
```

### 指定テナント実行バッチの仕組み

1. コマンドライン引数または環境変数からテナントコードを取得
2. 指定されたテナントのみのDBSetを作成
3. 指定されたテナントのみを並行処理で実行
4. 実行結果を `job_execution_logs` に記録（job_name: "run-specific-tenants"）

### 使用例

```bash
# 1つのテナントのみ実行
make run-specific TENANTS=acme

# 複数のテナントを実行（カンマ区切り）
make run-specific TENANTS=acme,techcorp,finserv

# 直接実行する場合（スペース区切り）
./run-specific-tenants acme techcorp finserv

# 環境変数で指定
TENANTS=acme,techcorp ./run-specific-tenants
```

## 動作確認

バッチが正常に動作すると、以下のようなログが出力されます：

```
[INFO] Starting Sample Batch Job Service (Multi-Tenant)
[INFO] Environment: development, Batch Name: sample-batch
[INFO] DB Config: Host=localhost, Port=3306, User=root
[INFO] Initializing database connections for all tenants...
[INFO] Database connections initialized for 5 tenants
[INFO] Starting sample job handler...
[INFO] Executing scheduled sample job...
[INFO] executeJob: Starting sample job execution for all tenants (concurrent mode)
[INFO] executeJob: Max workers = 10 (CPU cores = 5)
[INFO] [Tenant 1] Processing job for tenant: Acme Corporation (ID: 1, DB: 1_acme)
[INFO] [Tenant 2] Processing job for tenant: Tech Corp (ID: 2, DB: 2_techcorp)
[INFO] [Tenant 3] Processing job for tenant: Financial Services Inc (ID: 3, DB: 3_finserv)
[INFO] [Tenant 4] Processing job for tenant: Health Systems Ltd (ID: 4, DB: 4_healthsys)
[INFO] [Tenant 5] Processing job for tenant: Education Technology Group (ID: 5, DB: 5_edutech)
...
[INFO] executeJob: Finished processing all tenants (Total: 5, Success: 5, Error: 0)
[INFO] Sample job completed successfully
```

## 新しいバッチの追加方法

1. `cmd/cronjob/your-batch/main.go` を作成
2. `app/interface-adapters/cronjob/handlers/` にハンドラーを追加
3. `app/usecases/cronjob/interactors/` にビジネスロジックを実装
4. 必要に応じて `app/domain/entities/` にエンティティを追加

## AWS デプロイ

このバッチは以下の方法でAWS上にデプロイ可能です：

1. **ECS Fargate + EventBridge**
   - Dockerイメージをビルドし、ECRにpush
   - ECS Task Definitionを作成
   - EventBridgeでスケジュール実行

2. **AWS Batch + EventBridge**
   - Job Definitionを作成
   - Compute Environmentを設定
   - EventBridgeでトリガー

3. **Step Functions**
   - 複数バッチの連携実行
   - エラーハンドリングとリトライ
   - Slack通知の統合