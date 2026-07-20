#!/bin/bash

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
NC='\033[0m'

if command -v getprop &> /dev/null && [ -n "$(getprop net.rmnet0.dns1 2>/dev/null)" ]; then
    current_dns=$(getprop net.rmnet0.dns1)
else
    current_dns=$(grep '^nameserver' /etc/resolv.conf | awk '{print $2}' | head -1)
fi

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

fake_domain="check-hijack-$(date +%s%N).test"

echo -e "\n${CYAN}=== ЗАПУСК ТЕСТА DNS ===${NC}"
echo "Целевой домен: $domain"
echo "Тестовый домен: $fake_domain"
echo ""

printf "${GREEN}%-24s %-22s %-14s %-10s %-10s %-10s %-10s${NC}\n" "Сервис" "IP Сервера" "Статус" "RealTime" "RCODE" "FakeRCODE" "Проверка"
printf "${GREEN}%s${NC}\n" "---------------------------------------------------------------------------------------"

test_dns() {
    local name="$1"
    local ip="$2"
    local is_current="$3"

    local real_domain_resp fake_domain_resp
    local real_time real_rcode fake_rcode
    local fake_answer_rows fake_answer_count spoof_status

    real_domain_resp=$(dig @"$ip" "$domain" +norecurse +stats +time=2 +tries=1 2>/dev/null)
    real_time=$(awk '/Query time:/{print $4 " " $5}' <<< "$real_domain_resp" | head -1)
    real_rcode=$(awk -F'status: ' '/status: /{print $2}' <<< "$real_domain_resp" | awk -F',' '{print $1}' | head -1)

    fake_domain_resp=$(dig @"$ip" "$fake_domain" +norecurse +noall +comments +answer +authority +stats +time=2 +tries=1 2>/dev/null)
    fake_rcode=$(awk -F'status: ' '/status: /{print $2}' <<< "$fake_domain_resp" | awk -F',' '{print $1}' | head -1)

    fake_answer_rows=$(awk '
        /^;; ANSWER SECTION:/{in_answer=1; next}
        /^;; AUTHORITY SECTION:/{in_answer=0}
        in_answer
    ' <<< "$fake_domain_resp")

    fake_answer_count=$(grep -cE '^\S+.*\sIN\s+(A|AAAA)\s+' <<< "$fake_answer_rows" 2>/dev/null)
    spoof_status="Нет"

    if [[ "$fake_rcode" == "NXDOMAIN" ]]; then
        spoof_status="Нет"
    elif [[ "$fake_answer_count" -gt 0 ]]; then
        spoof_status="ПОДМЕНА!"
    elif [[ "$fake_rcode" == "NOERROR" ]]; then
        spoof_status="Нет"
    else
        spoof_status="Неопределено"
    fi

    if [[ "$is_current" == true ]]; then
        printf "${YELLOW}%-18s %-15s${NC} ${GREEN}%-8s${NC} %-10s %-10s %-10s %-10s\n" \
            "$name" "$ip" "OK" "${real_time:-N/A}" "${real_rcode:-N/A}" "${fake_rcode:-N/A}" "$spoof_status"
    else
        if [[ "$spoof_status" == "ПОДМЕНА!" ]]; then
            printf "%-18s %-15s ${GREEN}%-8s${NC} %-10s %-10s %-10s ${RED}%-10s${NC}\n" \
                "$name" "$ip" "OK" "${real_time:-N/A}" "${real_rcode:-N/A}" "${fake_rcode:-N/A}" "$spoof_status"
        else
            printf "%-18s %-15s ${GREEN}%-8s${NC} %-10s %-10s %-10s %-10s\n" \
                "$name" "$ip" "OK" "${real_time:-N/A}" "${real_rcode:-N/A}" "${fake_rcode:-N/A}" "$spoof_status"
        fi
    fi
}

if [[ -n "$current_dns" ]]; then
    test_dns "Current DNS" "$current_dns" true
    echo "---------------------------------------------------------------------------------------"
fi

for name in "${!servers[@]}"; do
    ip="${servers[$name]}"
    [[ "$ip" == "$current_dns" ]] && continue
    test_dns "$name" "$ip" false
done

echo ""
