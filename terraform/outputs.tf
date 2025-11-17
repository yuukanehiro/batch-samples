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
