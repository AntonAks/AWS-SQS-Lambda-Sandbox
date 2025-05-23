output "api_url" {
  description = "URL ендпоінту API Gateway для створення замовлень"
  value       = "${aws_api_gateway_deployment.api_deployment.invoke_url}/${aws_api_gateway_resource.orders_resource.path_part}"
}

output "orders_queue_url" {
  description = "URL черги SQS для замовлень"
  value       = aws_sqs_queue.orders_queue.url
}

output "orders_table_name" {
  description = "Назва таблиці DynamoDB для замовлень"
  value       = aws_dynamodb_table.orders_table.name
}

output "validator_lambda_name" {
  description = "Назва Lambda функції для валідації замовлень"
  value       = aws_lambda_function.order_validator.function_name
}

output "processor_lambda_name" {
  description = "Назва Lambda функції для обробки замовлень"
  value       = aws_lambda_function.order_processor.function_name
}

output "aws_region" {
  description = "AWS регіон розгортання"
  value       = var.aws_region
}

output "api_gateway_id" {
  description = "ID API Gateway"
  value       = aws_api_gateway_rest_api.orders_api.id
}

output "deployment_environment" {
  description = "Середовище розгортання"
  value       = var.environment
}