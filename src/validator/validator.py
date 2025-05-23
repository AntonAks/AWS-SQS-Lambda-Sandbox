def validate_order(order_data):
    """
    Валідує дані замовлення.

    Параметри:
        order_data (dict): Дані замовлення для валідації

    Повертає:
        dict: Результат валідації {'valid': bool, 'message': str}
    """
    # Перевірка обов'язкових полів
    required_fields = ['customerName', 'customerEmail', 'items', 'shippingAddress']
    for field in required_fields:
        if field not in order_data:
            return {
                'valid': False,
                'message': f"Відсутнє обов'язкове поле: {field}"
            }

    # Валідація електронної пошти (проста перевірка)
    email = order_data['customerEmail']
    if not '@' in email or not '.' in email:
        return {
            'valid': False,
            'message': "Невірний формат електронної пошти"
        }

    # Валідація товарів
    items = order_data['items']
    if not isinstance(items, list) or len(items) == 0:
        return {
            'valid': False,
            'message': "Замовлення повинно містити хоча б один товар"
        }

    # Перевірка наявності потрібних полів для кожного товару
    for i, item in enumerate(items):
        if not all(key in item for key in ['productId', 'quantity', 'price']):
            return {
                'valid': False,
                'message': f"Товар #{i + 1} містить неповні дані"
            }

        # Перевірка, що кількість є додатним числом
        if not isinstance(item['quantity'], int) or item['quantity'] <= 0:
            return {
                'valid': False,
                'message': f"Товар #{i + 1}: кількість повинна бути додатним цілим числом"
            }

        # Перевірка, що ціна є додатним числом
        if not isinstance(item['price'], (int, float)) or item['price'] <= 0:
            return {
                'valid': False,
                'message': f"Товар #{i + 1}: ціна повинна бути додатним числом"
            }

    # Валідація адреси доставки
    address = order_data['shippingAddress']
    required_address_fields = ['street', 'city', 'postalCode', 'country']
    for field in required_address_fields:
        if field not in address:
            return {
                'valid': False,
                'message': f"Відсутнє обов'язкове поле адреси: {field}"
            }

    # Якщо всі перевірки пройдені
    return {
        'valid': True,
        'message': "Валідація пройшла успішно"
    }