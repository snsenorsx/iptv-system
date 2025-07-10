import requests
import re
from datetime import datetime
from collections import defaultdict
import urllib3
import sqlite3
import os

# SSL uyarılarını devre dışı bırak
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class M3UParser:
    def __init__(self, db_path='iptv.db'):
        self.db_path = db_path
        self.categories = {}
        self.channels = []
        
    def parse_m3u(self, url, source_name="Default Source"):
        """M3U URL'sini parse et ve veritabanına kaydet"""
        try:
            print(f"M3U linkini indiriliyor: {url}")
            
            # Farklı URL formatlarını dene
            urls_to_try = [
                url,
                url.replace('https://', 'http://'),
                url.replace(':80', '')
            ]
            
            content = None
            working_url = None
            
            for test_url in urls_to_try:
                try:
                    print(f"Deneniyor: {test_url}")
                    response = requests.get(test_url, timeout=30, verify=False)
                    response.raise_for_status()
                    content = response.text
                    working_url = test_url
                    print(f"Başarılı! URL: {working_url}")
                    break
                except Exception as e:
                    print(f"Hata: {e}")
                    continue
            
            if not content:
                raise Exception("Hiçbir URL formatı çalışmadı")
            
            print(f"İçerik boyutu: {len(content)} karakter")
            
            # M3U içeriğini parse et
            channels_data = self._parse_m3u_content(content)
            
            # Veritabanı bağlantısı
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Eski verileri temizle
            print("Eski kanallar ve kategoriler temizleniyor...")
            cursor.execute('DELETE FROM channels')
            cursor.execute('DELETE FROM categories')
            cursor.execute('DELETE FROM watch_sessions')
            
            # Kategorileri kaydet
            print("Kategoriler kaydediliyor...")
            category_map = {}
            for category_name, channel_count in channels_data['categories'].items():
                if category_name:  # Boş kategori adlarını atla
                    slug = self._create_slug(category_name)
                    cursor.execute(
                        'INSERT INTO categories (name, slug, channel_count) VALUES (?, ?, ?)',
                        (category_name, slug, channel_count)
                    )
                    category_id = cursor.lastrowid
                    category_map[category_name] = category_id
            
            # Kanalları kaydet
            print("Kanallar kaydediliyor...")
            batch_size = 1000
            for i, channel_data in enumerate(channels_data['channels']):
                category_id = category_map.get(channel_data.get('category'))
                
                cursor.execute('''
                    INSERT INTO channels 
                    (name, stream_url, logo_url, tvg_id, tvg_name, category_id, language, country)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    channel_data.get('name', 'İsimsiz Kanal'),
                    channel_data.get('url', ''),
                    channel_data.get('logo'),
                    channel_data.get('tvg_id'),
                    channel_data.get('tvg_name'),
                    category_id,
                    self._extract_language(channel_data.get('category', '')),
                    self._extract_country(channel_data.get('category', ''))
                ))
                
                # Batch commit
                if (i + 1) % batch_size == 0:
                    conn.commit()
                    print(f"İşlenen kanal sayısı: {i + 1}")
            
            # M3U kaynağını kaydet
            cursor.execute('''
                INSERT OR REPLACE INTO m3u_sources (name, url, last_updated)
                VALUES (?, ?, ?)
            ''', (source_name, working_url, datetime.now().isoformat()))
            
            # Son commit
            conn.commit()
            conn.close()
            
            result = {
                'success': True,
                'total_channels': len(channels_data['channels']),
                'total_categories': len(channels_data['categories']),
                'working_url': working_url
            }
            
            print(f"Parse işlemi tamamlandı: {result['total_channels']} kanal, {result['total_categories']} kategori")
            return channels_data['channels']
            
        except Exception as e:
            print(f"Parse hatası: {e}")
            raise e
    
    def _parse_m3u_content(self, content):
        """M3U içeriğini parse et"""
        lines = content.split('\n')
        channels = []
        categories = defaultdict(int)
        
        current_channel = {}
        
        for line in lines:
            line = line.strip()
            
            if line.startswith('#EXTINF:'):
                # Kanal bilgilerini parse et
                # Format: #EXTINF:-1 tvg-id="..." tvg-name="..." tvg-logo="..." group-title="...",Kanal Adı
                
                # Grup başlığını (kategori) bul
                group_match = re.search(r'group-title="([^"]*)"', line)
                if group_match:
                    category = group_match.group(1).strip()
                    if category:  # Boş kategori adlarını atla
                        categories[category] += 1
                        current_channel['category'] = category
                
                # Kanal adını bul
                name_match = re.search(r',(.+)$', line)
                if name_match:
                    current_channel['name'] = name_match.group(1).strip()
                
                # Logo URL'sini bul
                logo_match = re.search(r'tvg-logo="([^"]*)"', line)
                if logo_match:
                    logo_url = logo_match.group(1).strip()
                    if logo_url:
                        current_channel['logo'] = logo_url
                
                # TVG ID'sini bul
                tvg_id_match = re.search(r'tvg-id="([^"]*)"', line)
                if tvg_id_match:
                    tvg_id = tvg_id_match.group(1).strip()
                    if tvg_id:
                        current_channel['tvg_id'] = tvg_id
                
                # TVG Name'i bul
                tvg_name_match = re.search(r'tvg-name="([^"]*)"', line)
                if tvg_name_match:
                    tvg_name = tvg_name_match.group(1).strip()
                    if tvg_name:
                        current_channel['tvg_name'] = tvg_name
                        
            elif line.startswith('http'):
                # Stream URL'si
                current_channel['url'] = line
                if current_channel.get('name') and current_channel.get('url'):
                    channels.append(current_channel.copy())
                current_channel = {}
        
        return {
            'channels': channels,
            'categories': dict(categories)
        }
    
    def _create_slug(self, name):
        """İsimden slug oluştur"""
        slug = re.sub(r'[^\w\s-]', '', name.lower())
        slug = re.sub(r'[-\s]+', '-', slug)
        return slug.strip('-')
    
    def _extract_language(self, category_name):
        """Kategori adından dil kodunu çıkar"""
        if not category_name:
            return None
            
        # Yaygın dil kodları
        language_patterns = {
            'TR': ['TR', 'TURK', 'TURKISH'],
            'EN': ['EN', 'ENG', 'ENGLISH', 'US', 'UK'],
            'DE': ['DE', 'GER', 'GERMAN', 'DEUTSCH'],
            'FR': ['FR', 'FRA', 'FRENCH'],
            'ES': ['ES', 'ESP', 'SPANISH'],
            'IT': ['IT', 'ITA', 'ITALIAN'],
            'AR': ['AR', 'ARA', 'ARABIC'],
            'RU': ['RU', 'RUS', 'RUSSIAN']
        }
        
        category_upper = category_name.upper()
        for lang_code, patterns in language_patterns.items():
            for pattern in patterns:
                if pattern in category_upper:
                    return lang_code
        
        return None
    
    def _extract_country(self, category_name):
        """Kategori adından ülke kodunu çıkar"""
        if not category_name:
            return None
            
        # Yaygın ülke kodları
        country_patterns = {
            'TR': ['TR', 'TURKEY', 'TURK'],
            'US': ['US', 'USA', 'AMERICA'],
            'UK': ['UK', 'BRITAIN'],
            'DE': ['DE', 'GERMANY', 'DEUTSCH'],
            'FR': ['FR', 'FRANCE'],
            'ES': ['ES', 'SPAIN'],
            'IT': ['IT', 'ITALY'],
            'BG': ['BG', 'BULGARIA'],
            'AL': ['AL', 'ALB', 'ALBANIA'],
            'HR': ['HR', 'CROATIA'],
            'RS': ['RS', 'SERBIA'],
            'BA': ['BA', 'BIH', 'BOSNIA'],
            'MK': ['MK', 'MACEDONIA'],
            'GR': ['GR', 'GREECE']
        }
        
        category_upper = category_name.upper()
        for country_code, patterns in country_patterns.items():
            for pattern in patterns:
                if pattern in category_upper:
                    return country_code
        
        return None

