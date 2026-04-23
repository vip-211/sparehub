import React, { useEffect, useMemo, useState } from 'react';
import api, { API_BASE_URL } from '../services/api';
import { Bot, Search, Package } from 'lucide-react';
import { useLocation } from 'react-router-dom';

type Product = {
  id: number;
  name: string;
  partNumber: string;
  imagePath?: string;
  imageLink?: string;
  categoryImagePath?: string;
  categoryImageLink?: string;
  sellingPrice?: number;
  mrp?: number;
  stock: number;
};

const Stock: React.FC = () => {
  const getImageUrl = (path: string) => {
    if (!path) return '';
    if (path.startsWith('http')) return path;
    const base = API_BASE_URL.endsWith('/api') ? API_BASE_URL.replace('/api', '') : API_BASE_URL;
    return `${base}${path.startsWith('/') ? '' : '/'}${path}`;
  };

  const loc = useLocation();
  const initialQuery = useMemo(() => {
    const sp = new URLSearchParams(loc.search);
    return sp.get('q') || '';
  }, [loc.search]);
  const [q, setQ] = useState(initialQuery);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [items, setItems] = useState<Product[]>([]);

  const fetchInitial = async () => {
    setLoading(true);
    setError('');
    try {
      const res = await api.get('products', { params: { page: 0, size: 20 } });
      setItems((res.data?.content || []) as Product[]);
    } catch (e: any) {
      setError(e?.response?.data?.message || 'Failed to load stock');
    } finally {
      setLoading(false);
    }
  };

  const search = async (query: string) => {
    if (!query.trim()) {
      fetchInitial();
      return;
    }
    setLoading(true);
    setError('');
    try {
      const res = await api.get('products/search', { params: { query, page: 0, size: 20 } });
      setItems((res.data?.content || []) as Product[]);
    } catch (e: any) {
      setError(e?.response?.data?.message || 'Search failed');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (initialQuery) {
      search(initialQuery);
    } else {
      fetchInitial();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initialQuery]);

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-black text-gray-900">Stock</h1>
      </div>
      <div className="flex gap-3 mb-6">
        <div className="relative flex-1">
          <Search className="w-4 h-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && search(q)}
            placeholder="Search by part name or number"
            className="w-full pl-9 pr-3 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-4 focus:ring-blue-50 focus:border-blue-400"
          />
        </div>
        <button
          onClick={() => search(q)}
          className="px-4 py-3 bg-blue-600 text-white rounded-xl font-bold hover:bg-blue-700 active:scale-95"
        >
          Search
        </button>
      </div>
      {loading && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">Loading…</div>
      )}
      {error && !loading && (
        <div className="bg-white rounded-xl shadow-sm border border-red-100 p-6 text-red-600 font-bold">{error}</div>
      )}
      {!loading && !error && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <table className="min-w-full divide-y divide-gray-100 hidden md:table">
            <thead className="bg-gray-50/50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Product</th>
                <th className="px-6 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Part</th>
                <th className="px-6 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Price</th>
                <th className="px-6 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Stock</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-100">
              {items.map((p) => {
                const displayPrice = p.sellingPrice ?? p.mrp ?? 0;
                const low = p.stock > 0 && p.stock <= 5;
                const out = p.stock <= 0;
                return (
                  <tr key={p.id}>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl bg-gray-50 flex items-center justify-center border border-gray-100 overflow-hidden">
                          {p.imagePath || p.imageLink || p.categoryImageLink || p.categoryImagePath ? (
                            <img src={getImageUrl(p.imagePath || p.imageLink || p.categoryImageLink || p.categoryImagePath)} alt={p.name} className="w-10 h-10 object-cover" />
                          ) : (
                            <Package className="w-5 h-5 text-gray-300" />
                          )}
                        </div>
                        <div className="text-sm font-bold text-gray-900">{p.name}</div>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-xs font-bold text-gray-400 uppercase tracking-widest">{p.partNumber}</td>
                    <td className="px-6 py-4 text-sm font-black text-primary-700">₹{displayPrice}</td>
                    <td className="px-6 py-4">
                      <span
                        className={`inline-block px-3 py-1 rounded-full text-xs font-bold ${
                          out ? 'bg-red-100 text-red-700' : low ? 'bg-amber-100 text-amber-700' : 'bg-emerald-100 text-emerald-700'
                        }`}
                      >
                        {out ? 'Out of stock' : `Stock: ${p.stock}`}
                      </span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          <div className="md:hidden divide-y divide-gray-100">
            {items.map((p) => {
              const displayPrice = p.sellingPrice ?? p.mrp ?? 0;
              const low = p.stock > 0 && p.stock <= 5;
              const out = p.stock <= 0;
              return (
                <div key={p.id} className="p-4 flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 rounded-xl bg-gray-50 flex items-center justify-center border border-gray-100 overflow-hidden">
                      {p.imagePath || p.imageLink || p.categoryImageLink || p.categoryImagePath ? (
                        <img src={getImageUrl(p.imagePath || p.imageLink || p.categoryImageLink || p.categoryImagePath)} alt={p.name} className="w-12 h-12 object-cover" />
                      ) : (
                        <Package className="w-6 h-6 text-gray-300" />
                      )}
                    </div>
                    <div>
                      <div className="text-sm font-bold text-gray-900">{p.name}</div>
                      <div className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Part: {p.partNumber}</div>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-primary-700 font-black">₹{displayPrice}</div>
                    <div
                      className={`text-xs font-bold ${
                        out ? 'text-red-600' : low ? 'text-amber-600' : 'text-emerald-600'
                      }`}
                    >
                      {out ? 'Out of stock' : `Stock: ${p.stock}`}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
};

export default Stock;
