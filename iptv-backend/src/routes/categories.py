from flask import Blueprint, jsonify, request
from src.models.iptv import db, Category, Channel
from sqlalchemy import func

categories_bp = Blueprint('categories', __name__)

@categories_bp.route('/categories', methods=['GET'])
def get_categories():
    """Tüm kategorileri listele"""
    try:
        # Kanal sayısı ile birlikte kategorileri getir
        categories = db.session.query(
            Category,
            func.count(Channel.id).label('actual_channel_count')
        ).outerjoin(
            Channel, Category.id == Channel.category_id
        ).filter(
            Channel.is_active == True
        ).group_by(
            Category.id
        ).order_by(
            func.count(Channel.id).desc()
        ).all()
        
        result = []
        for category, actual_count in categories:
            category_dict = category.to_dict()
            category_dict['actual_channel_count'] = actual_count
            result.append(category_dict)
        
        return jsonify({
            'success': True,
            'categories': result,
            'total': len(result)
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@categories_bp.route('/categories/<int:category_id>', methods=['GET'])
def get_category(category_id):
    """Kategori detayı"""
    try:
        category = Category.query.get_or_404(category_id)
        
        # Aktif kanal sayısını hesapla
        active_channel_count = Channel.query.filter_by(
            category_id=category_id,
            is_active=True
        ).count()
        
        category_dict = category.to_dict()
        category_dict['active_channel_count'] = active_channel_count
        
        return jsonify({
            'success': True,
            'category': category_dict
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@categories_bp.route('/categories/stats', methods=['GET'])
def get_category_stats():
    """Kategori istatistikleri"""
    try:
        # En popüler kategoriler
        popular_categories = db.session.query(
            Category.name,
            Category.id,
            func.count(Channel.id).label('channel_count')
        ).join(
            Channel, Category.id == Channel.category_id
        ).filter(
            Channel.is_active == True
        ).group_by(
            Category.id, Category.name
        ).order_by(
            func.count(Channel.id).desc()
        ).limit(10).all()
        
        # Dil bazında istatistikler
        language_stats = db.session.query(
            Channel.language,
            func.count(Channel.id).label('channel_count')
        ).filter(
            Channel.is_active == True,
            Channel.language.isnot(None)
        ).group_by(
            Channel.language
        ).order_by(
            func.count(Channel.id).desc()
        ).all()
        
        # Ülke bazında istatistikler
        country_stats = db.session.query(
            Channel.country,
            func.count(Channel.id).label('channel_count')
        ).filter(
            Channel.is_active == True,
            Channel.country.isnot(None)
        ).group_by(
            Channel.country
        ).order_by(
            func.count(Channel.id).desc()
        ).all()
        
        return jsonify({
            'success': True,
            'stats': {
                'popular_categories': [
                    {
                        'id': cat_id,
                        'name': name,
                        'channel_count': count
                    }
                    for name, cat_id, count in popular_categories
                ],
                'language_distribution': [
                    {
                        'language': lang or 'Unknown',
                        'channel_count': count
                    }
                    for lang, count in language_stats
                ],
                'country_distribution': [
                    {
                        'country': country or 'Unknown',
                        'channel_count': count
                    }
                    for country, count in country_stats
                ]
            }
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@categories_bp.route('/categories/search', methods=['GET'])
def search_categories():
    """Kategori arama"""
    try:
        query_text = request.args.get('q', '').strip()
        
        if not query_text:
            return jsonify({
                'success': False,
                'error': 'Arama terimi gerekli'
            }), 400
        
        categories = Category.query.filter(
            Category.name.ilike(f'%{query_text}%')
        ).order_by(
            Category.channel_count.desc()
        ).all()
        
        return jsonify({
            'success': True,
            'query': query_text,
            'categories': [category.to_dict() for category in categories]
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

