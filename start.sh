#!/bin/sh
echo "Starting setup in Docker please wait"
pkill xray || true
pkill tun2socks || true
sleep 2

# Загружаем переменные из .env если файл существует
if [ -f "/etc/xray/.env" ]; then
    set -o allexport
    source /etc/xray/.env
    set +o allexport
fi

# Проверяем обязательные переменные
: ${SERVER_ADDRESS:?Не задана SERVER_ADDRESS}
: ${SERVER_PORT:?Не задана SERVER_PORT}
: ${USER_ID:?Не задана USER_ID}
: ${ENCRYPTION:?Не задана ENCRYPTION}
: ${FLOW:?Не задана FLOW}
: ${FINGERPRINT_FP:?Не задана FINGERPRINT}
: ${SERVER_NAME_SNI:?Не задана SERVER_NAME}
: ${PUBLIC_KEY_PBK:?Не задана PUBLIC_KEY}
: ${SHORT_ID_SID:?Не задана SHORT_ID}
: ${GATEWAY:?Не задана GATEWAY}
: ${ADAPTER_NAME:?Не задана ADAPTER}

# Получение IP-адреса сервера
SERVER_IP_ADDRESS=$(getent ahosts $SERVER_ADDRESS | head -n 1 | awk '{print $1}')

if [ -z "$SERVER_IP_ADDRESS" ]; then
  echo "Failed to obtain an IP address for FQDN $SERVER_ADDRESS"
  exit 1
fi

# Настройка TUN интерфейса
ip tuntap del mode tun dev tun0 2>/dev/null || true

#ip tuntap add mode tun dev tun0
# Создание tun0
ip tuntap add mode tun dev tun0 || { echo "Не удалось создать tun0"; exit 1; }
ip link set tun0 up || { echo "Не удалось поднять tun0"; exit 1; }

# Проверка gateway
if [ -z "$GATEWAY" ]; then
  echo "GATEWAY не указан! Используйте IP основного интерфейса."
  exit 1
fi

ip addr add 172.31.200.10/30 dev tun0
ip link set dev tun0 up

# Маршрутизация
ip route del default || true
ip route add default via 172.31.200.10
ip route add $SERVER_IP_ADDRESS/32 via $GATEWAY
ip route add 1.0.0.1/32 via $GATEWAY
ip route add 8.8.4.4/32 via $GATEWAY
ip route add 192.168.0.0/16 via $GATEWAY
ip route add 10.0.0.0/8 via $GATEWAY
ip route add 172.16.0.0/12 via $GATEWAY

#Настройка dns
echo "nameserver $GATEWAY" > /etc/resolv.conf
echo "nameserver 1.0.0.1" >> /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

# Конфиг Xray
cat <<EOF > /etc/xray/config.json
{
  "log": {
    "loglevel": "silent"
  },
  "inbounds": [
    {
      "port": 10800,
      "listen": "0.0.0.0",
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "$SERVER_ADDRESS",
            "port": $SERVER_PORT,
            "users": [
              {
                "id": "$USER_ID",
                "flow": "$FLOW",
                "encryption": "$ENCRYPTION",
                "alterId": 0
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "fingerprint": "$FINGERPRINT_FP",
          "serverName": "$SERVER_NAME_SNI",
          "publicKey": "$PUBLIC_KEY_PBK",
          "spiderX": "",
          "shortId": "$SHORT_ID_SID"
        }
      },
      "tag": "proxy"
    }
  ]
}
EOF


# Очистка старых правил iptables
iptables -F
iptables -t nat -F
iptables -X

# Настройка NAT
iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
iptables -A FORWARD -i tun0 -o $ADAPTER_NAME -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $ADAPTER_NAME -o tun0 -j ACCEPT

# Запуск Xray в foreground
echo "Start Xray core"
/opt/xray/xray run -config /etc/xray/config.json &

# Запуск tun2socks в foreground
echo "Start tun2socks"
/opt/tun2socks/tun2socks -loglevel silent -tcp-sndbuf 3m -tcp-rcvbuf 3m -device tun0 -proxy socks5://127.0.0.1:10800 -interface eth0 &

echo "Docker setup is complete"

# Бесконечный цикл чтобы контейнер не завершался
while true; do sleep 3600; done
