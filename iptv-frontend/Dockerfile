# Node.js 20 base image
FROM node:20-alpine

# Çalışma dizini
WORKDIR /app

# Package dosyalarını kopyala
COPY package.json pnpm-lock.yaml ./

# pnpm'i global olarak yükle
RUN npm install -g pnpm

# Bağımlılıkları yükle
RUN pnpm install

# Uygulama kodunu kopyala
COPY . .

# Uygulamayı build et
RUN pnpm run build

# Nginx ile serve etmek için
FROM nginx:alpine

# Build edilen dosyaları nginx'e kopyala
COPY --from=0 /app/dist /usr/share/nginx/html

# Nginx konfigürasyonu
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Port 80'i aç
EXPOSE 80

# Nginx'i başlat
CMD ["nginx", "-g", "daemon off;"]

