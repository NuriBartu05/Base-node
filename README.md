# **Base Node Kurulumu: Geth ile Snapshot Kullanarak Başlatma**

Bu rehber, **Base ağı** için **Geth** kullanarak **snapshot üzerinden node** kurulumunu adım adım açıklamaktadır. Snapshot, senkronizasyon sürecini hızlandırır ve Base ağı üzerinde işlem yapmaya başlamanızı sağlar.

## **Gereksinimler**
- Ubuntu 20.04 veya 22.04
- Docker ve Docker Compose
- Base ağı **Mainnet** için snapshot dosyası

---

## **Adım 1: Sunucuyu Hazırlama**

Öncelikle sunucunu güncelleyelim ve gerekli yazılımları yükleyelim.

```bash
# Sunucu güncellemeleri
sudo apt update && sudo apt upgrade -y

# Gerekli bağımlılıkları kur
sudo apt install -y curl git docker.io docker-compose
```

---

## **Adım 2: Docker ve Docker Compose Kurulumu**

Eğer Docker ve Docker Compose kurulu değilse, aşağıdaki komutlarla kurulumu gerçekleştirebilirsin.

```bash
# Docker'ı kur
sudo apt install -y docker.io

# Docker Compose'u kur
sudo apt install -y docker-compose

# Docker'ı başlat ve her reboot sonrası otomatik başlatılmasını sağla
sudo systemctl enable --now docker
```

---

## **Adım 3: Snapshot Dosyasını İndirme**

Base ağına ait **Mainnet Geth Full snapshot** dosyasını indirmek için aşağıdaki komutları kullanabilirsin:

```bash
# Snapshot dosyasını indirmek
wget https://mainnet-full-snapshots.base.org/$(curl -s https://mainnet-full-snapshots.base.org/latest) -O snapshot.tar.gz
```

---

## **Adım 4: Snapshot'ı Çıkartma**

Snapshot dosyasını indirdikten sonra, çıkartmak için şu komutu çalıştırabilirsin:

```bash
# Snapshot'ı çıkart
tar -xzvf snapshot.tar.gz -C /path/to/data
```

Burada `/path/to/data` kısmını Base node’unun veri dosyalarının yer alacağı dizinle değiştirmelisin. Örneğin, `/data/geth` gibi bir dizin seçebilirsin.

---

## **Adım 5: Base Node Konfigürasyonu**

Şimdi, Base node'unu çalıştıracak Docker Compose dosyasını oluşturacağız.

1. **Base Node Konfigürasyon Dosyasını Oluşturma**

Aşağıdaki komut ile Docker Compose konfigürasyon dosyasını oluşturabilirsin:

```bash
# Base node dizinine git
cd /path/to/base-node
mkdir -p base-mainnet
cd base-mainnet

# Geth için config dosyasını oluştur
cat <<EOF > docker-compose.yml
version: '3.8'

services:
  op-geth:
    image: ghcr.io/base-org/op-geth
    ports:
      - '8545:8545'
    volumes:
      - ./data/geth:/data
    command: >
      --datadir /data
      --http
      --http.addr 0.0.0.0
      --http.api eth,net,web3
      --http.corsdomain '*'
      --http.vhosts '*'
      --syncmode full
      --gcmode=archive
      --rollup.sequencerhttp=https://mainnet-sequencer.base.org
      --rollup.disabletxpoolgossip=true
      --nodiscover
EOF
```

Bu dosya, Base node’unun Docker ile çalışmasını sağlayacak ve snapshot’ı yükleyerek senkronizasyon başlatacaktır.

2. **Docker Compose ile Node'u Başlatma**

```bash
# Docker Compose ile node'u başlat
docker-compose up -d
```

---

## **Adım 6: RPC'yi Test Etme**

Node'un çalışıp çalışmadığını test etmek için, aşağıdaki komutu kullanarak RPC üzerinden bağlantıyı kontrol edebilirsin:

```bash
curl http://<Sunucu_IP>:8545
```

Sunucu IP’sini kendi sunucunun IP adresiyle değiştirmeyi unutma. Eğer her şey doğru şekilde çalışıyorsa, RPC'den gelen yanıtı görmelisin.

---

## **Senkronizasyon Durumunu Kontrol Etme**

Node'un senkronizasyon durumunu kontrol etmek için şu komutu kullanabilirsin. Bu komut, **optimism_syncStatus** RPC metodunu kullanarak L2 senkronizasyon durumunu kontrol eder.

```bash
command -v jq  &> /dev/null || { echo "jq is not installed" 1>&2 ; }
echo Latest synced block behind by: \
$((($( date +%s )-\
$( curl -s -d '{"id":0,"jsonrpc":"2.0","method":"optimism_syncStatus"}' -H "Content-Type: application/json" http://localhost:7545 |
   jq -r .result.unsafe_l2.timestamp))/60)) minutes
```

Bu komut, **optimism_syncStatus** RPC çağrısını yaparak, en son senkronize edilen blok ile şu anki zaman arasındaki farkı hesaplar. Çıktı şu şekilde olabilir:

```
Latest synced block behind by: 30 minutes
```

Bu, senkronizasyonun şu anda 30 dakika geride olduğunu gösterir.

---

## **Node'un Çalışıp Çalışmadığını Kontrol Etme**

Node'un çalışıp çalışmadığını kontrol etmek için Docker komutlarıyla container durumunu kontrol edebilirsin:

```bash
# Docker container'larının durumunu kontrol et
docker ps -a

# Eğer node çalışıyorsa, container'ı görmelisin.
```

---

## **Sunucu Reboot Sonrası Docker Container'ın Yeniden Başlatılmasını Sağlama**

Sunucunun reboot olması veya terminalden çıkman durumunda Docker container'larının çalışmaya devam etmesini sağlamak için **restart policy** kullanabilirsin.

#### **Docker Compose Kullanıyorsan:**

`docker-compose.yml` dosyana şu satırı ekleyerek, container'ların reboot sonrası otomatik olarak yeniden başlatılmasını sağlayabilirsin:

```yaml
restart: unless-stopped
```

Bu ayar, container'ın sunucu reboot olduktan sonra otomatik olarak yeniden başlatılmasını sağlar. Ancak, container manuel olarak durdurulmadığı sürece yeniden başlatılmaya devam eder.

#### **Docker Komutuyla Container Başlatırken:**

Eğer Docker komutuyla container'ı başlatıyorsan, `--restart` parametresi ile bunu ayarlayabilirsin:

```bash
docker run --restart unless-stopped <image_name>
```

### **Restart Policy Seçenekleri:**
- **unless-stopped**: Container, sunucu reboot olduktan sonra otomatik olarak yeniden başlatılır. Manuel olarak durdurulmadığı sürece çalışmaya devam eder.
- **always**: Container her durumda yeniden başlatılır (manueller dahil).
- **no**: Docker container'ı reboot sonrası yeniden başlamaz.

Bu ayar ile, Base node'unun sunucu reboot olsa bile çalışmaya devam etmesini sağlayabilirsin.

---

## **Ekstra Notlar:**

- **Snapshot ve Senkronizasyon**: Snapshot, Base node'unu hızlı bir şekilde senkronize etmek için kullanılır. Eğer snapshot'tan sonra herhangi bir blok kaybı yaşarsan, Geth otomatik olarak en son blokları senkronize eder.
- **Geth ve Archive Modu**: Base node’unu çalıştırırken `--gcmode=archive` parametresi, daha eski verilere erişebilmeni sağlar. Bu parametre, eski bloklar ve geçmiş işlemler üzerinde tam erişim sunar.

---

### **Sonuç**

Bu rehberle, Base ağı üzerinde **Geth** ile snapshot kullanarak **Base node**'unu sıfırdan kurmuş olduk. Şimdi, Base ağına ait blok verilerine hızlı bir şekilde erişebilir ve işlemler yapabilirsin. Eğer takıldığın bir nokta olursa, GitHub issues veya topluluk forumlarından destek alabilirsin.






# NuriBartu Base Node Kurulum Scripti

Bu script, Base ağı için bir node kurmanı ve yönetmeni sağlar. Script GitHub üzerinden otomatik olarak indirilip çalıştırılabilir.

## Kurulum

Terminale aşağıdaki adımları sırasıyla uygulayın:

### 1. Scripti GitHub üzerinden indir

```bash
curl -O https://raw.githubusercontent.com/NuriBartu05/Base-node/main/nuribartu-base.sh
```

### 2. Scripti çalıştırılabilir hale getir

```bash
chmod +x nuribartu-base.sh
```

### 3. Scripti başlat

```bash
./nuribartu-base.sh
```

## Script Açıldığında

Script başlatıldığında aşağıdaki gibi bir menü ile karşılaşırsınız:

```
[1] Node Kurulumu
[2] Node Sağlık Kontrol Komutları
```

### Seçenekler

- **1** → Sunucuya Base node kurulumunu yapar. Snapshot indirir, yapılandırmaları yapar ve Docker üzerinden node'u başlatır.
- **2** → Node'un senkronize olup olmadığını, en son blok numarasını ve peer sayısını kontrol etmek için kullanabileceğiniz komutları gösterir.

## Gereksinimler

- Ubuntu 20.04 veya 22.04 yüklü bir sunucu
- Docker ve Docker Compose (script tarafından otomatik olarak kuruluyor)
- Root erişimi veya `sudo` yetkisi

---



