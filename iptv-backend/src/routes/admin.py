from flask import Blueprint, jsonify, request
from src.models.iptv import db, Channel, Category, M3USource, WatchSession
from src.services.m3u_parser import m3u_parser
from sqlalchemy import func

admin_bp = Blueprint('admin', __name__)

@admin_bp.route('/admin/m3u/update', methods=['POST'])
def update_m3u():
    """M3U kaynağını güncelle"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'JSON verisi gerekli'
            }), 400
        
        url = data.get('url')
        source_name = data.get('name', 'Default Source')
        
        if not url:
            return jsonify({
                'success': False,
                'error': 'M3U URL gerekli'
            }), 400
        
        # M3U parse işlemini başlat
        result = m3u_parser.parse_m3u_url(url, source_name)
        
        if result['success']:
            return jsonify({
                'success': True,
                'message': 'M3U başarıyla güncellendi',
                'stats': {
                    'total_channels': result['total_channels'],
                    'total_categories': result['total_categories'],
                    'working_url': result['working_url']
                }
            })
        else:
            return jsonify({
                'success': False,
                'error': result['error']
            }), 500
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@admin_bp.route('/admin/stats', methods=['GET'])
def get_system_stats():
    """Sistem istatistikleri"""
    try:
        # Temel istatistikler
        total_channels = Channel.query.filter_by(is_active=True).count()
        total_categories = Category.query.count()
        total_watch_sessions = WatchSession.query.count()
        
        # En popüler kategoriler
        popular_categories = db.session.query(
            Category.name,
            func.count(Channel.id).label('channel_count')
        ).join(
            Channel, Category.id == Channel.category_id
        ).filter(
            Channel.is_active == True
        ).group_by(
            Category.name
        ).order_by(
            func.count(Channel.id).desc()
        ).limit(10).all()
        
        # En çok izlenen kanallar
        popular_channels = db.session.query(
            Channel.name,
            func.count(WatchSession.id).label('watch_count')
        ).join(
            WatchSession, Channel.id == WatchSession.channel_id
        ).group_by(
            Channel.name
        ).order_by(
            func.count(WatchSession.id).desc()
        ).limit(10).all()
        
        # Dil dağılımı
        language_distribution = db.session.query(
            Channel.language,
            func.count(Channel.id).label('count')
        ).filter(
            Channel.is_active == True
        ).group_by(
            Channel.language
        ).order_by(
            func.count(Channel.id).desc()
        ).all()
        
        # Ülke dağılımı
        country_distribution = db.session.query(
            Channel.country,
            func.count(Channel.id).label('count')
        ).filter(
            Channel.is_active == True
        ).group_by(
            Channel.country
        ).order_by(
            func.count(Channel.id).desc()
        ).all()
        
        # M3U kaynakları
        m3u_sources = M3USource.query.all()
        
        return jsonify({
            'success': True,
            'stats': {
                'overview': {
                    'total_channels': total_channels,
                    'total_categories': total_categories,
                    'total_watch_sessions': total_watch_sessions
                },
                'popular_categories': [
                    {
                        'name': name,
                        'channel_count': count
                    }
                    for name, count in popular_categories
                ],
                'popular_channels': [
                    {
                        'name': name,
                        'watch_count': count
                    }
                    for name, count in popular_channels
                ],
                'language_distribution': [
                    {
                        'language': lang or 'Unknown',
                        'count': count
                    }
                    for lang, count in language_distribution
                ],
                'country_distribution': [
                    {
                        'country': country or 'Unknown',
                        'count': count
                    }
                    for country, count in country_distribution
                ],
                'm3u_sources': [source.to_dict() for source in m3u_sources]
            }
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@admin_bp.route('/admin/channels', methods=['GET'])
def get_admin_channels():
    """Admin kanal listesi (tüm kanallar dahil)"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        include_inactive = request.args.get('include_inactive', 'false').lower() == 'true'
        
        # Base query
        query = Channel.query
        
        if not include_inactive:
            query = query.filter_by(is_active=True)
        
        # Sayfalama
        pagination = query.order_by(
            Channel.created_at.desc()
        ).paginate(
            page=page,
            per_page=per_page,
            error_out=False
        )
        
        channels = []
        for channel in pagination.items:
            channel_dict = channel.to_dict()
            # İzlenme sayısını ekle
            watch_count = WatchSession.query.filter_by(channel_id=channel.id).count()
            channel_dict['watch_count'] = watch_count
            channels.append(channel_dict)
        
        return jsonify({
            'success': True,
            'channels': channels,
            'pagination': {
                'page': page,
                'per_page': per_page,
                'total': pagination.total,
                'pages': pagination.pages,
                'has_next': pagination.has_next,
                'has_prev': pagination.has_prev
            }
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@admin_bp.route('/admin/channels/<int:channel_id>', methods=['PUT'])
def update_channel(channel_id):
    """Kanal güncelle"""
    try:
        channel = Channel.query.get_or_404(channel_id)
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'JSON verisi gerekli'
            }), 400
        
        # Güncellenebilir alanlar
        if 'name' in data:
            channel.name = data['name']
        if 'is_active' in data:
            channel.is_active = data['is_active']
        if 'logo_url' in data:
            channel.logo_url = data['logo_url']
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Kanal güncellendi',
            'channel': channel.to_dict()
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@admin_bp.route('/admin/channels/<int:channel_id>', methods=['DELETE'])
def delete_channel(channel_id):
    """Kanal sil"""
    try:
        channel = Channel.query.get_or_404(channel_id)
        
        # İzleme durumlarını da sil
        WatchSession.query.filter_by(channel_id=channel_id).delete()
        
        db.session.delete(channel)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Kanal silindi'
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@admin_bp.route('/admin/cleanup', methods=['POST'])
def cleanup_database():
    """Veritabanı temizleme"""
    try:
        # Eski izleme durumlarını temizle (30 günden eski)
        from datetime import datetime, timedelta
        
        cutoff_date = datetime.utcnow() - timedelta(days=30)
        deleted_sessions = WatchSession.query.filter(
            WatchSession.last_watched_at < cutoff_date
        ).delete()
        
        # Boş kategorileri temizle
        empty_categories = Category.query.outerjoin(Channel).group_by(
            Category.id
        ).having(
            func.count(Channel.id) == 0
        ).all()
        
        deleted_categories = 0
        for category in empty_categories:
            db.session.delete(category)
            deleted_categories += 1
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Veritabanı temizlendi',
            'stats': {
                'deleted_sessions': deleted_sessions,
                'deleted_categories': deleted_categories
            }
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

