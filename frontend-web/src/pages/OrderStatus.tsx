import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import api from '../services/api';
import { useLanguage } from '../context/LanguageContext';

const OrderStatus: React.FC = () => {
  const { id } = useParams();
  const { tp } = useLanguage();
  const [order, setOrder] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const run = async () => {
      setLoading(true);
      setError('');
      try {
        const res = await api.get(`orders/${id}`);
        setOrder(res.data);
      } catch (e) {
        try {
          const res2 = await api.get('orders/seller-orders');
          const found = Array.isArray(res2.data) ? res2.data.find((o: any) => String(o.id) === String(id)) : null;
          if (found) {
            setOrder(found);
          } else {
            setError('Order not found.');
          }
        } catch {
          setError('Failed to load order.');
        }
      } finally {
        setLoading(false);
      }
    };
    run();
  }, [id]);

  if (loading) return <div className="p-10 text-center">Loading...</div>;

  return (
    <div className="container mx-auto">
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-6">
        <h1 className="text-xl font-bold">Order #{id}</h1>
        <p className="text-gray-500 text-sm mt-1">Live status and tracking</p>
        {order?.pointsRedeemed > 0 && (
          <div className="mt-4 p-4 rounded-xl bg-emerald-50 border border-emerald-100">
            <div className="text-emerald-800 font-black">
              You saved ₹{order.pointsRedeemed} on this order! 🎉
            </div>
            <div className="text-emerald-700 text-sm font-medium mt-1">
              Thanks for ordering with Parts Mitra — smart choice using your points.
            </div>
          </div>
        )}
        {order?.status === 'DELIVERED' && order?.pointsEarned > 0 && (
          <div className="mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100">
            <div className="text-amber-800 text-sm font-bold">
              Loyalty bonus: {order.pointsEarned} points credited for this order.
            </div>
          </div>
        )}
      </div>
      {!order ? (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">{error || 'Order unavailable.'}</div>
      ) : (
        <>
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
              <div className="text-sm text-gray-500">Customer</div>
              <div className="font-semibold">{order.customerName || '-'}</div>
              <div className="mt-3 text-sm text-gray-500">Seller</div>
              <div className="font-semibold">{order.sellerName || '-'}</div>
              <div className="mt-3 text-sm text-gray-500">Amount</div>
              <div className="font-semibold">₹{order.totalAmount?.toLocaleString?.() || order.totalAmount || '-'}</div>
            </div>
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
              <div className="text-sm text-gray-500">Status</div>
              <div
                className={`mt-2 inline-block px-3 py-1 text-sm font-semibold rounded-full ${
                  order.status === 'DELIVERED'
                    ? 'bg-green-100 text-green-800'
                    : order.status === 'OUT_FOR_DELIVERY'
                    ? 'bg-blue-100 text-blue-800'
                    : order.status === 'PREPARING' || order.status === 'PACKED'
                    ? 'bg-purple-100 text-purple-800'
                    : order.status === 'ACCEPTED'
                    ? 'bg-indigo-100 text-indigo-800'
                    : 'bg-yellow-100 text-yellow-800'
                }`}
              >
                {order.status}
              </div>
              <div className="mt-4">
                <Link to={`/track/${id}`} className="text-primary-600 hover:text-primary-800 font-medium">
                  Track delivery on map
                </Link>
              </div>
            </div>
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
              <div className="text-sm text-gray-500">ETA</div>
              <div className="font-semibold">{order.eta || '—'}</div>
              <div className="mt-3 text-sm text-gray-500">Order Time</div>
              <div className="font-semibold">{order.createdAt ? new Date(order.createdAt).toLocaleString() : '—'}</div>
            </div>
          </div>
          <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Item</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Qty</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Price</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Subtotal</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {(order.items || []).map((it: any, idx: number) => (
                  <tr key={idx}>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{tp(it.name || it.productName || '-')}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{it.quantity}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">₹{it.price}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">₹{(it.price * it.quantity).toFixed(2)}</td>
                  </tr>
                ))}
                {(order.items || []).length === 0 && (
                  <tr>
                    <td colSpan={4} className="px-6 py-4 text-center text-gray-500 text-sm">
                      Items unavailable
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  );
};

export default OrderStatus;
