#!/bin/bash

# IPTV System - Simple Installation Script
# Basit ve çalışan versiyon - v1.1

set -e

echo "🚀 IPTV System Basit Kurulum v1.1 Başlıyor..."
echo "============================================="

# Root kontrolü
if [[ $EUID -eq 0 ]]; then
   echo "❌ Bu script root kullanıcısı ile çalıştırılmamalıdır!"
   exit 1
fi

# Eski kurulumu temizle
echo "🧹 Eski kurulum temizleniyor..."
sudo systemctl stop iptv-backend 2>/dev/null || true
sudo systemctl disable iptv-backend 2>/dev/null || true
sudo rm -f /etc/systemd/system/iptv-backend.service
sudo rm -rf /opt/iptv-system 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true

# Sistem güncelle
echo "📦 Sistem güncelleniyor..."
sudo apt-get update -y

# Gerekli paketleri yükle
echo "📦 Gerekli paketler yükleniyor..."
sudo apt-get install -y python3 python3-pip python3-venv sqlite3 nginx curl wget

# Proje dizinini oluştur
PROJECT_DIR="/opt/iptv-system"
echo "📁 Proje dizini oluşturuluyor: $PROJECT_DIR"
sudo mkdir -p $PROJECT_DIR
sudo chown $USER:$USER $PROJECT_DIR
cd $PROJECT_DIR

# Proje dosyalarını kopyala
echo "📋 Proje dosyaları kopyalanıyor..."
cp -r ~/iptv-system/* . 2>/dev/null || true

# Python virtual environment oluştur
echo "🐍 Python virtual environment oluşturuluyor..."
python3 -m venv venv
source venv/bin/activate

# Backend bağımlılıklarını yükle
echo "📦 Backend bağımlılıkları yükleniyor..."
pip install flask flask-cors requests

# Basit veritabanı ve M3U parser oluştur
echo "🗄️ Basit veritabanı sistemi oluşturuluyor..."
mkdir -p src/models
cd src

# Basit models/iptv.py oluştur
cat > models/iptv.py << 'EOF'
import sqlite3
import requests
import re
from datetime import datetime

class SimpleIPTV:
    def __init__(self, db_path='iptv.db'):
        self.db_path = db_path
        self.create_tables()
    
    def create_tables(self):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS channels (
                id INTEGER PRIMARY KEY,
                name TEXT,
                url TEXT,
                category TEXT
            )
        ''')
        
        conn.commit()
        conn.close()
        print("✅ Veritabanı tabloları oluşturuldu")
    
    def load_m3u(self, url):
        print(f"📡 M3U yükleniyor: {url}")
        try:
            # HTTP kullan, HTTPS değil
            if url.startswith('https://'):
                url = url.replace('https://', 'http://')
            
            response = requests.get(url, timeout=30, verify=False)
            content = response.text
            
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Eski kanalları sil
            cursor.execute('DELETE FROM channels')
            
            lines = content.split('\n')
            current_channel = {}
            count = 0
            
            for line in lines:
                line = line.strip()
                
                if line.startswith('#EXTINF:'):
                    # Kategori bul
                    group_match = re.search(r'group-title="([^"]*)"', line)
                    category = group_match.group(1) if group_match else 'Genel'
                    
                    # Kanal adı bul
                    name_match = re.search(r',(.+)$', line)
                    name = name_match.group(1) if name_match else 'İsimsiz Kanal'
                    
                    current_channel = {'name': name, 'category': category}
                    
                elif line.startswith('http'):
                    if current_channel:
                        cursor.execute(
                            'INSERT INTO channels (name, url, category) VALUES (?, ?, ?)',
                            (current_channel['name'], line, current_channel['category'])
                        )
                        count += 1
                        if count % 1000 == 0:
                            print(f"📊 {count} kanal işlendi...")
                        current_channel = {}
            
            conn.commit()
            conn.close()
            print(f"✅ {count} kanal yüklendi")
            return count
            
        except Exception as e:
            print(f"❌ M3U yükleme hatası: {e}")
            return 0
EOF

# Basit main.py oluştur
cat > main.py << 'EOF'
from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS
import sqlite3
import os
from models.iptv import SimpleIPTV

app = Flask(__name__)
CORS(app)

# Veritabanını başlat
db = SimpleIPTV()

@app.route('/api/status')
def status():
    conn = sqlite3.connect('iptv.db')
    cursor = conn.cursor()
    cursor.execute('SELECT COUNT(*) FROM channels')
    count = cursor.fetchone()[0]
    conn.close()
    
    return jsonify({
        'status': 'ok',
        'channels': count,
        'message': 'IPTV System çalışıyor'
    })

@app.route('/api/channels')
def channels():
    page = int(request.args.get('page', 1))
    per_page = int(request.args.get('per_page', 50))
    offset = (page - 1) * per_page
    
    conn = sqlite3.connect('iptv.db')
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM channels LIMIT ? OFFSET ?', (per_page, offset))
    rows = cursor.fetchall()
    conn.close()
    
    channels = []
    for row in rows:
        channels.append({
            'id': row[0],
            'name': row[1],
            'url': row[2],
            'category': row[3]
        })
    
    return jsonify(channels)

@app.route('/api/categories')
def categories():
    conn = sqlite3.connect('iptv.db')
    cursor = conn.cursor()
    cursor.execute('SELECT category, COUNT(*) FROM channels GROUP BY category ORDER BY COUNT(*) DESC')
    rows = cursor.fetchall()
    conn.close()
    
    categories = []
    for row in rows:
        categories.append({
            'name': row[0],
            'count': row[1]
        })
    
    return jsonify(categories)

@app.route('/')
def index():
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>IPTV System</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
            .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            .header { text-align: center; margin-bottom: 30px; }
            .status { background: #e8f5e8; padding: 20px; border-radius: 8px; margin: 20px 0; }
            .controls { margin: 20px 0; text-align: center; }
            .channel { background: #f9f9f9; padding: 15px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #007cba; }
            .category { background: #fff3cd; padding: 10px; margin: 5px; border-radius: 4px; display: inline-block; }
            button { background: #007cba; color: white; padding: 12px 24px; border: none; border-radius: 4px; cursor: pointer; margin: 5px; font-size: 14px; }
            button:hover { background: #005a87; }
            .loading { text-align: center; padding: 20px; color: #666; }
            .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
            @media (max-width: 768px) { .grid { grid-template-columns: 1fr; } }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🎬 IPTV System</h1>
                <p>Basit ve Çalışan IPTV Player</p>
            </div>
            
            <div class="status">
                <h3>📊 Sistem Durumu</h3>
                <p id="status">Yükleniyor...</p>
                <div class="controls">
                    <button onclick="loadChannels()">📺 Kanalları Göster</button>
                    <button onclick="loadCategories()">📂 Kategoriler</button>
                    <button onclick="loadM3U()">🔄 M3U Güncelle</button>
                    <button onclick="loadStatus()">📊 Durum Yenile</button>
                </div>
            </div>
            
            <div class="grid">
                <div>
                    <h3>📺 Kanallar</h3>
                    <div id="channels">Kanalları görmek için butona tıklayın</div>
                </div>
                <div>
                    <h3>📂 Kategoriler</h3>
                    <div id="categories">Kategorileri görmek için butona tıklayın</div>
                </div>
            </div>
        </div>
        
        <script>
            async function loadStatus() {
                try {
                    const response = await fetch('/api/status');
                    const data = await response.json();
                    document.getElementById('status').innerHTML = 
                        `✅ <strong>${data.channels}</strong> kanal yüklü - ${data.message}`;
                } catch (error) {
                    document.getElementById('status').innerHTML = '❌ Bağlantı hatası';
                }
            }
            
            async function loadChannels() {
                document.getElementById('channels').innerHTML = '<div class="loading">📺 Kanallar yükleniyor...</div>';
                try {
                    const response = await fetch('/api/channels');
                    const channels = await response.json();
                    const html = channels.map(ch => 
                        `<div class="channel">
                            <strong>${ch.name}</strong>
                            <br><small>📂 ${ch.category}</small>
                            <br><small>🔗 ${ch.url.substring(0, 50)}...</small>
                        </div>`
                    ).join('');
                    document.getElementById('channels').innerHTML = html || 'Kanal bulunamadı';
                } catch (error) {
                    document.getElementById('channels').innerHTML = '❌ Kanal yükleme hatası';
                }
            }
            
            async function loadCategories() {
                document.getElementById('categories').innerHTML = '<div class="loading">📂 Kategoriler yükleniyor...</div>';
                try {
                    const response = await fetch('/api/categories');
                    const categories = await response.json();
                    const html = categories.map(cat => 
                        `<div class="category">
                            <strong>${cat.name}</strong><br>
                            <small>${cat.count} kanal</small>
                        </div>`
                    ).join('');
                    document.getElementById('categories').innerHTML = html || 'Kategori bulunamadı';
                } catch (error) {
                    document.getElementById('categories').innerHTML = '❌ Kategori yükleme hatası';
                }
            }
            
            async function loadM3U() {
                document.getElementById('status').innerHTML = '⏳ M3U yükleniyor...';
                try {
                    const response = await fetch('/api/load-m3u', {method: 'POST'});
                    const data = await response.json();
                    loadStatus();
                    alert(`✅ ${data.channels} kanal yüklendi!`);
                } catch (error) {
                    document.getElementById('status').innerHTML = '❌ M3U yükleme hatası';
                }
            }
            
            loadStatus();
        </script>
    </body>
    </html>
    '''

@app.route('/api/load-m3u', methods=['POST'])
def load_m3u():
    url = 'http://arc4949.xyz:80/get.php?username=turko8ii&password=Tv8828&type=m3u_plus&output=ts'
    count = db.load_m3u(url)
    return jsonify({'success': True, 'channels': count})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

# M3U'yu yükle
echo "📡 M3U dosyası yükleniyor..."
python3 -c "
from models.iptv import SimpleIPTV
db = SimpleIPTV()
db.load_m3u('http://arc4949.xyz:80/get.php?username=turko8ii&password=Tv8828&type=m3u_plus&output=ts')
"

# Nginx'i durdur ve temizle
echo "🌐 Nginx temizleniyor ve yeniden yapılandırılıyor..."
sudo systemctl stop nginx 2>/dev/null || true
sudo rm -f /etc/nginx/sites-enabled/*

# Nginx konfigürasyonu
sudo tee /etc/nginx/sites-available/iptv-simple > /dev/null <<EOF
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

sudo ln -sf /etc/nginx/sites-available/iptv-simple /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl start nginx
sudo systemctl enable nginx

# Systemd servisi
echo "⚙️ Systemd servisi oluşturuluyor..."
sudo tee /etc/systemd/system/iptv-backend.service > /dev/null <<EOF
[Unit]
Description=IPTV Simple Backend
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/iptv-system/src
Environment=PATH=/opt/iptv-system/venv/bin
ExecStart=/opt/iptv-system/venv/bin/python main.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable iptv-backend
sudo systemctl start iptv-backend

# Durum kontrolü
sleep 5
echo ""
echo "🎉 IPTV System Basit Kurulum v1.1 Tamamlandı!"
echo "============================================="
echo ""

# IP adresini al
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "🌐 Web Arayüzü: http://$SERVER_IP"
echo ""

# Servis durumları
BACKEND_STATUS=$(sudo systemctl is-active iptv-backend)
NGINX_STATUS=$(sudo systemctl is-active nginx)

echo "📊 Servis Durumları:"
echo "   - Backend: $BACKEND_STATUS"
echo "   - Nginx: $NGINX_STATUS"
echo ""

# Veritabanı kontrolü
cd /opt/iptv-system/src
CHANNEL_COUNT=$(sqlite3 iptv.db "SELECT COUNT(*) FROM channels;" 2>/dev/null || echo "0")

echo "📈 İstatistikler:"
echo "   - Yüklü Kanallar: $CHANNEL_COUNT"
echo ""

echo "🔧 Yönetim Komutları:"
echo "   - Backend durumu: sudo systemctl status iptv-backend"
echo "   - Backend logları: sudo journalctl -u iptv-backend -f"
echo "   - Nginx durumu: sudo systemctl status nginx"
echo "   - Nginx yeniden başlat: sudo systemctl restart nginx"
echo ""

if [[ "$BACKEND_STATUS" == "active" && "$NGINX_STATUS" == "active" && $CHANNEL_COUNT -gt 0 ]]; then
    echo "✅ Sistem tamamen çalışıyor! Tarayıcınızda http://$SERVER_IP adresini ziyaret edin."
else
    echo "⚠️ Bazı servisler çalışmıyor olabilir. Yukarıdaki komutlarla kontrol edin."
fi

echo ""
echo "🚀 Kurulum tamamlandı!"

