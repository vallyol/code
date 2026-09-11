#!/bin/bash

# Список DNS-серверов в формате "Название:IP"
DNS_SERVERS=(
    "Google_Primary:8.8.8.8"
    "Google_Secondary:8.8.4.4"
    "Yandex_Basic:77.88.8.8"
    "Yandex_Safe:77.88.8.88"
    "Cloudflare:1.1.1.1"
    "Cisco_OpenDNS:208.67.222.222"
    "Quad9:9.9.9.9"
    "Beeline_Cable:194.67.2.114"
    "Beeline_Mob:85.249.22.248"
    "Beeline_Main_Mob:217.118.93.16"
)

# Шапка таблицы
printf "%-26s | %-20s | %-16s | %-11s | %-16s | %-20s\n" "Название DNS" "IP-Адрес" "Ping avg (мс)" "Потери " "Dig time (мс)" "Est. Tunnel Speed"
echo "---------------------------------------------------------------------------------------------------------"

raw_results=""

for entry in "${DNS_SERVERS[@]}"; do
    name="${entry%%:*}"
    ip="${entry#*:}"

    # Меняем нижнее подчеркивание обратно на пробел для красивого вывода
    display_name="${name//_/ }"

    # Тест Ping
    ping_output=$(ping -c 4 -W 2 "$ip" 2>/dev/null)
    if [ $? -eq 0 ]; then
        loss="0%"
        # Вытаскиваем средний пинг
        ping_avg=$(echo "$ping_output" | awk -F'/' '/rtt/ {print $5}')
    else
        loss="100%"
        ping_avg="Мертв"
    fi

    # Тест Dig (только если сервер пингуется)
    dig_time="Таймаут"
    speed_str="0 Kbps"
    speed_sort_key=0  # Ключ для сортировки, если сервер мертв

    if [ "$loss" = "0%" ]; then
        dig_output=$(dig @"$ip" youtube.com +stats +time=2 2>/dev/null)
        query_time=$(echo "$dig_output" | grep "Query time:" | awk '{print $4}')

        if [ -n "$query_time" ]; then
            dig_time="$query_time"

            # Математика в Bash (только целые числа):
            # (20 потоков * 1000 мс * 500 байт * 8 бит) / (dig_time * 1000) -> 80000 / dig_time
            kbps=$(( 80000 / query_time ))
            kbytes=$(( 10000 / query_time ))

            speed_str="~$kbps Kbps ($kbytes KB/s)"
            speed_sort_key=$kbps
        fi
    fi

    # Сохраняем строку результатов во временную переменную для последующей сортировки
    # Формат: speed_sort_key|выводимая строка
    row=$(printf "%-18s | %-15s | %-14s | %-7s | %-14s | %-20s\n" "$display_name" "$ip" "$ping_avg" "$loss" "$dig_time" "$speed_str")
    raw_results+="${speed_sort_key}|${row}"$'\n'
done

# Сортируем по ключу скорости (первое поле перед знаком '|') в числовом порядке по убыванию
echo "$raw_results" | sort -t'|' -k1,1nr | cut -d'|' -f2-
