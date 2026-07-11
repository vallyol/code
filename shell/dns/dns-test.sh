#!/bin/bash

# Цвета для терминала
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m' # No Color

if command -v getprop &> /dev/null && [ -n "$(getprop net.rmnet0.dns1)" ]; then
    # Вариант для Android / Termux (мобильный интернет)
    current_dns=$(getprop net.rmnet0.dns1)
else
    # Вариант для стандартного Linux (Debian)
    current_dns=$(grep '^nameserver' /etc/resolv.conf | awk '{print $2}' | head -1)
fi

# Ассоциативный массив: имя -> IP
declare -A servers=(
  ["Google DNS"]="8.8.8.8"
  ["Cloudflare DNS"]="1.1.1.1"
  ["Quad9"]="9.9.9.9"
  ["OpenDNS"]="208.67.222.222"
  ["AdGuard DNS"]="94.140.14.14"
  ["Comodo Secure"]="8.26.56.26"
  ["CleanBrowsing"]="185.228.168.9"
  ["Control D"]="76.76.2.4"
  ["Neustar Ultra"]="156.154.70.5"
  ["Yandex DNS"]="77.88.8.8"
  ["Alibaba"]="223.5.5.5"
  ["Mullvad"]="194.242.2.2"
)

domain="$1"

if [ -z "$domain" ]; then
    echo "Ошибка: укажите доменное имя. Пример: $0 example.com"
    exit 1
fi

echo "" 
printf "Тестируем время запроса к $domain" 
echo # Пустая строка для разделения
echo "" 

# Проверка на пустой current_dns
if [[ -n "$current_dns" ]]; then
  servers["Current DNS"]="$current_dns"
fi

# Заголовок таблицы
printf "${GREEN}%s${NC}\n" "Сервис               Сервер          Статус               Query time"
printf "${GREEN}%s${NC}\n" "-------------------- --------------- -------------------- ----------"

# Сначала тестируем Current DNS (если есть)
if [[ -n "$current_dns" ]]; then
  printf "${YELLOW}%-20s${NC} " "Current DNS"
  result=$(dig @"$current_dns" "$domain" +stats 2>/dev/null | grep "Query time" | head -1)

  if [[ -n "$result" ]]; then
    query_time=$(echo "$result" | grep -o '[0-9]\+ msec' | head -1)
    printf "${GREEN}%-15s${NC} ${GREEN}%-20s${NC} %s\n" "$current_dns" "OK" "$query_time"
  else
    query_time="N/A"
    printf "${RED}%-15s${NC} ${RED}%-20s${NC} %s\n" "$current_dns" "ERROR" "$query_time"
  fi
  echo # Пустая строка для разделения
fi

# Остальные DNS (исключаем Current)
for name in "${!servers[@]}"; do
  [[ "$name" == "Current DNS" ]] && continue

  ip="${servers[$name]}"
  result=$(dig @"$ip" "$domain" +stats 2>/dev/null | grep "Query time" | head -1)

  if [[ -n "$result" ]]; then
    query_time=$(echo "$result" | grep -o '[0-9]\+ msec' | head -1)
    status="OK"
    printf "%-20s %-15s %-20s %s\n" "$name" "$ip" "$status" "$query_time"
  else
    query_time="N/A"
    status="ERROR"
    printf "%-20s %-15s %-20s %s\n" "$name" "$ip" "$status" "$query_time"
  fi
done

