#!/bin/bash

# IPTV Sistemi - Hızlı Kurulum
# Ubuntu 22.04 için tek komut kurulum

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
echo -e "${GREEN}IPTV Sistemi - Hızlı Kurulum${NC}"
echo -e "${YELLOW}179,101 Kanal • 40 Ülke • 285 Kategori${NC}"
echo ""

# Sistem kontrolü
echo -e "${BLUE}[1/4]${NC} Sistem kontrol ediliyor..."
if [[ "$EUID" -eq 0 ]]; then
    echo -e "${RED}HATA: Bu script root kullanıcısı ile çalıştırılmamalıdır!${NC}"
    echo -e "${YELLOW}Lütfen normal kullanıcı ile çalıştırın: ${NC}wget -O - DOWNLOAD_URL | bash"
    exit 1
fi

# Gerekli araçları yükle
echo -e "${BLUE}[2/4]${NC} Gerekli araçlar yükleniyor..."
sudo apt-get update -qq
sudo apt-get install -y wget unzip curl

# Projeyi indir
echo -e "${BLUE}[3/4]${NC} Proje dosyaları indiriliyor..."
cd /tmp
rm -rf iptv-system*

# Buraya upload URL'si gelecek
DOWNLOAD_URL="PLACEHOLDER_DOWNLOAD_URL"
wget -O iptv-system.zip "$DOWNLOAD_URL"
unzip -q iptv-system.zip

# Kurulum scriptini çalıştır
echo -e "${BLUE}[4/4]${NC} Kurulum başlatılıyor..."
cd iptv-system
chmod +x install.sh
./install.sh

echo -e "${GREEN}Hızlı kurulum tamamlandı! 🚀${NC}"

