from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import re
import sqlite3
import os

db = SQLAlchemy()

class IPTVDatabase:
    """IPTV veritabanı yönetim sınıfı"""
    
    def __init__(self, db_path='iptv.db'):
        self.db_path = db_path
        
    def create_tables(self):
        """Veritabanı tablolarını oluştur"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Kategoriler tablosu
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS categories (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                slug TEXT UNIQUE NOT NULL,
                channel_count INTEGER DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Kanallar tablosu
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS channels (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                stream_url TEXT NOT NULL,
                logo_url TEXT,
                tvg_id TEXT,
                tvg_name TEXT,
                category_id INTEGER,
                language TEXT,
                country TEXT,
                is_active BOOLEAN DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (category_id) REFERENCES categories (id)
            )
        ''')
        
        # İzleme oturumları tablosu
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS watch_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                channel_id INTEGER NOT NULL,
                watch_position INTEGER DEFAULT 0,
                last_watched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (channel_id) REFERENCES channels (id),
                UNIQUE(session_id, channel_id)
            )
        ''')
        
        # M3U kaynakları tablosu
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS m3u_sources (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                url TEXT NOT NULL,
                last_updated TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.commit()
        conn.close()
        
    def add_category(self, name, slug=None):
        """Kategori ekle"""
        if not slug:
            slug = Category.create_slug(name)
            
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute(
                'INSERT OR IGNORE INTO categories (name, slug) VALUES (?, ?)',
                (name, slug)
            )
            conn.commit()
            category_id = cursor.lastrowid
            conn.close()
            return category_id
        except Exception as e:
            conn.close()
            raise e
            
    def add_channel(self, channel_data):
        """Kanal ekle"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute('''
                INSERT INTO channels 
                (name, stream_url, logo_url, tvg_id, tvg_name, category_id, language, country)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                channel_data.get('name', ''),
                channel_data.get('stream_url', ''),
                channel_data.get('logo_url', ''),
                channel_data.get('tvg_id', ''),
                channel_data.get('tvg_name', ''),
                channel_data.get('category_id'),
                channel_data.get('language', ''),
                channel_data.get('country', '')
            ))
            conn.commit()
            channel_id = cursor.lastrowid
            conn.close()
            return channel_id
        except Exception as e:
            conn.close()
            raise e
            
    def get_category_by_name(self, name):
        """İsme göre kategori getir"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM categories WHERE name = ?', (name,))
        result = cursor.fetchone()
        conn.close()
        
        if result:
            return {
                'id': result[0],
                'name': result[1],
                'slug': result[2],
                'channel_count': result[3],
                'created_at': result[4]
            }
        return None
        
    def update_category_counts(self):
        """Kategori kanal sayılarını güncelle"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            UPDATE categories 
            SET channel_count = (
                SELECT COUNT(*) 
                FROM channels 
                WHERE channels.category_id = categories.id 
                AND channels.is_active = 1
            )
        ''')
        
        conn.commit()
        conn.close()

class Category(db.Model):
    __tablename__ = 'categories'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    slug = db.Column(db.String(255), unique=True, nullable=False)
    channel_count = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # İlişkiler
    channels = db.relationship('Channel', backref='category', lazy=True)
    
    def __repr__(self):
        return f'<Category {self.name}>'
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'slug': self.slug,
            'channel_count': self.channel_count,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
    
    @staticmethod
    def create_slug(name):
        """Kategori adından slug oluştur"""
        slug = re.sub(r'[^\w\s-]', '', name.lower())
        slug = re.sub(r'[-\s]+', '-', slug)
        return slug.strip('-')

class Channel(db.Model):
    __tablename__ = 'channels'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    stream_url = db.Column(db.Text, nullable=False)
    logo_url = db.Column(db.Text)
    tvg_id = db.Column(db.String(100))
    tvg_name = db.Column(db.String(255))
    category_id = db.Column(db.Integer, db.ForeignKey('categories.id'))
    language = db.Column(db.String(10))
    country = db.Column(db.String(10))
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # İlişkiler
    watch_sessions = db.relationship('WatchSession', backref='channel', lazy=True, cascade='all, delete-orphan')
    
    def __repr__(self):
        return f'<Channel {self.name}>'
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'stream_url': self.stream_url,
            'logo_url': self.logo_url,
            'tvg_id': self.tvg_id,
            'tvg_name': self.tvg_name,
            'category_id': self.category_id,
            'category_name': self.category.name if self.category else None,
            'language': self.language,
            'country': self.country,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class WatchSession(db.Model):
    __tablename__ = 'watch_sessions'
    
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.String(100), nullable=False)
    channel_id = db.Column(db.Integer, db.ForeignKey('channels.id'), nullable=False)
    watch_position = db.Column(db.Integer, default=0)  # saniye cinsinden
    last_watched_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Unique constraint
    __table_args__ = (db.UniqueConstraint('session_id', 'channel_id', name='unique_session_channel'),)
    
    def __repr__(self):
        return f'<WatchSession {self.session_id}:{self.channel_id}>'
    
    def to_dict(self):
        return {
            'id': self.id,
            'session_id': self.session_id,
            'channel_id': self.channel_id,
            'channel_name': self.channel.name if self.channel else None,
            'watch_position': self.watch_position,
            'last_watched_at': self.last_watched_at.isoformat() if self.last_watched_at else None
        }

class M3USource(db.Model):
    __tablename__ = 'm3u_sources'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    url = db.Column(db.Text, nullable=False)
    last_updated = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def __repr__(self):
        return f'<M3USource {self.name}>'
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'url': self.url,
            'last_updated': self.last_updated.isoformat() if self.last_updated else None,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

