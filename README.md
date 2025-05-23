# E-commerce Order Processing System

A serverless order processing system built with AWS Lambda, SQS, DynamoDB, and API Gateway, managed with Terraform.

## Architecture

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Client     │───▶│ API Gateway  │───▶│ Lambda      │───▶│ SQS Queue   │───▶│ Lambda      │
│ Application │    │              │    │ (Validator) │    │             │    │ (Processor) │
└─────────────┘    └──────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                                      │
                                                                                      ▼
                                                                              ┌─────────────┐
                                                                              │ DynamoDB    │
                                                                              │ Table       │
                                                                              └─────────────┘
```

### Components

- **API Gateway**: Accepts HTTP requests from clients
- **Lambda Validator**: Validates order data and sends to SQS
- **SQS Queue**: Stores valid orders for asynchronous processing
- **Lambda Processor**: Processes orders from queue and stores in DynamoDB
- **DynamoDB**: Stores order data
- **Lambda Layer**: Shared dependencies for all functions

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Python 3.9+
- Make

## Quick Start

1. **Setup and deploy everything:**
   ```bash
   make deploy
   ```

2. **Test the API:**
   ```bash
   make test-api
   ```

3. **Check status:**
   ```bash
   make status
   ```

4. **Clean up when done:**
   ```bash
   make destroy
   ```

## Detailed Usage

### Available Commands

```bash
make help                 # Show all available commands
make install             # Install required tools
make validate            # Validate configurations
make package             # Package all Lambda functions
make deploy              # Deploy infrastructure
make test-api            # Test the deployed API
make logs-validator      # Show validator Lambda logs
make logs-processor      # Show processor Lambda logs
make sqs-status          # Show SQS queue status
make dynamodb-scan       # Scan DynamoDB for orders
make destroy             # Destroy all infrastructure
```

### Environment Variables

You can customize the deployment by setting these variables:

```bash
export AWS_REGION=us-east-1
export ENVIRONMENT=prod
export PROJECT_NAME=my-order-system
make deploy
```

### Manual Deployment Steps

If you prefer manual control:

1. **Package Lambda functions:**
   ```bash
   make package
   ```

2. **Initialize Terraform:**
   ```bash
   make terraform-init
   ```

3. **Plan deployment:**
   ```bash
   make terraform-plan
   ```

4. **Apply changes:**
   ```bash
   make terraform-apply
   ```

## API Usage

### Create Order

**Endpoint:** `POST /orders`

**Request Body:**
```json
{
  "customerName": "John Doe",
  "customerEmail": "john.doe@example.com",
  "items": [
    {
      "productId": "p123",
      "productName": "Product Name",
      "quantity": 1,
      "price": 99.99
    }
  ],
  "shippingAddress": {
    "street": "123 Main St",
    "city": "Anytown",
    "postalCode": "12345",
    "country": "USA"
  },
  "paymentMethod": "CARD"
}
```

**Success Response (202 Accepted):**
```json
{
  "message": "Order accepted for processing",
  "orderId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error Response (400 Bad Request):**
```json
{
  "message": "Missing required field: customerEmail"
}
```

### Testing with curl

```bash
# Get API URL
API_URL=$(cd terraform && terraform output -raw api_url)

# Send test order
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "customerName": "Test User",
    "customerEmail": "test@example.com",
    "items": [{
      "productId": "test-123",
      "productName": "Test Product",
      "quantity": 1,
      "price": 19.99
    }],
    "shippingAddress": {
      "street": "123 Test St",
      "city": "Test City",
      "postalCode": "12345",
      "country": "USA"
    },
    "paymentMethod": "CARD"
  }'
```

## Project Structure

```
.
├── Makefile                    # Deployment automation
├── README.md                   # This file
├── .gitignore                 # Git ignore rules
├── layer/                     # Lambda layer dependencies
│   ├── requirements.txt       # Layer dependencies
│   └── README.md             # Layer documentation
├── src/                       # Source code
│   ├── processor/            # Order processor Lambda
│   │   ├── processor.py      # Main processor logic
│   │   └── requirements.txt  # Function dependencies
│   ├── utils/                # Shared utilities
│   │   └── common.py         # Common functions
│   └── validator/            # Order validator Lambda
│       ├── lambda_handler.py # API Gateway handler
│       ├── validator.py      # Validation logic
│       └── requirements.txt  # Function dependencies
├── scripts/                  # Utility scripts
│   └── test_api.py          # API testing script
├── terraform/               # Infrastructure as Code
│   ├── main.tf             # Main Terraform configuration
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Output values
│   └── README.md           # Terraform documentation
└── dist/                   # Build artifacts (auto-generated)
    ├── order_validator.zip # Validator function package
    ├── order_processor.zip # Processor function package
    └── python_layer.zip    # Dependencies layer
```

## Monitoring and Debugging

### CloudWatch Logs

View Lambda function logs:
```bash
# Validator logs
make logs-validator

# Processor logs
make logs-processor
```

### SQS Queue Monitoring

Check queue status:
```bash
make sqs-status
```

### DynamoDB Data

Scan orders table:
```bash
make dynamodb-scan
```

### Manual AWS CLI Commands

```bash
# Check SQS queue attributes
aws sqs get-queue-attributes \
  --queue-url $(cd terraform && terraform output -raw orders_queue_url) \
  --attribute-names All

# List recent Lambda invocations
aws logs filter-log-events \
  --log-group-name "/aws/lambda/$(cd terraform && terraform output -raw validator_lambda_name)" \
  --start-time $(date -d '1 hour ago' +%s)000

# Query DynamoDB
aws dynamodb scan \
  --table-name $(cd terraform && terraform output -raw orders_table_name) \
  --select "COUNT"
```

## Cost Optimization

This setup uses serverless components that scale to zero:

- **Lambda**: Pay per invocation
- **API Gateway**: Pay per request
- **SQS**: Pay per message
- **DynamoDB**: Pay per request (on-demand billing)

Estimated costs for 1000 orders/day: ~$5-10/month

## Security Features

- IAM roles with least privilege access
- API Gateway request validation
- SQS dead letter queue for error handling
- CloudWatch logging for audit trails
- No hardcoded credentials

## Customization

### Adding New Fields

1. Update validation in `src/validator/validator.py`
2. Update API Gateway model in `terraform/main.tf`
3. Redeploy: `make deploy`

### Changing Regions

```bash
export AWS_REGION=us-west-2
make deploy
```

### Adding Environments

```bash
export ENVIRONMENT=staging
make deploy
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   aws sts get-caller-identity  # Check AWS credentials
   ```

2. **Terraform State Lock**
   ```bash
   cd terraform && terraform force-unlock LOCK_ID
   ```

3. **Lambda Function Not Found**
   - Check if packaging completed successfully
   - Verify ZIP files exist in `dist/` directory

4. **API Gateway 502 Error**
   - Check Lambda function logs
   - Verify IAM permissions

### Getting Help

1. Check CloudWatch logs: `make logs-validator logs-processor`
2. Verify infrastructure: `make status`
3. Test components individually: `make sqs-status dynamodb-scan`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test locally
4. Run validation: `make validate`
5. Submit a pull request

## License

This project is licensed under the MIT License.

## Additional Resources

- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)
- [AWS SQS Documentation](https://docs.aws.amazon.com/sqs/)
- [DynamoDB Developer Guide](https://docs.aws.amazon.com/dynamodb/)