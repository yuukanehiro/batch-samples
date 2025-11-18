# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "RDS address"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDS port"
  value       = aws_db_instance.main.port
}

# ECR Outputs
output "ecr_sample_batch_url" {
  description = "ECR repository URL for sample batch"
  value       = aws_ecr_repository.sample_batch.repository_url
}

output "ecr_retry_batch_url" {
  description = "ECR repository URL for retry batch"
  value       = aws_ecr_repository.retry_batch.repository_url
}

output "ecr_specific_batch_url" {
  description = "ECR repository URL for run-specific-tenants batch"
  value       = aws_ecr_repository.specific_batch.repository_url
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_task_definition_sample_batch_arn" {
  description = "ECS task definition ARN for sample batch"
  value       = aws_ecs_task_definition.sample_batch.arn
}

output "ecs_task_definition_retry_batch_arn" {
  description = "ECS task definition ARN for retry batch"
  value       = aws_ecs_task_definition.retry_batch.arn
}

output "ecs_task_definition_specific_batch_arn" {
  description = "ECS task definition ARN for run-specific-tenants batch"
  value       = aws_ecs_task_definition.specific_batch.arn
}

# CloudWatch Outputs
output "cloudwatch_log_group_sample_batch" {
  description = "CloudWatch log group name for sample batch"
  value       = aws_cloudwatch_log_group.sample_batch.name
}

output "cloudwatch_log_group_retry_batch" {
  description = "CloudWatch log group name for retry batch"
  value       = aws_cloudwatch_log_group.retry_batch.name
}

output "cloudwatch_log_group_specific_batch" {
  description = "CloudWatch log group name for run-specific-tenants batch"
  value       = aws_cloudwatch_log_group.specific_batch.name
}

# Security Group Outputs
output "ecs_task_security_group_id" {
  description = "ECS task security group ID"
  value       = aws_security_group.ecs_task.id
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

# AWS Batch Outputs
output "batch_compute_environment_arn" {
  description = "AWS Batch compute environment ARN"
  value       = aws_batch_compute_environment.fargate.arn
}

output "batch_job_queue_arn" {
  description = "AWS Batch job queue ARN"
  value       = aws_batch_job_queue.main.arn
}

output "batch_job_queue_name" {
  description = "AWS Batch job queue name"
  value       = aws_batch_job_queue.main.name
}

output "batch_job_definition_sample_arn" {
  description = "AWS Batch job definition ARN for sample batch"
  value       = aws_batch_job_definition.sample_batch.arn
}

output "batch_job_definition_retry_arn" {
  description = "AWS Batch job definition ARN for retry batch"
  value       = aws_batch_job_definition.retry_batch.arn
}

output "batch_job_definition_specific_arn" {
  description = "AWS Batch job definition ARN for specific batch"
  value       = aws_batch_job_definition.specific_batch.arn
}

output "cloudwatch_log_group_batch_sample" {
  description = "CloudWatch log group name for AWS Batch sample"
  value       = aws_cloudwatch_log_group.batch_sample.name
}

output "cloudwatch_log_group_batch_retry" {
  description = "CloudWatch log group name for AWS Batch retry"
  value       = aws_cloudwatch_log_group.batch_retry.name
}

output "cloudwatch_log_group_batch_specific" {
  description = "CloudWatch log group name for AWS Batch specific"
  value       = aws_cloudwatch_log_group.batch_specific.name
}

# Lambda Outputs
output "lambda_batch_trigger_arn" {
  description = "Lambda function ARN for batch trigger"
  value       = aws_lambda_function.batch_trigger.arn
}

output "lambda_batch_trigger_name" {
  description = "Lambda function name for batch trigger"
  value       = aws_lambda_function.batch_trigger.function_name
}

output "cloudwatch_log_group_lambda_batch_trigger" {
  description = "CloudWatch log group name for Lambda batch trigger"
  value       = aws_cloudwatch_log_group.lambda_batch_trigger.name
}
