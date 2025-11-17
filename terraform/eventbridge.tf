# EventBridge Rule for Sample Batch (Scheduled)
resource "aws_cloudwatch_event_rule" "sample_batch" {
  name                = "${var.project_name}-${var.environment}-sample-batch-schedule"
  description         = "Scheduled execution of sample batch job"
  schedule_expression = var.sample_batch_schedule
  state               = "ENABLED"

  tags = {
    Name = "${var.project_name}-${var.environment}-sample-batch-schedule"
  }
}

# EventBridge Target for Sample Batch
resource "aws_cloudwatch_event_target" "sample_batch" {
  rule      = aws_cloudwatch_event_rule.sample_batch.name
  target_id = "sample-batch-target"
  arn       = aws_ecs_cluster.main.arn
  role_arn  = aws_iam_role.eventbridge_ecs.arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.sample_batch.arn
    launch_type         = "FARGATE"
    platform_version    = "LATEST"

    network_configuration {
      subnets          = aws_subnet.private[*].id
      security_groups  = [aws_security_group.ecs_task.id]
      assign_public_ip = false
    }
  }
}

# EventBridge Rule for Retry Batch (Scheduled)
resource "aws_cloudwatch_event_rule" "retry_batch" {
  name                = "${var.project_name}-${var.environment}-retry-batch-schedule"
  description         = "Scheduled execution of retry batch job"
  schedule_expression = var.retry_batch_schedule
  state               = "ENABLED"

  tags = {
    Name = "${var.project_name}-${var.environment}-retry-batch-schedule"
  }
}

# EventBridge Target for Retry Batch
resource "aws_cloudwatch_event_target" "retry_batch" {
  rule      = aws_cloudwatch_event_rule.retry_batch.name
  target_id = "retry-batch-target"
  arn       = aws_ecs_cluster.main.arn
  role_arn  = aws_iam_role.eventbridge_ecs.arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.retry_batch.arn
    launch_type         = "FARGATE"
    platform_version    = "LATEST"

    network_configuration {
      subnets          = aws_subnet.private[*].id
      security_groups  = [aws_security_group.ecs_task.id]
      assign_public_ip = false
    }
  }
}

# Note: run-specific-tenants は手動実行またはAPI経由での実行を想定
# EventBridge ルールは作成しない
