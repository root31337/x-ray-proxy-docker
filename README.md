# x-ray-proxy-docker
XRay Vless Reality Docker in Linux (raspberry pi)

#Переменные задаются в .env
cope .env.template .env

#Для сборки образа
docker build -t xray-tun2socks-arm .

#Для запуска 
sudo docker run --name xray-proxy   --network host   --cap-add=NET_ADMIN   --cap-add=NET_RAW   --cap-add=SYS_MODULE   -v /dev/net/tun:/dev/net/tun   --device /dev/net/tun   --privileged   -d xray-tun2socks-arm

#Для проверки туннеля
curl --interface tun0 https://www.cloudflare.com/cdn-cgi/trace
