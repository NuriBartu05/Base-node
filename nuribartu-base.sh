#!/bin/bash

clear
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║ ███╗   ██╗██╗   ██╗██████╗ ██╗██████╗  █████╗ ██████╗ ███████╗║"
echo "║ ████╗  ██║██║   ██║██╔══██╗██║██╔══██╗██╔══██╗██╔══██╗██╔════╝║"
echo "║ ██╔██╗ ██║██║   ██║██████╔╝██║██████╔╝███████║██║  ██║█████╗  ║"
echo "║ ██║╚██╗██║██║   ██║██╔═══╝ ██║██╔═══╝ ██╔══██║██║  ██║██╔══╝  ║"
echo "║ ██║ ╚████║╚██████╔╝██║     ██║██║     ██║  ██║██████╔╝███████╗║"
echo "║ ╚═╝  ╚═══╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝  ╚═╝╚═════╝ ╚══════╝║"
echo "║                                                              ║"
echo "║                   Base Node Kurulum Scripti                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"

read -p "Sunucunun IP adresini giriniz (örnek: 1.2.3.4): " SERVER_IP

echo -e "\n[1] Node Kurulumu"
echo "[2] Node Sağlık Kontrol Komutları"
echo ""

read -p "Seçiminiz (1/2): " CHOICE

if [ "$CHOICE" == "1" ]; then
  echo -e "\n[+] Sistem güncelleniyor ve gerekli paketler kuruluyor..."
  apt update && apt upgrade -y
  apt install -y docker.io docker-compose curl unzip lz4 build-essential git make ufw

  echo -e "\n[+] Çalışma dizini oluşturuluyor..."
  mkdir -p /opt/base-node && cd /opt/base-node

  echo -e "\n[+] Güvenlik duvarı ayarlanıyor..."
  ufw allow 8545
  ufw allow 8546
  ufw reload

  echo -e "\n[+] Log dizini oluşturuluyor..."
  mkdir -p /opt/base-node/logs

  echo -e "\n[+] Base Geth kaynakları indiriliyor..."
  git clone https://github.com/ethereum-optimism/op-geth.git && cd op-geth
  git checkout base
  make geth
  cd ..

  echo -e "\n[+] Snapshot indiriliyor..."
  curl -L https://snapshots.base.org/mainnet/geth.tar.lz4 -o geth.tar.lz4

  echo -e "\n[+] Snapshot çıkarılıyor..."
  mkdir -p data
  tar --use-compress-program=lz4 -xf geth.tar.lz4 -C data

  echo -e "\n[+] Docker Compose dosyası oluşturuluyor..."
  cat <<EOF > docker-compose.yml
version: "3.9"
services:
  base-node:
    image: ethereumoptimism/op-geth
    container_name: base-node
    restart: always
    command: |
      --datadir=/data
      --http
      --http.addr=0.0.0.0
      --http.port=8545
      --http.api=web3,eth,debug,net
      --ws
      --ws.addr=0.0.0.0
      --ws.port=8546
      --ws.api=web3,eth,debug,net
      --syncmode=full
      --gcmode=archive
    volumes:
      - ./data:/data
    ports:
      - "8545:8545"
      - "8546:8546"
EOF

  echo -e "\n[+] Node başlatılıyor..."
  docker-compose up -d

  echo -e "\n[✓] Kurulum tamamlandı!"
  echo "RPC endpoint: http://$SERVER_IP:8545"
  echo "WebSocket: ws://$SERVER_IP:8546"

elif [ "$CHOICE" == "2" ]; then
  echo -e "\n[+] Sağlık Kontrol Komutları:\n"
  echo "Node senkronize mi?"
  echo 'curl -X POST http://localhost:8545 -H "Content-Type: application/json" --data '\''{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'\'''
  echo ""
  echo "En son blok numarası:"
  echo 'curl -X POST http://localhost:8545 -H "Content-Type: application/json" --data '\''{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'\'''
  echo ""
  echo "Peer sayısı:"
  echo 'curl -X POST http://localhost:8545 -H "Content-Type: application/json" --data '\''{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'\'''
  echo ""
else
  echo "Geçersiz seçim yaptınız. Lütfen 1 veya 2 girin."
fi
