# XRay Proxy Docker for Linux (Raspberry Pi)

Docker контейнер для настройки клиента XRay с Vless Reality на Linux (включая Raspberry Pi) с использованием tun2socks для туннелирования трафика.

## Быстрый старт
   
### Подготовка
Переменные окружения
Все настройки задаются в файле .env. Используйте .env.template как образец для создания своего файла .env.

1. Скопируйте файл `.env.template` в `.env`:
   ```bash
   cp .env.template .env

2. Отредактируйте файл .env, задав необходимые переменные окружения.

### Сборка образа
```bash
docker build -t xray-tun2socks-arm .


### Запуск контейнера
```bash
sudo docker run --name xray-proxy --network host \
  --cap-add=NET_ADMIN --cap-add=NET_RAW --cap-add=SYS_MODULE \
  -v /dev/net/tun:/dev/net/tun --device /dev/net/tun \
  --privileged -d xray-tun2socks-arm```

###проверка работы
Проверить работу туннеля можно командой:

```bash
curl --interface tun0 https://www.cloudflare.com/cdn-cgi/trace```


###Требования
Docker установленный на системе
Доступ к сети (для загрузки базового образа)
Привилегии root для запуска контейнера (из-за работы с сетевыми интерфейсами)

###Особенности
Контейнер требует привилегированного режима из-за работы с сетевыми интерфейсами
Используется режим host для сети
Автоматически настраивается туннель через tun0



