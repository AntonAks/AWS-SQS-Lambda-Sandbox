import json
import os
import uuid
import boto3
import logging
from datetime import datetime
from validator import validate_order

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize SQS client
sqs_client = boto3.client('sqs')
SQS_QUEUE_URL = os.environ['SQS_QUEUE_URL']


def lambda_handler(event, context):
    """
    Lambda function for order validation and sending to SQS queue.

    Parameters:
        event (dict): Input data from API Gateway
        context (object): Lambda execution context object

    Returns:
        dict: Response for API Gateway
    """
    logger.info(f"Received new request: {json.dumps(event)}")

    try:
        # Get order data from request body
        if 'body' in event:
            try:
                body = json.loads(event['body'])
            except:
                logger.error("Failed to parse request body as JSON")
                return {
                    'statusCode': 400,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'message': 'Invalid JSON format'})
                }
        else:
            logger.error("Missing request body")
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'message': 'Missing request body'})
            }

        # Validate order
        validation_result = validate_order(body)
        if not validation_result['valid']:
            logger.warning(f"Order validation failed: {validation_result['message']}")
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'message': validation_result['message']})
            }

        # Generate unique order ID
        order_id = str(uuid.uuid4())

        # Add additional information to order
        order_data = body
        order_data['orderId'] = order_id
        order_data['timestamp'] = datetime.utcnow().isoformat()
        order_data['status'] = 'PENDING'

        # Send order to SQS queue
        response = sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(order_data),
            MessageAttributes={
                'OrderId': {
                    'DataType': 'String',
                    'StringValue': order_id
                }
            }
        )

        logger.info(f"Order {order_id} successfully sent to queue: {response['MessageId']}")

        # Success response
        return {
            'statusCode': 202,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'message': 'Order accepted for processing',
                'orderId': order_id
            })
        }

    except Exception as e:
        logger.error(f"Error processing order: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'message': 'Internal server error'})
        }