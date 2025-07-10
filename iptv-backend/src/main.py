import os
import sys
import re

from flask import Flask, send_from_directory, jsonify, request
from flask_cors import CORS

# Flask uygulaması
app = Flask(__name__, static_folder=os.path.join(os.path.dirname(__file__), 'static'))
app.config['SECRET_KEY'] = 'iptv-secret-key-2024'

# CORS ayarları
CORS(app, origins="*")

# Veritabanı konfigürasyonu
try:
    from flask_sqlalchemy import SQLAlchemy
    app.config['SQLALCHEMY_DATABASE_URI'] = f"sqlite:///{os.path.join(os.path.dirname(__file__), 'database', 'iptv.db')}"
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    db = SQLAlchemy(app)
    
    # Hiyerarşik kategori modelleri
    class MainCategory(db.Model):
        __tablename__ = 'main_categories'
        id = db.Column(db.Integer, primary_key=True)
        name = db.Column(db.String(100), nullable=False, unique=True)
        display_name = db.Column(db.String(255), nullable=False)
        channel_count = db.Column(db.Integer, default=0)
        
    class SubCategory(db.Model):
        __tablename__ = 'sub_categories'
        id = db.Column(db.Integer, primary_key=True)
        name = db.Column(db.String(255), nullable=False)
        main_category_id = db.Column(db.Integer, db.ForeignKey('main_categories.id'))
        channel_count = db.Column(db.Integer, default=0)
        
    class CategoryType(db.Model):
        __tablename__ = 'category_types'
        id = db.Column(db.Integer, primary_key=True)
        name = db.Column(db.String(100), nullable=False)
        sub_category_id = db.Column(db.Integer, db.ForeignKey('sub_categories.id'))
        
    class Channel(db.Model):
        __tablename__ = 'channels'
        id = db.Column(db.Integer, primary_key=True)
        name = db.Column(db.String(255), nullable=False)
        stream_url = db.Column(db.Text, nullable=False)
        main_category_id = db.Column(db.Integer, db.ForeignKey('main_categories.id'))
        sub_category_id = db.Column(db.Integer, db.ForeignKey('sub_categories.id'))
        category_type_id = db.Column(db.Integer, db.ForeignKey('category_types.id'))
        original_category = db.Column(db.String(500))  # Orijinal group-title
        is_active = db.Column(db.Boolean, default=True)
        logo_url = db.Column(db.Text)
        tvg_id = db.Column(db.String(255))
        tvg_name = db.Column(db.String(255))
        
    # Legacy kategori modeli (geriye uyumluluk için)
    class Category(db.Model):
        __tablename__ = 'categories'
        id = db.Column(db.Integer, primary_key=True)
        name = db.Column(db.String(255), nullable=False)
        
    # Veritabanı tablolarını oluştur
    with app.app_context():
        db.create_all()
        
except Exception as e:
    print(f"Veritabanı hatası: {e}")
    db = None

def parse_category_hierarchy(group_title):
    """Kategori hiyerarşisini parse et"""
    if not group_title or not group_title.strip():
        return None, None, None
        
    # ★ ile ayrılmış yapıyı parse et
    parts = group_title.split('★')
    
    if len(parts) >= 2:
        main_category = parts[0].strip()
        sub_part = parts[1].strip()
        
        # Alt kategoriyi | ile ayrılmış kısımları parse et
        if '|' in sub_part:
            sub_parts = [p.strip() for p in sub_part.split('|') if p.strip()]
            sub_category = sub_parts[0] if sub_parts else sub_part
            category_type = sub_parts[1] if len(sub_parts) > 1 else None
        else:
            sub_category = sub_part
            category_type = None
            
        return main_category, sub_category, category_type
    else:
        # Basit kategori yapısı
        return group_title.strip(), None, None

# API endpoint'leri
@app.route('/api/status', methods=['GET'])
def api_status():
    """API durumu"""
    try:
        if db and Channel:
            total_channels = Channel.query.filter_by(is_active=True).count()
            total_main_categories = MainCategory.query.count() if MainCategory else 0
            total_sub_categories = SubCategory.query.count() if SubCategory else 0
            
            return jsonify({
                'success': True,
                'status': 'IPTV API çalışıyor',
                'stats': {
                    'total_channels': total_channels,
                    'total_main_categories': total_main_categories,
                    'total_sub_categories': total_sub_categories
                }
            })
        else:
            return jsonify({
                'success': True,
                'status': 'IPTV API çalışıyor (veritabanı bağlantısı yok)',
                'message': 'Temel sistem aktif'
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'status': 'Veritabanı hatası',
            'error': str(e)
        }), 500

@app.route('/api/main-categories', methods=['GET'])
def get_main_categories():
    """Ana kategori listesi"""
    try:
        if not db or not MainCategory:
            return jsonify({'success': False, 'error': 'Veritabanı bağlantısı yok'}), 500
            
        main_categories = MainCategory.query.order_by(MainCategory.channel_count.desc()).all()
        
        return jsonify({
            'success': True,
            'main_categories': [{
                'id': cat.id,
                'name': cat.name,
                'display_name': cat.display_name,
                'channel_count': cat.channel_count
            } for cat in main_categories]
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/sub-categories/<int:main_category_id>', methods=['GET'])
def get_sub_categories(main_category_id):
    """Belirli ana kategorinin alt kategorileri"""
    try:
        if not db or not SubCategory:
            return jsonify({'success': False, 'error': 'Veritabanı bağlantısı yok'}), 500
            
        sub_categories = SubCategory.query.filter_by(main_category_id=main_category_id)\
                                         .order_by(SubCategory.channel_count.desc()).all()
        
        return jsonify({
            'success': True,
            'sub_categories': [{
                'id': cat.id,
                'name': cat.name,
                'main_category_id': cat.main_category_id,
                'channel_count': cat.channel_count
            } for cat in sub_categories]
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/channels', methods=['GET'])
def get_channels():
    """Kanal listesi"""
    try:
        if not db or not Channel:
            return jsonify({'success': False, 'error': 'Veritabanı bağlantısı yok'}), 500
            
        page = int(request.args.get('page', 1))
        per_page = min(int(request.args.get('per_page', 20)), 100)
        main_category_id = request.args.get('main_category_id')
        sub_category_id = request.args.get('sub_category_id')
        
        query = Channel.query.filter_by(is_active=True)
        
        if main_category_id:
            query = query.filter_by(main_category_id=main_category_id)
        if sub_category_id:
            query = query.filter_by(sub_category_id=sub_category_id)
            
        channels = query.paginate(page=page, per_page=per_page, error_out=False)
        
        return jsonify({
            'success': True,
            'channels': [{
                'id': ch.id,
                'name': ch.name,
                'stream_url': ch.stream_url,
                'main_category_id': ch.main_category_id,
                'sub_category_id': ch.sub_category_id,
                'original_category': ch.original_category,
                'logo_url': ch.logo_url
            } for ch in channels.items],
            'pagination': {
                'page': page,
                'pages': channels.pages,
                'per_page': per_page,
                'total': channels.total,
                'has_next': channels.has_next,
                'has_prev': channels.has_prev
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# Legacy endpoint'ler (geriye uyumluluk için)
@app.route('/api/categories', methods=['GET'])
def get_categories():
    """Legacy kategori listesi"""
    try:
        if not db or not MainCategory:
            return jsonify({'success': False, 'error': 'Veritabanı bağlantısı yok'}), 500
            
        main_categories = MainCategory.query.order_by(MainCategory.channel_count.desc()).all()
        
        return jsonify({
            'success': True,
            'categories': [{
                'id': cat.id,
                'name': f"{cat.display_name} ({cat.channel_count} kanal)"
            } for cat in main_categories]
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# Dummy endpoint'ler frontend için
@app.route('/api/watch/continue/<session_id>', methods=['GET'])
def get_continue_watching(session_id):
    """Kaldığı yerden devam listesi"""
    return jsonify({
        'success': True,
        'continue_watching': []
    })

# Frontend static dosyaları serve et
@app.route('/')
def serve_frontend():
    """Ana sayfa - React uygulamasını serve et"""
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/<path:path>')
def serve_static(path):
    """Static dosyaları serve et"""
    if path and os.path.exists(os.path.join(app.static_folder, path)):
        return send_from_directory(app.static_folder, path)
    else:
        # SPA routing için index.html'i döndür
        return send_from_directory(app.static_folder, 'index.html')

if __name__ == '__main__':
    print("IPTV Backend API başlatılıyor...")
    print("Server: http://0.0.0.0:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)

