#!/bin/bash

# IPTV Sistemi - Düzeltilmiş Kurulum
# Ubuntu 22.04/24.04 uyumlu

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
echo -e "${GREEN}IPTV Sistemi - Düzeltilmiş Kurulum${NC}"
echo -e "${YELLOW}179,101 Kanal • 40 Ülke • 285 Kategori${NC}"
echo ""

# Sistem kontrolü
echo -e "${BLUE}[1/9]${NC} Sistem kontrol ediliyor..."
if [[ "$EUID" -eq 0 ]]; then
    echo -e "${RED}HATA: Bu script root kullanıcısı ile çalıştırılmamalıdır!${NC}"
    exit 1
fi

# Port 80 kontrolü ve temizleme
echo -e "${BLUE}[2/9]${NC} Port 80 kontrol ediliyor..."
sudo pkill -f nginx 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true
sudo systemctl stop apache2 2>/dev/null || true

# Node.js çakışmasını çöz
echo -e "${BLUE}[3/9]${NC} Node.js çakışması çözülüyor..."
sudo apt-get remove -y nodejs npm 2>/dev/null || true
sudo apt-get autoremove -y
sudo apt-get autoclean

# Sistem paketleri
echo -e "${BLUE}[4/9]${NC} Sistem paketleri yükleniyor..."
sudo apt-get update
sudo apt-get install -y curl wget python3 python3-pip python3-venv sqlite3 nginx unzip

# Node.js 20 yükle
echo -e "${BLUE}[5/9]${NC} Node.js 20 yükleniyor..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# pnpm yükle
echo -e "${BLUE}[6/9]${NC} pnpm yükleniyor..."
sudo npm install -g pnpm

# Proje dizini oluştur
echo -e "${BLUE}[7/9]${NC} Proje dizini hazırlanıyor..."
sudo mkdir -p /opt/iptv-system
sudo chown $USER:$USER /opt/iptv-system
cp -r . /opt/iptv-system/
cd /opt/iptv-system

# Backend API düzeltmesi
echo "Backend API düzeltiliyor..."
cat > iptv-backend/src/routes/admin.py << 'EOF'
from flask import Blueprint, request, jsonify
from ..services.m3u_parser import M3UParser
from ..models.iptv import db

admin_bp = Blueprint('admin', __name__)

@admin_bp.route('/update-m3u', methods=['POST'])
def update_m3u():
    try:
        data = request.get_json()
        m3u_url = data.get('m3u_url', 'http://arc4949.xyz:80/get.php?username=turko8ii&password=Tv8828&type=m3u_plus&output=ts')
        
        parser = M3UParser()
        result = parser.parse_and_save(m3u_url)
        
        return jsonify({
            'success': True,
            'message': f'M3U başarıyla güncellendi',
            'channels_count': result['channels_count'],
            'categories_count': result['categories_count']
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@admin_bp.route('/stats', methods=['GET'])
def get_stats():
    try:
        from ..models.iptv import Channel, Category
        
        channels_count = Channel.query.count()
        categories_count = Category.query.count()
        
        return jsonify({
            'success': True,
            'channels_count': channels_count,
            'categories_count': categories_count
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
EOF

# Frontend API dosyası düzeltmesi
echo "Frontend API dosyası düzeltiliyor..."
cat > iptv-frontend/src/lib/api.js << 'EOF'
// Dinamik API base URL - hangi domain'de olursa olsun çalışır
const API_BASE_URL = typeof window !== 'undefined' 
  ? `${window.location.protocol}//${window.location.host}/api`
  : '/api';

class APIClient {
  constructor() {
    this.baseURL = API_BASE_URL;
  }

  async request(endpoint, options = {}) {
    const url = `${this.baseURL}${endpoint}`;
    const config = {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache',
        ...options.headers,
      },
      ...options,
    };

    try {
      const response = await fetch(url, config);
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      return await response.json();
    } catch (error) {
      console.error('API call failed:', error);
      throw error;
    }
  }

  // Status endpoint
  async getStatus() {
    return this.request('/status');
  }

  // Ana kategoriler (ülkeler)
  async getMainCategories() {
    return this.request('/main-categories');
  }

  // Alt kategoriler
  async getSubCategories(mainCategoryId) {
    return this.request(`/sub-categories/${mainCategoryId}`);
  }

  // Kanallar
  async getChannels(params = {}) {
    const queryString = new URLSearchParams(params).toString();
    return this.request(`/channels${queryString ? `?${queryString}` : ''}`);
  }

  // Kanal arama
  async searchChannels(query, params = {}) {
    const searchParams = { search: query, ...params };
    const queryString = new URLSearchParams(searchParams).toString();
    return this.request(`/channels?${queryString}`);
  }

  // İzleme durumu güncelle
  async updateWatchPosition(channelId, position) {
    return this.request('/watch/update', {
      method: 'POST',
      body: JSON.stringify({
        channel_id: channelId,
        watch_position: position
      })
    });
  }

  // İzleme durumu al
  async getWatchPosition(channelId) {
    return this.request(`/watch/${channelId}`);
  }

  // Admin - M3U güncelle
  async updateM3U(m3uUrl) {
    return this.request('/admin/update-m3u', {
      method: 'POST',
      body: JSON.stringify({ m3u_url: m3uUrl })
    });
  }

  // Admin - İstatistikler
  async getStats() {
    return this.request('/admin/stats');
  }
}

const api = new APIClient();
export default api;
EOF

# Backend kurulum
echo -e "${BLUE}[8/9]${NC} Backend kuruluyor..."
cd iptv-backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Veritabanı oluştur ve M3U yükle
echo "Veritabanı oluşturuluyor ve M3U yükleniyor..."
python3 src/main.py &
BACKEND_PID=$!
sleep 10

# M3U yükle (düzeltilmiş endpoint)
curl -X POST http://localhost:5000/api/admin/update-m3u \
  -H "Content-Type: application/json" \
  -d '{"m3u_url": "http://arc4949.xyz:80/get.php?username=turko8ii&password=Tv8828&type=m3u_plus&output=ts"}' || true

sleep 5
kill $BACKEND_PID 2>/dev/null || true
deactivate

# Frontend kurulum
echo -e "${BLUE}[9/9]${NC} Frontend kuruluyor..."
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

