import React, { useEffect, useState } from 'react';
import api from '../services/api';
import { useCart } from '../context/CartContext';
import { useLanguage } from '../context/LanguageContext';
import { Package, Star, Lock, ShoppingCart, Info, CheckCircle2, Search, ArrowRight, TrendingUp } from 'lucide-react';
import Skeleton from '../components/Skeleton';

const Offers: React.FC = () => {
  const { t, tp } = useLanguage();
  const [offers, setOffers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const { addItem } = useCart();
  const [selectedOffer, setSelectedOffer] = useState<any>(null);

  const getImageUrl = (path: string) => {
    if (!path) return '';
    if (path.startsWith('http')) return path;
    const base = window.location.origin; // Simplified for this environment
    return `${base}${path.startsWith('/') ? '' : '/'}${path}`;
  };

  useEffect(() => {
    const fetchOffers = async () => {
      setLoading(true);
      try {
        const res = await api.get('offers/active');
        setOffers(res.data || []);
      } catch (err) {
        console.error('Error fetching offers:', err);
        setError('Failed to load exclusive offers.');
      } finally {
        setLoading(false);
      }
    };
    fetchOffers();
  }, []);

  const handleBuyNow = (offer: any) => {
    const p = offer.product;
    addItem({
      productId: p.id,
      name: p.name,
      price: offer.offerPrice || p.sellingPrice,
      partNumber: p.partNumber,
      wholesalerId: p.wholesalerId
    }, offer.minimumQuantity, offer.quantityLocked, undefined, offer.id);
    alert(`${p.name} added to cart!`);
  };

  if (loading) {
    return (
      <div className="container mx-auto px-4 py-12">
        <Skeleton className="w-64 h-12 mb-4" />
        <Skeleton className="w-full h-8 mb-12" />
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {[1, 2, 3].map(i => <Skeleton key={i} className="aspect-[4/5] rounded-[2.5rem]" />)}
        </div>
      </div>
    );
  }

  if (offers.length === 0) {
    return (
      <div className="container mx-auto px-4 py-20 text-center">
        <Star className="w-24 h-24 text-gray-200 mx-auto mb-6" />
        <h2 className="text-3xl font-black text-gray-900 mb-4">No active offers right now</h2>
        <p className="text-gray-500 font-bold mb-8 text-lg">Check back later for exclusive deals!</p>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-12">
      <div className="mb-12">
        <h1 className="text-5xl font-black text-gray-900 mb-4 flex items-center gap-4">
          <Star className="w-12 h-12 text-amber-500 fill-amber-500" />
          Exclusive Deals
        </h1>
        <p className="text-gray-500 font-bold text-xl">Special offers just for you. Buy more, save more!</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        {offers.map((offer) => {
          const p = offer.product;
          const discount = p.mrp > (offer.offerPrice || p.sellingPrice) 
            ? Math.round((1 - (offer.offerPrice || p.sellingPrice) / p.mrp) * 100) 
            : 0;

          return (
            <div key={offer.id} className="group relative bg-white rounded-[3rem] border-2 border-gray-100 overflow-hidden hover:border-amber-300 transition-all duration-500 hover:shadow-2xl hover:shadow-amber-100">
              {discount > 0 && (
                <div className="absolute top-6 left-6 z-10 bg-red-500 text-white px-4 py-2 rounded-2xl font-black text-sm shadow-xl shadow-red-100">
                  {discount}% OFF
                </div>
              )}
              
              <div className="aspect-[4/3] bg-gray-50 overflow-hidden relative">
                <img 
                  src={getImageUrl(p.imageLink || p.imagePath)} 
                  alt={p.name} 
                  className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-700"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
              </div>

              <div className="p-10">
                <div className="flex items-center gap-2 mb-4">
                  <span className="bg-amber-100 text-amber-700 px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest">Special Offer</span>
                  {offer.quantityLocked && (
                    <span className="bg-red-50 text-red-600 px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest flex items-center gap-1">
                      <Lock size={10} /> Locked
                    </span>
                  )}
                </div>

                <h3 className="text-2xl font-black text-gray-900 mb-2 truncate">{p.name}</h3>
                <p className="text-gray-500 text-sm font-medium mb-6 line-clamp-2 h-10">{offer.description || 'Exclusive bundle offer available for a limited time.'}</p>
                
                <div className="flex items-end justify-between mb-8">
                  <div>
                    <div className="text-4xl font-black text-primary-600">₹{(offer.offerPrice || p.sellingPrice).toLocaleString()}</div>
                    <div className="text-gray-400 font-bold line-through">₹{p.mrp.toLocaleString()}</div>
                  </div>
                  <div className="text-right">
                    <div className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-1">Minimum Order</div>
                    <div className="text-xl font-black text-gray-900">{offer.minimumQuantity} Units</div>
                  </div>
                </div>

                <button 
                  onClick={() => handleBuyNow(offer)}
                  disabled={p.stock <= 0}
                  className={`w-full py-5 rounded-[2rem] font-black text-lg transition-all flex items-center justify-center gap-3 ${
                    p.stock > 0 
                      ? 'bg-amber-500 text-white shadow-xl shadow-amber-100 hover:bg-amber-600 active:scale-95' 
                      : 'bg-gray-100 text-gray-400 cursor-not-allowed'
                  }`}
                >
                  {p.stock > 0 ? (
                    <>
                      <ShoppingCart className="w-6 h-6" />
                      Grab This Offer
                    </>
                  ) : 'Out of Stock'}
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default Offers;
