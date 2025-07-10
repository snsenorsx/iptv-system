# 🎬 IPTV Sistemi - Tek Komut Kurulum

Modern, hızlı ve kullanıcı dostu IPTV sistemi. Ubuntu 22.04 için optimize edilmiştir.

## 🚀 Tek Komut Kurulum

```bash
git clone https://github.com/snsenorsx/iptv-system.git
cd iptv-system
chmod +x install.sh
./install.sh
```

## 📊 Özellikler

- **179,101 Kanal** - Dünya çapında IPTV kanalları
- **40 Ülke** - Organize edilmiş ülke kategorileri
- **285 Kategori** - Detaylı alt kategoriler
- **Modern Arayüz** - React + Tailwind CSS
- **Responsive Tasarım** - Mobil ve desktop uyumlu
- **Hızlı Arama** - Gelişmiş filtreleme sistemi
- **Kaldığı Yerden Devam** - İzleme pozisyonu takibi

## 🛠️ Sistem Gereksinimleri

- Ubuntu 22.04 LTS
- 2GB RAM (minimum)
- 10GB Disk Alanı
- İnternet Bağlantısı

## 📱 Kullanım

1. Kurulum tamamlandıktan sonra tarayıcınızda `http://sunucu-ip` adresine gidin
2. Sol menüden ülke kategorilerini seçin
3. Alt kategorilere göz atın
4. İzlemek istediğiniz kanalı seçin
5. Video player'da izlemeye başlayın

## 🔧 Yönetim

### Servis Durumu
```bash
sudo systemctl status iptv-backend
```

### Servisi Yeniden Başlat
```bash
sudo systemctl restart iptv-backend
```

### Logları Görüntüle
```bash
sudo journalctl -u iptv-backend -f
```

## 📁 Proje Yapısı

```
iptv-system/
├── iptv-backend/          # Flask API backend
│   ├── src/
│   │   ├── main.py        # Ana uygulama
│   │   ├── models/        # Veritabanı modelleri
│   │   ├── routes/        # API endpoint'leri
│   │   ├── services/      # İş mantığı
│   │   └── database/      # SQLite veritabanı
│   └── requirements.txt   # Python bağımlılıkları
├── iptv-frontend/         # React frontend
│   ├── src/
│   │   ├── components/    # React bileşenleri
│   │   ├── contexts/      # React context'leri
│   │   └── lib/           # Yardımcı kütüphaneler
│   └── package.json       # Node.js bağımlılıkları
└── install.sh             # Otomatik kurulum scripti
```

## 🌐 API Endpoint'leri

- `GET /api/status` - Sistem durumu
- `GET /api/main-categories` - Ülke kategorileri
- `GET /api/sub-categories/{id}` - Alt kategoriler
- `GET /api/channels` - Kanal listesi
- `POST /api/watch/position` - İzleme pozisyonu güncelle

## 🔒 Güvenlik

- Sistem root kullanıcısı ile çalıştırılmaz
- Firewall kuralları otomatik yapılandırılır
- CORS güvenlik başlıkları eklenir
- Static dosyalar cache ile optimize edilir

## 🐛 Sorun Giderme

### Backend Çalışmıyor
```bash
sudo systemctl restart iptv-backend
sudo journalctl -u iptv-backend -n 50
```

### Nginx Hatası
```bash
sudo nginx -t
sudo systemctl restart nginx
```

### Veritabanı Sorunu
```bash
cd /opt/iptv-system/iptv-backend
source venv/bin/activate
python3 -c "
import sys
sys.path.append('src')
from main import create_app, db
app = create_app()
with app.app_context():
    db.create_all()
"
```

## 📞 Destek

Sorun yaşarsanız:
1. Logları kontrol edin
2. Servislerin durumunu kontrol edin
3. Sistem gereksinimlerini doğrulayın

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır.

---

**🎯 5-10 dakikada kurulum tamamlanır!** 🚀

