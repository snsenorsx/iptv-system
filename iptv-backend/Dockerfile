# Python 3.11 base image
FROM python:3.11-slim

# Çalışma dizini
WORKDIR /app

# Sistem paketlerini güncelle ve gerekli paketleri yükle
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Python bağımlılıklarını kopyala ve yükle
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Uygulama kodunu kopyala
COPY src/ ./src/

# Veritabanı dizinini oluştur
RUN mkdir -p src/database

# Port 5000'i aç
EXPOSE 5000

# Ortam değişkenleri
ENV PYTHONPATH=/app
ENV FLASK_ENV=production

# Uygulamayı başlat
CMD ["python", "src/main.py"]

