import React, { useState } from 'react';
import { useCart } from '../context/CartContext';
import { useAuth } from '../context/AuthContext';
import { useLanguage } from '../context/LanguageContext';
import api from '../services/api';
import { useNavigate } from 'react-router-dom';
import { Trash2, Plus, Minus, ShoppingCart, ArrowRight, Package, Star } from 'lucide-react';

const Cart: React.FC = () => {
  const { items, updateQty, removeItem, total, clear } = useCart();
  const { currentUser, setCurrentUser } = useAuth();
  const { t, tp } = useLanguage();
  const [placing, setPlacing] = useState(false);
  const [usePoints, setUsePoints] = useState(false);
  const [msg, setMsg] = useState('');
  const navigate = useNavigate();

  const userPoints = currentUser?.points || 0;
  const pointsToRedeem = usePoints ? Math.min(userPoints, total) : 0;
  const finalTotal = total - pointsToRedeem;

  const checkout = async () => {
    if (!items.length) return;
    setPlacing(true);
    setMsg('');
    try {
      console.log('Cart: starting checkout with items:', items);
      const wholesalerGroups: Record<number, any[]> = {};
      items.forEach((i) => {
        if (!i.wholesalerId) {
          console.warn(`Item ${i.name} missing wholesalerId, skipping.`);
          return;
        }
        const wid = i.wholesalerId;
        if (!wholesalerGroups[wid]) wholesalerGroups[wid] = [];
        wholesalerGroups[wid].push(i);
      });

      if (Object.keys(wholesalerGroups).length === 0) {
        setMsg(t('shop.orderFail'));
        setPlacing(false);
        return;
      }

      const orderPromises = Object.entries(wholesalerGroups).map(([wid, groupItems]) => {
        const payload = {
          sellerId: parseInt(wid),
          pointsToRedeem: usePoints ? pointsToRedeem : 0, // In multi-seller cart, this might need refinement
          items: groupItems.map((i) => ({
            productId: i.productId,
            productName: i.name,
            quantity: i.quantity,
            price: i.price || 0,
          })),
        };
        return api.post('orders', payload);
      });

      const responses = await Promise.all(orderPromises);
      
      // Refresh user points
      try {
        const profileRes = await api.get('users/profile');
        const updatedUser = { ...currentUser, ...profileRes.data };
        setCurrentUser(updatedUser);
        localStorage.setItem('user', JSON.stringify(updatedUser));
      } catch (e) {
        console.error('Failed to refresh profile after checkout:', e);
      }

      clear();
      
      if (responses.length === 1) {
        const orderId = responses[0]?.data?.id;
        if (orderId) {
          navigate(`/order/${orderId}`);
          return;
        }
      }
      
      setMsg(t('shop.orderSuccess'));
      setTimeout(() => navigate('/shop'), 2000);
    } catch (err: any) {
      const errorMessage = err?.response?.data?.message || err?.message || t('shop.orderFail');
      setMsg(errorMessage);
    } finally {
      setPlacing(false);
    }
  };

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex items-center gap-3 mb-8">
        <div className="p-3 bg-primary-100 rounded-xl">
          <ShoppingCart className="w-6 h-6 text-primary-600" />
        </div>
        <h1 className="text-2xl font-bold text-gray-900">{t('shop.cart')}</h1>
      </div>

      {items.length === 0 ? (
        <div className="bg-white p-12 rounded-2xl shadow-sm border border-gray-100 text-center">
          <div className="w-20 h-20 bg-gray-50 rounded-full flex items-center justify-center mx-auto mb-6">
            <Package className="w-10 h-10 text-gray-300" />
          </div>
          <p className="text-gray-500 text-lg mb-8">{t('shop.empty')}</p>
          <button
            onClick={() => navigate('/shop')}
            className="inline-flex items-center gap-2 bg-primary-600 text-white px-8 py-3 rounded-xl font-bold hover:bg-primary-700 transition"
          >
            {t('nav.shop')} <ArrowRight className="w-5 h-5" />
          </button>
        </div>
      ) : (
        <div className="flex flex-col lg:flex-row gap-8">
          {/* Items Section */}
          <div className="flex-grow space-y-4">
            {/* Desktop Table View */}
            <div className="hidden md:block bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50/50">
                  <tr>
                    <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Product Details</th>
                    <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Price</th>
                    <th className="px-6 py-4 text-center text-xs font-bold text-gray-500 uppercase tracking-wider">Quantity</th>
                    <th className="px-6 py-4 text-right text-xs font-bold text-gray-500 uppercase tracking-wider">Subtotal</th>
                    <th className="px-6 py-4 text-right text-xs font-bold text-gray-500 uppercase tracking-wider"></th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-100">
                  {items.map((i) => (
                    <tr key={i.productId} className="hover:bg-gray-50/50 transition">
                      <td className="px-6 py-5">
                        <div className="flex items-center gap-4">
                          <div className="w-12 h-12 bg-gray-100 rounded-lg flex items-center justify-center">
                            <Package className="w-6 h-6 text-gray-400" />
                          </div>
                          <div>
                            <div className="font-bold text-gray-900">{tp(i.name)}</div>
                            <div className="text-sm text-gray-500 font-medium">Part: {i.partNumber}</div>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-5 whitespace-nowrap text-sm text-gray-600 font-medium">₹{i.price}</td>
                      <td className="px-6 py-5 whitespace-nowrap">
                        <div className="flex items-center justify-center bg-gray-50 rounded-lg p-1 w-fit mx-auto">
                          <button
                            onClick={() => updateQty(i.productId, Math.max(1, i.quantity - 1))}
                            className="w-8 h-8 rounded-md bg-white border border-gray-200 shadow-sm flex items-center justify-center hover:bg-gray-50 text-gray-600 transition"
                          ><Minus className="w-4 h-4" /></button>
                          <span className="w-10 text-center font-bold text-gray-900">{i.quantity}</span>
                          <button
                            onClick={() => updateQty(i.productId, i.quantity + 1)}
                            className="w-8 h-8 rounded-md bg-white border border-gray-200 shadow-sm flex items-center justify-center hover:bg-gray-50 text-gray-600 transition"
                          ><Plus className="w-4 h-4" /></button>
                        </div>
                      </td>
                      <td className="px-6 py-5 whitespace-nowrap text-right text-sm text-primary-700 font-bold">₹{(i.price || 0) * i.quantity}</td>
                      <td className="px-6 py-5 whitespace-nowrap text-right">
                        <button onClick={() => removeItem(i.productId)} className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition">
                          <Trash2 className="w-5 h-5" />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Mobile Card View */}
            <div className="md:hidden space-y-4">
              {items.map((i) => (
                <div key={i.productId} className="bg-white p-4 rounded-2xl shadow-sm border border-gray-100">
                  <div className="flex gap-4 mb-4">
                    <div className="w-16 h-16 bg-gray-100 rounded-xl flex items-center justify-center shrink-0">
                      <Package className="w-8 h-8 text-gray-400" />
                    </div>
                    <div className="flex-grow">
                      <div className="font-bold text-gray-900">{tp(i.name)}</div>
                      <div className="text-sm text-gray-500">Part: {i.partNumber}</div>
                      <div className="text-primary-700 font-bold mt-1">₹{i.price}</div>
                    </div>
                    <button onClick={() => removeItem(i.productId)} className="p-2 text-gray-400 hover:text-red-600 h-fit">
                      <Trash2 className="w-5 h-5" />
                    </button>
                  </div>
                  <div className="flex items-center justify-between pt-4 border-t border-gray-50">
                    <div className="flex items-center bg-gray-50 rounded-lg p-1">
                      <button
                        onClick={() => updateQty(i.productId, Math.max(1, i.quantity - 1))}
                        className="w-8 h-8 rounded-md bg-white border border-gray-200 flex items-center justify-center shadow-sm"
                      ><Minus className="w-4 h-4" /></button>
                      <span className="w-10 text-center font-bold">{i.quantity}</span>
                      <button
                        onClick={() => updateQty(i.productId, i.quantity + 1)}
                        className="w-8 h-8 rounded-md bg-white border border-gray-200 flex items-center justify-center shadow-sm"
                      ><Plus className="w-4 h-4" /></button>
                    </div>
                    <div className="text-right">
                      <div className="text-xs text-gray-400 uppercase font-bold tracking-wider">Subtotal</div>
                      <div className="text-lg font-bold text-primary-700">₹{(i.price || 0) * i.quantity}</div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Summary Section */}
          <div className="w-full lg:w-96 shrink-0">
            <div className="bg-white p-8 rounded-2xl shadow-sm border border-gray-100 sticky top-24">
              <h2 className="text-xl font-bold text-gray-900 mb-6">Order Summary</h2>
              <div className="space-y-4 mb-8">
                <div className="flex justify-between text-gray-600">
                  <span>Items Total</span>
                  <span className="font-medium">₹{total}</span>
                </div>
                <div className="flex justify-between text-gray-600">
                  <span>Delivery Fee</span>
                  <span className="text-blue-600 font-medium">Free</span>
                </div>
                {userPoints > 0 && (
                  <div className="pt-4 border-t border-gray-100">
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center gap-2">
                        <Star className="w-4 h-4 text-amber-500 fill-amber-500" />
                        <span className="text-sm font-bold text-gray-700">Redeem Points</span>
                      </div>
                      <button
                        onClick={() => setUsePoints(!usePoints)}
                        className={`w-10 h-5 rounded-full transition-colors relative ${usePoints ? 'bg-primary-600' : 'bg-gray-200'}`}
                      >
                        <div className={`absolute top-1 w-3 h-3 bg-white rounded-full transition-all ${usePoints ? 'left-6' : 'left-1'}`} />
                      </button>
                    </div>
                    <div className="text-xs text-gray-500">
                      Available: <span className="font-bold text-amber-600">{userPoints}</span> points (₹1 = 1 point)
                    </div>
                    {usePoints && (
                      <div className="flex justify-between text-amber-600 font-bold mt-2 text-sm">
                        <span>Points Discount</span>
                        <span>-₹{pointsToRedeem}</span>
                      </div>
                    )}
                  </div>
                )}
                <div className="pt-4 border-t border-gray-100 flex justify-between items-center">
                  <span className="text-lg font-bold text-gray-900">{t('shop.total')}</span>
                  <div className="text-right">
                    {usePoints && pointsToRedeem > 0 && (
                      <div className="text-sm text-gray-400 line-through">₹{total}</div>
                    )}
                    <div className="text-2xl font-black text-primary-700">₹{finalTotal}</div>
                  </div>
                </div>
              </div>

              <button
                onClick={checkout}
                disabled={placing}
                className="w-full bg-primary-600 text-white py-4 rounded-xl font-bold hover:bg-primary-700 transition-all shadow-lg shadow-primary-200 disabled:opacity-50 flex items-center justify-center gap-2"
              >
                {placing ? (
                  <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                ) : (
                  <>
                    {t('shop.checkout')}
                    <ArrowRight className="w-5 h-5" />
                  </>
                )}
              </button>

              {msg && (
                <div className={`mt-6 p-4 rounded-xl text-sm font-medium text-center ${msg.includes(t('common.success')) ? 'bg-blue-50 text-blue-700' : 'bg-red-50 text-red-700'}`}>
                  {msg}
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Cart;
