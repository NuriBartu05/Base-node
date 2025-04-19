#!/bin/bash

clear
echo "_____   ______  ___________________________________________________  __"
echo "___  | / /_  / / /__  __ \___  _/__  __ )__    |__  __ \__  __/_  / / /"
echo "__   |/ /_  / / /__  /_/ /__  / __  __  |_  /| |_  /_/ /_  /  _  / / / "
echo "_  /|  / / /_/ / _  _, _/__/ /  _  /_/ /_  ___ |  _, _/_  /   / /_/ /  "
echo "/_/ |_/  \____/  /_/ |_| /___/  /_____/ /_/  |_/_/ |_| /_/    \____/   "
echo ""
echo "[+] Base Node kurulumu başlatılıyor..."

# Adım 1: Sunucuyu Güncelle
echo "[+] Sunucu güncelleniyor..."
sudo apt update && sudo apt upgrade -y

# Gerekli bağımlılıkları kur
echo "[+] Gerekli bağımlılıklar kuruluyor..."
sudo apt install -y curl git docker.io docker-compose jq

# Docker servislerini başlat
echo "[+] Docker başlatılıyor..."
sudo systemctl enable --now docker

# Kurulum dizinlerini oluştur
INSTALL_DIR=~/base-mainnet
DATA_DIR=$INSTALL_DIR/data/geth
mkdir -p $DATA_DIR

# Snapshot indiriliyor
echo "[+] Snapshot indiriliyor..."
cd $INSTALL_DIR
LATEST=$(curl -s https://mainnet-full-snapshots.base.org/latest)
SNAPSHOT_URL=https://mainnet-full-snapshots.base.org/$LATEST
wget $SNAPSHOT_URL -O snapshot.tar.gz

# Snapshot çıkarılıyor
echo "[+] Snapshot çıkarılıyor..."
tar -xzvf snapshot.tar.gz -C $DATA_DIR

# Docker Compose dosyası oluşturuluyor
echo "[+] Docker Compose dosyası oluşturuluyor..."
cat <<EOF > $INSTALL_DIR/docker-compose.yml
version: '3.8'

services:
  op-geth:
    image: ghcr.io/base-org/op-geth
    ports:
      - '8545:8545'
    volumes:
      - ./data/geth:/data
    restart: unless-stopped
    command: >
      --datadir /data \
      --http \
      --http.addr 0.0.0.0 \
      --http.api eth,net,web3 \
      --http.corsdomain '*' \
      --http.vhosts '*' \
      --syncmode full \
      --gcmode=archive \
      --rollup.sequencerhttp=https://mainnet-sequencer.base.org \
      --rollup.disabletxpoolgossip=true \
      --nodiscover
EOF

# Node başlatılıyor
echo "[+] Base Node başlatılıyor..."
docker-compose -f $INSTALL_DIR/docker-compose.yml up -d

# RPC testi
echo "[+] RPC endpoint kontrol ediliyor..."
curl http://localhost:8545

# Sync durumu
echo "[+] Senkronizasyon durumu kontrol ediliyor..."
echo "Latest synced block behind by: " $((($( date +%s )-\
$( curl -s -d '{"id":0,"jsonrpc":"2.0","method":"optimism_syncStatus"}' \
  -H "Content-Type: application/json" http://localhost:8545 | jq -r .result.unsafe_l2.timestamp))/60)) minutes

echo "[✓] Kurulum tamamlandı!"
echo "RPC endpoint: http://$(curl -s ifconfig.me):8545"
echo "WebSocket: ws://$(curl -s ifconfig.me):8546"
