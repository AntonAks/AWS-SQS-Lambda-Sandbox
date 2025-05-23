variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "ecommerce-order-processor"
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions (seconds)"
  type        = number
  default     = 30
}

variable "lambda_memory" {
  description = "Allocated memory for Lambda functions (MB)"
  type        = number
  default     = 256
}

variable "sqs_message_retention_seconds" {
  description = "SQS message retention time (seconds)"
  type        = number
  default     = 86400 # 24 hours
}

variable "sqs_visibility_timeout_seconds" {
  description = "SQS message visibility timeout (seconds)"
  type        = number
  default     = 60
}

variable "lambda_validator_zip" {
  description = "Path to ZIP archive with validator Lambda function code"
  type        = string
  default     = "../dist/order_validator.zip"
}

variable "lambda_processor_zip" {
  description = "Path to ZIP archive with processor Lambda function code"
  type        = string
  default     = "../dist/order_processor.zip"
}

variable "lambda_layer_zip" {
  description = "Path to ZIP archive with Lambda layer dependencies"
  type        = string
  default     = "../dist/python_layer.zip"
}