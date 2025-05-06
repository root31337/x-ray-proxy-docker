# Используем многоэтапную сборку
ARG PLATFORM=linux/arm/v7
ARG FROM_IMAGE=alpine
ARG FROM_VERSION=3.18

# Билдер этап
FROM --platform=${PLATFORM} ${FROM_IMAGE}:${FROM_VERSION} AS builder

# Устанавливаем зависимости для сборки
RUN apk add --no-cache curl unzip

# Версии
ARG XRAY_VERSION="v1.8.11"
ARG TUN2SOCKS_VERSION="v2.5.2"

WORKDIR /tmp

# Скачиваем бинарники
RUN curl -L https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-arm32-v7a.zip --output Xray-linux-arm32-v7a.zip && \
    unzip Xray-linux-arm32-v7a.zip -d /tmp/xray && \
    curl -L https://github.com/xjasonlyu/tun2socks/releases/download/${TUN2SOCKS_VERSION}/tun2socks-linux-armv7.zip --output tun2socks-linux-armv7.zip && \
    unzip tun2socks-linux-armv7.zip -d /tmp/tun2socks

# Финальный образ
FROM --platform=${PLATFORM} ${FROM_IMAGE}:${FROM_VERSION}

# Копируем бинарники
COPY --from=builder /tmp/xray/xray /opt/xray/xray
COPY --from=builder /tmp/tun2socks/tun2socks-linux-armv7 /opt/tun2socks/tun2socks

# Устанавливаем runtime зависимости
RUN apk add --no-cache \
    iproute2 \
    iptables \
    libcap \
    && rm -rf /var/cache/apk/*

# Настраиваем capability
RUN setcap cap_net_admin+ep /opt/xray/xray && \
    setcap cap_net_admin+ep /opt/tun2socks/tun2socks

# Создаем директории
RUN mkdir -p /etc/xray

# Копируем скрипт и переменные
COPY start.sh /usr/local/bin/start.sh
COPY .env /etc/xray/.env

RUN chmod +x /usr/local/bin/start.sh

WORKDIR /etc/xray

ENTRYPOINT ["/usr/local/bin/start.sh"]
