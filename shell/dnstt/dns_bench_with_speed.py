#!/usr/bin/env python3
import subprocess
import re
import sys

# Список популярных публичных и провайдерских DNS-серверов
DNS_SERVERS = {
    "Google Primary": "8.8.8.8",
    "Google Secondary": "8.8.4.4",
    "Yandex Basic": "77.88.8.8",
    "Yandex Safe": "77.88.8.88",
    "Cloudflare": "1.1.1.1",
    "Cisco OpenDNS": "208.67.222.222",
    "Quad9": "9.9.9.9",
    "Beeline Main": "194.67.1.1",
    "Beeline Backup": "85.21.192.3"
}

def get_ping_stats(ip):
    try:
        res = subprocess.run(["ping", "-c", "4", "-W", "2", ip], capture_output=True, text=True, check=True)
        match = re.search(r"rtt min/avg/max/mdev = [\d\.]+/(?P<avg>[\d\.]+)/", res.stdout)
        if match:
            return float(match.group("avg")), "0%"
        return None, "100%"
    except subprocess.CalledProcessError:
        return None, "100%"

def get_dig_time(ip):
    try:
        res = subprocess.run(["dig", f"@{ip}", "youtube.com", "+stats", "+time=2"], capture_output=True, text=True, check=True)
        match = re.search(r"Query time:\s+(\d+)\s+msec", res.stdout)
        if match:
            return int(match.group(1))
        return None
    except subprocess.CalledProcessError:
        return None

def calculate_tunnel_speed(dig_time):
    if dig_time is None or dig_time <= 0:
        return 0, 0
    # Математика: 20 потоков * (1000 мс / dig_time) = Запросов в секунду (RPS)
    # RPS * 500 байт = Байт в секунду
    # Байт в секунду * 8 / 1000 = Кбит/с (Kbps)
    # Байт в секунду / 1024 = Кбайт/с (KB/s)
    rps = 20 * (1000 / dig_time)
    bytes_per_sec = rps * 500
    kbps = (bytes_per_sec * 8) / 1000
    kbytes_per_sec = bytes_per_sec / 1024
    return int(kbps), int(kbytes_per_sec)

def main():
    # Расширяем шапку таблицы под новые колонки скорости
    print(f"{'Название DNS':<18} | {'IP-Адрес':<15} | {'Ping avg (мс)':<14} | {'Потери':<7} | {'Dig time (мс)':<14} | {'Est. Tunnel Speed':<20}")
    print("-" * 105)

    results = []

    for name, ip in DNS_SERVERS.items():
        ping_avg, loss = get_ping_stats(ip)
        dig_time = get_dig_time(ip) if loss != "100%" else None

        kbps, kbytes = calculate_tunnel_speed(dig_time)

        results.append({
            "name": name,
            "ip": ip,
            "ping": ping_avg if ping_avg is not None else float('inf'),
            "loss": loss,
            "dig": dig_time if dig_time is not None else float('inf'),
            "kbps": kbps,
            "kbytes": kbytes
        })

    # Сортируем: сначала работающие, затем по МАКСИМАЛЬНОЙ скорости туннеля (kbps) в порядке убывания
    results.sort(key=lambda x: (x["loss"] == "100%", -x["kbps"]))

    for r in results:
        ping_str = f"{r['ping']:.1f}" if r['ping'] != float('inf') else "Мертв"
        dig_str = f"{r['dig']}" if r['dig'] != float('inf') else "Таймаут"

        if r['kbps'] > 0:
            speed_str = f"~{r['kbps']} Kbps ({r['kbytes']} KB/s)"
        else:
            speed_str = "0 Kbps"

        print(f"{r['name']:<18} | {r['ip']:<15} | {ping_str:<14} | {r['loss']:<7} | {dig_str:<14} | {speed_str:<20}")

if __name__ == "__main__":
    main()
