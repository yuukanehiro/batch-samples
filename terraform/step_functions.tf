# =============================================================================
# AWS Step Functions Configuration
# =============================================================================

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/vendedlogs/states/${var.project_name}-${var.environment}-batch-workflow"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-step-functions-logs"
  }
}

# =============================================================================
# IAM Role for Step Functions
# =============================================================================

resource "aws_iam_role" "step_functions" {
  name = "${var.project_name}-${var.environment}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-step-functions-role"
  }
}

# Step Functions policy for AWS Batch
resource "aws_iam_role_policy" "step_functions_batch" {
  name = "${var.project_name}-${var.environment}-step-functions-batch-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "batch:SubmitJob",
          "batch:DescribeJobs",
          "batch:TerminateJob"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutTargets",
          "events:PutRule",
          "events:DescribeRule"
        ]
        Resource = [
          "arn:aws:events:${var.aws_region}:*:rule/StepFunctionsGetEventsForBatchJobsRule"
        ]
      }
    ]
  })
}

# Step Functions policy for Lambda
resource "aws_iam_role_policy" "step_functions_lambda" {
  name = "${var.project_name}-${var.environment}-step-functions-lambda-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.batch_trigger.arn
        ]
      }
    ]
  })
}

# Step Functions policy for CloudWatch Logs
resource "aws_iam_role_policy" "step_functions_logs" {
  name = "${var.project_name}-${var.environment}-step-functions-logs-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutLogEvents",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# State Machine: Batch Workflow
# =============================================================================

resource "aws_sfn_state_machine" "batch_workflow" {
  name     = "${var.project_name}-${var.environment}-batch-workflow"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "Batch workflow: sample-batch -> check failures -> retry if needed"
    StartAt = "RunSampleBatch"
    States = {
      # Step 1: Run sample-batch for all tenants
      RunSampleBatch = {
        Type     = "Task"
        Resource = "arn:aws:states:::batch:submitJob.sync"
        Parameters = {
          JobName       = "sfn-sample-batch"
          JobDefinition = aws_batch_job_definition.sample_batch.arn
          JobQueue      = aws_batch_job_queue.main.arn
        }
        ResultPath = "$.sampleBatchResult"
        Next       = "CheckSampleBatchResult"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "SampleBatchFailed"
          }
        ]
      }

      # Step 2: Check if sample-batch succeeded
      CheckSampleBatchResult = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.sampleBatchResult.Container.ExitCode"
            NumericEquals = 0
            Next         = "SampleBatchSucceeded"
          }
        ]
        Default = "RunRetryBatch"
      }

      # Step 3a: Sample batch succeeded
      SampleBatchSucceeded = {
        Type = "Pass"
        Result = {
          status  = "SUCCESS"
          message = "All tenants processed successfully"
        }
        ResultPath = "$.finalResult"
        End        = true
      }

      # Step 3b: Sample batch had failures - run retry
      RunRetryBatch = {
        Type     = "Task"
        Resource = "arn:aws:states:::batch:submitJob.sync"
        Parameters = {
          JobName       = "sfn-retry-batch"
          JobDefinition = aws_batch_job_definition.retry_batch.arn
          JobQueue      = aws_batch_job_queue.main.arn
        }
        ResultPath = "$.retryBatchResult"
        Next       = "CheckRetryBatchResult"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "RetryBatchFailed"
          }
        ]
      }

      # Step 4: Check retry batch result
      CheckRetryBatchResult = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.retryBatchResult.Container.ExitCode"
            NumericEquals = 0
            Next          = "RetryBatchSucceeded"
          }
        ]
        Default = "RetryBatchFailed"
      }

      # Retry batch succeeded
      RetryBatchSucceeded = {
        Type = "Pass"
        Result = {
          status  = "SUCCESS_WITH_RETRY"
          message = "All tenants processed after retry"
        }
        ResultPath = "$.finalResult"
        End        = true
      }

      # Error states
      SampleBatchFailed = {
        Type  = "Fail"
        Error = "SampleBatchFailed"
        Cause = "Sample batch job failed"
      }

      RetryBatchFailed = {
        Type  = "Fail"
        Error = "RetryBatchFailed"
        Cause = "Retry batch job failed after sample batch failure"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-batch-workflow"
  }
}

# =============================================================================
# State Machine: Specific Tenants Workflow (Lambda経由)
# =============================================================================

resource "aws_sfn_state_machine" "specific_tenants_workflow" {
  name     = "${var.project_name}-${var.environment}-specific-tenants-workflow"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "Run batch for specific tenants via Lambda"
    StartAt = "InvokeLambda"
    States = {
      InvokeLambda = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.batch_trigger.arn
          Payload = {
            "tenant_codes.$" = "$.tenant_codes"
          }
        }
        ResultPath = "$.lambdaResult"
        Next       = "WaitForBatchJob"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "LambdaFailed"
          }
        ]
      }

      # Wait for batch job to complete
      WaitForBatchJob = {
        Type    = "Wait"
        Seconds = 30
        Next    = "CheckBatchJobStatus"
      }

      # Check batch job status
      CheckBatchJobStatus = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:batch:describeJobs"
        Parameters = {
          "Jobs.$" = "States.Array($.lambdaResult.Payload.body.jobId)"
        }
        ResultPath = "$.jobStatus"
        Next       = "EvaluateJobStatus"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "JobCheckFailed"
          }
        ]
      }

      # Evaluate job status
      EvaluateJobStatus = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.jobStatus.Jobs[0].Status"
            StringEquals = "SUCCEEDED"
            Next         = "JobSucceeded"
          },
          {
            Variable     = "$.jobStatus.Jobs[0].Status"
            StringEquals = "FAILED"
            Next         = "JobFailed"
          }
        ]
        Default = "WaitForBatchJob"
      }

      # Success state
      JobSucceeded = {
        Type = "Pass"
        Result = {
          status  = "SUCCESS"
          message = "Specific tenants batch completed successfully"
        }
        ResultPath = "$.finalResult"
        End        = true
      }

      # Error states
      LambdaFailed = {
        Type  = "Fail"
        Error = "LambdaInvocationFailed"
        Cause = "Failed to invoke Lambda function"
      }

      JobFailed = {
        Type  = "Fail"
        Error = "BatchJobFailed"
        Cause = "Batch job failed"
      }

      JobCheckFailed = {
        Type  = "Fail"
        Error = "JobCheckFailed"
        Cause = "Failed to check batch job status"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-specific-tenants-workflow"
  }
}

# =============================================================================
# EventBridge Rule for Step Functions (Optional)
# =============================================================================

resource "aws_cloudwatch_event_rule" "step_functions_batch_workflow" {
  name                = "${var.project_name}-${var.environment}-sfn-batch-workflow"
  description         = "Trigger Step Functions batch workflow"
  schedule_expression = "cron(0 5 * * ? *)"  # 毎日午前5時 UTC = 日本時間午後2時
  state               = "DISABLED"  # 初期状態は無効

  tags = {
    Name = "${var.project_name}-${var.environment}-sfn-batch-workflow"
  }
}

# IAM Role for EventBridge to start Step Functions
resource "aws_iam_role" "eventbridge_step_functions" {
  name = "${var.project_name}-${var.environment}-eventbridge-sfn-role"

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
    Name = "${var.project_name}-${var.environment}-eventbridge-sfn-role"
  }
}

resource "aws_iam_role_policy" "eventbridge_step_functions" {
  name = "${var.project_name}-${var.environment}-eventbridge-sfn-policy"
  role = aws_iam_role.eventbridge_step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = [
          aws_sfn_state_machine.batch_workflow.arn
        ]
      }
    ]
  })
}

resource "aws_cloudwatch_event_target" "step_functions_batch_workflow" {
  rule      = aws_cloudwatch_event_rule.step_functions_batch_workflow.name
  target_id = "BatchWorkflowStateMachine"
  arn       = aws_sfn_state_machine.batch_workflow.arn
  role_arn  = aws_iam_role.eventbridge_step_functions.arn
}
