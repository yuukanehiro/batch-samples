# CloudWatch Log Groups for ECS Tasks
resource "aws_cloudwatch_log_group" "sample_batch" {
  name              = "/ecs/${var.project_name}-${var.environment}/sample-batch"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-sample-batch-logs"
  }
}

resource "aws_cloudwatch_log_group" "retry_batch" {
  name              = "/ecs/${var.project_name}-${var.environment}/retry-failed-tenants"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-retry-batch-logs"
  }
}

resource "aws_cloudwatch_log_group" "specific_batch" {
  name              = "/ecs/${var.project_name}-${var.environment}/run-specific-tenants"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-specific-batch-logs"
  }
}
