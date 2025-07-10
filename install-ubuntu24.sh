#!/bin/bash

# IPTV Sistemi - Ubuntu 24.04 Uyumlu Kurulum
# Otomatik kurulum scripti

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logo
echo -e "${BLUE}"
echo "██╗██████╗ ████████╗██╗   ██╗    ███████╗██╗   ██╗███████╗████████╗███████╗███╗   ███╗"
echo "██║██╔══██╗╚══██╔══╝██║   ██║    ██╔════╝╚██╗ ██╔╝██╔════╝╚══██╔══╝██╔════╝████╗ ████║"
echo "██║██████╔╝   ██║   ██║   ██║    ███████╗ ╚████╔╝ ███████╗   ██║   █████╗  ██╔████╔██║"
echo "██║██╔═══╝    ██║   ╚██╗ ██╔╝    ╚════██║  ╚██╔╝  ╚════██║   ██║   ██╔══╝  ██║╚██╔╝██║"
echo "██║██║        ██║    ╚████╔╝     ███████║   ██║   ███████║   ██║   ███████╗██║ ╚═╝ ██║"
echo "╚═╝╚═╝        ╚═╝     ╚═══╝      ╚══════╝   ╚═╝   ╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝"
echo -e "${NC}"
echo -e "${GREEN}IPTV Sistemi - Ubuntu 24.04 Uyumlu Kurulum${NC}"
echo -e "${YELLOW}179,101 Kanal • 40 Ülke • 285 Kategori${NC}"
echo ""

# Sistem kontrolü
echo -e "${BLUE}[1/8]${NC} Sistem kontrol ediliyor..."
if [[ "$EUID" -eq 0 ]]; then
    echo -e "${RED}HATA: Bu script root kullanıcısı ile çalıştırılmamalıdır!${NC}"
    exit 1
fi

# Ubuntu sürümü kontrol
UBUNTU_VERSION=$(lsb_release -rs)
echo "Ubuntu sürümü: $UBUNTU_VERSION"

# Node.js çakışmasını çöz
echo -e "${BLUE}[2/8]${NC} Node.js çakışması çözülüyor..."
sudo apt-get remove -y nodejs npm 2>/dev/null || true
sudo apt-get autoremove -y
sudo apt-get autoclean

# Sistem paketleri
echo -e "${BLUE}[3/8]${NC} Sistem paketleri yükleniyor..."
sudo apt-get update
sudo apt-get install -y curl wget python3 python3-pip python3-venv sqlite3 nginx unzip

# Node.js 20 yükle (Ubuntu 24.04 uyumlu)
echo -e "${BLUE}[4/8]${NC} Node.js 20 yükleniyor..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# pnpm yükle
echo -e "${BLUE}[5/8]${NC} pnpm yükleniyor..."
sudo npm install -g pnpm

# Proje dizini oluştur
echo -e "${BLUE}[6/8]${NC} Proje dizini hazırlanıyor..."
sudo mkdir -p /opt/iptv-system
sudo chown $USER:$USER /opt/iptv-system
cp -r . /opt/iptv-system/
cd /opt/iptv-system

# Backend kurulum
echo -e "${BLUE}[7/8]${NC} Backend kuruluyor..."
cd iptv-backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Veritabanı oluştur ve M3U yükle
echo "Veritabanı oluşturuluyor ve M3U yükleniyor..."
python3 src/main.py &
BACKEND_PID=$!
sleep 5

# M3U yükle
curl -X POST http://localhost:5000/api/admin/update-m3u \
  -H "Content-Type: application/json" \
  -d '{"m3u_url": "http://arc4949.xyz:80/get.php?username=turko8ii&password=Tv8828&type=m3u_plus&output=ts"}' || true

kill $BACKEND_PID 2>/dev/null || true
deactivate

# Frontend kurulum
echo -e "${BLUE}[8/8]${NC} Frontend kuruluyor..."
cd ../iptv-frontend
pnpm install
pnpm run build

# Frontend dosyalarını backend'e kopyala
cp -r dist/* ../iptv-backend/src/static/

# Systemd servisi oluştur
echo "Systemd servisi oluşturuluyor..."
sudo tee /etc/systemd/system/iptv-backend.service > /dev/null <<EOF
[Unit]
Description=IPTV Backend Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/iptv-system/iptv-backend
Environment=PATH=/opt/iptv-system/iptv-backend/venv/bin
ExecStart=/opt/iptv-system/iptv-backend/venv/bin/python src/main.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Nginx konfigürasyonu
echo "Nginx konfigürasyonu..."
sudo tee /etc/nginx/sites-available/iptv-system > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/iptv-system /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Servisleri başlat
echo "Servisler başlatılıyor..."
sudo systemctl daemon-reload
sudo systemctl enable iptv-backend
sudo systemctl start iptv-backend
sudo systemctl restart nginx

# Firewall ayarları
echo "Firewall ayarları..."
sudo ufw allow 80/tcp 2>/dev/null || true

echo ""
echo -e "${GREEN}🎉 IPTV Sistemi başarıyla kuruldu!${NC}"
echo ""
echo -e "${YELLOW}📱 Erişim:${NC}"
echo -e "   Web arayüzü: ${BLUE}http://$(hostname -I | awk '{print $1}')${NC}"
echo ""
echo -e "${YELLOW}🔧 Yönetim komutları:${NC}"
echo -e "   Durum kontrol: ${GREEN}sudo systemctl status iptv-backend${NC}"
echo -e "   Yeniden başlat: ${GREEN}sudo systemctl restart iptv-backend${NC}"
echo -e "   Logları görüntüle: ${GREEN}sudo journalctl -u iptv-backend -f${NC}"
echo ""
echo -e "${GREEN}Kurulum tamamlandı! 🚀${NC}"

