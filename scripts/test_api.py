import json
import requests
import sys
import time
from typing import Optional


def test_order_submission(api_url: str) -> Optional[str]:
    """
    Function to test the API.
    Creates a test order and sends it to the API.

    Args:
        api_url: API endpoint URL

    Returns:
        Order ID if successful, None otherwise
    """
    # Test order data
    test_order = {
        "customerName": "John Doe",
        "customerEmail": "john.doe@example.com",
        "items": [
            {
                "productId": "p123",
                "productName": "Smartphone XYZ",
                "quantity": 1,
                "price": 599.99
            },
            {
                "productId": "p456",
                "productName": "Protective Case",
                "quantity": 2,
                "price": 29.50
            }
        ],
        "shippingAddress": {
            "street": "123 Main Street, Apt 5",
            "city": "New York",
            "postalCode": "10001",
            "country": "USA"
        },
        "paymentMethod": "CARD"
    }

    # Send request
    try:
        print(f"Sending request to: {api_url}")
        headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'OrderTestScript/1.0'
        }

        response = requests.post(api_url, json=test_order, headers=headers, timeout=30)

        # Output result
        print(f"Response Status: {response.status_code}")
        print(f"Response Headers: {dict(response.headers)}")
        print(f"Response Body: {response.text}")

        # If request successful
        if response.status_code == 202:
            try:
                response_data = response.json()
                order_id = response_data.get("orderId")
                print(f"✅ Order successfully created with ID: {order_id}")
                return order_id
            except json.JSONDecodeError:
                print("⚠️ Warning: Response is not valid JSON")
                return None
        else:
            print(f"❌ Error sending order. Status: {response.status_code}")
            try:
                error_data = response.json()
                print(f"Error details: {error_data}")
            except json.JSONDecodeError:
                print(f"Raw error response: {response.text}")
            return None

    except requests.exceptions.Timeout:
        print("❌ Request timeout")
        return None
    except requests.exceptions.ConnectionError:
        print("❌ Connection error - check if the API URL is correct")
        return None
    except requests.exceptions.RequestException as e:
        print(f"❌ Request error: {str(e)}")
        return None
    except Exception as e:
        print(f"❌ Unexpected error: {str(e)}")
        return None


def test_invalid_order(api_url: str) -> bool:
    """
    Test API with invalid order data to verify validation.

    Args:
        api_url: API endpoint URL

    Returns:
        True if validation works correctly, False otherwise
    """
    print("\n🧪 Testing order validation...")

    # Invalid order (missing required fields)
    invalid_order = {
        "customerName": "John Doe",
        # Missing customerEmail
        "items": []  # Empty items array
    }

    try:
        response = requests.post(api_url, json=invalid_order, timeout=30)

        print(f"Validation test - Status: {response.status_code}")
        print(f"Validation test - Response: {response.text}")

        # Should return 400 for invalid data
        if response.status_code == 400:
            print("✅ Validation working correctly")
            return True
        else:
            print("❌ Validation not working as expected")
            return False

    except Exception as e:
        print(f"❌ Validation test error: {str(e)}")
        return False


def check_api_health(api_url: str) -> bool:
    """
    Basic health check for API endpoint.

    Args:
        api_url: API endpoint URL

    Returns:
        True if API is reachable, False otherwise
    """
    try:
        # Try OPTIONS request first (CORS preflight)
        response = requests.options(api_url, timeout=10)
        print(f"OPTIONS request status: {response.status_code}")

        if response.status_code in [200, 204]:
            print("✅ API is reachable")
            return True
        else:
            print("⚠️ API responded but with unexpected status for OPTIONS")
            return True  # Still consider it reachable

    except Exception as e:
        print(f"❌ API health check failed: {str(e)}")
        return False


def main():
    """Main test function."""
    print("🚀 Testing Order Processing API...")
    print("=" * 50)

    # Get API URL from command line argument or use default
    if len(sys.argv) > 1:
        api_url = sys.argv[1]
    else:
        # Try to get from terraform output
        try:
            import subprocess
            result = subprocess.run(
                ["terraform", "output", "-raw", "api_url"],
                cwd="../terraform",
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                api_url = result.stdout.strip()
            else:
                print("❌ Could not get API URL from terraform output")
                print("Usage: python test_api.py [API_URL]")
                sys.exit(1)
        except Exception:
            print("❌ Could not get API URL from terraform output")
            print("Usage: python test_api.py [API_URL]")
            sys.exit(1)

    print(f"🎯 Target API: {api_url}")
    print()

    # Health check
    if not check_api_health(api_url):
        print("❌ API health check failed. Exiting.")
        sys.exit(1)

    print()

    # Test valid order
    order_id = test_order_submission(api_url)

    print()

    # Test invalid order
    validation_works = test_invalid_order(api_url)

    print()
    print("📊 Test Summary:")
    print("=" * 30)

    if order_id:
        print("✅ Valid order test: PASSED")
        print(f"   Order ID: {order_id}")
    else:
        print("❌ Valid order test: FAILED")

    if validation_works:
        print("✅ Validation test: PASSED")
    else:
        print("❌ Validation test: FAILED")

    # Overall result
    if order_id and validation_works:
        print("\n🎉 All tests PASSED!")
        print("\n💡 Next steps:")
        print("   - Check CloudWatch logs for Lambda functions")
        print("   - Verify data in DynamoDB table")
        print("   - Monitor SQS queue processing")
        sys.exit(0)
    else:
        print("\n💥 Some tests FAILED!")
        print("\n🔍 Troubleshooting:")
        print("   - Check Lambda function logs")
        print("   - Verify IAM permissions")
        print("   - Check API Gateway configuration")
        sys.exit(1)


if __name__ == "__main__":
    main()