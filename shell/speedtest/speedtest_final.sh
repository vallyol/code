#!/bin/bash

export LC_ALL=C

URL_CLOUDFLARE="https://speed.cloudflare.com/__down?bytes=52428800"
URL_SELECTEL="https://mirror.selectel.ru/astra/stable/2.12_x86-64/iso/alce-2.12.46.6-17.04.2023_15.09.iso"
URL_YANDEX="https://storage.yandexcloud.net/yandexcloud-yc/release/yc_linux_amd64.tar.gz"
URL_PSN="https://ftp.psn.ru/debian-cd/13.6.0/amd64/iso-cd/debian-13.6.0-amd64-netinst.iso"
URL_LV="https://debian.koyanet.lv/debian-cd/13.6.0/amd64/iso-cd/debian-13.6.0-amd64-netinst.iso"

# Единственный рабочий эндпоинт для выгрузки (Upload)
URL_UP="https://speed.cloudflare.com/__up"

# Домены для проверок (строго без протоколов https://)
HOST_1="speed.cloudflare.com"
HOST_2="mirror.selectel.ru"
HOST_3="storage.yandexcloud.net"
HOST_4="ftp.psn.ru"
HOST_5="debian.koyanet.lv"

echo "Выберите сервер для теста скорости (длительность ~30-40 сек):"
echo "1) Cloudflare CDN"
echo "2) Selectel ISO Mirror (РФ)"
echo "3) Yandex Cloud Storage (РФ)"
echo "4) PSN Debian repo (РФ Москва)"
echo "5) Debian repo (Latvia)"
read -p "Введите цифру (1-5): " choice

case $choice in
    1) URL=$URL_CLOUDFLARE; HOST=$HOST_1 ;;
    2) URL=$URL_SELECTEL; HOST=$HOST_2 ;;
    3) URL=$URL_YANDEX; HOST=$HOST_3 ;;
    4) URL=$URL_PSN; HOST=$HOST_4 ;;
    5) URL=$URL_LV; HOST=$HOST_5 ;;
    *) echo "Неверный выбор"; exit 1 ;;
esac

echo -e "\n1. Измерение задержки (Ping)..."
# Сначала пробуем обычный ping. Если он заблокирован (как у Cloudflare), меряем TCP-задержку через curl
PING_RES=$(ping -c 2 -W 2 "$HOST" 2>/dev/null | awk -F '/' 'END {print $5}')

if [ -z "$PING_RES" ]; then
    # TCP-пинг: curl подключается к хосту и отдает время установки соединения в секундах
    TCP_TIME=$(curl -so /dev/null -w "%{time_connect}" --max-time 3 "https://$HOST")
    if [ "$TCP_TIME" = "0.000" ] || [ -z "$TCP_TIME" ]; then
        PING_RES="Блокировка (Таймаут)"
    else
        PING_RES=$(awk "BEGIN {printf \"%.1f мс (TCP)\", ($TCP_TIME * 1000)}")
    fi
else
    PING_RES="${PING_RES} мс (ICMP)"
fi

echo "2. Тест СКАЧИВАНИЯ (Download)... Подождите 15 секунд."
SPEED_DL_RAW=$(curl -L -N -o /dev/null --max-time 15 -w "%{speed_download}" "$URL" 2>/dev/null)

echo "3. Тест ВЫГРУЗКИ (Upload)... Отправка 10 МБ на Cloudflare."
# Добавлены HTTP-заголовки, чтобы Cloudflare корректно принимал входящий POST-поток
SPEED_UL_RAW=$(dd if=/dev/zero bs=1M count=10 2>/dev/null | curl -s -X POST -H "Content-Type: application/octet-stream" -H "Expect:" -T - -w '%{speed_upload}' "$URL_UP")

# Защита от пустых значений перед вычислениями
if [ -z "$SPEED_DL_RAW" ] || [ "$SPEED_DL_RAW" = "0.000" ]; then SPEED_DL_RAW=0; fi
if [ -z "$SPEED_UL_RAW" ] || [ "$SPEED_UL_RAW" = "0.000" ]; then SPEED_UL_RAW=0; fi

# Перевод сырых байтов в Мбит/с
SPEED_DL=$(awk "BEGIN {print ($SPEED_DL_RAW * 8 / 1000000)}")
SPEED_UL=$(awk "BEGIN {print ($SPEED_UL_RAW * 8 / 1000000)}")

echo -e "\n================================="
echo "Сервер (Download): $HOST"
echo "Задержка (Ping):   $PING_RES"
echo -e "---------------------------------"

# Вывод Download
if [ $(awk "BEGIN {print ($SPEED_DL < 0.1 ? 1 : 0)}") -eq 1 ]; then
    SPEED_DL_KB=$(awk "BEGIN {print ($SPEED_DL_RAW * 8 / 1024)}")
    printf "Скачивание (DL):  %.2f Кбит/с\n" $SPEED_DL_KB
else
    printf "Скачивание (DL):  %.2f Мбит/с\n" $SPEED_DL
fi

# Вывод Upload
if [ $(awk "BEGIN {print ($SPEED_UL < 0.1 ? 1 : 0)}") -eq 1 ]; then
    SPEED_UL_KB=$(awk "BEGIN {print ($SPEED_UL_RAW * 8 / 1024)}")
    printf "Выгрузка (UL):    %.2f Кбит/с\n" $SPEED_UL_KB
else
    printf "Выгрузка (UL):    %.2f Мбит/с\n" $SPEED_UL
fi
echo "================================="
