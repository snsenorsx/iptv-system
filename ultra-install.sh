#!/bin/bash

# IPTV System - Ultra Installation Script
# Ubuntu 22.04 & 24.04 Compatible
# Tüm sorunlar düzeltilmiş - ULTRA versiyon v2.1

set -e

echo "🚀 IPTV System ULTRA Kurulumu v2.1 Başlıyor..."
echo "=============================================="

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Log fonksiyonu
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

success() {
    echo -e "${PURPLE}[SUCCESS] $1${NC}"
}

# Root kontrolü
if [[ $EUID -eq 0 ]]; then
   error "Bu script root kullanıcısı ile çalıştırılmamalıdır!"
fi

# Ubuntu versiyon kontrolü
UBUNTU_VERSION=$(lsb_release -rs)
log "Ubuntu $UBUNTU_VERSION tespit edildi"

# Eski kurulumu temizle
log "Eski kurulum temizleniyor..."
sudo systemctl stop iptv-backend 2>/dev/null || true
sudo systemctl disable iptv-backend 2>/dev/null || true
sudo rm -f /etc/systemd/system/iptv-backend.service
sudo rm -rf /opt/iptv-system 2>/dev/null || true

# Sistem güncellemesi
log "Sistem güncelleniyor..."
sudo apt-get update -y
sudo apt-get upgrade -y

# Temel paketleri yükle
log "Temel paketler yükleniyor..."
sudo apt-get install -y curl wget git build-essential software-properties-common

# Port 80'i temizle
log "Port 80 temizleniyor..."
sudo systemctl stop apache2 2>/dev/null || true
sudo systemctl disable apache2 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true
sudo apt-get remove --purge -y apache2 apache2-utils 2>/dev/null || true

# Mevcut Node.js/npm'i temizle (Ubuntu 24.04 için)
if [[ "$UBUNTU_VERSION" == "24.04" ]]; then
    log "Ubuntu 24.04 için Node.js temizleniyor..."
    sudo apt-get remove --purge -y nodejs npm 2>/dev/null || true
    sudo apt-get autoremove -y 2>/dev/null || true
    sudo rm -rf /usr/local/bin/npm /usr/local/share/man/man1/node* /usr/local/lib/dtrace/node.d ~/.npm ~/.node-gyp /opt/local/bin/node /opt/local/include/node /opt/local/lib/node_modules 2>/dev/null || true
fi

# Python 3.11 yükle
log "Python 3.11 yükleniyor..."
sudo apt-get install -y python3 python3-pip python3-venv python3-dev

# Node.js 20 yükle
log "Node.js 20 yükleniyor..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Node.js versiyonunu kontrol et
NODE_VERSION=$(node --version)
log "Node.js $NODE_VERSION yüklendi"

# pnpm yükle
log "pnpm yükleniyor..."
sudo npm install -g pnpm

# SQLite yükle
log "SQLite yükleniyor..."
sudo apt-get install -y sqlite3

# Nginx yükle
log "Nginx yükleniyor..."
sudo apt-get install -y nginx

# Proje dizinini oluştur
PROJECT_DIR="/opt/iptv-system"
log "Proje dizini oluşturuluyor: $PROJECT_DIR"
sudo mkdir -p $PROJECT_DIR
sudo chown $USER:$USER $PROJECT_DIR

# Backend kurulumu
log "Backend kurulumu başlıyor..."
cd $PROJECT_DIR

# Python virtual environment oluştur
python3 -m venv venv
source venv/bin/activate

# Backend bağımlılıklarını yükle
cd iptv-backend
pip install -r requirements.txt

# M3U dosyasını parse et ve veritabanını oluştur
log "M3U dosyası parse ediliyor ve veritabanı oluşturuluyor..."
cd src

# Python script dosyası oluştur - v2.1 güncellenmiş
cat > setup_database.py << 'EOF'
#!/usr/bin/env python3
import sys
import os

# Mevcut dizini Python path'ine ekle
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, current_dir)

print(f"Current directory: {current_dir}")
print(f"Python path: {sys.path}")

# Dosya varlığını kontrol et
iptv_file = os.path.join(current_dir, 'models', 'iptv.py')
print(f"IPTV file exists: {os.path.exists(iptv_file)}")

if os.path.exists(iptv_file):
    with open(iptv_file, 'r') as f:
        content = f.read()
        print(f"File size: {len(content)} characters")
        if 'class IPTVDatabase' in content:
            print("✅ IPTVDatabase class found in file")
        else:
            print("❌ IPTVDatabase class NOT found in file")

try:
    # Import test
    print("Attempting to import IPTVDatabase...")
    from models.iptv import IPTVDatabase
    print("✅ IPTVDatabase imported successfully")
    
    from services.m3u_parser import M3UParser
    print("✅ M3UParser imported successfully")
    
    # Veritabanını oluştur
    print('Veritabanı tabloları oluşturuluyor...')
    db = IPTVDatabase()
    db.create_tables()
    print("✅ Database tables created")
    
    # M3U'yu parse et
    print('M3U dosyası parse ediliyor...')
    parser = M3UParser()
    m3u_url = 'https://arc4949.xyz:80/get.php?username=turko8ii&password=Tv8828&type=m3u_plus&output=ts'
    channels = parser.parse_m3u(m3u_url)
    print(f'✅ {len(channels)} kanal başarıyla yüklendi!')
    
except ImportError as e:
    print(f'❌ Import hatası: {e}')
    print('Mevcut dizin:', os.getcwd())
    print('Python path:', sys.path)
    
    # Dosya içeriğini debug için göster
    try:
        with open('models/iptv.py', 'r') as f:
            lines = f.readlines()
            print("First 20 lines of models/iptv.py:")
            for i, line in enumerate(lines[:20], 1):
                print(f"{i:2d}: {line.rstrip()}")
    except Exception as fe:
        print(f"Could not read file: {fe}")
    
    sys.exit(1)
except Exception as e:
    print(f'❌ Genel hata: {e}')
    import traceback
    traceback.print_exc()
    sys.exit(1)

print("🎉 Database setup completed successfully!")
EOF

# Python scriptini çalıştır
python3 setup_database.py

# Cleanup
rm setup_database.py

# Frontend kurulumu
log "Frontend kurulumu başlıyor..."
cd ../../iptv-frontend

# Node modules yükle
pnpm install

# Frontend build et
log "Frontend build ediliyor..."
pnpm run build

# Nginx konfigürasyonu
log "Nginx konfigürasyonu yapılıyor..."
sudo tee /etc/nginx/sites-available/iptv-system > /dev/null <<EOF
server {
    listen 80;
    server_name _;
    
    # Frontend static files
    location / {
        root /opt/iptv-system/iptv-frontend/dist;
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Backend API
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

# Nginx site'ı aktifleştir
sudo ln -sf /etc/nginx/sites-available/iptv-system /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Nginx'i test et ve başlat
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

# Backend systemd servisi oluştur
log "Backend systemd servisi oluşturuluyor..."
sudo tee /etc/systemd/system/iptv-backend.service > /dev/null <<EOF
[Unit]
Description=IPTV Backend Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/iptv-system/iptv-backend/src
Environment=PATH=/opt/iptv-system/venv/bin
ExecStart=/opt/iptv-system/venv/bin/python main.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Systemd servisini başlat
sudo systemctl daemon-reload
sudo systemctl enable iptv-backend
sudo systemctl start iptv-backend

# Firewall ayarları
log "Firewall ayarları yapılıyor..."
sudo ufw allow 80/tcp 2>/dev/null || true
sudo ufw allow 22/tcp 2>/dev/null || true

# Servis durumlarını kontrol et
log "Servis durumları kontrol ediliyor..."
sleep 5

# Backend durumu
if sudo systemctl is-active --quiet iptv-backend; then
    success "✅ Backend servisi çalışıyor"
else
    warning "⚠️ Backend servisi başlatılamadı, logları kontrol ediliyor..."
    sudo journalctl -u iptv-backend --no-pager -n 20
fi

# Nginx durumu
if sudo systemctl is-active --quiet nginx; then
    success "✅ Nginx servisi çalışıyor"
else
    error "❌ Nginx servisi başlatılamadı"
fi

# Veritabanı kontrolü
log "Veritabanı kontrolü yapılıyor..."
cd /opt/iptv-system/iptv-backend/src
CHANNEL_COUNT=$(sqlite3 iptv.db "SELECT COUNT(*) FROM channels;" 2>/dev/null || echo "0")
CATEGORY_COUNT=$(sqlite3 iptv.db "SELECT COUNT(*) FROM categories;" 2>/dev/null || echo "0")

if [[ $CHANNEL_COUNT -gt 0 ]]; then
    success "✅ Veritabanında $CHANNEL_COUNT kanal, $CATEGORY_COUNT kategori bulundu"
else
    warning "⚠️ Veritabanında kanal bulunamadı"
fi

# API testi
log "API testi yapılıyor..."
sleep 2
API_RESPONSE=$(curl -s http://localhost:5000/api/status || echo "FAILED")
if [[ "$API_RESPONSE" != "FAILED" ]]; then
    success "✅ API çalışıyor"
else
    warning "⚠️ API yanıt vermiyor"
fi

# Kurulum tamamlandı
echo ""
echo "🎉 IPTV System ULTRA v2.1 Kurulumu Tamamlandı!"
echo "==============================================="
echo ""
echo "🌐 Web Arayüzü: http://$(hostname -I | awk '{print $1}')"
echo "📊 API Status: http://$(hostname -I | awk '{print $1}')/api/status"
echo ""
echo "📈 Sistem İstatistikleri:"
echo "   - Kanallar: $CHANNEL_COUNT"
echo "   - Kategoriler: $CATEGORY_COUNT"
echo "   - Backend: $(sudo systemctl is-active iptv-backend)"
echo "   - Frontend: $(sudo systemctl is-active nginx)"
echo ""
echo "🔧 Servis Komutları:"
echo "   - Backend durumu: sudo systemctl status iptv-backend"
echo "   - Backend yeniden başlat: sudo systemctl restart iptv-backend"
echo "   - Backend logları: sudo journalctl -u iptv-backend -f"
echo "   - Nginx durumu: sudo systemctl status nginx"
echo "   - Nginx yeniden başlat: sudo systemctl restart nginx"
echo ""
echo "🗄️ Veritabanı:"
echo "   - Konum: /opt/iptv-system/iptv-backend/src/iptv.db"
echo "   - Yönetim: sqlite3 /opt/iptv-system/iptv-backend/src/iptv.db"
echo ""
echo "✨ Sistem hazır! Tarayıcınızda IP adresinizi ziyaret edin."
echo "🚀 ULTRA v2.1 kurulum başarıyla tamamlandı!"

