# =============================================================================
# AWS Batch Configuration (Fargate)
# =============================================================================

# Batch Service Role
resource "aws_iam_role" "batch_service" {
  name = "${var.project_name}-${var.environment}-batch-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "batch.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-batch-service-role"
  }
}

resource "aws_iam_role_policy_attachment" "batch_service" {
  role       = aws_iam_role.batch_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

# Batch Execution Role (for Fargate)
resource "aws_iam_role" "batch_execution" {
  name = "${var.project_name}-${var.environment}-batch-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-batch-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "batch_execution" {
  role       = aws_iam_role.batch_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECR pull policy for Batch execution role
resource "aws_iam_role_policy" "batch_execution_ecr" {
  name = "${var.project_name}-${var.environment}-batch-execution-ecr-policy"
  role = aws_iam_role.batch_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# Secrets Manager access for Batch execution role
resource "aws_iam_role_policy" "batch_execution_secrets" {
  name = "${var.project_name}-${var.environment}-batch-execution-secrets-policy"
  role = aws_iam_role.batch_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_password.arn
      }
    ]
  })
}

# Batch Job Role (for the job itself)
resource "aws_iam_role" "batch_job" {
  name = "${var.project_name}-${var.environment}-batch-job-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-batch-job-role"
  }
}

# CloudWatch Logs policy for Batch job role
resource "aws_iam_role_policy" "batch_job_cloudwatch" {
  name = "${var.project_name}-${var.environment}-batch-job-cloudwatch-policy"
  role = aws_iam_role.batch_job.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.batch_sample.arn}:*",
          "${aws_cloudwatch_log_group.batch_retry.arn}:*",
          "${aws_cloudwatch_log_group.batch_specific.arn}:*"
        ]
      }
    ]
  })
}

# =============================================================================
# CloudWatch Log Groups for AWS Batch
# =============================================================================

resource "aws_cloudwatch_log_group" "batch_sample" {
  name              = "/aws/batch/${var.project_name}-${var.environment}/sample-batch"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-batch-sample-logs"
  }
}

resource "aws_cloudwatch_log_group" "batch_retry" {
  name              = "/aws/batch/${var.project_name}-${var.environment}/retry-failed-tenants"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-batch-retry-logs"
  }
}

resource "aws_cloudwatch_log_group" "batch_specific" {
  name              = "/aws/batch/${var.project_name}-${var.environment}/run-specific-tenants"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-batch-specific-logs"
  }
}

# =============================================================================
# Compute Environment (Fargate)
# =============================================================================

resource "aws_batch_compute_environment" "fargate" {
  compute_environment_name = "${var.project_name}-${var.environment}-fargate"
  type                     = "MANAGED"
  state                    = "ENABLED"
  service_role             = aws_iam_role.batch_service.arn

  compute_resources {
    type      = "FARGATE"
    max_vcpus = 4

    subnets = aws_subnet.private[*].id

    security_group_ids = [aws_security_group.ecs_task.id]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-fargate-compute-env"
  }

  depends_on = [aws_iam_role_policy_attachment.batch_service]
}

# =============================================================================
# Job Queues
# =============================================================================

resource "aws_batch_job_queue" "main" {
  name     = "${var.project_name}-${var.environment}-job-queue"
  state    = "ENABLED"
  priority = 1

  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.fargate.arn
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-job-queue"
  }
}

# =============================================================================
# Job Definitions
# =============================================================================

resource "aws_batch_job_definition" "sample_batch" {
  name = "${var.project_name}-${var.environment}-sample-batch"
  type = "container"

  platform_capabilities = ["FARGATE"]

  container_properties = jsonencode({
    image            = "${aws_ecr_repository.sample_batch.repository_url}:latest"
    jobRoleArn       = aws_iam_role.batch_job.arn
    executionRoleArn = aws_iam_role.batch_execution.arn

    resourceRequirements = [
      {
        type  = "VCPU"
        value = "0.25"
      },
      {
        type  = "MEMORY"
        value = "512"
      }
    ]

    networkConfiguration = {
      assignPublicIp = "DISABLED"
    }

    fargatePlatformConfiguration = {
      platformVersion = "LATEST"
    }

    environment = [
      {
        name  = "ENVIRONMENT"
        value = var.environment
      },
      {
        name  = "BATCH_NAME"
        value = "sample-batch"
      },
      {
        name  = "DB_HOST"
        value = aws_db_instance.main.address
      },
      {
        name  = "DB_PORT"
        value = tostring(var.db_port)
      },
      {
        name  = "DB_USER"
        value = var.db_master_username
      },
      {
        name  = "DB_NAME"
        value = var.db_name
      }
    ]

    secrets = [
      {
        name      = "DB_PASSWORD"
        valueFrom = aws_secretsmanager_secret.db_password.arn
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.batch_sample.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "batch"
      }
    }
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-sample-batch-job-def"
  }
}

resource "aws_batch_job_definition" "retry_batch" {
  name = "${var.project_name}-${var.environment}-retry-batch"
  type = "container"

  platform_capabilities = ["FARGATE"]

  container_properties = jsonencode({
    image            = "${aws_ecr_repository.retry_batch.repository_url}:latest"
    jobRoleArn       = aws_iam_role.batch_job.arn
    executionRoleArn = aws_iam_role.batch_execution.arn

    resourceRequirements = [
      {
        type  = "VCPU"
        value = "0.25"
      },
      {
        type  = "MEMORY"
        value = "512"
      }
    ]

    networkConfiguration = {
      assignPublicIp = "DISABLED"
    }

    fargatePlatformConfiguration = {
      platformVersion = "LATEST"
    }

    environment = [
      {
        name  = "ENVIRONMENT"
        value = var.environment
      },
      {
        name  = "BATCH_NAME"
        value = "retry-failed-tenants"
      },
      {
        name  = "DB_HOST"
        value = aws_db_instance.main.address
      },
      {
        name  = "DB_PORT"
        value = tostring(var.db_port)
      },
      {
        name  = "DB_USER"
        value = var.db_master_username
      },
      {
        name  = "DB_NAME"
        value = var.db_name
      }
    ]

    secrets = [
      {
        name      = "DB_PASSWORD"
        valueFrom = aws_secretsmanager_secret.db_password.arn
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.batch_retry.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "batch"
      }
    }
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-retry-batch-job-def"
  }
}

resource "aws_batch_job_definition" "specific_batch" {
  name = "${var.project_name}-${var.environment}-specific-batch"
  type = "container"

  platform_capabilities = ["FARGATE"]

  container_properties = jsonencode({
    image            = "${aws_ecr_repository.specific_batch.repository_url}:latest"
    jobRoleArn       = aws_iam_role.batch_job.arn
    executionRoleArn = aws_iam_role.batch_execution.arn

    resourceRequirements = [
      {
        type  = "VCPU"
        value = "0.25"
      },
      {
        type  = "MEMORY"
        value = "512"
      }
    ]

    networkConfiguration = {
      assignPublicIp = "DISABLED"
    }

    fargatePlatformConfiguration = {
      platformVersion = "LATEST"
    }

    environment = [
      {
        name  = "ENVIRONMENT"
        value = var.environment
      },
      {
        name  = "BATCH_NAME"
        value = "run-specific-tenants"
      },
      {
        name  = "DB_HOST"
        value = aws_db_instance.main.address
      },
      {
        name  = "DB_PORT"
        value = tostring(var.db_port)
      },
      {
        name  = "DB_USER"
        value = var.db_master_username
      },
      {
        name  = "DB_NAME"
        value = var.db_name
      }
    ]

    secrets = [
      {
        name      = "DB_PASSWORD"
        valueFrom = aws_secretsmanager_secret.db_password.arn
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.batch_specific.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "batch"
      }
    }
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-specific-batch-job-def"
  }
}

# =============================================================================
# EventBridge Rules for AWS Batch
# =============================================================================

# IAM Role for EventBridge to submit Batch jobs
resource "aws_iam_role" "eventbridge_batch" {
  name = "${var.project_name}-${var.environment}-eventbridge-batch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-eventbridge-batch-role"
  }
}

resource "aws_iam_role_policy" "eventbridge_batch" {
  name = "${var.project_name}-${var.environment}-eventbridge-batch-policy"
  role = aws_iam_role.eventbridge_batch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "batch:SubmitJob"
        ]
        Resource = [
          aws_batch_job_definition.sample_batch.arn,
          aws_batch_job_definition.retry_batch.arn,
          aws_batch_job_queue.main.arn
        ]
      }
    ]
  })
}

# EventBridge rule for sample-batch (AWS Batch)
resource "aws_cloudwatch_event_rule" "batch_sample" {
  name                = "${var.project_name}-${var.environment}-batch-sample-schedule"
  description         = "Schedule for sample batch job (AWS Batch)"
  schedule_expression = var.sample_batch_schedule
  state               = "DISABLED"  # 初期状態は無効（ECS版と重複しないように）

  tags = {
    Name = "${var.project_name}-${var.environment}-batch-sample-schedule"
  }
}

resource "aws_cloudwatch_event_target" "batch_sample" {
  rule     = aws_cloudwatch_event_rule.batch_sample.name
  arn      = aws_batch_job_queue.main.arn
  role_arn = aws_iam_role.eventbridge_batch.arn

  batch_target {
    job_definition = aws_batch_job_definition.sample_batch.arn
    job_name       = "scheduled-sample-batch"
  }
}

# EventBridge rule for retry-batch (AWS Batch)
resource "aws_cloudwatch_event_rule" "batch_retry" {
  name                = "${var.project_name}-${var.environment}-batch-retry-schedule"
  description         = "Schedule for retry batch job (AWS Batch)"
  schedule_expression = var.retry_batch_schedule
  state               = "DISABLED"  # 初期状態は無効

  tags = {
    Name = "${var.project_name}-${var.environment}-batch-retry-schedule"
  }
}

resource "aws_cloudwatch_event_target" "batch_retry" {
  rule     = aws_cloudwatch_event_rule.batch_retry.name
  arn      = aws_batch_job_queue.main.arn
  role_arn = aws_iam_role.eventbridge_batch.arn

  batch_target {
    job_definition = aws_batch_job_definition.retry_batch.arn
    job_name       = "scheduled-retry-batch"
  }
}
