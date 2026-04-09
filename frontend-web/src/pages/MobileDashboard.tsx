
import React, { useState, useEffect, useCallback } from 'react';
import api, { API_BASE_URL } from '../services/api';
import { useLanguage } from '../context/LanguageContext';
import { 
  Users, 
  ShoppingBag, 
  BarChart2, 
  Package, 
  TrendingUp, 
  Clock, 
  CheckCircle, 
  AlertCircle,
  ChevronRight,
  Search,
  Bell,
  Menu,
  Settings,
  Plus
} from 'lucide-react';
import Skeleton from '../components/Skeleton';
import { 
  BarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer,
  AreaChart,
  Area
} from 'recharts';
import useSound from 'use-sound';
import SockJS from 'sockjs-client';
import Stomp from 'stompjs';

const MobileDashboard = () => {
  const { tp } = useLanguage();
  const [stats, setStats] = useState<any>(null);
  const [recentOrders, setRecentOrders] = useState<any[]>([]);
  const [cms, setCms] = useState<any>({});
  const [layout, setLayout] = useState<string[]>([]);
  const [hotDeals, setHotDeals] = useState<any[]>([]);
  const [categories, setCategories] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const [playNotification] = useSound('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3');

  const [period, setPeriod] = useState<'DAILY'|'WEEKLY'|'MONTHLY'>('MONTHLY');

  const fetchDashboardData = useCallback(async () => {
    try {
      setLoading(true);
      const [ordersRes, usersRes, productsRes, salesRes, titleRes, bannerRes, btnRes, layoutRes, catRes, featuredRes] = await Promise.all([
        api.get('admin/orders'),
        api.get('admin/users'),
        api.get('products'),
        api.get('admin/sales', { params: { type: period } }),
        api.get('cms/settings/mechanic_home_title'),
        api.get('cms/settings/mechanic_banner_text'),
        api.get('cms/settings/mechanic_banner_btn'),
        api.get('cms/settings/mechanic_home_layout'),
        api.get('categories'),
        api.get('products/featured')
      ]);

      const orders = ordersRes.data || [];
      const totalRevenue = (salesRes.data?.totalSales ?? orders.reduce((acc: number, o: any) => acc + (o.totalAmount || 0), 0));
      const pendingOrders = orders.filter((o: any) => o.status === 'PENDING').length;
      
      setStats({
        totalOrders: (salesRes.data?.totalOrders ?? orders.length),
        totalUsers: usersRes.data.length,
        totalProducts: productsRes.data.length,
        totalRevenue,
        pendingOrders
      });

      setRecentOrders(orders.slice(0, 5));
      setCms({
        title: titleRes.data.value || 'Parts Mitra',
        banner: bannerRes.data.value || '',
        btn: btnRes.data.value || 'Buy Now'
      });
      setLayout((layoutRes.data.value || 'header,search_bar,categories,banner,hot_deals').split(',').filter(Boolean));
      setCategories((catRes.data || []).filter((c: any) => c.showOnHome !== false));
      setHotDeals(featuredRes.data || []);
    } catch (err) {
      console.error("Failed to fetch dashboard data:", err);
    } finally {
      setLoading(false);
    }
  }, [period]);

  useEffect(() => {
    fetchDashboardData();
  }, [fetchDashboardData]);

  useEffect(() => {
    let stompClient: any = null;
    const getSocketUrl = () => {
      let baseUrl = API_BASE_URL.endsWith('/api/') 
        ? API_BASE_URL.substring(0, API_BASE_URL.length - 5) 
        : API_BASE_URL.endsWith('/api') 
          ? API_BASE_URL.substring(0, API_BASE_URL.length - 4) 
          : API_BASE_URL.endsWith('/')
            ? API_BASE_URL.substring(0, API_BASE_URL.length - 1)
            : API_BASE_URL;
      
      // If using https, we should use wss for pure WebSocket
      // SockJS handles this automatically, but for pure WS we'd use:
      // baseUrl.replace('http', 'ws') + '/ws'
      return `${baseUrl}/ws`;
    };
    
    try {
      const socket = new SockJS(getSocketUrl());
      stompClient = Stomp.over(socket);
      stompClient.debug = () => {};
      stompClient.reconnect_delay = 5000; // Auto-reconnect

      stompClient.connect({}, () => {
        stompClient.subscribe('/topic/orders', (message: any) => {
          try {
            const orderData = JSON.parse(message.body);
            if (orderData.status === 'PENDING') {
              playNotification();
              fetchDashboardData();
            }
          } catch (e) {
            console.error('Error parsing socket message:', e);
          }
        });
      }, (error: any) => {
        if (import.meta.env.DEV) console.warn('WebSocket connection error:', error);
      });
    } catch (e) {
      console.error('Socket initialization error:', e);
    }

    return () => {
      if (stompClient && stompClient.connected) {
        stompClient.disconnect(() => {});
      }
    };
  }, [playNotification, fetchDashboardData]);

  const chartData = [
    { name: 'Mon', sales: 4000 },
    { name: 'Tue', sales: 3000 },
    { name: 'Wed', sales: 2000 },
    { name: 'Thu', sales: 2780 },
    { name: 'Fri', sales: 1890 },
    { name: 'Sat', sales: 2390 },
    { name: 'Sun', sales: 3490 },
  ];

  const getCategoryIcon = (cat: any) => {
    if (cat.imagePath || cat.imageLink) {
      return (
        <img 
          src={getImageUrl(cat.imagePath || cat.imageLink)} 
          alt={cat.name} 
          className="w-10 h-10 rounded-full object-cover mb-2" 
        />
      );
    }
    if (cat.iconCodePoint) {
      return (
        <span className="material-icons text-[32px] mb-2 text-primary-600">
          {String.fromCharCode(cat.iconCodePoint)}
        </span>
      );
    }
    return <Package className="mb-2 text-primary-600" size={32} />;
  };

  const getImageUrl = (path: string) => {
    if (!path) return '';
    if (path.startsWith('http')) return path;
    const base = API_BASE_URL.endsWith('/api') ? API_BASE_URL.replace('/api', '') : API_BASE_URL;
    return `${base}${path.startsWith('/') ? '' : '/'}${path}`;
  };

  if (loading) {
    return (
      <div className="p-4 space-y-6 animate-pulse">
        <div className="h-8 w-48 bg-gray-200 rounded-lg mb-6"></div>
        <div className="grid grid-cols-2 gap-4">
          {[1, 2, 3, 4].map(i => (
            <div key={i} className="h-24 bg-gray-100 rounded-2xl"></div>
          ))}
        </div>
        <div className="h-64 bg-gray-100 rounded-2xl"></div>
        <div className="h-48 bg-gray-100 rounded-2xl"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50/50 p-6 md:p-8 space-y-8 pb-32">
      {/* Dynamic Layout Rendering */}
      {layout.map((section) => {
        switch (section) {
          case 'header':
            return (
              <div key="header" className="flex items-center justify-between">
                <div>
                  <h1 className="text-3xl font-black text-gray-900 tracking-tight">{cms.title}</h1>
                  <p className="text-gray-500 text-sm font-bold uppercase tracking-widest mt-1">Dashboard Overview</p>
                </div>
                <div className="flex items-center gap-3">
                  <button className="p-3 bg-white rounded-2xl shadow-sm border border-gray-100 text-gray-400 hover:text-primary-600 transition-all relative">
                    <Bell size={24} />
                    <span className="absolute top-3 right-3 w-2 h-2 bg-red-500 rounded-full border-2 border-white"></span>
                  </button>
                  <button className="p-3 bg-white rounded-2xl shadow-sm border border-gray-100 text-gray-400 hover:text-primary-600 transition-all md:hidden">
                    <Menu size={24} />
                  </button>
                </div>
              </div>
            );
          case 'search_bar':
            return (
              <div key="search_bar" className="relative">
                <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
                <input 
                  type="text" 
                  placeholder={tp('dashboard.searchPlaceholder')}
                  className="w-full bg-white border-2 border-gray-100 rounded-[2rem] pl-12 pr-6 py-4 font-bold text-gray-700 focus:border-primary-500 outline-none transition-all shadow-sm"
                />
              </div>
            );
          case 'categories':
            return (
              <div key="categories" className="space-y-4">
                <h3 className="font-black text-gray-900 text-lg uppercase tracking-tight px-2">Bike Brands</h3>
                <div className="flex gap-4 overflow-x-auto pb-4 no-scrollbar">
                  {categories.map((cat) => (
                    <div key={cat.id} className="flex-shrink-0 flex flex-col items-center justify-center w-24 h-24 bg-white rounded-3xl border border-gray-100 shadow-sm hover:border-primary-200 transition-all cursor-pointer">
                      {getCategoryIcon(cat)}
                      <span className="text-[10px] font-black text-gray-500 uppercase tracking-widest text-center px-1 truncate w-full">{cat.name}</span>
                    </div>
                  ))}
                </div>
              </div>
            );
          case 'banner':
            return (
              <div key="banner" className="bg-gradient-to-br from-primary-600 to-indigo-700 rounded-[2.5rem] p-8 text-white relative overflow-hidden shadow-2xl shadow-primary-200">
                <div className="relative z-10 space-y-4">
                  <h2 className="text-2xl font-black leading-tight max-w-[200px] whitespace-pre-line">{cms.banner}</h2>
                  <button className="bg-yellow-400 text-black px-6 py-2.5 rounded-full font-black text-sm uppercase tracking-widest shadow-lg active:scale-95 transition-all">
                    {cms.btn}
                  </button>
                </div>
                <div className="absolute -right-8 -bottom-8 opacity-20 transform -rotate-12 scale-150">
                  <ShoppingBag size={160} />
                </div>
              </div>
            );
          case 'hot_deals':
            return (
              <div key="hot_deals" className="space-y-4">
                <h3 className="font-black text-gray-900 text-lg uppercase tracking-tight px-2">Hot Deals ⚡</h3>
                <div className="flex gap-6 overflow-x-auto pb-6 no-scrollbar">
                  {hotDeals.map((deal) => (
                    <div key={deal.id} className="flex-shrink-0 w-48 bg-white rounded-[2rem] border border-gray-100 shadow-sm overflow-hidden group cursor-pointer hover:shadow-md transition-all">
                      <div className="h-40 bg-gray-50 relative overflow-hidden">
                        <img 
                          src={getImageUrl(deal.imageLink || deal.imagePath)} 
                          alt={deal.name}
                          className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-500" 
                        />
                        <div className="absolute top-3 left-3 bg-red-500 text-white px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest shadow-lg">Hot</div>
                      </div>
                      <div className="p-4 space-y-1">
                        <h4 className="font-black text-gray-900 text-sm truncate">{deal.name}</h4>
                        <p className="text-primary-600 font-black text-lg">₹{deal.sellingPrice.toLocaleString()}</p>
                        <div className="flex items-center gap-2">
                          <span className="text-gray-400 text-[10px] font-bold line-through">₹{deal.mrp.toLocaleString()}</span>
                          <span className="text-green-500 text-[10px] font-black uppercase tracking-widest">{Math.round((1 - deal.sellingPrice/deal.mrp)*100)}% Off</span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            );
          default:
            return null;
        }
      })}

      {/* Sales Chart */}
      <div className="bg-white p-6 rounded-[2.5rem] shadow-sm border border-gray-100 mb-8">
        <div className="flex items-center justify-between mb-6">
          <h3 className="font-black text-gray-900 text-lg uppercase tracking-tight">Sales Analytics</h3>
          <select
            className="text-xs font-bold text-gray-500 bg-gray-50 border-none rounded-lg px-2 py-1 outline-none"
            value={period}
            onChange={(e) => setPeriod(e.target.value as any)}
          >
            <option value="DAILY">Daily</option>
            <option value="WEEKLY">Weekly</option>
            <option value="MONTHLY">Monthly</option>
          </select>
        </div>
        <div className="h-64 w-full" style={{ minHeight: '256px', position: 'relative', overflow: 'hidden' }}>
          <ResponsiveContainer width="100%" height="100%" minWidth={0} minHeight={0}>
            <AreaChart data={chartData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
              <defs>
                <linearGradient id="colorSales" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#4f46e5" stopOpacity={0.1}/>
                  <stop offset="95%" stopColor="#4f46e5" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
              <XAxis 
                dataKey="name" 
                axisLine={false} 
                tickLine={false} 
                tick={{fontSize: 10, fontWeight: 700, fill: '#94a3b8'}}
                dy={10}
              />
              <YAxis hide />
              <Tooltip 
                contentStyle={{borderRadius: '16px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)'}}
                itemStyle={{fontSize: '12px', fontWeight: 900}}
              />
              <Area 
                type="monotone" 
                dataKey="sales" 
                stroke="#4f46e5" 
                strokeWidth={4}
                fillOpacity={1} 
                fill="url(#colorSales)" 
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Recent Activity */}
      <div className="bg-white p-6 rounded-[2.5rem] shadow-sm border border-gray-100">
        <div className="flex items-center justify-between mb-6">
          <h3 className="font-black text-gray-900 text-lg uppercase tracking-tight">Recent Orders</h3>
          <button className="text-xs font-bold text-primary-600 uppercase tracking-widest hover:underline">View All</button>
        </div>
        <div className="space-y-4">
          {(recentOrders || []).map((order) => (
            <div key={order.id} className="flex items-center justify-between p-4 bg-gray-50/50 rounded-2xl hover:bg-gray-50 transition group cursor-pointer">
              <div className="flex items-center gap-4">
                <div className={`p-3 rounded-xl ${
                  order.status === 'DELIVERED' ? 'bg-blue-100 text-blue-600' : 'bg-amber-100 text-amber-600'
                }`}>
                  {order.status === 'DELIVERED' ? <CheckCircle size={20} /> : <Clock size={20} />}
                </div>
                <div>
                  <p className="font-black text-gray-900 text-sm">#{order.id} - {order.customerName}</p>
                  <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">
                    {new Date(order.orderDate).toLocaleDateString()} • {order.items?.length || 0} Items
                  </p>
                </div>
              </div>
              <div className="text-right">
                <p className="font-black text-gray-900 text-sm">₹{(order.totalAmount || 0).toLocaleString()}</p>
                <div className="flex items-center justify-end text-primary-600 group-hover:translate-x-1 transition-transform">
                  <ChevronRight size={16} />
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Quick Action FAB - Bottom Nav Style for Mobile */}
      <div className="fixed bottom-6 left-1/2 -translate-x-1/2 flex items-center bg-white/80 backdrop-blur-xl border border-white/20 shadow-2xl rounded-full px-6 py-3 gap-8 z-50 md:hidden">
        <button className="text-primary-600"><BarChart2 size={24} /></button>
        <button className="text-gray-400 hover:text-primary-600 transition"><ShoppingBag size={24} /></button>
        <div className="w-12 h-12 bg-primary-600 rounded-full flex items-center justify-center text-white shadow-lg shadow-primary-200 -mt-10">
          <Plus size={28} />
        </div>
        <button className="text-gray-400 hover:text-primary-600 transition"><Users size={24} /></button>
        <button className="text-gray-400 hover:text-primary-600 transition"><Settings size={24} /></button>
      </div>
    </div>
  );
};

export default MobileDashboard;
