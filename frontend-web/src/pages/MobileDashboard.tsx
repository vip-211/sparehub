
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
  const [loading, setLoading] = useState(true);

  const [playNotification] = useSound('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3');

  const fetchDashboardData = useCallback(async () => {
    try {
      setLoading(true);
      const [ordersRes, usersRes, productsRes] = await Promise.all([
        api.get('/admin/orders'),
        api.get('/admin/users'),
        api.get('/products')
      ]);

      const orders = ordersRes.data;
      const totalRevenue = orders.reduce((acc: number, o: any) => acc + o.totalAmount, 0);
      const pendingOrders = orders.filter((o: any) => o.status === 'PENDING').length;
      
      setStats({
        totalOrders: orders.length,
        totalUsers: usersRes.data.length,
        totalProducts: productsRes.data.length,
        totalRevenue,
        pendingOrders
      });

      setRecentOrders(orders.slice(0, 5));
    } catch (err) {
      console.error("Failed to fetch dashboard data:", err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchDashboardData();
  }, [fetchDashboardData]);

  useEffect(() => {
    const socketBaseUrl = API_BASE_URL.endsWith('/api') 
      ? API_BASE_URL.substring(0, API_BASE_URL.length - 4) 
      : API_BASE_URL;
    
    const socket = new SockJS(`${socketBaseUrl}/ws`);
    const stompClient = Stomp.over(socket);
    stompClient.debug = () => {};

    stompClient.connect({}, () => {
      stompClient.subscribe('/topic/orders', (message) => {
        const orderData = JSON.parse(message.body);
        if (orderData.status === 'PENDING') {
          playNotification();
          fetchDashboardData();
        }
      });
    }, (error) => {
      console.error('WebSocket error:', error);
    });

    return () => {
      if (stompClient.connected) {
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
    <div className="pb-20 md:pb-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6 px-1">
        <div>
          <h1 className="text-2xl font-black text-gray-900 tracking-tight">Overview</h1>
          <p className="text-sm text-gray-500 font-medium">Welcome back to SpareHub</p>
        </div>
        <div className="flex gap-2">
          <button className="p-2.5 bg-white rounded-xl shadow-sm border border-gray-100 text-gray-600 hover:bg-gray-50 transition">
            <Search size={20} />
          </button>
          <button className="p-2.5 bg-white rounded-xl shadow-sm border border-gray-100 text-gray-600 hover:bg-gray-50 transition relative">
            <Bell size={20} />
            <span className="absolute top-2 right-2 w-2 h-2 bg-red-500 rounded-full border-2 border-white"></span>
          </button>
        </div>
      </div>

      {/* Stats Grid - Mobile Friendly */}
      <div className="grid grid-cols-2 gap-4 mb-8">
        <div className="bg-indigo-600 p-5 rounded-[2rem] text-white shadow-xl shadow-indigo-100 relative overflow-hidden group">
          <div className="absolute -right-4 -top-4 w-20 h-20 bg-white/10 rounded-full group-hover:scale-150 transition-transform duration-700"></div>
          <ShoppingBag className="mb-3 opacity-80" size={24} />
          <p className="text-xs font-bold uppercase tracking-wider opacity-70">Orders</p>
          <p className="text-2xl font-black">{stats?.totalOrders}</p>
        </div>
        <div className="bg-emerald-500 p-5 rounded-[2rem] text-white shadow-xl shadow-emerald-100 relative overflow-hidden group">
          <div className="absolute -right-4 -top-4 w-20 h-20 bg-white/10 rounded-full group-hover:scale-150 transition-transform duration-700"></div>
          <TrendingUp className="mb-3 opacity-80" size={24} />
          <p className="text-xs font-bold uppercase tracking-wider opacity-70">Revenue</p>
          <p className="text-2xl font-black">₹{stats?.totalRevenue?.toLocaleString()}</p>
        </div>
        <div className="bg-amber-400 p-5 rounded-[2rem] text-white shadow-xl shadow-amber-100 relative overflow-hidden group">
          <div className="absolute -right-4 -top-4 w-20 h-20 bg-white/10 rounded-full group-hover:scale-150 transition-transform duration-700"></div>
          <Clock className="mb-3 opacity-80" size={24} />
          <p className="text-xs font-bold uppercase tracking-wider opacity-70">Pending</p>
          <p className="text-2xl font-black">{stats?.pendingOrders}</p>
        </div>
        <div className="bg-rose-500 p-5 rounded-[2rem] text-white shadow-xl shadow-rose-100 relative overflow-hidden group">
          <div className="absolute -right-4 -top-4 w-20 h-20 bg-white/10 rounded-full group-hover:scale-150 transition-transform duration-700"></div>
          <Package className="mb-3 opacity-80" size={24} />
          <p className="text-xs font-bold uppercase tracking-wider opacity-70">Stock</p>
          <p className="text-2xl font-black">{stats?.totalProducts}</p>
        </div>
      </div>

      {/* Sales Chart */}
      <div className="bg-white p-6 rounded-[2.5rem] shadow-sm border border-gray-100 mb-8">
        <div className="flex items-center justify-between mb-6">
          <h3 className="font-black text-gray-900 text-lg uppercase tracking-tight">Sales Analytics</h3>
          <select className="text-xs font-bold text-gray-500 bg-gray-50 border-none rounded-lg px-2 py-1 outline-none">
            <option>Weekly</option>
            <option>Monthly</option>
          </select>
        </div>
        <div className="h-64 w-full" style={{ minWidth: 0 }}>
          <ResponsiveContainer width="100%" height="100%" minWidth={0} minHeight={0}>
            <AreaChart data={chartData}>
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
          {recentOrders.map((order) => (
            <div key={order.id} className="flex items-center justify-between p-4 bg-gray-50/50 rounded-2xl hover:bg-gray-50 transition group cursor-pointer">
              <div className="flex items-center gap-4">
                <div className={`p-3 rounded-xl ${
                  order.status === 'DELIVERED' ? 'bg-green-100 text-green-600' : 'bg-amber-100 text-amber-600'
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
                <p className="font-black text-gray-900 text-sm">₹{order.totalAmount?.toLocaleString()}</p>
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
