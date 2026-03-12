import React, { useEffect, useState } from 'react';
import api, { API_BASE_URL } from '../services/api';
import { useCart } from '../context/CartContext';
import { useLanguage } from '../context/LanguageContext';
import AuthService from '../services/auth.service';
import { ROLE_MECHANIC, ROLE_RETAILER, ROLE_WHOLESALER } from '../services/constants';
import { Search, ShoppingCart, Package, Info, CheckCircle2 } from 'lucide-react';
import { useLocation } from 'react-router-dom';

const Shop: React.FC = () => {
  const { t, tp } = useLanguage();
  const [products, setProducts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [searchTerm, setSearchTerm] = useState('');
  const { addItem } = useCart();
  const currentUser = AuthService.getCurrentUser();
  const location = useLocation();

  const getImageUrl = (path: string) => {
    if (!path) return '';
    if (path.startsWith('http')) return path;
    // Remove /api from base URL if path already includes it
    const base = API_BASE_URL.endsWith('/api') ? API_BASE_URL.replace('/api', '') : API_BASE_URL;
    return `${base}${path.startsWith('/') ? '' : '/'}${path}`;
  };

  useEffect(() => {
    const run = async () => {
      try {
        let res;
        const isWholesaler = currentUser?.roles?.includes(ROLE_WHOLESALER);
        
        if (isWholesaler) {
          res = await api.get('/products/wholesaler');
        } else {
          res = await api.get('/products');
        }

        const data = res.data || [];
        setProducts(data);
      } catch (e: any) {
        console.error('Shop fetch error:', e);
        if (e?.response?.status === 403 || e?.response?.status === 400) {
          try {
            const res2 = await api.get('/products');
            setProducts(res2.data || []);
          } catch {
            setError(t('common.error'));
          }
        } else {
          setError(t('common.error'));
        }
      } finally {
        setLoading(false);
      }
    };
    run();
  }, [currentUser, t]);

  useEffect(() => {
    const params = new URLSearchParams(location.search);
    const q = params.get('q') || '';
    if (q) setSearchTerm(q);
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

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh]">
        <div className="w-12 h-12 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin mb-4" />
        <p className="text-gray-500 font-medium">{t('common.loading')}</p>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 mb-10">
        <div>
          <h1 className="text-3xl font-black text-gray-900 mb-2">{t('shop.title')}</h1>
          <p className="text-gray-500 font-medium">Find high-quality spare parts for your business</p>
        </div>

        <div className="relative group w-full md:w-96">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400 group-focus-within:text-primary-500 transition" />
          <input
            type="text"
            placeholder={t('shop.search')}
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-12 pr-4 py-3.5 bg-white border border-gray-200 rounded-2xl focus:outline-none focus:ring-4 focus:ring-primary-500/10 focus:border-primary-500 shadow-sm transition-all"
          />
        </div>
      </div>

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
                  {p.imagePath ? (
                    <img 
                      src={getImageUrl(p.imagePath)} 
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
                    <div className="absolute top-3 left-3 bg-green-500 text-white px-2.5 py-1 rounded-lg font-bold text-[10px] uppercase tracking-widest shadow-lg shadow-green-200">
                      Member Price
                    </div>
                  )}
                </div>

                <div className="flex-grow">
                  <div className="flex justify-between items-start gap-2 mb-1">
                    <h3 className="font-bold text-gray-900 leading-tight line-clamp-2">{tp(p.name)}</h3>
                  </div>
                  <div className="text-xs font-bold text-gray-400 uppercase tracking-widest mb-3">Part: {p.partNumber}</div>
                  
                  <div className="flex items-baseline gap-2 mb-2">
                    <span className="text-2xl font-black text-primary-700">₹{displayPrice}</span>
                    <span className="text-sm text-gray-400 line-through">₹{p.mrp}</span>
                  </div>
                </div>

                <div className="mt-4 space-y-3">
                  <div className="flex items-center gap-2">
                    <div className={`w-2 h-2 rounded-full ${inStock ? 'bg-green-500' : 'bg-red-500'}`} />
                    <span className="text-xs font-bold text-gray-600">{t('shop.stock')}: {p.stock}</span>
                  </div>

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
                    className={`w-full flex items-center justify-center gap-2 py-3 rounded-xl font-bold text-sm transition-all shadow-lg ${
                      inStock 
                        ? 'bg-primary-600 text-white hover:bg-primary-700 shadow-primary-100' 
                        : 'bg-gray-100 text-gray-400 cursor-not-allowed shadow-none'
                    }`}
                    disabled={!inStock}
                  >
                    {inStock ? (
                      <>
                        <ShoppingCart className="w-4 h-4" />
                        {t('shop.addToCart')}
                      </>
                    ) : (
                      t('shop.outOfStock')
                    )}
                  </button>
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
