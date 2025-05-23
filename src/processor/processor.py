import json
import os
import boto3
import logging
from datetime import datetime

# Налаштування логування
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Ініціалізація клієнтів AWS
dynamodb = boto3.resource('dynamodb')
ses_client = boto3.client('ses')

# Отримання імені таблиці DynamoDB з змінних середовища
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
orders_table = dynamodb.Table(DYNAMODB_TABLE)


def lambda_handler(event, context):
    """
    Lambda-функція для обробки замовлень з черги SQS.

    Параметри:
        event (dict): Подія SQS з повідомленнями
        context (object): Об'єкт контексту виконання Lambda

    Повертає:
        dict: Результат обробки
    """
    logger.info(f"Отримано подію SQS: {json.dumps(event)}")

    # Відстеження успішних та невдалих обробок
    processed_orders = []
    failed_orders = []

    # Перебір отриманих повідомлень
    for record in event['Records']:
        try:
            # Отримання даних замовлення
            message_body = record['body']
            order_data = json.loads(message_body)
            order_id = order_data['orderId']

            logger.info(f"Обробка замовлення: {order_id}")

            # Обробка замовлення
            process_order(order_data)

            # Відправка підтвердження електронною поштою
            send_confirmation_email(order_data)

            processed_orders.append(order_id)
            logger.info(f"Замовлення {order_id} успішно оброблено")

        except Exception as e:
            if 'orderId' in locals():
                failed_order_id = order_id
            else:
                failed_order_id = "unknown"

            failed_orders.append(failed_order_id)
            logger.error(f"Помилка обробки замовлення {failed_order_id}: {str(e)}")

    # Повернення результату
    return {
        'processedOrders': processed_orders,
        'failedOrders': failed_orders,
        'totalProcessed': len(processed_orders),
        'totalFailed': len(failed_orders)
    }


def process_order(order_data):
    """
    Обробляє замовлення та зберігає його в DynamoDB.

    Параметри:
        order_data (dict): Дані замовлення
    """
    # Оновлення статусу та часу обробки
    order_data['status'] = 'PROCESSED'
    order_data['processedAt'] = datetime.utcnow().isoformat()

    # Обчислення загальної суми замовлення
    total_amount = sum(item['price'] * item['quantity'] for item in order_data['items'])
    order_data['totalAmount'] = total_amount

    # Збереження замовлення в DynamoDB
    orders_table.put_item(Item=order_data)

    # Тут також можна додати оновлення інвентаря, створення рахунку тощо
    logger.info(f"Замовлення {order_data['orderId']} збережено в DynamoDB")


def send_confirmation_email(order_data):
    """
    Відправляє електронний лист підтвердження замовлення.

    Параметри:
        order_data (dict): Дані замовлення
    """
    # В реальному додатку ви б використовували AWS SES для відправки листів
    # Тут це заглушка, оскільки для використання SES потрібна верифікація домену

    customer_email = order_data['customerEmail']
    order_id = order_data['orderId']
    customer_name = order_data['customerName']

    # Створення тексту листа
    email_subject = f"Підтвердження замовлення #{order_id}"

    items_list = "\n".join([
        f"- {item['quantity']}x {item.get('productName', 'Товар')} "
        f"({item['price']} грн за одиницю)"
        for item in order_data['items']
    ])

    total_amount = sum(item['price'] * item['quantity'] for item in order_data['items'])

    email_body = f"""
    Шановний(а) {customer_name},

    Дякуємо за ваше замовлення #{order_id}!

    Деталі замовлення:
    {items_list}

    Загальна сума: {total_amount} грн

    Статус замовлення: Оброблено

    Відстежуйте статус вашого замовлення через наш веб-сайт.

    З повагою,
    Команда електронного магазину
    """

    # Це місце для виклику AWS SES, якщо ваш аккаунт має всі необхідні дозволи
    logger.info(f"Підтвердження надіслано на адресу {customer_email} для замовлення {order_id}")

    # Заглушка для SES (в реальному додатку розкоментуйте код нижче)
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