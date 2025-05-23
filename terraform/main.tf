provider "aws" {
  region = var.aws_region
}

# Lambda Layer for shared dependencies
resource "aws_lambda_layer_version" "python_dependencies" {
  filename            = var.lambda_layer_zip
  layer_name          = "python-dependencies"
  compatible_runtimes = ["python3.9", "python3.10", "python3.11"]
  description         = "Python dependencies for order processing functions"

  lifecycle {
    create_before_destroy = true
  }
}

# SQS queue for orders
resource "aws_sqs_queue" "orders_queue" {
  name                      = "${var.project}-orders-queue-${var.environment}"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = var.sqs_message_retention_seconds
  receive_wait_time_seconds = 10
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# Dead Letter Queue for failed messages
resource "aws_sqs_queue" "orders_dlq" {
  name = "${var.project}-orders-dlq-${var.environment}"

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# Redrive policy for main queue to DLQ
resource "aws_sqs_queue_redrive_policy" "orders_queue_redrive" {
  queue_url = aws_sqs_queue.orders_queue.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = 3
  })
}

# DynamoDB table for storing orders
resource "aws_dynamodb_table" "orders_table" {
  name           = "${var.project}-Orders-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "orderId"

  attribute {
    name = "orderId"
    type = "S"
  }

  attribute {
    name = "customerEmail"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "CustomerEmailIndex"
    hash_key        = "customerEmail"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    projection_type = "ALL"
  }

  tags = {
    Name        = "${var.project}-orders-table-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "${var.project}-lambda-execution-role-${var.environment}"

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
    Environment = var.environment
    Project     = var.project
  }
}

# Access policy for SQS, DynamoDB and CloudWatch logs
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.project}-lambda-execution-policy-${var.environment}"
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
        Effect = "Allow"
        Resource = [
          aws_sqs_queue.orders_queue.arn,
          aws_sqs_queue.orders_dlq.arn
        ]
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect = "Allow"
        Resource = [
          aws_dynamodb_table.orders_table.arn,
          "${aws_dynamodb_table.orders_table.arn}/index/*"
        ]
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "ses:FromAddress" = "noreply@${var.project}.com"
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda function for order validation
resource "aws_lambda_function" "order_validator" {
  filename         = var.lambda_validator_zip
  function_name    = "${var.project}-order-validator-${var.environment}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_handler.lambda_handler"
  runtime         = "python3.9"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory
  layers          = [aws_lambda_layer_version.python_dependencies.arn]

  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.orders_queue.url
      ENVIRONMENT   = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy_attachment,
    aws_cloudwatch_log_group.validator_logs,
  ]

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# Lambda function for order processing
resource "aws_lambda_function" "order_processor" {
  filename         = var.lambda_processor_zip
  function_name    = "${var.project}-order-processor-${var.environment}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "processor.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60
  memory_size     = var.lambda_memory
  layers          = [aws_lambda_layer_version.python_dependencies.arn]

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.orders_table.name
      ENVIRONMENT    = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy_attachment,
    aws_cloudwatch_log_group.processor_logs,
  ]

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "validator_logs" {
  name              = "/aws/lambda/${var.project}-order-validator-${var.environment}"
  retention_in_days = 14

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_cloudwatch_log_group" "processor_logs" {
  name              = "/aws/lambda/${var.project}-order-processor-${var.environment}"
  retention_in_days = 14

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# SQS trigger for order processor
resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  event_source_arn = aws_sqs_queue.orders_queue.arn
  function_name    = aws_lambda_function.order_processor.function_name
  batch_size       = 10
  maximum_batching_window_in_seconds = 5
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "orders_api" {
  name        = "${var.project}-orders-api-${var.environment}"
  description = "API for order management"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# API Gateway resource
resource "aws_api_gateway_resource" "orders_resource" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  parent_id   = aws_api_gateway_rest_api.orders_api.root_resource_id
  path_part   = "orders"
}

# API Gateway POST method
resource "aws_api_gateway_method" "orders_post" {
  rest_api_id   = aws_api_gateway_rest_api.orders_api.id
  resource_id   = aws_api_gateway_resource.orders_resource.id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.validator.id
  request_models = {
    "application/json" = aws_api_gateway_model.order_model.name
  }
}

# API Gateway OPTIONS method for CORS
resource "aws_api_gateway_method" "orders_options" {
  rest_api_id   = aws_api_gateway_rest_api.orders_api.id
  resource_id   = aws_api_gateway_resource.orders_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# CORS integration for OPTIONS
resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  resource_id = aws_api_gateway_resource.orders_resource.id
  http_method = aws_api_gateway_method.orders_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# CORS response for OPTIONS
resource "aws_api_gateway_method_response" "options_response" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  resource_id = aws_api_gateway_resource.orders_resource.id
  http_method = aws_api_gateway_method.orders_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  resource_id = aws_api_gateway_resource.orders_resource.id
  http_method = aws_api_gateway_method.orders_options.http_method
  status_code = aws_api_gateway_method_response.options_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Request validator
resource "aws_api_gateway_request_validator" "validator" {
  name                        = "request-validator"
  rest_api_id                 = aws_api_gateway_rest_api.orders_api.id
  validate_request_body       = true
  validate_request_parameters = false
}

# Request model for validation
resource "aws_api_gateway_model" "order_model" {
  rest_api_id  = aws_api_gateway_rest_api.orders_api.id
  name         = "OrderModel"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Order Schema"
    type      = "object"
    required  = ["customerName", "customerEmail", "items", "shippingAddress"]
    properties = {
      customerName = {
        type = "string"
        minLength = 1
      }
      customerEmail = {
        type = "string"
        pattern = "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"
      }
      items = {
        type = "array"
        minItems = 1
        items = {
          type = "object"
          required = ["productId", "quantity", "price"]
          properties = {
            productId = {
              type = "string"
              minLength = 1
            }
            quantity = {
              type = "integer"
              minimum = 1
            }
            price = {
              type = "number"
              minimum = 0
            }
          }
        }
      }
      shippingAddress = {
        type = "object"
        required = ["street", "city", "postalCode", "country"]
        properties = {
          street = { type = "string", minLength = 1 }
          city = { type = "string", minLength = 1 }
          postalCode = { type = "string", minLength = 1 }
          country = { type = "string", minLength = 1 }
        }
      }
    }
  })
}

# API Gateway integration with Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.orders_api.id
  resource_id             = aws_api_gateway_resource.orders_resource.id
  http_method             = aws_api_gateway_method.orders_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.order_validator.invoke_arn
}

# Method response for POST
resource "aws_api_gateway_method_response" "post_response" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  resource_id = aws_api_gateway_resource.orders_resource.id
  http_method = aws_api_gateway_method.orders_post.http_method
  status_code = "202"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Permission for API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_validator.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.orders_api.execution_arn}/*/*"
}

# API deployment (without deprecated stage_name)
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.options_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.orders_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.orders_resource.id,
      aws_api_gateway_method.orders_post.id,
      aws_api_gateway_method.orders_options.id,
      aws_api_gateway_integration.lambda_integration.id,
      aws_api_gateway_integration.options_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway stage (replaces deprecated stage_name in deployment)
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.orders_api.id
  stage_name    = var.environment

  # Enable CloudWatch logging
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# CloudWatch log group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.project}-orders-api-${var.environment}"
  retention_in_days = 14

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}