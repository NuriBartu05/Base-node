#!/bin/bash

# NuriBartu Base Node Kurulum Scripti
# Bu script, Base ağına Geth node kurulumu yapar ve hızlı senkronizasyon (snapshot kullanmadan) başlatır.

# Renklendirme
GREEN="\033[0;32m"
NC="\033[0m"

# Fonksiyonlar
function banner() {
  echo -e "${GREEN}"
  echo "_____   ______  ___________________________________________________  __"
  echo "___  | / /_  / / /__  __ \___  _/__  __ )__    |__  __ \__  __/_  / / /"
  echo "__   |/ /_  / / /__  /_/ /__  / __  __  |_  /| |_  /_/ /_  /  _  / / / "
  echo "_  /|  / / /_/ / _  _, _/__/ /  _  /_/ /_  ___ |  _, _/_  /   / /_/ /  "
  echo "/_/ |_/  \____/  /_/ |_| /___/  /_____/ /_/  |_/_/ |_| /_/    \____/   "
  echo ""
  echo -e "${NC}"
}

function install_dependencies() {
  echo -e "${GREEN}Sunucu guncelleniyor ve gerekli paketler kuruluyor...${NC}"
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y curl git docker.io docker-compose jq screen
  sudo systemctl enable --now docker
}

function setup_node() {
  echo -e "${GREEN}Node kurulumu basliyor...${NC}"

  # Screen baslat
  screen -S base-node -dm bash -c '
    # Klasor olustur
    mkdir -p /opt/base-node/data
    cd /opt/base-node || exit

    # Docker Compose dosyasi olustur
    echo "Docker Compose dosyasi olusturuluyor..."
    cat <<EOF > docker-compose.yml
version: "3.8"
services:
  op-geth:
    image: ghcr.io/base-org/op-geth
    ports:
      - "8545:8545"
    volumes:
      - ./data:/data
    restart: unless-stopped
    command: >
      --datadir /data
      --http
      --http.addr 0.0.0.0
      --http.api eth,net,web3
      --http.corsdomain "*"
      --http.vhosts "*"
      --syncmode full
      --gcmode full
      --rollup.sequencerhttp=https://mainnet-sequencer.base.org
      --rollup.disabletxpoolgossip=true
      --nodiscover
EOF

    # Node'u baslat
    docker-compose up -d

    # Sonsuz bekleme koy, screen kapanmasin
    exec bash
  '

  echo -e "${GREEN}Node kurulumu tamamlandi!${NC}"
  echo "RPC kontrol etmek icin: curl http://<Sunucu_IP>:8545"
}

function health_check_commands() {
  echo -e "${GREEN}Node saglik kontrol komutlari:${NC}"
  echo ""
  echo "Container durumunu kontrol etmek icin:"
  echo "docker ps -a"
  echo ""
  echo "Node senkronizasyon durumunu kontrol etmek icin:"
  echo "curl -s -d '{\"id\":0,\"jsonrpc\":\"2.0\",\"method\":\"optimism_syncStatus\"}' -H 'Content-Type: application/json' http://localhost:8545 | jq"
  echo ""
  echo "Blok gerilik hesaplama komutu:"
  echo "command -v jq &> /dev/null || { echo 'jq is not installed' 1>&2 ; }"
  echo "echo Latest synced block behind by: \\
\$(( ( \$(date +%s) - \\n\$(curl -s -d '{\"id\":0,\"jsonrpc\":\"2.0\",\"method\":\"optimism_syncStatus\"}' -H 'Content-Type: application/json' http://localhost:8545 | jq -r .result.unsafe_l2.timestamp) ) / 60 )) minutes"
}

# Ana Menu
banner

echo "[1] Node Kurulumu"
echo "[2] Node Saglik Kontrol Komutlari"
echo "[0] Cikis"

read -rp "Bir secim yapiniz: " choice

case $choice in
  1)
    install_dependencies
    setup_node
    ;;
  2)
    health_check_commands
    ;;
  0)
    echo "Cikiliyor..."
    exit 0
    ;;
  *)
    echo "Gecersiz secim."
    exit 1
    ;;
esac
