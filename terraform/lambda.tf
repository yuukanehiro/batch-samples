# =============================================================================
# EventBridge + Lambda + AWS Batch Configuration
# =============================================================================

# Lambda用のCloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_batch_trigger" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-batch-trigger"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-batch-trigger-logs"
  }
}

# =============================================================================
# Lambda IAM Role
# =============================================================================

resource "aws_iam_role" "lambda_batch_trigger" {
  name = "${var.project_name}-${var.environment}-lambda-batch-trigger-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-batch-trigger-role"
  }
}

# Lambda基本実行ポリシー（CloudWatch Logs）
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_batch_trigger.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# AWS Batch SubmitJobポリシー
resource "aws_iam_role_policy" "lambda_batch_submit" {
  name = "${var.project_name}-${var.environment}-lambda-batch-submit-policy"
  role = aws_iam_role.lambda_batch_trigger.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "batch:SubmitJob",
          "batch:DescribeJobs",
          "batch:ListJobs"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# Lambda Function
# =============================================================================

data "archive_file" "batch_trigger" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/src"
  output_path = "${path.module}/lambda/batch_trigger.zip"
}

resource "aws_lambda_function" "batch_trigger" {
  function_name    = "${var.project_name}-${var.environment}-batch-trigger"
  role             = aws_iam_role.lambda_batch_trigger.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 128
  filename         = data.archive_file.batch_trigger.output_path
  source_code_hash = data.archive_file.batch_trigger.output_base64sha256

  environment {
    variables = {
      BATCH_JOB_QUEUE      = aws_batch_job_queue.main.name
      BATCH_JOB_DEFINITION = aws_batch_job_definition.specific_batch.arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_batch_trigger,
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-batch-trigger"
  }
}

# =============================================================================
# EventBridge Rule for Lambda Trigger
# =============================================================================

# 手動実行用（スケジュールなし）- API Gateway/CLIから直接呼び出し用
# 必要に応じてスケジュール設定を有効化

# スケジュール実行用のEventBridgeルール（例：毎日特定テナントを処理）
resource "aws_cloudwatch_event_rule" "lambda_batch_trigger" {
  name                = "${var.project_name}-${var.environment}-lambda-batch-trigger"
  description         = "Trigger Lambda to run specific tenant batch job"
  schedule_expression = "cron(0 4 * * ? *)"  # 毎日午前4時 UTC = 日本時間午後1時
  state               = "DISABLED"  # 初期状態は無効

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-batch-trigger"
  }
}

resource "aws_cloudwatch_event_target" "lambda_batch_trigger" {
  rule      = aws_cloudwatch_event_rule.lambda_batch_trigger.name
  target_id = "BatchTriggerLambda"
  arn       = aws_lambda_function.batch_trigger.arn

  # 空のイベントを渡す（Lambdaはtenant_codes.jsonから読み込む）
  input = jsonencode({})
}

# LambdaにEventBridgeからの呼び出しを許可
resource "aws_lambda_permission" "eventbridge_batch_trigger" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.batch_trigger.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_batch_trigger.arn
}

