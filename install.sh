#!/bin/bash

# IPTV Sistemi Otomatik Kurulum Scripti
# Ubuntu 22.04 için hazırlanmıştır

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logo
echo -e "${BLUE}"
echo "██╗██████╗ ████████╗██╗   ██╗    ███████╗██╗   ██╗███████╗████████╗███████╗███╗   ███╗"
echo "██║██╔══██╗╚══██╔══╝██║   ██║    ██╔════╝╚██╗ ██╔╝██╔════╝╚══██╔══╝██╔════╝████╗ ████║"
echo "██║██████╔╝   ██║   ██║   ██║    ███████╗ ╚████╔╝ ███████╗   ██║   █████╗  ██╔████╔██║"
echo "██║██╔═══╝    ██║   ╚██╗ ██╔╝    ╚════██║  ╚██╔╝  ╚════██║   ██║   ██╔══╝  ██║╚██╔╝██║"
echo "██║██║        ██║    ╚████╔╝     ███████║   ██║   ███████║   ██║   ███████╗██║ ╚═╝ ██║"
echo "╚═╝╚═╝        ╚═╝     ╚═══╝      ╚══════╝   ╚═╝   ╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝"
echo -e "${NC}"
echo -e "${GREEN}IPTV Sistemi - Otomatik Kurulum${NC}"
echo -e "${YELLOW}179,101 Kanal • 40 Ülke • 285 Kategori${NC}"
echo ""

# Sistem kontrolü
echo -e "${BLUE}[1/8]${NC} Sistem kontrol ediliyor..."
if [[ "$EUID" -eq 0 ]]; then
    echo -e "${RED}HATA: Bu script root kullanıcısı ile çalıştırılmamalıdır!${NC}"
    exit 1
fi

if ! command -v lsb_release &> /dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y lsb-release
fi

OS_VERSION=$(lsb_release -rs)
if [[ "$OS_VERSION" != "22.04" ]]; then
    echo -e "${YELLOW}UYARI: Bu script Ubuntu 22.04 için optimize edilmiştir. Mevcut sürüm: $OS_VERSION${NC}"
fi

# Gerekli paketleri yükle
echo -e "${BLUE}[2/8]${NC} Sistem paketleri yükleniyor..."
sudo apt-get update -qq
sudo apt-get install -y curl wget git python3 python3-pip python3-venv nodejs npm nginx sqlite3 unzip

# Node.js 20 yükle
echo -e "${BLUE}[3/8]${NC} Node.js 20 yükleniyor..."
if ! node --version | grep -q "v20"; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# pnpm yükle
if ! command -v pnpm &> /dev/null; then
    sudo npm install -g pnpm
fi

# Proje dizinini oluştur
PROJECT_DIR="/opt/iptv-system"
echo -e "${BLUE}[4/8]${NC} Proje dizini hazırlanıyor: $PROJECT_DIR"
sudo mkdir -p $PROJECT_DIR
sudo chown $USER:$USER $PROJECT_DIR

# Backend kurulumu
echo -e "${BLUE}[5/8]${NC} Backend kuruluyor..."
cd $PROJECT_DIR

# Python virtual environment
python3 -m venv iptv-backend/venv
source iptv-backend/venv/bin/activate
pip install -r iptv-backend/requirements.txt

# Veritabanını oluştur ve M3U'yu yükle
echo -e "${BLUE}[6/8]${NC} Veritabanı oluşturuluyor ve kanallar yükleniyor..."
cd iptv-backend
python3 -c "
import sys
sys.path.append('src')
from main import create_app, db
app = create_app()
with app.app_context():
    db.create_all()
    print('Veritabanı tabloları oluşturuldu')
"

# M3U'yu yükle
python3 -c "
import sys
sys.path.append('src')
import requests
import re
import sqlite3
from collections import defaultdict

def parse_m3u():
    url = 'http://arc4949.xyz:80/get.php?username=turko8ii&password=Tv8828&type=m3u_plus&output=ts'
    db_path = 'src/database/iptv.db'
    
    print('M3U dosyası indiriliyor...')
    response = requests.get(url, timeout=120)
    content = response.text
    
    print('Veritabanı bağlantısı kuruluyor...')
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Eski verileri temizle
    cursor.execute('DELETE FROM channels')
    cursor.execute('DELETE FROM main_categories')
    cursor.execute('DELETE FROM sub_categories') 
    cursor.execute('DELETE FROM category_types')
    
    lines = content.split('\n')
    
    countries = {}
    categories = {}
    types = {}
    
    def get_or_create_country(country_name):
        if country_name not in countries:
            cursor.execute('''
                INSERT INTO main_categories (name, display_name, channel_count) 
                VALUES (?, ?, 0)
            ''', (country_name, country_name))
            countries[country_name] = cursor.lastrowid
        return countries[country_name]
    
    def get_or_create_category(category_name, country_id):
        key = f'{country_id}::{category_name}'
        if key not in categories:
            cursor.execute('''
                INSERT INTO sub_categories (name, main_category_id, channel_count) 
                VALUES (?, ?, 0)
            ''', (category_name, country_id))
            categories[key] = cursor.lastrowid
        return categories[key]
    
    def get_or_create_type(type_name, category_id):
        key = f'{category_id}::{type_name}'
        if key not in types:
            cursor.execute('''
                INSERT INTO category_types (name, sub_category_id) 
                VALUES (?, ?)
            ''', (type_name, category_id))
            types[key] = cursor.lastrowid
        return types[key]
    
    def parse_group_title(group_title):
        if not group_title or not group_title.strip():
            return None, None, None
            
        if '★' not in group_title:
            return group_title.strip(), None, None
            
        parts = group_title.split('★', 1)
        if len(parts) != 2:
            return group_title.strip(), None, None
            
        country = parts[0].strip()
        rest = parts[1].strip()
        
        if '|' in rest:
            pipe_parts = [p.strip() for p in rest.split('|')]
            category = pipe_parts[0] if pipe_parts else rest
            type_name = pipe_parts[1] if len(pipe_parts) > 1 and pipe_parts[1] else None
        else:
            category = rest
            type_name = None
            
        return country, category, type_name
    
    print('Kanallar parse ediliyor...')
    
    current_extinf = None
    channel_count = 0
    
    group_title_pattern = r'group-title=\"([^\"]*)\"'
    tvg_name_pattern = r'tvg-name=\"([^\"]*)\"'
    tvg_logo_pattern = r'tvg-logo=\"([^\"]*)\"'
    tvg_id_pattern = r'tvg-id=\"([^\"]*)\"'
    
    for line in lines:
        line = line.strip()
        
        if line.startswith('#EXTINF:'):
            current_extinf = line
            
        elif line.startswith('http') and current_extinf:
            group_match = re.search(group_title_pattern, current_extinf)
            tvg_name_match = re.search(tvg_name_pattern, current_extinf)
            tvg_logo_match = re.search(tvg_logo_pattern, current_extinf)
            tvg_id_match = re.search(tvg_id_pattern, current_extinf)
            
            channel_name = ''
            if ',' in current_extinf:
                channel_name = current_extinf.split(',')[-1].strip()
            
            group_title = group_match.group(1) if group_match else ''
            country, category, type_name = parse_group_title(group_title)
            
            if country and category:
                country_id = get_or_create_country(country)
                category_id = get_or_create_category(category, country_id)
                type_id = get_or_create_type(type_name, category_id) if type_name else None
                
                tvg_name = tvg_name_match.group(1) if tvg_name_match else ''
                tvg_logo = tvg_logo_match.group(1) if tvg_logo_match else ''
                tvg_id = tvg_id_match.group(1) if tvg_id_match else ''
                
                cursor.execute('''
                    INSERT INTO channels (
                        name, stream_url, main_category_id, sub_category_id, 
                        category_type_id, original_category, is_active,
                        logo_url, tvg_id, tvg_name
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    channel_name or tvg_name, line, country_id, category_id,
                    type_id, group_title, True,
                    tvg_logo, tvg_id, tvg_name
                ))
                
                channel_count += 1
                if channel_count % 10000 == 0:
                    print(f'İşlenen kanal sayısı: {channel_count}')
            
            current_extinf = None
    
    # Kanal sayılarını güncelle
    cursor.execute('''
        UPDATE main_categories 
        SET channel_count = (
            SELECT COUNT(*) FROM channels 
            WHERE channels.main_category_id = main_categories.id AND channels.is_active = 1
        )
    ''')
    
    cursor.execute('''
        UPDATE sub_categories 
        SET channel_count = (
            SELECT COUNT(*) FROM channels 
            WHERE channels.sub_category_id = sub_categories.id AND channels.is_active = 1
        )
    ''')
    
    conn.commit()
    
    cursor.execute('SELECT COUNT(*) FROM channels WHERE is_active = 1')
    total_channels = cursor.fetchone()[0]
    
    cursor.execute('SELECT COUNT(*) FROM main_categories')
    total_countries = cursor.fetchone()[0]
    
    cursor.execute('SELECT COUNT(*) FROM sub_categories')
    total_categories = cursor.fetchone()[0]
    
    print(f'Parse tamamlandı: {total_channels} kanal, {total_countries} ülke, {total_categories} kategori')
    
    conn.close()

parse_m3u()
"

deactivate
cd ..

# Frontend kurulumu
echo -e "${BLUE}[7/8]${NC} Frontend kuruluyor..."
cd iptv-frontend
pnpm install
pnpm run build

# Frontend build'ini backend'e kopyala
rm -rf ../iptv-backend/src/static/*
cp -r dist/* ../iptv-backend/src/static/

cd ..

# Systemd servisleri oluştur
echo -e "${BLUE}[8/8]${NC} Sistem servisleri yapılandırılıyor..."

# Backend servisi
sudo tee /etc/systemd/system/iptv-backend.service > /dev/null <<EOF
[Unit]
Description=IPTV Backend Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_DIR/iptv-backend
Environment=PATH=$PROJECT_DIR/iptv-backend/venv/bin
ExecStart=$PROJECT_DIR/iptv-backend/venv/bin/python src/main.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Nginx konfigürasyonu
sudo tee /etc/nginx/sites-available/iptv-system > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    # Frontend static files
    location / {
        root $PROJECT_DIR/iptv-backend/src/static;
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # API proxy
    location /api/ {
        proxy_pass http://127.0.0.1:5000/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # CORS headers
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization";
        
        if (\$request_method = 'OPTIONS') {
            return 204;
        }
    }
}
EOF

# Nginx'i etkinleştir
sudo ln -sf /etc/nginx/sites-available/iptv-system /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx

# Servisleri başlat
sudo systemctl daemon-reload
sudo systemctl enable iptv-backend
sudo systemctl start iptv-backend

# Firewall ayarları
if command -v ufw &> /dev/null; then
    sudo ufw allow 80/tcp
    sudo ufw allow 22/tcp
fi

# Kurulum tamamlandı
echo ""
echo -e "${GREEN}🎉 KURULUM TAMAMLANDI! 🎉${NC}"
echo ""
echo -e "${BLUE}📊 Sistem Bilgileri:${NC}"
echo -e "   • 179,101 Kanal yüklendi"
echo -e "   • 40 Ülke kategorisi"
echo -e "   • 285 Alt kategori"
echo -e "   • Modern React arayüzü"
echo ""
echo -e "${BLUE}🌐 Erişim Bilgileri:${NC}"
echo -e "   • Web Arayüzü: ${GREEN}http://$(hostname -I | awk '{print $1}')${NC}"
echo -e "   • Yerel Erişim: ${GREEN}http://localhost${NC}"
echo ""
echo -e "${BLUE}🔧 Yönetim Komutları:${NC}"
echo -e "   • Durumu kontrol et: ${YELLOW}sudo systemctl status iptv-backend${NC}"
echo -e "   • Servisi yeniden başlat: ${YELLOW}sudo systemctl restart iptv-backend${NC}"
echo -e "   • Logları görüntüle: ${YELLOW}sudo journalctl -u iptv-backend -f${NC}"
echo ""
echo -e "${GREEN}Sistem başarıyla kuruldu ve çalışıyor! 🚀${NC}"

