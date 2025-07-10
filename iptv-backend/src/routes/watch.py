from flask import Blueprint, jsonify, request
from src.models.iptv import db, WatchSession, Channel
from datetime import datetime

watch_bp = Blueprint('watch', __name__)

@watch_bp.route('/watch/update/<session_id>', methods=['POST'])
def update_watch_position(session_id):
    """İzleme durumunu güncelle"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'JSON verisi gerekli'
            }), 400
        
        channel_id = data.get('channel_id')
        watch_position = data.get('watch_position', 0)
        
        if not channel_id:
            return jsonify({
                'success': False,
                'error': 'channel_id gerekli'
            }), 400
        
        # Kanal kontrolü
        channel = Channel.query.get(channel_id)
        if not channel:
            return jsonify({
                'success': False,
                'error': 'Kanal bulunamadı'
            }), 404
        
        # İzleme durumunu bul veya oluştur
        watch_session = WatchSession.query.filter_by(
            session_id=session_id,
            channel_id=channel_id
        ).first()
        
        if watch_session:
            # Mevcut durumu güncelle
            watch_session.watch_position = watch_position
            watch_session.last_watched_at = datetime.utcnow()
        else:
            # Yeni izleme durumu oluştur
            watch_session = WatchSession(
                session_id=session_id,
                channel_id=channel_id,
                watch_position=watch_position,
                last_watched_at=datetime.utcnow()
            )
            db.session.add(watch_session)
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'watch_session': watch_session.to_dict()
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@watch_bp.route('/watch/continue/<session_id>', methods=['GET'])
def get_continue_watching(session_id):
    """Kaldığı yerden devam edilecek kanallar"""
    try:
        limit = request.args.get('limit', 10, type=int)
        
        # Son izlenen kanalları getir (pozisyon > 0 olanlar)
        watch_sessions = WatchSession.query.filter(
            WatchSession.session_id == session_id,
            WatchSession.watch_position > 0
        ).order_by(
            WatchSession.last_watched_at.desc()
        ).limit(limit).all()
        
        result = []
        for session in watch_sessions:
            session_dict = session.to_dict()
            # Kanal bilgilerini ekle
            if session.channel:
                session_dict['channel'] = session.channel.to_dict()
            result.append(session_dict)
        
        return jsonify({
            'success': True,
            'continue_watching': result
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@watch_bp.route('/watch/history/<session_id>', methods=['GET'])
def get_watch_history(session_id):
    """İzleme geçmişi"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)
        
        # İzleme geçmişini getir
        pagination = WatchSession.query.filter_by(
            session_id=session_id
        ).order_by(
            WatchSession.last_watched_at.desc()
        ).paginate(
            page=page,
            per_page=per_page,
            error_out=False
        )
        
        history = []
        for session in pagination.items:
            session_dict = session.to_dict()
            # Kanal bilgilerini ekle
            if session.channel:
                session_dict['channel'] = session.channel.to_dict()
            history.append(session_dict)
        
        return jsonify({
            'success': True,
            'history': history,
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

@watch_bp.route('/watch/position/<session_id>/<int:channel_id>', methods=['GET'])
def get_watch_position(session_id, channel_id):
    """Belirli bir kanal için izleme pozisyonunu getir"""
    try:
        watch_session = WatchSession.query.filter_by(
            session_id=session_id,
            channel_id=channel_id
        ).first()
        
        if watch_session:
            return jsonify({
                'success': True,
                'watch_position': watch_session.watch_position,
                'last_watched_at': watch_session.last_watched_at.isoformat()
            })
        else:
            return jsonify({
                'success': True,
                'watch_position': 0,
                'last_watched_at': None
            })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@watch_bp.route('/watch/clear/<session_id>/<int:channel_id>', methods=['DELETE'])
def clear_watch_position(session_id, channel_id):
    """İzleme pozisyonunu temizle"""
    try:
        watch_session = WatchSession.query.filter_by(
            session_id=session_id,
            channel_id=channel_id
        ).first()
        
        if watch_session:
            db.session.delete(watch_session)
            db.session.commit()
            
            return jsonify({
                'success': True,
                'message': 'İzleme pozisyonu temizlendi'
            })
        else:
            return jsonify({
                'success': True,
                'message': 'İzleme pozisyonu zaten yok'
            })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@watch_bp.route('/watch/clear-all/<session_id>', methods=['DELETE'])
def clear_all_watch_positions(session_id):
    """Tüm izleme pozisyonlarını temizle"""
    try:
        deleted_count = WatchSession.query.filter_by(
            session_id=session_id
        ).delete()
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': f'{deleted_count} izleme pozisyonu temizlendi'
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

