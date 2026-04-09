import React, { useEffect, useState } from 'react';
import api, { API_BASE_URL } from '../services/api';
import { useCart } from '../context/CartContext';
import { useLanguage } from '../context/LanguageContext';
import AuthService from '../services/auth.service';
import { ROLE_ADMIN, ROLE_MECHANIC, ROLE_RETAILER, ROLE_SUPER_MANAGER, ROLE_WHOLESALER } from '../services/constants';
import { Search, ShoppingCart, Package, Info, CheckCircle2, Settings, Car, StopCircle, Disc, Droplets, Lightbulb, Battery, LayoutGrid, Mic, ScanBarcode, Keyboard } from 'lucide-react';
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
  const [scannerMode, setScannerMode] = useState<'camera' | 'external'>('camera');
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

  const [selectedProduct, setSelectedProduct] = useState<any>(null);
  const [currentImageIndex, setCurrentImageIndex] = useState(0);

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
          <div className="relative group">
            <button
              onClick={() => {
                setScannerMode('camera');
                setShowScanner(true);
              }}
              className="p-4 rounded-2xl bg-white border-2 border-gray-200 hover:border-primary-500 hover:text-primary-600 transition-all shadow-lg shadow-gray-100 flex items-center gap-2"
              title="Scan Barcode"
            >
              <ScanBarcode className="w-7 h-7" />
            </button>
            <div className="absolute top-full right-0 mt-2 bg-white border border-gray-200 rounded-xl shadow-xl z-10 hidden group-hover:block overflow-hidden min-w-[180px]">
              <button
                onClick={() => {
                  setScannerMode('camera');
                  setShowScanner(true);
                }}
                className="w-full text-left px-4 py-3 hover:bg-gray-50 flex items-center gap-3 font-bold text-sm text-gray-700"
              >
                <div className="p-1.5 bg-blue-100 text-blue-600 rounded-lg">
                  <ScanBarcode size={16} />
                </div>
                Camera Scan
              </button>
              <button
                onClick={() => {
                  setScannerMode('external');
                  setShowScanner(true);
                }}
                className="w-full text-left px-4 py-3 hover:bg-gray-50 flex items-center gap-3 font-bold text-sm text-gray-700"
              >
                <div className="p-1.5 bg-amber-100 text-amber-600 rounded-lg">
                  <Keyboard size={16} />
                </div>
                Hardware Scanner
              </button>
            </div>
          </div>
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
          initialMode={scannerMode}
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
            const images = [p.imageLink || p.imagePath, ...(p.imageLinks || [])].filter(Boolean);
            const mainImage = images.length > 0 ? getImageUrl(images[0]) : (p.categoryImageLink || p.categoryImagePath ? getImageUrl(p.categoryImageLink || p.categoryImagePath) : null);

            return (
              <div 
                key={p.id} 
                className="group bg-white rounded-2xl shadow-sm border border-gray-100 p-5 flex flex-col h-full hover:shadow-xl hover:-translate-y-1 transition-all duration-300 cursor-pointer"
                onClick={() => {
                  setSelectedProduct(p);
                  setCurrentImageIndex(0);
                }}
              >
                <div className="relative mb-4 aspect-square bg-gray-50 rounded-xl flex items-center justify-center overflow-hidden">
                  {mainImage ? (
                    <img 
                      src={mainImage} 
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

      {/* Product Detail Modal */}
      {selectedProduct && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm overflow-y-auto">
          <div className="bg-white rounded-3xl w-full max-w-4xl max-h-[90vh] overflow-hidden shadow-2xl flex flex-col md:flex-row">
            {/* Image Gallery */}
            <div className="w-full md:w-1/2 bg-gray-50 p-6 flex flex-col items-center justify-center">
              <div className="relative w-full aspect-square rounded-2xl overflow-hidden mb-4 border border-gray-200 bg-white flex items-center justify-center">
                {(() => {
                  const images = [selectedProduct.imageLink || selectedProduct.imagePath, ...(selectedProduct.imageLinks || [])].filter(Boolean);
                  if (images.length > 0) {
                    return (
                      <img 
                        src={getImageUrl(images[currentImageIndex])} 
                        alt={selectedProduct.name} 
                        className="w-full h-full object-contain"
                      />
                    );
                  }
                  return <Package className="w-24 h-24 text-gray-300" />;
                })()}
              </div>
              
              {selectedProduct.imageLinks && selectedProduct.imageLinks.length > 0 && (
                <div className="flex gap-2 overflow-x-auto pb-2 w-full justify-center">
                  {[selectedProduct.imageLink || selectedProduct.imagePath, ...selectedProduct.imageLinks].filter(Boolean).map((img, idx) => (
                    <button 
                      key={idx}
                      onClick={() => setCurrentImageIndex(idx)}
                      className={`w-16 h-16 rounded-lg border-2 flex-shrink-0 overflow-hidden transition-all ${currentImageIndex === idx ? 'border-primary-500 scale-105 shadow-md' : 'border-gray-200 opacity-70 hover:opacity-100'}`}
                    >
                      <img src={getImageUrl(img)} alt="" className="w-full h-full object-cover" />
                    </button>
                  ))}
                </div>
              )}
            </div>

            {/* Product Info */}
            <div className="w-full md:w-1/2 p-8 flex flex-col">
              <div className="flex justify-between items-start mb-4">
                <div>
                  <h2 className="text-3xl font-black text-gray-900 mb-2">{tp(selectedProduct.name)}</h2>
                  <span className="text-sm font-bold text-gray-400">Part Number: #{selectedProduct.partNumber}</span>
                </div>
                <button 
                  onClick={() => setSelectedProduct(null)}
                  className="p-2 hover:bg-gray-100 rounded-full transition-colors"
                >
                  <Info className="w-6 h-6 text-gray-400" />
                </button>
              </div>

              <div className="flex items-center gap-3 mb-6">
                <span className={`px-3 py-1.5 rounded-xl text-xs font-black uppercase tracking-widest ${selectedProduct.stock > 0 ? 'bg-blue-100 text-blue-700' : 'bg-red-100 text-red-700'}`}>
                  {selectedProduct.stock > 0 ? 'In Stock' : 'Out of Stock'}
                </span>
                {selectedProduct.categoryName && (
                  <span className="px-3 py-1.5 rounded-xl bg-gray-100 text-gray-600 text-xs font-black uppercase tracking-widest">
                    {selectedProduct.categoryName}
                  </span>
                )}
              </div>

              <div className="mb-8 flex-grow overflow-y-auto pr-2">
                <h4 className="text-lg font-black text-gray-900 mb-3">Description</h4>
                <p className="text-gray-600 leading-relaxed font-bold">
                  {selectedProduct.description || 'No detailed description available for this part.'}
                </p>
                
                {selectedProduct.rackNumber && (
                  <div className="mt-4 p-4 bg-gray-50 rounded-2xl flex items-center justify-between border border-gray-100">
                    <span className="text-sm font-bold text-gray-500 uppercase tracking-widest">Storage Location</span>
                    <span className="text-lg font-black text-primary-600">{selectedProduct.rackNumber}</span>
                  </div>
                )}

                {selectedProduct.minOrderQty > 1 && (
                  <div className="mt-4 p-4 bg-amber-50 rounded-2xl flex items-center justify-between border border-amber-100">
                    <span className="text-sm font-bold text-amber-700 uppercase tracking-widest">Min Order Qty</span>
                    <span className="text-lg font-black text-amber-600">{selectedProduct.minOrderQty} Units</span>
                  </div>
                )}
              </div>

              <div className="mt-auto">
                <div className="flex items-baseline gap-3 mb-6">
                  <span className="text-4xl font-black text-primary-600">₹{getPriceForRole(selectedProduct)}</span>
                  {selectedProduct.mrp > getPriceForRole(selectedProduct) && (
                    <span className="text-xl text-gray-400 line-through font-bold">₹{selectedProduct.mrp}</span>
                  )}
                </div>

                {!isRestricted && (
                  <button
                    onClick={() => {
                      addItem({
                        productId: selectedProduct.id,
                        name: selectedProduct.name,
                        partNumber: selectedProduct.partNumber,
                        price: getPriceForRole(selectedProduct),
                        wholesalerId: selectedProduct.wholesalerId,
                      }, selectedProduct.minOrderQty || 1);
                      setSelectedProduct(null);
                    }}
                    className={`w-full py-5 rounded-2xl font-black text-xl flex items-center justify-center gap-3 shadow-2xl transition-all active:scale-95 ${
                      selectedProduct.stock > 0 
                        ? 'bg-primary-600 text-white hover:bg-primary-700 shadow-primary-200' 
                        : 'bg-gray-100 text-gray-400 cursor-not-allowed shadow-none'
                    }`}
                    disabled={selectedProduct.stock <= 0}
                  >
                    <ShoppingCart className="w-7 h-7" />
                    {selectedProduct.stock > 0 ? t('shop.addToCart') : 'Out of Stock'}
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Shop;
