from flask import Blueprint, jsonify, request
from src.models.iptv import db, Channel, Category
from sqlalchemy import or_, func

channels_bp = Blueprint('channels', __name__)

@channels_bp.route('/channels', methods=['GET'])
def get_channels():
    """Tüm kanalları listele"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        category_id = request.args.get('category_id', type=int)
        search = request.args.get('search', '').strip()
        
        # Base query
        query = Channel.query.filter_by(is_active=True)
        
        # Kategori filtresi
        if category_id:
            query = query.filter_by(category_id=category_id)
        
        # Arama filtresi
        if search:
            query = query.filter(
                or_(
                    Channel.name.ilike(f'%{search}%'),
                    Channel.tvg_name.ilike(f'%{search}%')
                )
            )
        
        # Sayfalama
        pagination = query.paginate(
            page=page, 
            per_page=per_page, 
            error_out=False
        )
        
        channels = [channel.to_dict() for channel in pagination.items]
        
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

@channels_bp.route('/channels/<int:channel_id>', methods=['GET'])
def get_channel(channel_id):
    """Kanal detayı"""
    try:
        channel = Channel.query.get_or_404(channel_id)
        return jsonify({
            'success': True,
            'channel': channel.to_dict()
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@channels_bp.route('/channels/category/<int:category_id>', methods=['GET'])
def get_channels_by_category(category_id):
    """Kategoriye göre kanallar"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        
        # Kategori kontrolü
        category = Category.query.get_or_404(category_id)
        
        # Kanalları getir
        pagination = Channel.query.filter_by(
            category_id=category_id, 
            is_active=True
        ).paginate(
            page=page, 
            per_page=per_page, 
            error_out=False
        )
        
        channels = [channel.to_dict() for channel in pagination.items]
        
        return jsonify({
            'success': True,
            'category': category.to_dict(),
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

@channels_bp.route('/channels/search', methods=['GET'])
def search_channels():
    """Kanal arama"""
    try:
        query_text = request.args.get('q', '').strip()
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        
        if not query_text:
            return jsonify({
                'success': False,
                'error': 'Arama terimi gerekli'
            }), 400
        
        # Arama sorgusu
        pagination = Channel.query.filter(
            Channel.is_active == True,
            or_(
                Channel.name.ilike(f'%{query_text}%'),
                Channel.tvg_name.ilike(f'%{query_text}%')
            )
        ).paginate(
            page=page, 
            per_page=per_page, 
            error_out=False
        )
        
        channels = [channel.to_dict() for channel in pagination.items]
        
        return jsonify({
            'success': True,
            'query': query_text,
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

@channels_bp.route('/channels/popular', methods=['GET'])
def get_popular_channels():
    """Popüler kanallar (en çok izlenen)"""
    try:
        limit = request.args.get('limit', 20, type=int)
        
        # İzleme sayısına göre popüler kanalları getir
        popular_channels = db.session.query(
            Channel,
            func.count(Channel.watch_sessions).label('watch_count')
        ).join(
            Channel.watch_sessions
        ).group_by(
            Channel.id
        ).order_by(
            func.count(Channel.watch_sessions).desc()
        ).limit(limit).all()
        
        channels = []
        for channel, watch_count in popular_channels:
            channel_dict = channel.to_dict()
            channel_dict['watch_count'] = watch_count
            channels.append(channel_dict)
        
        return jsonify({
            'success': True,
            'channels': channels
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@channels_bp.route('/channels/recent', methods=['GET'])
def get_recent_channels():
    """Son eklenen kanallar"""
    try:
        limit = request.args.get('limit', 20, type=int)
        
        channels = Channel.query.filter_by(
            is_active=True
        ).order_by(
            Channel.created_at.desc()
        ).limit(limit).all()
        
        return jsonify({
            'success': True,
            'channels': [channel.to_dict() for channel in channels]
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

