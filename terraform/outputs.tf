output "api_url" {
  description = "API Gateway endpoint URL for creating orders"
  value       = "${aws_api_gateway_deployment.api_deployment.invoke_url}/${aws_api_gateway_resource.orders_resource.path_part}"
}

output "api_base_url" {
  description = "API Gateway base URL"
  value       = aws_api_gateway_deployment.api_deployment.invoke_url
}

output "orders_queue_url" {
  description = "SQS queue URL for orders"
  value       = aws_sqs_queue.orders_queue.url
}

output "orders_dlq_url" {
  description = "SQS dead letter queue URL"
  value       = aws_sqs_queue.orders_dlq.url
}

output "orders_table_name" {
  description = "DynamoDB table name for orders"
  value       = aws_dynamodb_table.orders_table.name
}

output "validator_lambda_name" {
  description = "Order validator Lambda function name"
  value       = aws_lambda_function.order_validator.function_name
}

output "processor_lambda_name" {
  description = "Order processor Lambda function name"
  value       = aws_lambda_function.order_processor.function_name
}

output "lambda_layer_arn" {
  description = "Lambda layer ARN"
  value       = aws_lambda_layer_version.python_dependencies.arn
}

output "aws_region" {
  description = "AWS deployment region"
  value       = var.aws_region
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_api_gateway_rest_api.orders_api.id
}

output "deployment_environment" {
  description = "Deployment environment"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project
}