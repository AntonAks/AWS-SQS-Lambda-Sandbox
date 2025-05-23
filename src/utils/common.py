import os
import json
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_common_headers():
    """
    Returns standard headers for API responses.

    Returns:
        dict: HTTP response headers
    """
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
    }


def create_response(status_code, body):
    """
    Creates standard response format for API Gateway.

    Parameters:
        status_code (int): HTTP status code
        body (dict): Response body

    Returns:
        dict: Structured response for API Gateway
    """
    return {
        'statusCode': status_code,
        'headers': get_common_headers(),
        'body': json.dumps(body)
    }


def validate_required_fields(data, required_fields):
    """
    Checks presence of all required fields in data.

    Parameters:
        data (dict): Data to check
        required_fields (list): List of required fields

    Returns:
        tuple: (True, None) if all fields present, otherwise (False, error_message)
    """
    for field in required_fields:
        if field not in data:
            return False, f"Missing required field: {field}"

    return True, None


def get_environment_name():
    """
    Gets current deployment environment name.

    Returns:
        str: Environment name ('dev', 'test', 'prod')
    """
    return os.environ.get('ENVIRONMENT', 'dev')


def is_debug_mode():
    """
    Checks if debug mode is enabled.

    Returns:
        bool: True if debug mode is enabled
    """
    return os.environ.get('DEBUG_MODE', 'false').lower() == 'true'


def sanitize_data(data):
    """
    Sanitizes data from potentially dangerous content.

    Parameters:
        data (dict): Data to sanitize

    Returns:
        dict: Sanitized data
    """
    # Simple data sanitization - in real application there would be more complex logic
    if not isinstance(data, dict):
        return data

    sanitized = {}
    for key, value in data.items():
        if isinstance(value, str):
            # Remove control characters
            sanitized[key] = ''.join(c for c in value if c >= ' ')
        elif isinstance(value, dict):
            sanitized[key] = sanitize_data(value)
        elif isinstance(value, list):
            sanitized[key] = [sanitize_data(item) if isinstance(item, dict) else item for item in value]
        else:
            sanitized[key] = value

    return sanitized