import os
import json
import logging

# Налаштування логування
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_common_headers():
    """
    Повертає стандартні заголовки для відповідей API.

    Повертає:
        dict: Заголовки HTTP відповіді
    """
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
    }


def create_response(status_code, body):
    """
    Створює стандартний формат відповіді для API Gateway.

    Параметри:
        status_code (int): HTTP код статусу
        body (dict): Тіло відповіді

    Повертає:
        dict: Структурована відповідь для API Gateway
    """
    return {
        'statusCode': status_code,
        'headers': get_common_headers(),
        'body': json.dumps(body)
    }


def validate_required_fields(data, required_fields):
    """
    Перевіряє наявність всіх обов'язкових полів у даних.

    Параметри:
        data (dict): Дані для перевірки
        required_fields (list): Список обов'язкових полів

    Повертає:
        tuple: (True, None) якщо всі поля присутні, інакше (False, повідомлення_про_помилку)
    """
    for field in required_fields:
        if field not in data:
            return False, f"Відсутнє обов'язкове поле: {field}"

    return True, None


def get_environment_name():
    """
    Отримує назву поточного середовища розгортання.

    Повертає:
        str: Назва середовища ('dev', 'test', 'prod')
    """
    return os.environ.get('ENVIRONMENT', 'dev')


def is_debug_mode():
    """
    Перевіряє, чи увімкнено режим налагодження.

    Повертає:
        bool: True, якщо режим налагодження увімкнено
    """
    return os.environ.get('DEBUG_MODE', 'false').lower() == 'true'


def sanitize_data(data):
    """
    Очищує дані від потенційно небезпечного вмісту.

    Параметри:
        data (dict): Дані для очищення

    Повертає:
        dict: Очищені дані
    """
    # Проста версія очищення даних - у реальному додатку тут буде складніша логіка
    if not isinstance(data, dict):
        return data

    sanitized = {}
    for key, value in data.items():
        if isinstance(value, str):
            # Видалення керуючих символів
            sanitized[key] = ''.join(c for c in value if c >= ' ')
        elif isinstance(value, dict):
            sanitized[key] = sanitize_data(value)
        elif isinstance(value, list):
            sanitized[key] = [sanitize_data(item) if isinstance(item, dict) else item for item in value]
        else:
            sanitized[key] = value

    return sanitized