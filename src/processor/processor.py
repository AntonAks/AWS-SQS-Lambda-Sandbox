import json
import os
import boto3
import logging
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
ses_client = boto3.client('ses')

# Get DynamoDB table name from environment variables
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
orders_table = dynamodb.Table(DYNAMODB_TABLE)


def lambda_handler(event, context):
    """
    Lambda function for processing orders from SQS queue.

    Parameters:
        event (dict): SQS event with messages
        context (object): Lambda execution context object

    Returns:
        dict: Processing result
    """
    logger.info(f"Received SQS event: {json.dumps(event)}")

    # Track successful and failed processing
    processed_orders = []
    failed_orders = []

    # Process received messages
    for record in event['Records']:
        order_id = "unknown"
        try:
            # Get order data
            message_body = record['body']
            order_data = json.loads(message_body)
            order_id = order_data['orderId']

            logger.info(f"Processing order: {order_id}")

            # Process order
            process_order(order_data)

            # Send confirmation email
            send_confirmation_email(order_data)

            processed_orders.append(order_id)
            logger.info(f"Order {order_id} processed successfully")

        except Exception as e:
            failed_orders.append(order_id)
            logger.error(f"Error processing order {order_id}: {str(e)}")

    # Return result
    return {
        'processedOrders': processed_orders,
        'failedOrders': failed_orders,
        'totalProcessed': len(processed_orders),
        'totalFailed': len(failed_orders)
    }


def process_order(order_data):
    """
    Processes order and stores it in DynamoDB.

    Parameters:
        order_data (dict): Order data
    """
    # Update status and processing time
    order_data['status'] = 'PROCESSED'
    order_data['processedAt'] = datetime.utcnow().isoformat()

    # Calculate total order amount
    total_amount = sum(item['price'] * item['quantity'] for item in order_data['items'])
    order_data['totalAmount'] = total_amount

    # Save order to DynamoDB
    orders_table.put_item(Item=order_data)

    # Here you can also add inventory updates, invoice creation, etc.
    logger.info(f"Order {order_data['orderId']} saved to DynamoDB")


def send_confirmation_email(order_data):
    """
    Sends order confirmation email.

    Parameters:
        order_data (dict): Order data
    """
    # In a real application you would use AWS SES to send emails
    # This is a stub since SES requires domain verification

    customer_email = order_data['customerEmail']
    order_id = order_data['orderId']
    customer_name = order_data['customerName']

    # Create email content
    email_subject = f"Order Confirmation #{order_id}"

    items_list = "\n".join([
        f"- {item['quantity']}x {item.get('productName', 'Product')} "
        f"(${item['price']:.2f} each)"
        for item in order_data['items']
    ])

    total_amount = sum(item['price'] * item['quantity'] for item in order_data['items'])

    email_body = f"""
    Dear {customer_name},

    Thank you for your order #{order_id}!

    Order details:
    {items_list}

    Total amount: ${total_amount:.2f}

    Order status: Processed

    Track your order status on our website.

    Best regards,
    E-commerce Team
    """

    # This is where you would call AWS SES if your account has all necessary permissions
    logger.info(f"Confirmation sent to {customer_email} for order {order_id}")

    # SES stub (uncomment in real application)
    """
    ses_client.send_email(
        Source='orders@yourstore.com',
        Destination={
            'ToAddresses': [
                customer_email,
            ],
        },
        Message={
            'Subject': {
                'Data': email_subject,
                'Charset': 'UTF-8'
            },
            'Body': {
                'Text': {
                    'Data': email_body,
                    'Charset': 'UTF-8'
                }
            }
        }
    )
    """