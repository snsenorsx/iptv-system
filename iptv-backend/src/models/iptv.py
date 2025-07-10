from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import re

db = SQLAlchemy()

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

