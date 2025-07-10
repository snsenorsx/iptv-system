# 🎬 IPTV System - Tam Özellikli IPTV Player

Modern, responsive ve kullanıcı dostu IPTV sistemi. Ubuntu 22.04 ve 24.04 için optimize edilmiş.

## ✨ Özellikler

- 🌍 **179,101+ Kanal** - Dünya çapında IPTV kanalları
- 🏷️ **40 Ülke Kategorisi** - Organize edilmiş ülke grupları
- 📂 **285 Alt Kategori** - Detaylı kategori sistemi
- 🎯 **Gelişmiş Arama** - Hızlı kanal bulma
- 📱 **Responsive Tasarım** - Mobil ve desktop uyumlu
- ⏯️ **Kaldığı Yerden Devam** - İzleme pozisyonu takibi
- 🚀 **Modern Arayüz** - React + Tailwind CSS
- 🔄 **Otomatik Güncelleme** - M3U listesi otomatik parse

## 🚀 Hızlı Kurulum

### 🔥 ULTRA Kurulum (Önerilen):

```bash
git clone https://github.com/snsenorsx/iptv-system.git
cd iptv-system
chmod +x ultra-install.sh
./ultra-install.sh
```

### 📋 Alternatif Kurulum Seçenekleri:

**Ubuntu 22.04 için:**
```bash
./install.sh
```

**Ubuntu 24.04 için:**
```bash
./install-ubuntu24.sh
```

**Tüm Sorunlar Düzeltilmiş:**
```bash
./final-install.sh
```

**ULTRA Versiyon (En Güncel):**
```bash
./ultra-install.sh
```

### Kurulum Süreci:
- ⏱️ **5-10 dakika** kurulum süresi
- 🔧 **Otomatik bağımlılık** yüklemesi
- 📊 **Veritabanı oluşturma** ve M3U parse
- 🌐 **Web server** konfigürasyonu
- 🔄 **Systemd servisleri** kurulumu
- ✅ **Otomatik test** ve doğrulama

## 📋 Sistem Gereksinimleri

- **İşletim Sistemi**: Ubuntu 22.04 LTS veya 24.04 LTS
- **RAM**: Minimum 2GB (4GB önerilen)
- **Disk**: Minimum 10GB boş alan
- **Ağ**: İnternet bağlantısı gerekli
- **Kullanıcı**: Root olmayan kullanıcı (sudo yetkisi olan)

## 🌐 Kurulum Sonrası

Kurulum tamamlandıktan sonra:

```
🌐 Web Arayüzü: http://sunucu-ip
📊 API Status: http://sunucu-ip/api/status
```

## 🔧 Servis Yönetimi

### Backend Servisi:
```bash
# Durum kontrolü
sudo systemctl status iptv-backend

# Yeniden başlatma
sudo systemctl restart iptv-backend

# Logları görüntüleme
sudo journalctl -u iptv-backend -f
```

### Nginx Web Server:
```bash
# Durum kontrolü
sudo systemctl status nginx

# Yeniden başlatma
sudo systemctl restart nginx

# Konfigürasyon testi
sudo nginx -t
```

## 📊 Sistem Mimarisi

### Backend (Flask + Python):
- **Framework**: Flask RESTful API
- **Veritabanı**: SQLite
- **M3U Parser**: Otomatik kanal parse
- **Port**: 5000 (internal)

### Frontend (React + Vite):
- **Framework**: React 18
- **Build Tool**: Vite
- **UI Library**: Tailwind CSS
- **State Management**: Context API

### Web Server (Nginx):
- **Reverse Proxy**: Backend API yönlendirme
- **Static Files**: Frontend asset serving
- **Port**: 80 (public)

## 🎯 API Endpoints

### Ana Kategoriler:
```
GET /api/main-categories
```

### Alt Kategoriler:
```
GET /api/sub-categories/{country_id}
```

### Kanallar:
```
GET /api/channels?main_category_id=X&sub_category_id=Y&search=query
```

### Sistem Durumu:
```
GET /api/status
```

## 🛠️ Geliştirme

### Lokal Geliştirme Ortamı:

```bash
# Backend
cd iptv-backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cd src
python main.py

# Frontend
cd iptv-frontend
pnpm install
pnpm run dev
```

### Proje Yapısı:
```
iptv-system/
├── iptv-backend/          # Flask API
│   ├── src/
│   │   ├── main.py        # Ana uygulama
│   │   ├── models/        # Veritabanı modelleri
│   │   ├── routes/        # API endpoint'leri
│   │   └── services/      # İş mantığı
│   └── requirements.txt
├── iptv-frontend/         # React SPA
│   ├── src/
│   │   ├── components/    # React bileşenleri
│   │   ├── contexts/      # State management
│   │   └── lib/          # API client
│   └── package.json
├── ultra-install.sh       # ULTRA kurulum scripti (önerilen)
├── final-install.sh       # Düzeltilmiş kurulum scripti
├── install-ubuntu24.sh    # Ubuntu 24.04 kurulum scripti
└── install.sh            # Temel kurulum scripti
```

## 🔒 Güvenlik

- 🌐 **Lokal Kullanım**: Güvenlik katmanları minimal
- 🚫 **Kimlik Doğrulama**: Yok (lokal ağ için)
- 🔥 **Firewall**: Port 80 ve 22 açık
- 🛡️ **CORS**: Tüm origin'lere izin

## 📝 Sorun Giderme

### Backend Çalışmıyor:
```bash
# Logları kontrol et
sudo journalctl -u iptv-backend -f

# Servisi yeniden başlat
sudo systemctl restart iptv-backend

# Port kontrolü
sudo netstat -tlnp | grep :5000
```

### Frontend Yüklenmiyor:
```bash
# Nginx durumu
sudo systemctl status nginx

# Nginx logları
sudo tail -f /var/log/nginx/error.log

# Build dosyaları kontrolü
ls -la /opt/iptv-system/iptv-frontend/dist/
```

### Veritabanı Sorunları:
```bash
# Veritabanı kontrolü
sqlite3 /opt/iptv-system/iptv-backend/src/iptv.db "SELECT COUNT(*) FROM channels;"

# Tabloları listele
sqlite3 /opt/iptv-system/iptv-backend/src/iptv.db ".tables"

# M3U'yu yeniden parse et
cd /opt/iptv-system/iptv-backend/src
source ../../venv/bin/activate
python -c "
from services.m3u_parser import M3UParser
from models.iptv import IPTVDatabase
db = IPTVDatabase()
parser = M3UParser()
channels = parser.parse_m3u('https://arc4949.xyz:80/get.php?username=turko8ii&password=Tv8828&type=m3u_plus&output=ts')
print(f'{len(channels)} kanal güncellendi')
"
```

## 🆕 Sürüm Notları

### v2.0 - ULTRA Edition
- ✅ Tüm kurulum sorunları düzeltildi
- ✅ IPTVDatabase sınıfı eklendi
- ✅ M3U parser tamamen yeniden yazıldı
- ✅ SQLite veritabanı desteği iyileştirildi
- ✅ Otomatik test ve doğrulama eklendi
- ✅ Detaylı hata raporlama
- ✅ Ubuntu 24.04 tam desteği

### v1.0 - İlk Sürüm
- ✅ Temel IPTV player
- ✅ React frontend
- ✅ Flask backend
- ✅ M3U parse desteği

## 📞 Destek

Sorun yaşadığınızda:

1. **ULTRA kurulum scriptini kullanın** - `./ultra-install.sh`
2. **Logları kontrol edin** - `sudo journalctl -u iptv-backend -f`
3. **Servisleri yeniden başlatın** - `sudo systemctl restart iptv-backend nginx`
4. **Port kontrolü yapın** - `sudo netstat -tlnp | grep :80`
5. **Disk alanını kontrol edin** - `df -h`
6. **Veritabanını kontrol edin** - `sqlite3 /opt/iptv-system/iptv-backend/src/iptv.db ".tables"`

## 📄 Lisans

Bu proje açık kaynak kodludur ve MIT lisansı altında dağıtılmaktadır.

---

**🎉 IPTV System - Modern IPTV çözümünüz hazır!**
**🚀 ULTRA Edition ile sorunsuz kurulum garantisi!**

