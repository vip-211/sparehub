import React, { useEffect, useState } from 'react';
import api, { API_BASE_URL } from '../services/api';
import { useCart } from '../context/CartContext';
import { useLanguage } from '../context/LanguageContext';
import AuthService from '../services/auth.service';
import { ROLE_ADMIN, ROLE_MECHANIC, ROLE_RETAILER, ROLE_SUPER_MANAGER, ROLE_WHOLESALER } from '../services/constants';
import { Search, ShoppingCart, Package, Info, CheckCircle2, Settings, Car, StopCircle, Disc, Droplets, Lightbulb, Battery, LayoutGrid, Mic, ScanBarcode } from 'lucide-react';
import { useLocation } from 'react-router-dom';
import Skeleton from '../components/Skeleton';
import BarcodeScanner from '../components/BarcodeScanner';
import { useExternalScanner } from '../hooks/useExternalScanner';

const Shop: React.FC = () => {
  const { t, tp } = useLanguage();
  const [products, setProducts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [searchTerm, setSearchTerm] = useState('');
  const [isListening, setIsListening] = useState(false);
  const [showScanner, setShowScanner] = useState(false);
  const { addItem } = useCart();

  // Listen for external hardware scanner
  useExternalScanner((code) => {
    setSearchTerm(code);
    // Focus search input if not already
    const searchInput = document.querySelector('input[placeholder*="search"]') as HTMLInputElement;
    if (searchInput) searchInput.focus();
  });
  const currentUser = AuthService.getCurrentUser();
  const location = useLocation();
  const [categoryId, setCategoryId] = useState<number | null>(null);
  const [categories, setCategories] = useState<any[]>([]);

  const isRestricted = currentUser?.roles?.includes(ROLE_ADMIN) || currentUser?.roles?.includes(ROLE_SUPER_MANAGER);

  const getCategoryIcon = (name: string) => {
    const n = name.toLowerCase();
    if (n.includes('engine')) return <Settings className="w-5 h-5" />;
    if (n.includes('body')) return <Car className="w-5 h-5" />;
    if (n.includes('brake')) return <StopCircle className="w-5 h-5" />;
    if (n.includes('tyre') || n.includes('tire')) return <Disc className="w-5 h-5" />;
    if (n.includes('oil')) return <Droplets className="w-5 h-5" />;
    if (n.includes('light')) return <Lightbulb className="w-5 h-5" />;
    if (n.includes('battery')) return <Battery className="w-5 h-5" />;
    return <Package className="w-5 h-5" />;
  };

  const getImageUrl = (path: string) => {
    if (!path) return '';
    if (path.startsWith('http')) return path;
    // Remove /api from base URL if path already includes it
    const base = API_BASE_URL.endsWith('/api') ? API_BASE_URL.replace('/api', '') : API_BASE_URL;
    return `${base}${path.startsWith('/') ? '' : '/'}${path}`;
  };

  const toggleVoiceSearch = () => {
    if (!('webkitSpeechRecognition' in window)) {
      alert('Voice search not supported in this browser');
      return;
    }
    const recognition = new (window as any).webkitSpeechRecognition();
    recognition.lang = 'en-IN';
    recognition.onstart = () => setIsListening(true);
    recognition.onend = () => setIsListening(false);
    recognition.onresult = (event: any) => {
      const text = event.results[0][0].transcript;
      setSearchTerm(text);
    };
    recognition.start();
  };

  useEffect(() => {
    const run = async () => {
      setLoading(true);
      try {
        // load categories if not already loaded or once
        if (categories.length === 0) {
          try {
            const cats = await api.get('categories');
            setCategories(cats.data || []);
          } catch (err) {
            console.warn('Categories load failed', err);
          }
        }

        let res;
        const isWholesaler = currentUser?.roles?.includes(ROLE_WHOLESALER);
        
        if (isWholesaler) {
          res = await api.get('products/wholesaler');
        } else {
          const params: any = {};
          if (categoryId) params.categoryId = categoryId;
          res = await api.get('products', { params });
        }

        const data = res.data || [];
        setProducts(data);
        setError('');
      } catch (e: any) {
        console.error('Shop fetch error:', e);
        setError(t('common.error'));
      } finally {
        setLoading(false);
      }
    };
    run();
  }, [currentUser, categoryId]);

  useEffect(() => {
    const params = new URLSearchParams(location.search);
    const q = params.get('q') || '';
    if (q) setSearchTerm(q);
    const cat = params.get('cat');
    if (cat) {
      const id = Number(cat);
      if (!Number.isNaN(id)) setCategoryId(id);
    }
  }, [location.search]);

  const getPriceForRole = (p: any) => {
    if (currentUser?.roles?.includes(ROLE_MECHANIC)) {
      return (p.mechanicPrice !== null && p.mechanicPrice !== undefined) ? p.mechanicPrice : (p.sellingPrice || 0);
    }
    if (currentUser?.roles?.includes(ROLE_RETAILER)) {
      return (p.retailerPrice !== null && p.retailerPrice !== undefined) ? p.retailerPrice : (p.sellingPrice || 0);
    }
    return p.sellingPrice || 0;
  };

  const filteredProducts = products.filter(p => 
    p.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
    p.partNumber.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const renderSkeletons = () => (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
      {[1, 2, 3, 4, 5, 6, 7, 8].map((i) => (
        <div key={i} className="bg-white rounded-2xl p-4 shadow-sm border border-gray-100">
          <Skeleton className="w-full aspect-square rounded-xl mb-4" />
          <Skeleton className="w-3/4 h-4 mb-2" />
          <Skeleton className="w-1/2 h-3 mb-4" />
          <div className="flex justify-between items-center">
            <Skeleton className="w-20 h-6" />
            <Skeleton className="w-10 h-10 rounded-full" />
          </div>
        </div>
      ))}
    </div>
  );

  if (loading && products.length === 0) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="flex flex-col md:flex-row gap-4 mb-8">
          <Skeleton className="flex-1 h-12 rounded-xl" />
          <Skeleton className="w-full md:w-48 h-12 rounded-xl" />
        </div>
        <div className="flex gap-2 overflow-x-auto pb-4 mb-8">
          {[1, 2, 3, 4, 5].map(i => <Skeleton key={i} className="min-w-[100px] h-10 rounded-full" />)}
        </div>
        {renderSkeletons()}
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 mb-8">
        <div>
          <h1 className="text-4xl font-black text-gray-900 mb-2">{t('shop.title')}</h1>
          <p className="text-gray-500 font-bold text-lg">See parts, tap to buy</p>
        </div>

        <div className="flex items-center gap-4 w-full md:w-auto">
          <div className="relative group flex-1 md:w-96">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-6 h-6 text-gray-400 group-focus-within:text-primary-500 transition" />
            <input
              type="text"
              placeholder={t('shop.search')}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-12 pr-4 py-4 bg-white border-2 border-gray-200 rounded-2xl focus:outline-none focus:ring-4 focus:ring-primary-500/10 focus:border-primary-500 shadow-sm transition-all text-lg font-bold"
            />
          </div>
          <button
            onClick={() => setShowScanner(true)}
            className="p-4 rounded-2xl bg-white border-2 border-gray-200 hover:border-primary-500 hover:text-primary-600 transition-all shadow-lg shadow-gray-100"
            title="Scan Barcode"
          >
            <ScanBarcode className="w-7 h-7" />
          </button>
          <button
            onClick={toggleVoiceSearch}
            className={`p-4 rounded-2xl transition-all shadow-lg ${isListening ? 'bg-red-500 animate-pulse scale-110 shadow-red-200' : 'bg-primary-600 hover:bg-primary-700 shadow-primary-100'}`}
            title="Speak to find parts"
          >
            <Mic className={`w-7 h-7 text-white ${isListening ? 'animate-bounce' : ''}`} />
          </button>
        </div>
      </div>

      {showScanner && (
        <BarcodeScanner 
          onScanSuccess={(text) => setSearchTerm(text)}
          onClose={() => setShowScanner(false)}
        />
      )}

      {categories.length > 0 && (
        <div className="flex flex-wrap gap-3 mb-10 overflow-x-auto pb-2 scrollbar-hide">
          <button
            onClick={() => { setCategoryId(null); }}
            className={`flex items-center gap-2 px-6 py-3 rounded-2xl text-sm font-black border-2 transition-all ${categoryId === null ? 'bg-primary-600 text-white border-primary-600 shadow-lg shadow-primary-200 scale-105' : 'bg-white text-gray-700 border-gray-200 hover:border-primary-300'}`}
          >
            <LayoutGrid className="w-5 h-5" />
            All
          </button>
          {categories.map((c) => (
            <button
              key={c.id}
              onClick={() => { setCategoryId(c.id); }}
              className={`flex items-center gap-2 px-6 py-3 rounded-2xl text-sm font-black border-2 transition-all ${categoryId === c.id ? 'bg-primary-600 text-white border-primary-600 shadow-lg shadow-primary-200 scale-105' : 'bg-white text-gray-700 border-gray-200 hover:border-primary-300'}`}
            >
              {c.imageLink || c.imagePath ? (
                <img src={getImageUrl(c.imageLink || c.imagePath)} alt="" className="w-5 h-5 object-cover rounded-full" />
              ) : (
                getCategoryIcon(c.name)
              )}
              {c.name}
            </button>
          ))}
        </div>
      )}

      {error && (
        <div className="mb-8 p-4 bg-red-50 border border-red-100 rounded-xl flex items-center gap-3 text-red-700 font-medium">
          <Info className="w-5 h-5" />
          {error}
        </div>
      )}

      {filteredProducts.length === 0 ? (
        <div className="bg-white rounded-3xl shadow-sm border border-gray-100 p-16 text-center">
          <div className="w-20 h-20 bg-gray-50 rounded-full flex items-center justify-center mx-auto mb-6">
            <Search className="w-10 h-10 text-gray-300" />
          </div>
          <h3 className="text-xl font-bold text-gray-900 mb-2">No products found</h3>
          <p className="text-gray-500">Try adjusting your search terms or filters</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          {filteredProducts.map((p) => {
            const displayPrice = getPriceForRole(p);
            const inStock = p.stock > 0;
            return (
              <div key={p.id} className="group bg-white rounded-2xl shadow-sm border border-gray-100 p-5 flex flex-col h-full hover:shadow-xl hover:-translate-y-1 transition-all duration-300">
                <div className="relative mb-4 aspect-square bg-gray-50 rounded-xl flex items-center justify-center overflow-hidden">
                  {p.imagePath || p.imageLink || p.categoryImageLink || p.categoryImagePath ? (
                    <img 
                      src={getImageUrl(p.imagePath || p.imageLink || p.categoryImageLink || p.categoryImagePath)} 
                      alt={tp(p.name)} 
                      className="w-full h-full object-cover group-hover:scale-110 transition duration-500"
                      onError={(e) => {
                        (e.target as HTMLImageElement).src = 'https://via.placeholder.com/400x400?text=Part';
                      }}
                    />
                  ) : (
                    <Package className="w-16 h-16 text-gray-300 group-hover:scale-110 transition duration-500" />
                  )}
                  {!inStock && (
                    <div className="absolute inset-0 bg-white/60 backdrop-blur-[2px] flex items-center justify-center">
                      <span className="bg-red-100 text-red-700 px-3 py-1.5 rounded-lg font-bold text-xs uppercase tracking-wider">{t('shop.outOfStock')}</span>
                    </div>
                  )}
                  {displayPrice !== p.sellingPrice && (
                    <div className="absolute top-3 left-3 bg-blue-500 text-white px-2.5 py-1 rounded-lg font-bold text-[10px] uppercase tracking-widest shadow-lg shadow-blue-200">
                      Member Price
                    </div>
                  )}
                </div>

                <div className="flex-grow">
                  <div className="flex justify-between items-start gap-2 mb-2">
                    <h3 className="text-xl font-black text-gray-900 leading-tight line-clamp-2">{tp(p.name)}</h3>
                  </div>
                  <div className="flex items-center gap-2 mb-4">
                    <span className={`flex items-center gap-1 px-2 py-1 rounded-lg text-[10px] font-black uppercase tracking-widest ${inStock ? 'bg-blue-100 text-blue-700' : 'bg-red-100 text-red-700'}`}>
                      {inStock ? <CheckCircle2 className="w-3 h-3" /> : <Info className="w-3 h-3" />}
                      {inStock ? 'In Stock' : 'Out of Stock'}
                    </span>
                    <span className="text-xs font-bold text-gray-400">#{p.partNumber}</span>
                  </div>
                  
                  <div className="flex flex-col mb-4">
                    <span className="text-3xl font-black text-primary-600">₹{displayPrice}</span>
                    {p.mrp > displayPrice && (
                      <span className="text-sm text-gray-400 line-through font-bold">MRP: ₹{p.mrp}</span>
                    )}
                  </div>
                </div>

                <div className="mt-auto pt-4 border-t border-gray-50">
                  {!isRestricted && (
                    <button
                      onClick={() =>
                        addItem(
                          {
                            productId: p.id,
                            name: p.name,
                            partNumber: p.partNumber,
                            price: displayPrice,
                            wholesalerId: p.wholesalerId,
                          },
                          1,
                        )
                      }
                      className={`w-full flex items-center justify-center gap-3 py-4 rounded-2xl font-black text-lg transition-all shadow-xl active:scale-95 ${
                        inStock 
                          ? 'bg-primary-600 text-white hover:bg-primary-700 shadow-primary-200 hover:shadow-2xl' 
                          : 'bg-gray-100 text-gray-400 cursor-not-allowed shadow-none'
                      }`}
                      disabled={!inStock}
                    >
                      {inStock ? (
                        <>
                          <ShoppingCart className="w-6 h-6" />
                          {t('shop.addToCart')}
                        </>
                      ) : (
                        'Sold Out'
                      )}
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default Shop;
