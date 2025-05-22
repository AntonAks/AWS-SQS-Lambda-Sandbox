provider "aws" {
  region = "eu-central-1"
}

# SQS queue for orders
resource "aws_sqs_queue" "orders_queue" {
  name                      = "orders-queue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  visibility_timeout_seconds = 60

  tags = {
    Environment = "dev"
    Project     = "e-commerce-order-processor"
  }
}

# DynamoDB table for storing the orders
resource "aws_dynamodb_table" "orders_table" {
  name           = "Orders"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "OrderId"

  attribute {
    name = "OrderId"
    type = "S"
  }

  attribute {
    name = "CustomerEmail"
    type = "S"
  }

  global_secondary_index {
    name               = "CustomerEmailIndex"
    hash_key           = "CustomerEmail"
    projection_type    = "ALL"
  }

  tags = {
    Name        = "orders-table"
    Environment = "dev"
    Project     = "e-commerce-order-processor"
  }
}

# IAM role for the lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

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

# Access policy for SQS, DynamoDB and CloudWatch logs
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_execution_policy"
  description = "Policy for Lambda functions to access SQS, DynamoDB and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.orders_queue.arn
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.orders_table.arn
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Assigning policy to the role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda function for orders validation
resource "aws_lambda_function" "order_validator" {
  filename      = "order_validator.zip"
  function_name = "order-validator"
  role          = aws_iam_role.lambda_role.arn
  handler       = "validator.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30

  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.orders_queue.url
    }
  }

  tags = {
    Environment = "dev"
    Project     = "e-commerce-order-processor"
  }
}

# Lambda function for orders processing
resource "aws_lambda_function" "order_processor" {
  filename      = "order_processor.zip"
  function_name = "order-processor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "processor.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.orders_table.name
    }
  }

  tags = {
    Environment = "dev"
    Project     = "e-commerce-order-processor"
  }
}

# Trigger for the 
# Тригер для обробника замовлень з SQS
resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  event_source_arn = aws_sqs_queue.orders_queue.arn
  function_name    = aws_lambda_function.order_processor.function_name
  batch_size       = 10
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "orders_api" {
  name        = "orders-api"
  description = "API для управління замовленнями"
}

# API Gateway ресурс
resource "aws_api_gateway_resource" "orders_resource" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  parent_id   = aws_api_gateway_rest_api.orders_api.root_resource_id
  path_part   = "orders"
}

# API Gateway метод POST
resource "aws_api_gateway_method" "orders_post" {
  rest_api_id   = aws_api_gateway_rest_api.orders_api.id
  resource_id   = aws_api_gateway_resource.orders_resource.id
  http_method   = "POST"
  authorization_type = "NONE"
}

# API Gateway інтеграція з Lambda-функцією
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.orders_api.id
  resource_id             = aws_api_gateway_resource.orders_resource.id
  http_method             = aws_api_gateway_method.orders_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.order_validator.invoke_arn
}

# Дозвіл для API Gateway викликати Lambda-функцію
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_validator.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.orders_api.execution_arn}/*/*"
}

# Розгортання API
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  stage_name  = "dev"
}

# Виведення URL API Gateway
output "api_url" {
  value = "${aws_api_gateway_deployment.api_deployment.invoke_url}/orders"
}