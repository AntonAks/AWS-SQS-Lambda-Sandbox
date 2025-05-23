#!/bin/bash

# Скрипт для пакування Lambda функцій

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$ROOT_DIR/dist"
SRC_DIR="$ROOT_DIR/src"

echo "Підготовка архівів Lambda функцій..."

# Створення директорії для архівів, якщо вона не існує
mkdir -p "$DIST_DIR"

# Функція для пакування Lambda
package_lambda() {
    local FUNCTION_NAME=$1
    local SOURCE_DIR=$2
    local HANDLER_FILE=$3

    echo "Підготовка архіву для функції $FUNCTION_NAME..."

    # Створення тимчасової директорії
    TMP_DIR=$(mktemp -d)

    # Встановлення залежностей у тимчасовій директорії
    if [ -f "$SOURCE_DIR/requirements.txt" ]; then
        echo "Встановлення залежностей для $FUNCTION_NAME..."
        pip install -r "$SOURCE_DIR/requirements.txt" -t "$TMP_DIR" --no-cache-dir
    fi

    # Копіювання Python файлів
    echo "Копіювання Python файлів..."
    cp "$SOURCE_DIR/$HANDLER_FILE" "$TMP_DIR/"

    # Додавання додаткових файлів, якщо потрібно
    if [ -n "$4" ]; then
        cp "$SOURCE_DIR/$4" "$TMP_DIR/"
    fi

    # Створення архіву
    echo "Створення zip архіву..."
    cd "$TMP_DIR"
    zip -r "$DIST_DIR/${FUNCTION_NAME}.zip" .

    # Очищення
    cd - > /dev/null
    rm -rf "$TMP_DIR"

    echo "Архів для $FUNCTION_NAME створено: $DIST_DIR/${FUNCTION_NAME}.zip"
}

# Пакування Lambda-функції для валідації замовлень
package_lambda "order_validator" "$SRC_DIR/validator" "lambda_handler.py" "validator.py"

# Пакування Lambda-функції для обробки замовлень
package_lambda "order_processor" "$SRC_DIR/processor" "processor.py"

echo "Всі архіви Lambda функцій успішно створено в $DIST_DIR"