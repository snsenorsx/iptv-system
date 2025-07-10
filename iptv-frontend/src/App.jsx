import React, { useState, useEffect } from 'react';
import { Menu, X, Search, Play, Globe, Folder, Monitor, Tv } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import VideoPlayer from './components/VideoPlayer';
import ChannelList from './components/ChannelList';
import CategoryList from './components/CategoryList';
import { AppProvider, useApp } from './contexts/AppContext';

function AppContent() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [selectedChannel, setSelectedChannel] = useState(null);
  const [selectedCategory, setSelectedCategory] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [stats, setStats] = useState(null);
  const { api } = useApp();

  useEffect(() => {
    loadStats();
  }, []);

  const loadStats = async () => {
    try {
      const response = await api.getStatus();
      if (response.success) {
        setStats(response.stats);
      }
    } catch (error) {
      console.error('İstatistikler yüklenemedi:', error);
    }
  };

  const handleChannelSelect = (channel) => {
    setSelectedChannel(channel);
  };

  const handleCategorySelect = (category) => {
    setSelectedCategory(category);
    setSidebarOpen(false); // Mobilde sidebar'ı kapat
  };

  const handleSearch = (query) => {
    setSearchQuery(query);
    setSelectedCategory(null); // Arama yaparken kategori seçimini temizle
  };

  const getCategoryDisplayText = () => {
    if (!selectedCategory) return 'Tüm Kanallar';
    
    if (selectedCategory.type === 'country') {
      return `${selectedCategory.name} (${selectedCategory.channelCount.toLocaleString()} kanal)`;
    } else if (selectedCategory.type === 'subcategory') {
      return `${selectedCategory.countryName} → ${selectedCategory.name} (${selectedCategory.channelCount} kanal)`;
    }
    
    return selectedCategory.name;
  };

  return (
    <div className="h-screen flex bg-gray-100">
      {/* Sidebar */}
      <div className={`
        fixed inset-y-0 left-0 z-50 w-80 bg-white shadow-xl transform transition-transform duration-300 ease-in-out
        lg:relative lg:translate-x-0
        ${sidebarOpen ? 'translate-x-0' : '-translate-x-full'}
      `}>
        {/* Sidebar Header */}
        <div className="flex items-center justify-between p-4 border-b bg-gradient-to-r from-blue-600 to-indigo-600 text-white">
          <div className="flex items-center gap-2">
            <Tv className="w-6 h-6" />
            <h1 className="text-xl font-bold">IPTV Player</h1>
          </div>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setSidebarOpen(false)}
            className="lg:hidden text-white hover:bg-white/20"
          >
            <X className="w-5 h-5" />
          </Button>
        </div>
        
        {/* İstatistikler */}
        {stats && (
          <div className="p-4 border-b bg-gradient-to-r from-blue-50 to-indigo-50">
            <div className="grid grid-cols-2 gap-3 text-sm">
              <div className="flex items-center gap-2 bg-white p-2 rounded-lg shadow-sm">
                <Monitor className="w-4 h-4 text-blue-500" />
                <div>
                  <div className="font-semibold text-gray-800">
                    {stats.total_channels?.toLocaleString() || 0}
                  </div>
                  <div className="text-xs text-gray-500">Kanal</div>
                </div>
              </div>
              <div className="flex items-center gap-2 bg-white p-2 rounded-lg shadow-sm">
                <Globe className="w-4 h-4 text-green-500" />
                <div>
                  <div className="font-semibold text-gray-800">
                    {stats.total_main_categories || 0}
                  </div>
                  <div className="text-xs text-gray-500">Ülke</div>
                </div>
              </div>
              <div className="flex items-center gap-2 bg-white p-2 rounded-lg shadow-sm">
                <Folder className="w-4 h-4 text-orange-500" />
                <div>
                  <div className="font-semibold text-gray-800">
                    {stats.total_sub_categories || 0}
                  </div>
                  <div className="text-xs text-gray-500">Kategori</div>
                </div>
              </div>
              <div className="flex items-center gap-2 bg-white p-2 rounded-lg shadow-sm">
                <div className="w-4 h-4 bg-green-500 rounded-full"></div>
                <div>
                  <div className="font-semibold text-gray-800">Canlı</div>
                  <div className="text-xs text-gray-500">Durum</div>
                </div>
              </div>
            </div>
          </div>
        )}

        <CategoryList 
          onCategorySelect={handleCategorySelect}
          selectedCategory={selectedCategory}
        />
      </div>

      {/* Overlay */}
      {sidebarOpen && (
        <div 
          className="fixed inset-0 bg-black bg-opacity-50 z-40 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Ana içerik */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Header */}
        <header className="bg-white shadow-sm border-b px-4 py-3">
          <div className="flex items-center gap-4">
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setSidebarOpen(true)}
              className="lg:hidden hover:bg-gray-100"
            >
              <Menu className="w-5 h-5" />
            </Button>

            <div className="flex-1 max-w-md">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
                <input
                  type="text"
                  placeholder="Kanal ara..."
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                  value={searchQuery}
                  onChange={(e) => handleSearch(e.target.value)}
                />
              </div>
            </div>

            <div className="hidden md:flex items-center gap-2">
              <Badge variant="outline" className="text-sm">
                {getCategoryDisplayText()}
              </Badge>
            </div>
          </div>
        </header>

        {/* Video Player */}
        {selectedChannel && (
          <div className="bg-black">
            <VideoPlayer 
              channel={selectedChannel}
              onTimeUpdate={(time) => {
                // İzleme pozisyonunu kaydet
                console.log(`Kanal ${selectedChannel.id} - Pozisyon: ${time}`);
              }}
            />
          </div>
        )}

        {/* Kanal Listesi */}
        <div className="flex-1 overflow-hidden bg-gray-50">
          <ChannelList
            onChannelSelect={handleChannelSelect}
            selectedChannel={selectedChannel}
            selectedCategory={selectedCategory}
            searchQuery={searchQuery}
          />
        </div>
      </div>
    </div>
  );
}

function App() {
  return (
    <AppProvider>
      <AppContent />
    </AppProvider>
  );
}

export default App;

