import React, { useState, useEffect } from 'react';
import { ChevronRight, ChevronDown, Globe, Folder, Tag } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { useApp } from '../contexts/AppContext';

const CategoryList = ({ onCategorySelect, selectedCategory }) => {
  const [countries, setCountries] = useState([]);
  const [subCategories, setSubCategories] = useState({});
  const [expandedCountries, setExpandedCountries] = useState(new Set());
  const [loading, setLoading] = useState(true);
  const { api } = useApp();

  useEffect(() => {
    loadCountries();
  }, []);

  const loadCountries = async () => {
    try {
      setLoading(true);
      const response = await api.getMainCategories();
      if (response.success) {
        setCountries(response.main_categories);
      }
    } catch (error) {
      console.error('Ülkeler yüklenemedi:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadSubCategories = async (countryId) => {
    if (subCategories[countryId]) return; // Zaten yüklü

    try {
      const response = await api.getSubCategories(countryId);
      if (response.success) {
        setSubCategories(prev => ({
          ...prev,
          [countryId]: response.sub_categories
        }));
      }
    } catch (error) {
      console.error('Alt kategoriler yüklenemedi:', error);
    }
  };

  const toggleCountry = async (countryId) => {
    const newExpanded = new Set(expandedCountries);
    
    if (newExpanded.has(countryId)) {
      newExpanded.delete(countryId);
    } else {
      newExpanded.add(countryId);
      await loadSubCategories(countryId);
    }
    
    setExpandedCountries(newExpanded);
  };

  const handleCountrySelect = (country) => {
    onCategorySelect({
      type: 'country',
      id: country.id,
      name: country.display_name,
      channelCount: country.channel_count
    });
  };

  const handleSubCategorySelect = (country, subCategory) => {
    onCategorySelect({
      type: 'subcategory',
      countryId: country.id,
      countryName: country.display_name,
      id: subCategory.id,
      name: subCategory.name,
      channelCount: subCategory.channel_count
    });
  };

  // Ülke adını düzgün göster
  const getCountryDisplayName = (country) => {
    const countryNames = {
      'DE': 'Almanya',
      'TR': 'Türkiye',
      'EU': 'Avrupa',
      'XXX': 'Yetişkin',
      'FR': 'Fransa',
      'BG': 'Bulgaristan',
      'ALB': 'Arnavutluk',
      'NL': 'Hollanda',
      'EN': 'İngilizce',
      'ES': 'İspanya',
      'AR': 'Arapça',
      'PL': 'Polonya',
      'PT': 'Portekiz',
      'US': 'Amerika',
      'IT': 'İtalya',
      'GR': 'Yunanistan',
      'SV': 'İsveç',
      'RU': 'Rusya',
      'UK': 'İngiltere',
      'AL': 'Arnavutluk',
      'RO': 'Romanya',
      'NORDIC': 'Nordik',
      'EX': 'Eski Yugoslavya',
      'CH': 'İsviçre',
      'AU': 'Avusturya',
      'IR': 'İran',
      'BE': 'Belçika',
      'HU': 'Macaristan',
      'IL': 'İsrail',
      'KU': 'Kürtçe',
      'NO': 'Norveç',
      'SE': 'İsveç',
      'PT -BR': 'Brezilya',
      'DK': 'Danimarka',
      'CA': 'Kanada',
      'HR': 'Hırvatistan',
      'AZ': 'Azerbaycan',
      'BIH': 'Bosna',
      'FIN': 'Finlandiya',
      'MK': 'Makedonya',
      'EX-YU': 'Eski Yugoslavya'
    };
    
    return countryNames[country.name] || country.display_name || country.name;
  };

  if (loading) {
    return (
      <div className="p-4">
        <div className="animate-pulse space-y-3">
          {[...Array(10)].map((_, i) => (
            <div key={i} className="flex items-center space-x-3">
              <div className="w-6 h-6 bg-gray-200 rounded"></div>
              <div className="flex-1 h-4 bg-gray-200 rounded"></div>
              <div className="w-12 h-4 bg-gray-200 rounded"></div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="h-full overflow-y-auto bg-white">
      {/* Header */}
      <div className="p-4 border-b bg-gradient-to-r from-blue-50 to-indigo-50">
        <h2 className="text-lg font-bold text-gray-800 flex items-center gap-2">
          <Globe className="w-5 h-5 text-blue-600" />
          Kategoriler
        </h2>
        <p className="text-sm text-gray-600 mt-1">
          {countries.length} ülke • {countries.reduce((sum, c) => sum + c.channel_count, 0).toLocaleString()} kanal
        </p>
      </div>

      {/* Ülke listesi */}
      <div className="p-2 space-y-1">
        {countries.map((country) => (
          <div key={country.id} className="bg-white rounded-lg border border-gray-100 shadow-sm">
            {/* Ülke başlığı */}
            <div className="flex items-center">
              <Button
                variant="ghost"
                className="flex-1 justify-start p-3 h-auto hover:bg-blue-50 rounded-l-lg rounded-r-none"
                onClick={() => handleCountrySelect(country)}
              >
                <div className="flex items-center gap-3 w-full">
                  <Globe className="w-5 h-5 text-blue-500 flex-shrink-0" />
                  <div className="flex-1 text-left">
                    <div className="font-medium text-gray-800">
                      {getCountryDisplayName(country)}
                    </div>
                    <div className="text-xs text-gray-500">
                      {country.name}
                    </div>
                  </div>
                  <Badge variant="secondary" className="bg-blue-100 text-blue-700 font-medium">
                    {country.channel_count.toLocaleString()}
                  </Badge>
                </div>
              </Button>
              
              <Button
                variant="ghost"
                size="sm"
                onClick={() => toggleCountry(country.id)}
                className="p-2 hover:bg-blue-50 rounded-r-lg rounded-l-none border-l border-gray-100"
              >
                {expandedCountries.has(country.id) ? (
                  <ChevronDown className="w-4 h-4 text-gray-600" />
                ) : (
                  <ChevronRight className="w-4 h-4 text-gray-600" />
                )}
              </Button>
            </div>

            {/* Alt kategoriler */}
            {expandedCountries.has(country.id) && (
              <div className="border-t border-gray-100 bg-gray-50">
                {subCategories[country.id] ? (
                  <div className="p-2 space-y-1">
                    {subCategories[country.id].map((subCat) => (
                      <Button
                        key={subCat.id}
                        variant="ghost"
                        className="w-full justify-start p-2 h-auto text-sm hover:bg-white rounded-md"
                        onClick={() => handleSubCategorySelect(country, subCat)}
                      >
                        <div className="flex items-center gap-2 w-full">
                          <Folder className="w-4 h-4 text-orange-500 flex-shrink-0" />
                          <span className="flex-1 text-left truncate text-gray-700">
                            {subCat.name}
                          </span>
                          <Badge variant="outline" className="text-xs bg-white">
                            {subCat.channel_count}
                          </Badge>
                        </div>
                      </Button>
                    ))}
                  </div>
                ) : (
                  <div className="p-3 text-sm text-gray-500 text-center">
                    <div className="animate-pulse">Yükleniyor...</div>
                  </div>
                )}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};

export default CategoryList;

