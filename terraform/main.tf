# Main Terraform Configuration
# このファイルは各リソースモジュールの参照用です
# 実際のリソース定義は個別のファイルに分割されています

# リソース構成:
# - vpc.tf: VPC、サブネット、ルートテーブル
# - security_groups.tf: セキュリティグループ
# - rds.tf: RDS MySQL インスタンス
# - ecr.tf: ECR リポジトリ
# - ecs.tf: ECS クラスター、タスク定義
# - iam.tf: IAM ロール、ポリシー
# - eventbridge.tf: EventBridge ルール
# - cloudwatch.tf: CloudWatch ロググループ
# - secrets.tf: Secrets Manager
# - variables.tf: 入力変数
# - outputs.tf: 出力値
