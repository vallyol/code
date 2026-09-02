#!/usr/bin/env bash

HOST="speed.cloudflare.com"
URL_DOWNLOAD="https://speed.cloudflare.com/__down?bytes=10485760"
URL_UPLOAD="https://speed.cloudflare.com/__up"
#URL_DOWNLOAD="http://speedtest.tele2.net/10MB.zip"

# download
d=$(curl -o /dev/null -s -w '%{speed_download}' "$URL_DOWNLOAD")

# upload (Speed Cloudflare)
u=$(dd if=/dev/zero bs=1M count=10 2>/dev/null | curl -s -X POST -T - -w '%{speed_upload}' "$URL_UPLOAD")

# --- ping & оценка хопов из TTL ---
# предполагаем, что сервер стартует с TTL=64 (типично для Cloudflare/Linux)
INITIAL_TTL=64

ping_line=$(ping -c 1 "$HOST" | awk '/icmp_seq=1/ {print}')
avg_rtt=$(echo "$ping_line" | awk -F'time=' '{print $2}' | awk '{print $1}')
seen_ttl=$(echo "$ping_line" | awk '{for(i=1;i<=NF;i++) if($i ~ /^ttl=/) {sub(/^ttl=/,"",$i); print $i}}')

hops_ping=$((INITIAL_TTL - seen_ttl))

# --- точное число хопов из traceroute ---
hops_tr=$(traceroute -m 30 -n "$HOST" 2>/dev/null | tail -n 1 | awk '{print $1}')

# сравнение количества хопов
diff=$((hops_tr - hops_ping))
if [ "$diff" -lt 0 ]; then diff=$((-diff)); fi

if [ "$diff" -le 3 ]; then
  route_status="OK"
else
  route_status="ВНИМАНИЕ: большая разница маршрутов"
fi

# onscreen
echo "Скорость загрузки: $(echo "scale=2; $d*8/1048576" | bc) Мбит/с"
echo "Скорость выгрузки:   $(echo "scale=2; $u*8/1048576" | bc) Мбит/с"
echo "Средний пинг: ${avg_rtt} ms"
echo "Хопов (оценка из ping, TTL $seen_ttl): ~$hops_ping"
echo "Хопов (traceroute): ${hops_tr}"
echo "Разница хопов (traceroute − ping): $diff → $route_status"
