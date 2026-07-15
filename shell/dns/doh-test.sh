#!/bin/bash

# 1. Требуется указать доменное имя
TARGET_DOMAIN="$1"
if [ -z "$TARGET_DOMAIN" ]; then
    echo "Ошибка: укажите доменное имя. Пример: $0 example.com"
    exit 1
fi

# 2. Проверка наличия curl
if ! command -v curl &> /dev/null; then
    echo "Ошибка: утилита 'curl' не найдена в системе."
    echo "Инструкция по установке:"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "   Для Ubuntu/Debian: sudo apt update && sudo apt install curl"
        echo "   Для CentOS/RCE:    sudo dnf install curl"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   Для macOS:          brew install curl (или установите Xcode Command Line Tools)"
    fi
    exit 1
fi

echo "curl найден. Продолжаем..."

# 3. Определение текущего DNS (для информации, без блокировки)
echo "Анализ сетевого окружения..."
CURRENT_DNS=$(nmcli dev show | grep 'IP4.DNS' | awk '{print $2}' 2>/dev/null || cat /etc/resolv.conf | grep nameserver | awk '{print $2}')
echo "Ваш текущий DNS-сервер: $CURRENT_DNS (может быть IP-адресом вашего телефона)"

# 4. Настройка и проверка DoH (Cloudflare в качестве примера)
DOH_URL="https://cloudflare-dns.com/dns-query"

echo "Тестируем DoH-запрос через $DOH_URL..."

RESPONSE=$(curl -s -H "accept: application/dns-json" "$DOH_URL?name=$TARGET_DOMAIN&type=A")

if [ $? -eq 0 ] && echo "$RESPONSE" | grep -q "Status"; then
    echo "Успех! DoH работает корректно."
    echo "Ответ от сервера:"
    echo "$RESPONSE" | grep -o '"data":"[^"]*"' | head -n 3
else
    echo "Ошибка: не удалось выполнить DoH-запрос. Проверьте подключение к интернету."
fi
