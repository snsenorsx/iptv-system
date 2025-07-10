import React, { useState, useEffect } from 'react';
import { Play, Monitor, Globe, Folder, Search, Image } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { useApp } from '../contexts/AppContext';

const ChannelList = ({ onChannelSelect, selectedChannel, selectedCategory, searchQuery }) => {
  const [channels, setChannels] = useState([]);
  const [loading, setLoading] = useState(false);
  const [pagination, setPagination] = useState(null);
  const [currentPage, setCurrentPage] = useState(1);
  const { api } = useApp();

  useEffect(() => {
    loadChannels(1);
  }, [selectedCategory, searchQuery]);

  const loadChannels = async (page = 1) => {
    try {
      setLoading(true);
      
      const params = {
        page: page,
        per_page: 50
      };

      // Kategori filtresi
      if (selectedCategory) {
        if (selectedCategory.type === 'country') {
          params.main_category_id = selectedCategory.id;
        } else if (selectedCategory.type === 'subcategory') {
          params.main_category_id = selectedCategory.countryId;
          params.sub_category_id = selectedCategory.id;
        }
      }

      // Arama filtresi
      if (searchQuery && searchQuery.trim()) {
        params.search = searchQuery.trim();
      }

      const response = await api.getChannels(params);
      
      if (response.success) {
        if (page === 1) {
          setChannels(response.channels);
        } else {
          setChannels(prev => [...prev, ...response.channels]);
        }
        setPagination(response.pagination);
        setCurrentPage(page);
      }
    } catch (error) {
      console.error('Kanallar yüklenemedi:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadMoreChannels = () => {
    if (pagination && pagination.has_next && !loading) {
      loadChannels(currentPage + 1);
    }
  };

  const handleChannelClick = (channel) => {
    onChannelSelect(channel);
  };

  const getChannelDisplayName = (channel) => {
    return channel.name || channel.tvg_name || 'İsimsiz Kanal';
  };

  const getCategoryInfo = (channel) => {
    // Orijinal kategori bilgisini göster
    if (channel.original_category) {
      return channel.original_category;
    }
    return 'Kategori yok';
  };

  if (loading && channels.length === 0) {
    return (
      <div className="p-4">
        <div className="animate-pulse space-y-3">
          {[...Array(10)].map((_, i) => (
            <div key={i} className="flex items-center space-x-3 bg-white p-3 rounded-lg">
              <div className="w-16 h-12 bg-gray-200 rounded"></div>
              <div className="flex-1 space-y-2">
                <div className="h-4 bg-gray-200 rounded w-3/4"></div>
                <div className="h-3 bg-gray-200 rounded w-1/2"></div>
              </div>
              <div className="w-20 h-8 bg-gray-200 rounded"></div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col">
      {/* Header */}
      <div className="p-4 border-b bg-white shadow-sm">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Monitor className="w-5 h-5 text-blue-500" />
            <h2 className="font-semibold text-gray-800">
              {searchQuery ? 'Arama Sonuçları' : 'Kanallar'}
            </h2>
          </div>
          
          {pagination && (
            <Badge variant="secondary" className="bg-blue-100 text-blue-700">
              {pagination.total.toLocaleString()} kanal
            </Badge>
          )}
        </div>

        {/* Kategori bilgisi */}
        {selectedCategory && (
          <div className="mt-3 flex items-center gap-2 text-sm text-gray-600 bg-gray-50 p-2 rounded-lg">
            {selectedCategory.type === 'country' ? (
              <>
                <Globe className="w-4 h-4 text-blue-500" />
                <span className="font-medium">{selectedCategory.name}</span>
              </>
            ) : (
              <>
                <Globe className="w-4 h-4 text-blue-500" />
                <span>{selectedCategory.countryName}</span>
                <span className="text-gray-400">→</span>
                <Folder className="w-4 h-4 text-orange-500" />
                <span className="font-medium">{selectedCategory.name}</span>
              </>
            )}
          </div>
        )}

        {/* Arama bilgisi */}
        {searchQuery && (
          <div className="mt-3 flex items-center gap-2 text-sm text-gray-600 bg-yellow-50 p-2 rounded-lg">
            <Search className="w-4 h-4 text-yellow-600" />
            <span>"{searchQuery}" için sonuçlar</span>
          </div>
        )}
      </div>

      {/* Kanal listesi */}
      <div className="flex-1 overflow-y-auto bg-gray-50">
        {channels.length === 0 && !loading ? (
          <div className="p-8 text-center text-gray-500">
            <Monitor className="w-16 h-16 mx-auto mb-4 text-gray-300" />
            <p className="text-lg font-medium mb-2">Kanal bulunamadı</p>
            <p className="text-sm">
              {searchQuery 
                ? 'Arama kriterlerinizi değiştirmeyi deneyin'
                : 'Bu kategoride kanal bulunmuyor'
              }
            </p>
          </div>
        ) : (
          <div className="p-4 space-y-3">
            {channels.map((channel) => (
              <div
                key={channel.id}
                className={`
                  flex items-center p-4 rounded-lg cursor-pointer transition-all duration-200 shadow-sm
                  ${selectedChannel?.id === channel.id 
                    ? 'bg-blue-50 border-2 border-blue-300 shadow-md' 
                    : 'bg-white hover:bg-gray-50 border border-gray-200 hover:shadow-md'
                  }
                `}
                onClick={() => handleChannelClick(channel)}
              >
                {/* Logo */}
                <div className="w-16 h-12 rounded-lg overflow-hidden bg-gray-100 flex-shrink-0 border">
                  {channel.logo_url ? (
                    <img
                      src={channel.logo_url}
                      alt={getChannelDisplayName(channel)}
                      className="w-full h-full object-cover"
                      onError={(e) => {
                        e.target.style.display = 'none';
                        e.target.nextSibling.style.display = 'flex';
                      }}
                    />
                  ) : null}
                  <div className="w-full h-full flex items-center justify-center text-gray-400 bg-gradient-to-br from-gray-100 to-gray-200">
                    <Image className="w-6 h-6" />
                  </div>
                </div>

                {/* Kanal bilgileri */}
                <div className="flex-1 ml-4 min-w-0">
                  <h3 className="font-semibold text-gray-900 truncate text-lg">
                    {getChannelDisplayName(channel)}
                  </h3>
                  <p className="text-sm text-gray-500 truncate mt-1">
                    {getCategoryInfo(channel)}
                  </p>
                  {channel.tvg_id && (
                    <p className="text-xs text-gray-400 mt-1">
                      ID: {channel.tvg_id}
                    </p>
                  )}
                </div>

                {/* Oynat butonu */}
                <Button
                  size="sm"
                  className="ml-4 flex-shrink-0 bg-blue-600 hover:bg-blue-700 text-white shadow-md"
                  onClick={(e) => {
                    e.stopPropagation();
                    handleChannelClick(channel);
                  }}
                >
                  <Play className="w-4 h-4 mr-1" />
                  İzle
                </Button>
              </div>
            ))}

            {/* Daha fazla yükle */}
            {pagination && pagination.has_next && (
              <div className="p-4 text-center">
                <Button
                  variant="outline"
                  onClick={loadMoreChannels}
                  disabled={loading}
                  className="w-full bg-white hover:bg-gray-50 border-2 border-dashed border-gray-300 hover:border-blue-300"
                >
                  {loading ? (
                    <div className="flex items-center gap-2">
                      <div className="w-4 h-4 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
                      Yükleniyor...
                    </div>
                  ) : (
                    'Daha Fazla Yükle'
                  )}
                </Button>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default ChannelList;

