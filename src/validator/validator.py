def validate_order(order_data):
    """
    Validates order data.

    Parameters:
        order_data (dict): Order data to validate

    Returns:
        dict: Validation result {'valid': bool, 'message': str}
    """
    # Check required fields
    required_fields = ['customerName', 'customerEmail', 'items', 'shippingAddress']
    for field in required_fields:
        if field not in order_data:
            return {
                'valid': False,
                'message': f"Missing required field: {field}"
            }

    # Email validation (simple check)
    email = order_data['customerEmail']
    if '@' not in email or '.' not in email:
        return {
            'valid': False,
            'message': "Invalid email format"
        }

    # Items validation
    items = order_data['items']
    if not isinstance(items, list) or len(items) == 0:
        return {
            'valid': False,
            'message': "Order must contain at least one item"
        }

    # Check required fields for each item
    for i, item in enumerate(items):
        if not all(key in item for key in ['productId', 'quantity', 'price']):
            return {
                'valid': False,
                'message': f"Item #{i+1} contains incomplete data"
            }

        # Check quantity is positive integer
        if not isinstance(item['quantity'], int) or item['quantity'] <= 0:
            return {
                'valid': False,
                'message': f"Item #{i+1}: quantity must be a positive integer"
            }

        # Check price is positive number
        if not isinstance(item['price'], (int, float)) or item['price'] <= 0:
            return {
                'valid': False,
                'message': f"Item #{i+1}: price must be a positive number"
            }

    # Shipping address validation
    address = order_data['shippingAddress']
    required_address_fields = ['street', 'city', 'postalCode', 'country']
    for field in required_address_fields:
        if field not in address:
            return {
                'valid': False,
                'message': f"Missing required address field: {field}"
            }

    # If all checks pass
    return {
        'valid': True,
        'message': "Validation successful"
    }