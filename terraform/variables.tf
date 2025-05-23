variable "aws_region" {
  description = "AWS регіон для розгортання"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Середовище розгортання (dev, prod)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Назва проекту"
  type        = string
  default     = "e-commerce-order-processor"
}

variable "lambda_timeout" {
  description = "Таймаут для Lambda функцій (секунди)"
  type        = number
  default     = 30
}

variable "lambda_memory" {
  description = "Виділена пам'ять для Lambda функцій (МБ)"
  type        = number
  default     = 256
}

variable "sqs_message_retention_seconds" {
  description = "Час зберігання повідомлень в SQS черзі (секунди)"
  type        = number
  default     = 86400 # 24 години
}

variable "sqs_visibility_timeout_seconds" {
  description = "Час видимості повідомлень в SQS черзі (секунди)"
  type        = number
  default     = 60
}

variable "lambda_validator_zip" {
  description = "Шлях до ZIP архіву з кодом Lambda функції для валідації"
  type        = string
  default     = "../dist/order_validator.zip"
}

variable "lambda_processor_zip" {
  description = "Шлях до ZIP архіву з кодом Lambda функції для обробки"
  type        = string
  default     = "../dist/order_processor.zip"
}