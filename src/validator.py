import json
import os
import uuid
import boto3
import logging
from datetime import datetime
from validator import validate_order

# Налаштування логування
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Ініціалізація клієнта SQS
sqs_client = boto3.client('sqs')
SQS_QUEUE_URL = os.environ['SQS_QUEUE_URL']


def lambda_handler(event, context):
    """
    Lambda-функція для валідації замовлень та їх відправки до черги SQS.

    Параметри:
        event (dict): Вхідні дані від API Gateway
        context (object): Об'єкт контексту виконання Lambda

    Повертає:
        dict: Відповідь для API Gateway
    """
    logger.info(f"Отримано новий запит: {json.dumps(event)}")

    try:
        # Отримання даних замовлення з тіла запиту
        if 'body' in event:
            try:
                body = json.loads(event['body'])
            except:
                logger.error("Не вдалося обробити тіло запиту як JSON")
                return {
                    'statusCode': 400,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'message': 'Невірний формат JSON'})
                }
        else:
            logger.error("Відсутнє тіло запиту")
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'message': 'Відсутнє тіло запиту'})
            }

        # Валідація замовлення
        validation_result = validate_order(body)
        if not validation_result['valid']:
            logger.warning(f"Валідація замовлення не пройшла: {validation_result['message']}")
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'message': validation_result['message']})
            }

        # Генерація унікального ID для замовлення
        order_id = str(uuid.uuid4())

        # Додавання додаткової інформації до замовлення
        order_data = body
        order_data['orderId'] = order_id
        order_data['timestamp'] = datetime.utcnow().isoformat()
        order_data['status'] = 'PENDING'

        # Відправка замовлення до черги SQS
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

        logger.info(f"Замовлення {order_id} успішно надіслано до черги: {response['MessageId']}")

        # Успішна відповідь
        return {
            'statusCode': 202,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'message': 'Замовлення прийнято на обробку',
                'orderId': order_id
            })
        }

    except Exception as e:
        logger.error(f"Помилка при обробці замовлення: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'message': 'Внутрішня помилка сервера'})
        }