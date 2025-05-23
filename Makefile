.PHONY: help install package deploy test destroy clean
.DEFAULT_GOAL := help

# Variables
AWS_REGION ?= eu-central-1
ENVIRONMENT ?= dev
PROJECT_NAME ?= ecommerce-order-processor

# Directories
SRC_DIR := src
DIST_DIR := dist
TERRAFORM_DIR := terraform
LAYER_DIR := layer

# Python settings
PYTHON_VERSION := python3.9

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install required tools
	@echo "Installing required tools..."
	@command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed. Please install it first."; exit 1; }
	@command -v terraform >/dev/null 2>&1 || { echo "Terraform is required but not installed. Please install it first."; exit 1; }
	@command -v $(PYTHON_VERSION) >/dev/null 2>&1 || { echo "$(PYTHON_VERSION) is required but not installed. Please install it first."; exit 1; }
	@echo "All required tools are installed."

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	rm -rf $(DIST_DIR)
	rm -rf $(LAYER_DIR)/python
	rm -rf $(SRC_DIR)/validator/__pycache__
	rm -rf $(SRC_DIR)/processor/__pycache__
	rm -rf $(SRC_DIR)/utils/__pycache__
	find . -name "*.pyc" -delete
	find . -name "*.pyo" -delete
	@echo "Clean completed."

package-layer: ## Package Lambda layer with dependencies
	@echo "Packaging Lambda layer..."
	mkdir -p $(DIST_DIR)
	mkdir -p $(LAYER_DIR)/python
	pip install -r $(LAYER_DIR)/requirements.txt -t $(LAYER_DIR)/python --no-cache-dir --upgrade
	cd $(LAYER_DIR) && zip -r ../$(DIST_DIR)/python_layer.zip python/
	rm -rf $(LAYER_DIR)/python
	@echo "Lambda layer packaged: $(DIST_DIR)/python_layer.zip"

package-validator: ## Package validator Lambda function
	@echo "Packaging validator Lambda function..."
	mkdir -p $(DIST_DIR)
	cd $(SRC_DIR)/validator && zip -r ../../$(DIST_DIR)/order_validator.zip . -x "__pycache__/*" "*.pyc" "requirements.txt"
	@echo "Validator function packaged: $(DIST_DIR)/order_validator.zip"

package-processor: ## Package processor Lambda function
	@echo "Packaging processor Lambda function..."
	mkdir -p $(DIST_DIR)
	cd $(SRC_DIR)/processor && zip -r ../../$(DIST_DIR)/order_processor.zip . -x "__pycache__/*" "*.pyc" "requirements.txt"
	@echo "Processor function packaged: $(DIST_DIR)/order_processor.zip"

package: clean package-layer package-validator package-processor ## Package all Lambda functions and layer
	@echo "All packages created successfully!"
	@ls -la $(DIST_DIR)

terraform-init: ## Initialize Terraform
	@echo "Initializing Terraform..."
	cd $(TERRAFORM_DIR) && terraform init

terraform-plan: terraform-init ## Plan Terraform deployment
	@echo "Planning Terraform deployment..."
	cd $(TERRAFORM_DIR) && terraform plan \
		-var="aws_region=$(AWS_REGION)" \
		-var="environment=$(ENVIRONMENT)" \
		-var="project=$(PROJECT_NAME)"

terraform-apply: ## Apply Terraform configuration
	@echo "Applying Terraform configuration..."
	cd $(TERRAFORM_DIR) && terraform apply \
		-var="aws_region=$(AWS_REGION)" \
		-var="environment=$(ENVIRONMENT)" \
		-var="project=$(PROJECT_NAME)" \
		-auto-approve

deploy: package terraform-apply ## Package and deploy everything
	@echo "Deployment completed!"
	@echo "Getting API URL..."
	@cd $(TERRAFORM_DIR) && terraform output -raw api_url

test-api: ## Test the deployed API
	@echo "Testing API..."
	@API_URL=$$(cd $(TERRAFORM_DIR) && terraform output -raw api_url 2>/dev/null); \
	if [ -z "$$API_URL" ]; then \
		echo "Error: Could not get API URL. Make sure the infrastructure is deployed."; \
		exit 1; \
	fi; \
	echo "API URL: $$API_URL"; \
	python3 -c " \
import json; \
import requests; \
api_url = '$$API_URL'; \
test_order = { \
    'customerName': 'John Doe', \
    'customerEmail': 'john.doe@example.com', \
    'items': [{ \
        'productId': 'p123', \
        'productName': 'Test Product', \
        'quantity': 1, \
        'price': 99.99 \
    }], \
    'shippingAddress': { \
        'street': '123 Main St', \
        'city': 'Anytown', \
        'postalCode': '12345', \
        'country': 'USA' \
    }, \
    'paymentMethod': 'CARD' \
}; \
response = requests.post(api_url, json=test_order); \
print(f'Status: {response.status_code}'); \
print(f'Response: {response.text}'); \
exit(0 if response.status_code == 202 else 1) \
"

logs-validator: ## Show validator Lambda logs
	@FUNCTION_NAME=$$(cd $(TERRAFORM_DIR) && terraform output -raw validator_lambda_name 2>/dev/null); \
	if [ -z "$$FUNCTION_NAME" ]; then \
		echo "Error: Could not get validator function name."; \
		exit 1; \
	fi; \
	echo "Fetching logs for $$FUNCTION_NAME..."; \
	aws logs filter-log-events \
		--log-group-name "/aws/lambda/$$FUNCTION_NAME" \
		--start-time $$(date -d '10 minutes ago' +%s)000 \
		--region $(AWS_REGION)

logs-processor: ## Show processor Lambda logs
	@FUNCTION_NAME=$$(cd $(TERRAFORM_DIR) && terraform output -raw processor_lambda_name 2>/dev/null); \
	if [ -z "$$FUNCTION_NAME" ]; then \
		echo "Error: Could not get processor function name."; \
		exit 1; \
	fi; \
	echo "Fetching logs for $$FUNCTION_NAME..."; \
	aws logs filter-log-events \
		--log-group-name "/aws/lambda/$$FUNCTION_NAME" \
		--start-time $$(date -d '10 minutes ago' +%s)000 \
		--region $(AWS_REGION)

status: ## Show deployment status
	@echo "Deployment Status:"
	@echo "=================="
	@cd $(TERRAFORM_DIR) && terraform output 2>/dev/null || echo "No deployment found"

sqs-status: ## Show SQS queue status
	@QUEUE_URL=$$(cd $(TERRAFORM_DIR) && terraform output -raw orders_queue_url 2>/dev/null); \
	if [ -z "$$QUEUE_URL" ]; then \
		echo "Error: Could not get SQS queue URL."; \
		exit 1; \
	fi; \
	echo "SQS Queue Status:"; \
	aws sqs get-queue-attributes \
		--queue-url "$$QUEUE_URL" \
		--attribute-names ApproximateNumberOfMessages,ApproximateNumberOfMessagesNotVisible \
		--region $(AWS_REGION) \
		--query 'Attributes' \
		--output table

dynamodb-scan: ## Scan DynamoDB table for orders
	@TABLE_NAME=$$(cd $(TERRAFORM_DIR) && terraform output -raw orders_table_name 2>/dev/null); \
	if [ -z "$$TABLE_NAME" ]; then \
		echo "Error: Could not get DynamoDB table name."; \
		exit 1; \
	fi; \
	echo "Scanning DynamoDB table: $$TABLE_NAME"; \
	aws dynamodb scan \
		--table-name "$$TABLE_NAME" \
		--region $(AWS_REGION) \
		--query 'Items[*].[orderId.S,customerName.S,status.S,totalAmount.N]' \
		--output table

destroy: ## Destroy all infrastructure
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		cd $(TERRAFORM_DIR) && terraform destroy \
			-var="aws_region=$(AWS_REGION)" \
			-var="environment=$(ENVIRONMENT)" \
			-var="project=$(PROJECT_NAME)" \
			-auto-approve; \
		echo "Infrastructure destroyed."; \
	else \
		echo "Destruction cancelled."; \
	fi

# Development helpers
dev-setup: install ## Setup development environment
	@echo "Setting up development environment..."
	@if [ ! -d ".git" ]; then \
		echo "Initializing git repository..."; \
		git init; \
	fi
	@echo "Development environment ready!"

validate: ## Validate all configurations
	@echo "Validating Terraform configuration..."
	@cd $(TERRAFORM_DIR) && terraform validate
	@echo "Validating Python syntax..."
	@python3 -m py_compile $(SRC_DIR)/validator/*.py
	@python3 -m py_compile $(SRC_DIR)/processor/*.py
	@python3 -m py_compile $(SRC_DIR)/utils/*.py
	@echo "All validations passed!"

# Quick commands
quick-deploy: package terraform-apply ## Quick deployment (package + deploy)
quick-test: test-api sqs-status ## Quick test (API + SQS status)
quick-logs: logs-validator logs-processor ## Show all Lambda logs