provider "aws" {
  region = "us-east-1"
}

# S3 Bucket for Context Storage
resource "aws_s3_bucket" "context_bucket" {
  bucket_prefix = "agenthandoff-context-"
}

resource "aws_s3_bucket_public_access_block" "context_bucket_pab" {
  bucket                  = aws_s3_bucket.context_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SQS Queue for Routing
resource "aws_sqs_queue" "routing_queue" {
  name                      = "AgentHandoff-RoutingQueue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 345600 # 4 days
  receive_wait_time_seconds = 0
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "agenthandoff_lambda_role"

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
}

# IAM Policy for Lambda (S3 + SQS)
resource "aws_iam_policy" "lambda_policy" {
  name        = "agenthandoff_lambda_policy"
  description = "IAM policy for AgentHandoff Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.context_bucket.arn}/*"
      },
      {
        Action = [
          "sqs:SendMessage"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.routing_queue.arn
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Package the Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda Function
resource "aws_lambda_function" "handoff_function" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "AgentHandoff-API"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handoff.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.11"

  environment {
    variables = {
      CONTEXT_BUCKET    = aws_s3_bucket.context_bucket.id
      ROUTING_QUEUE_URL = aws_sqs_queue.routing_queue.id
    }
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "agenthandoff_api" {
  name          = "AgentHandoffAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.agenthandoff_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.handoff_function.invoke_arn
}

resource "aws_apigatewayv2_route" "post_route" {
  api_id    = aws_apigatewayv2_api.agenthandoff_api.id
  route_key = "POST /handoff"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.handoff_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.agenthandoff_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.agenthandoff_api.id
  name        = "$default"
  auto_deploy = true
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.agenthandoff_api.api_endpoint
}
