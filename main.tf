# AWS provider configuration for LocalStack
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    apigateway     = "http://localhost:4566"
    cloudformation = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    es             = "http://localhost:4566"
    firehose       = "http://localhost:4566"
    iam            = "http://localhost:4566"
    kinesis        = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    route53        = "http://localhost:4566"
    redshift       = "http://localhost:4566"
    s3             = "http://s3.localhost.localstack.cloud:4566"
    secretsmanager = "http://localhost:4566"
    ses            = "http://localhost:4566"
    sns            = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    ssm            = "http://localhost:4566"
    stepfunctions  = "http://localhost:4566"
    sts            = "http://localhost:4566"
    elb            = "http://localhost:4566"
    elbv2          = "http://localhost:4566"
    rds            = "http://localhost:4566"
    autoscaling    = "http://localhost:4566"
    events         = "http://localhost:4566"
  }
}

# S3 Bucket: The target resource for auto-remediation monitoring
resource "aws_s3_bucket" "remediation_target" {
  bucket = "auto-remediation-target-bucket"

  tags = {
    Name        = "auto-remediation-target-bucket"
    Environment = "Lab"
  }
}

# IAM Role: Identity for the remediation Lambda function
resource "aws_iam_role" "remediation_lambda_role" {
  name = "auto-remediation-lambda-role"

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
    Name        = "auto-remediation-lambda-role"
    Environment = "Lab"
  }
}

# IAM Policy: Permissions for S3 remediation and CloudWatch logging
resource "aws_iam_role_policy" "remediation_lambda_policy" {
  name = "auto-remediation-lambda-policy"
  role = aws_iam_role.remediation_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketAcl",
          "s3:PutBucketAcl"
        ]
        Resource = aws_s3_bucket.remediation_target.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda Function: The core of the auto-remediation system
resource "aws_lambda_function" "remediation_lambda" {
  filename      = "remediation.zip"
  function_name = "s3-remediation-function"
  role          = aws_iam_role.remediation_lambda_role.arn
  handler       = "remediation.handler"
  runtime       = "python3.9"

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.remediation_target.id
    }
  }

  tags = {
    Name        = "s3-remediation-function"
    Environment = "Lab"
  }
}

# EventBridge Rule: The trigger for our auto-remediation workflow
resource "aws_cloudwatch_event_rule" "s3_misconfig_rule" {
  name        = "s3-misconfig-rule"
  description = "Triggered when an S3 bucket configuration changes"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail_type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["s3.amazonaws.com"]
      eventName   = ["PutBucketAcl"]
    }
  })

  tags = {
    Name        = "s3-misconfig-rule"
    Environment = "Lab"
  }
}

# EventBridge Target: Connects the rule to our Lambda function
resource "aws_cloudwatch_event_target" "remediation_target" {
  rule      = aws_cloudwatch_event_rule.s3_misconfig_rule.name
  target_id = "remediate-s3-public-access"
  arn       = aws_lambda_function.remediation_lambda.arn
}

# Lambda Permission: Allows EventBridge to invoke the remediation function
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediation_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_misconfig_rule.arn
}

# Outputs: Key identifiers for testing the auto-remediation workflow
output "s3_bucket_name" {
  value = aws_s3_bucket.remediation_target.id
}

output "lambda_function_name" {
  value = aws_lambda_function.remediation_lambda.function_name
}
