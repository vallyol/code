#!/usr/bin/env bash
set -uo pipefail

usage() {
    cat <<'EOF'
Usage:
  doh-test.sh -d DOMAIN [-t TYPE] [-p PROVIDER] [-g GROUP] [-v]

Options:
  -d DOMAIN     Домен для проверки (обязательно)
  -t TYPE       Тип записи: A|AAAA|MX|TXT|NS|CNAME (по умолчанию: A)
  -p PROVIDER   Провайдер: cloudflare|google|quad9|adguard|adguard_family|nextdns|opendns|yandex|mullvad|cleanbrowsing|libredns|snopyta|all
                (по умолчанию: all)
  -g GROUP      Тег для фильтрации: privacy|filtering|family|security|standard
  -v            Подробный вывод
  -h            Справка
EOF
}

if [[ -t 1 ]]; then
    RED=$'\033[31m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    BLUE=$'\033[34m'
    RESET=$'\033[0m'
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    RESET=""
fi

status_ok()   { printf "%sOK%s" "$GREEN" "$RESET"; }
status_warn() { printf "%sWARN%s" "$YELLOW" "$RESET"; }
status_fail() { printf "%sFAIL%s" "$RED" "$RESET"; }

truncate() {
    local s="$1"
    local max="${2:-70}"
    if (( ${#s} > max )); then
        printf "%s..." "${s:0:max-3}"
    else
        printf "%s" "$s"
    fi
}

print_header() {
    printf "%-16s %-10s %-6s %-8s %-24s %-70s\n" "Provider" "Status" "HTTP" "Time" "Tags" "Result"
    printf "%-16s %-10s %-6s %-8s %-24s %-70s\n" "--------" "------" "----" "----" "----" "------"
}

print_row() {
    local provider="$1"
    local status="$2"
    local http="$3"
    local time="$4"
    local tags="$5"
    local result="$6"

    tags="$(truncate "$tags" 24)"
    result="$(truncate "$result" 70)"
    printf "%-16s %-10s %-6s %-8s %-24s %-70s\n" "$provider" "$status" "$http" "$time" "$tags" "$result"
}

DOMAIN=""
TYPE="A"
PROVIDER="all"
GROUP=""
VERBOSE=0

while getopts ":d:t:p:g:vh" opt; do
    case "$opt" in
        d) DOMAIN="$OPTARG" ;;
        t) TYPE="$OPTARG" ;;
        p) PROVIDER="$OPTARG" ;;
        g) GROUP="$OPTARG" ;;
        v) VERBOSE=1 ;;
        h) usage; exit 0 ;;
        \?) echo "Ошибка: неизвестный параметр -$OPTARG" >&2; usage; exit 1 ;;
        :) echo "Ошибка: параметр -$OPTARG требует значение" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$DOMAIN" ]]; then
    echo "Ошибка: укажите домен через -d DOMAIN" >&2
    usage
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Ошибка: curl не найден" >&2
    exit 1
fi

HAS_JQ=0
if command -v jq >/dev/null 2>&1; then
    HAS_JQ=1
fi

declare -A PROVIDERS=(
    [cloudflare]="https://cloudflare-dns.com/dns-query|privacy,security,standard"
    [google]="https://dns.google/dns-query|standard,security"
    [quad9]="https://dns.quad9.net/dns-query|privacy,security"
    [nextdns]="https://dns.nextdns.io|privacy,filtering,family"
    [opendns]="https://doh.opendns.com/dns-query|security,family"
    [cleanbrowsing]="https://doh.cleanbrowsing.org/doh/family-filter|family,filtering"
    [mullvad]="https://doh.mullvad.net/dns-query|privacy,standard"
    [adguard]="https://dns.adguard.com/dns-query|privacy,filtering"
    [adguard_family]="https://dns-family.adguard.com/dns-query|family,filtering"
)

ORDER=(cloudflare google quad9 nextdns opendns cleanbrowsing mullvad adguard adguard_family)

get_url() {
    local name="$1"
    printf "%s" "${PROVIDERS[$name]%%|*}"
}

get_tags() {
    local name="$1"
    printf "%s" "${PROVIDERS[$name]#*|}"
}

match_group() {
    local tags="$1"
    local group="$2"
    [[ -z "$group" ]] && return 0
    [[ ",$tags," == *",$group,"* ]]
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

print_header

test_provider() {
    local name="$1"
    local url="$2"
    local tags="$3"
    local tmp="$TMP_DIR/$name.json"
    local meta="$TMP_DIR/$name.meta"
    local http_code time_total total_ms status answer_count result status_text

    if ! curl -sS \
        --http2 \
        --connect-timeout 5 \
        --max-time 10 \
        -H 'accept: application/dns-json' \
        -o "$tmp" \
        -w '%{http_code} %{time_total}\n' \
        "${url}?name=${DOMAIN}&type=${TYPE}" > "$meta"; then
        status_text="$(status_fail)"
        print_row "$name" "$status_text" "000" "0ms" "$tags" "curl error"
        [[ "$VERBOSE" -eq 1 ]] && cat "$tmp" 2>/dev/null || true
        return
    fi

    read -r http_code time_total < "$meta" || {
        status_text="$(status_fail)"
        print_row "$name" "$status_text" "000" "0ms" "$tags" "parse error"
        return
    }

    total_ms="$(awk -v t="$time_total" 'BEGIN{printf "%.0f", t*1000}')"

    if [[ "$http_code" != "200" ]]; then
        status_text="$(status_warn)"
        print_row "$name" "$status_text" "$http_code" "${total_ms}ms" "$tags" "HTTP error"
        [[ "$VERBOSE" -eq 1 ]] && cat "$tmp"
        return
    fi

    if [[ "$HAS_JQ" -eq 1 ]]; then
        status="$(jq -r '.Status // empty' "$tmp")"
        answer_count="$(jq '.Answer | length // 0' "$tmp")"

        if [[ "$status" == "0" ]]; then
            if [[ "$answer_count" -gt 0 ]]; then
                result="$(jq -r '.Answer[]? | "\(.name) \(.TTL) \(.type) \(.data)"' "$tmp" | paste -sd '; ' -)"
            else
                result="no answers"
            fi
            status_text="$(status_ok)"
            print_row "$name" "$status_text" "$http_code" "${total_ms}ms" "$tags" "$result"
        else
            status_text="$(status_warn)"
            print_row "$name" "$status_text" "$http_code" "${total_ms}ms" "$tags" "DNS Status=${status:-unknown}"
            [[ "$VERBOSE" -eq 1 ]] && jq '.' "$tmp"
        fi
    else
        if grep -q '"Status":[[:space:]]*0' "$tmp"; then
            result="$(grep -o '"data":"[^"]*"' "$tmp" | head -n 3 | sed 's/"data":"//; s/"$//' | paste -sd '; ' -)"
            [[ -n "$result" ]] || result="ok"
            status_text="$(status_ok)"
            print_row "$name" "$status_text" "$http_code" "${total_ms}ms" "$tags" "$result"
        else
            status_text="$(status_warn)"
            print_row "$name" "$status_text" "$http_code" "${total_ms}ms" "$tags" "DNS Status!=0"
            [[ "$VERBOSE" -eq 1 ]] && cat "$tmp"
        fi
    fi
}

if [[ "$PROVIDER" == "all" ]]; then
    for name in "${ORDER[@]}"; do
        tags="$(get_tags "$name")"
        if match_group "$tags" "$GROUP"; then
            test_provider "$name" "$(get_url "$name")" "$tags"
        fi
    done
else
    if [[ -z "${PROVIDERS[$PROVIDER]:-}" ]]; then
        echo "Ошибка: неизвестный провайдер '$PROVIDER'" >&2
        exit 1
    fi

    tags="$(get_tags "$PROVIDER")"
    if ! match_group "$tags" "$GROUP"; then
        echo "Провайдер '$PROVIDER' не подходит под группу '$GROUP'" >&2
        exit 0
    fi

    test_provider "$PROVIDER" "$(get_url "$PROVIDER")" "$tags"
fi
