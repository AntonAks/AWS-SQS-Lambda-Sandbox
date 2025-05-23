import json
import requests


def test_order_submission():
    """
    Функція для тестування API.
    Створює тестове замовлення і надсилає його до API.
    """
    # URL вашого API (замініть на свій після розгортання)
    api_url = "https://your-api-gateway-url.execute-api.eu-central-1.amazonaws.com/dev/orders"

    # Тестове замовлення
    test_order = {
        "customerName": "Іван Петренко",
        "customerEmail": "ivan.petrenko@example.com",
        "items": [
            {
                "productId": "p123",
                "productName": "Смартфон XYZ",
                "quantity": 1,
                "price": 12999.99
            },
            {
                "productId": "p456",
                "productName": "Захисний чохол",
                "quantity": 2,
                "price": 299.50
            }
        ],
        "shippingAddress": {
            "street": "вул. Шевченка, 10, кв. 5",
            "city": "Київ",
            "postalCode": "01001",
            "country": "Україна"
        },
        "paymentMethod": "CARD"
    }

    # Відправка запиту
    try:
        response = requests.post(api_url, json=test_order)

        # Вивід результату
        print(f"Статус відповіді: {response.status_code}")
        print(f"Тіло відповіді: {response.text}")

        # Якщо запит успішний
        if response.status_code == 202:
            order_id = response.json().get("orderId")
            print(f"Замовлення успішно створено з ID: {order_id}")
            return order_id
        else:
            print("Помилка при відправці замовлення")
            return None

    except Exception as e:
        print(f"Виникла помилка: {str(e)}")
        return None


if __name__ == "__main__":
    print("Тестування API для системи обробки замовлень...")
    order_id = test_order_submission()

    if order_id:
        print(f"Тестування успішне. OrderID: {order_id}")
    else:
        print("Тестування завершилось невдачею.")