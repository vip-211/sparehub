
import React, { useState, useEffect, useCallback, useRef } from 'react';
import api, { API_BASE_URL } from '../services/api';
import { useNavigate } from 'react-router-dom';
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
  Plus,
  ShoppingCart,
  Zap,
  Mic,
  QrCode,
  Star,
  ArrowRight,
  MessageSquare
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
import { useCart } from '../context/CartContext';
import { ROLE_ADMIN, ROLE_SUPER_MANAGER } from '../services/constants';
import { useAuth } from '../context/AuthContext';

const MobileDashboard = () => {
  const { tp } = useLanguage();
  const { reorder } = useCart();
  const { currentUser } = useAuth();
  const [stats, setStats] = useState<any>(null);
  const [recentOrders, setRecentOrders] = useState<any[]>([]);
  const [chartData, setChartData] = useState<any[]>([]);
  const [cms, setCms] = useState<any>({});
  const [layout, setLayout] = useState<string[]>([]);
  const [hotDeals, setHotDeals] = useState<any[]>([]);
  const [categories, setCategories] = useState<any[]>([]);
  const [banners, setBanners] = useState<any[]>([]);
  const [carouselInfo, setCarouselInfo] = useState({ isCarousel: false, autoScrollSpeed: 3 });
  const [currentBannerIndex, setCurrentBannerIndex] = useState(0);
  const [loading, setLoading] = useState(true);
  const [searchFocused, setSearchFocused] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const navigate = useNavigate();

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (searchTerm.trim()) {
      navigate(`/shop?search=${encodeURIComponent(searchTerm)}`);
    }
  };

  const [playNotification] = useSound('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3');

  const [period, setPeriod] = useState<'DAILY'|'WEEKLY'|'MONTHLY'>('MONTHLY');

  const fetchDashboardData = useCallback(async () => {
    try {
      setLoading(true);
      const isAdmin = currentUser?.roles?.includes(ROLE_ADMIN) || currentUser?.roles?.includes(ROLE_SUPER_MANAGER);
      
      const requests: any[] = [
        isAdmin ? api.get('admin/orders') : api.get('orders/my-orders'),
        isAdmin ? api.get('admin/users') : Promise.resolve({ data: [] }),
        api.get('products'),
        isAdmin ? api.get('admin/sales', { params: { type: period } }) : Promise.resolve({ data: { totalSales: 0, totalOrders: 0, chartData: [] } }),
        api.get('cms/settings/mechanic_home_title'),
        api.get('cms/settings/mechanic_banner_text'),
        api.get('cms/settings/mechanic_banner_btn'),
        api.get('cms/settings/mechanic_home_layout'),
        api.get('categories'),
        api.get('products/featured'),
        api.get('banners/active')
      ];

      const [ordersRes, usersRes, productsRes, salesRes, titleRes, bannerRes, btnRes, layoutRes, catRes, featuredRes, bannersRes] = await Promise.all(requests);

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
      setChartData(salesRes.data?.chartData || []);
      setCms({
        title: titleRes.data.value || 'Parts Mitra',
        banner: bannerRes.data.value || '',
        btn: btnRes.data.value || 'Buy Now'
      });
      setLayout((layoutRes.data.value || 'header,search_bar,stats,categories,banner,hot_deals,recent_orders').split(',').filter(Boolean));
      setCategories((catRes.data || []).filter((c: any) => c.showOnHome !== false));
      setHotDeals(featuredRes.data || []);
      
      if (bannersRes.data) {
        setBanners(bannersRes.data.banners || []);
        setCarouselInfo({
          isCarousel: bannersRes.data.isCarousel,
          autoScrollSpeed: bannersRes.data.autoScrollSpeed
        });
      }
    } catch (err) {
      console.error("Failed to fetch dashboard data:", err);
    } finally {
      setLoading(false);
    }
  }, [period, currentUser]);

  useEffect(() => {
    fetchDashboardData();
  }, [fetchDashboardData]);

  useEffect(() => {
    if (!carouselInfo.isCarousel || banners.length <= 1) return;
    
    const timer = setInterval(() => {
      setCurrentBannerIndex((prev) => (prev + 1) % banners.length);
    }, carouselInfo.autoScrollSpeed * 1000);
    
    return () => clearInterval(timer);
  }, [carouselInfo.isCarousel, carouselInfo.autoScrollSpeed, banners.length]);

  const { addItem } = useCart();

  const handleBannerBuyClick = async (banner: any) => {
    if (!banner.productId) return;
    try {
      const res = await api.get(`products/${banner.productId}`);
      const product = res.data;
      if (product && product.stock > 0) {
        addItem(
          {
            productId: product.id,
            name: product.name,
            price: banner.fixedPrice || product.sellingPrice,
            partNumber: product.partNumber,
            wholesalerId: product.wholesalerId,
            image: product.imageLink || product.imagePath || product.categoryImagePath || product.categoryImageLink
          },
          banner.minimumQuantity || 1,
          banner.quantityLocked,
          banner.id
        );
        alert(`${product.name} added to cart!`);
      } else {
        alert('Product out of stock');
      }
    } catch (err) {
      console.error('Error in banner buy click:', err);
    }
  };

  const handleQuickAdd = (p: any) => {
    addItem({
      productId: p.id,
      name: p.name,
      price: p.sellingPrice,
      partNumber: p.partNumber,
      wholesalerId: p.wholesalerId,
      image: p.imageLink || p.imagePath || p.categoryImagePath || p.categoryImageLink
    }, 1);
    alert(`${p.name} added to cart!`);
  };

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
      return `${baseUrl}/ws`;
    };
    
    try {
      const socket = new SockJS(getSocketUrl());
      stompClient = Stomp.over(socket);
      stompClient.debug = () => {};
      stompClient.reconnect_delay = 5000;

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



  const getCategoryIcon = (cat: any) => {
    if (cat.imagePath || cat.imageLink) {
      return (
        <div className="w-12 h-12 rounded-2xl bg-primary-50 p-2 group-hover:scale-110 transition-transform duration-300">
          <img 
            src={getImageUrl(cat.imagePath || cat.imageLink)} 
            alt={cat.name} 
            className="w-full h-full object-contain" 
          />
        </div>
      );
    }
    return <Package className="mb-2 text-primary-600 group-hover:scale-110 transition-transform duration-300" size={32} />;
  };

  const getImageUrl = (path: string | undefined | null) => {
    if (!path) return '';
    if (path.startsWith('http')) return path;
    const base = API_BASE_URL.endsWith('/api') ? API_BASE_URL.replace('/api', '') : API_BASE_URL;
    return `${base}${path.startsWith('/') ? '' : '/'}${path}`;
  };

  if (loading) {
    return (
      <div className="p-8 max-w-7xl mx-auto space-y-10 animate-pulse">
        <div className="flex justify-between items-center">
          <div className="space-y-2">
            <div className="h-10 w-64 bg-gray-200 rounded-xl"></div>
            <div className="h-4 w-40 bg-gray-100 rounded-lg"></div>
          </div>
          <div className="h-12 w-12 bg-gray-200 rounded-2xl"></div>
        </div>
        <div className="h-16 w-full bg-gray-100 rounded-[2rem]"></div>
        <div className="flex gap-4 overflow-hidden">
          {[1, 2, 3, 4, 5, 6].map(i => (
            <div key={i} className="h-24 w-24 flex-shrink-0 bg-gray-100 rounded-3xl"></div>
          ))}
        </div>
        <div className="h-64 w-full bg-gray-100 rounded-[3rem]"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#F8FAFC] pb-32">
      {/* Sticky Search Bar */}
      <div className={`sticky top-0 z-50 transition-all duration-300 ${searchFocused ? 'bg-white/80 backdrop-blur-xl py-4 shadow-lg shadow-gray-100' : 'bg-transparent py-6'}`}>
        <div className="max-w-7xl mx-auto px-6 md:px-8">
          <form onSubmit={handleSearch} className="relative group">
            <Search className={`absolute left-6 top-1/2 -translate-y-1/2 transition-colors ${searchFocused ? 'text-primary-600' : 'text-gray-400'}`} size={22} />
            <input 
              type="text" 
              placeholder="Search spare parts, brands, or part numbers..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              onFocus={() => setSearchFocused(true)}
              onBlur={() => setSearchFocused(false)}
              className="w-full bg-white border-2 border-gray-100 rounded-[2.5rem] pl-16 pr-24 py-5 font-bold text-gray-700 focus:border-primary-500 focus:ring-4 focus:ring-primary-50 focus:shadow-xl outline-none transition-all"
            />
            <div className="absolute right-4 top-1/2 -translate-y-1/2 flex items-center gap-2">
              <button type="button" className="p-2.5 text-gray-400 hover:text-primary-600 hover:bg-primary-50 rounded-full transition-all">
                <Mic size={20} />
              </button>
              <button type="button" className="p-2.5 text-gray-400 hover:text-primary-600 hover:bg-primary-50 rounded-full transition-all">
                <QrCode size={20} />
              </button>
              <button 
                type="submit"
                className="bg-primary-600 text-white px-6 py-2.5 rounded-2xl font-black text-[10px] uppercase tracking-widest hover:bg-primary-700 transition-all shadow-lg shadow-primary-200 active:scale-95"
              >
                Search
              </button>
            </div>
          </form>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-6 md:px-8 space-y-12">
        {/* Dynamic Layout Rendering */}
        {layout.map((section) => {
          switch (section) {
            case 'header':
              return (
                <div key="header" className="flex items-center justify-between">
                  <div>
                    <h1 className="text-4xl font-black text-gray-900 tracking-tight leading-none">{cms.title}</h1>
                    <p className="text-gray-400 text-sm font-bold uppercase tracking-[0.2em] mt-3 ml-1">Welcome back, Mechanic!</p>
                  </div>
                  <div className="flex items-center gap-4">
                    <button className="p-4 bg-white rounded-3xl shadow-sm border border-gray-100 text-gray-400 hover:text-primary-600 hover:shadow-xl transition-all relative group">
                      <Bell size={26} />
                      <span className="absolute top-4 right-4 w-3 h-3 bg-red-500 rounded-full border-2 border-white shadow-sm animate-pulse"></span>
                    </button>
                    <div className="w-14 h-14 bg-white rounded-3xl shadow-sm border border-gray-100 p-1 group cursor-pointer hover:shadow-xl transition-all">
                      <div className="w-full h-full bg-primary-100 rounded-2xl flex items-center justify-center text-primary-600 overflow-hidden">
                        <Users size={28} />
                      </div>
                    </div>
                  </div>
                </div>
              );
            case 'stats':
              const isAdmin = currentUser?.roles?.includes(ROLE_ADMIN) || currentUser?.roles?.includes(ROLE_SUPER_MANAGER);
              if (!isAdmin) return (
                <div key="stats" className="grid grid-cols-2 gap-4">
                  <div className="bg-white p-6 rounded-[2rem] shadow-sm border border-gray-100 flex flex-col items-center justify-center text-center space-y-2">
                    <div className="w-12 h-12 bg-primary-50 rounded-2xl flex items-center justify-center text-primary-600">
                      <Star size={24} className="fill-current" />
                    </div>
                    <div>
                      <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest">My Points</p>
                      <p className="text-2xl font-black text-gray-900">{currentUser?.points || 0}</p>
                    </div>
                  </div>
                  <div className="bg-white p-6 rounded-[2rem] shadow-sm border border-gray-100 flex flex-col items-center justify-center text-center space-y-2">
                    <div className="w-12 h-12 bg-indigo-50 rounded-2xl flex items-center justify-center text-indigo-600">
                      <ShoppingBag size={24} />
                    </div>
                    <div>
                      <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest">My Orders</p>
                      <p className="text-2xl font-black text-gray-900">{stats?.totalOrders || 0}</p>
                    </div>
                  </div>
                </div>
              );
              return (
                <div key="stats" className="grid grid-cols-2 md:grid-cols-4 gap-4 md:gap-6">
                  {[
                    { label: 'Revenue', value: `₹${(stats?.totalRevenue || 0).toLocaleString()}`, icon: TrendingUp, color: 'text-green-600', bg: 'bg-green-50' },
                    { label: 'Orders', value: stats?.totalOrders || 0, icon: ShoppingBag, color: 'text-primary-600', bg: 'bg-primary-50' },
                    { label: 'Pending', value: stats?.pendingOrders || 0, icon: Clock, color: 'text-amber-600', bg: 'bg-amber-50' },
                    { label: 'Users', value: stats?.totalUsers || 0, icon: Users, color: 'text-indigo-600', bg: 'bg-indigo-50' },
                  ].map((stat, i) => (
                    <div key={i} className="bg-white p-6 rounded-[2rem] shadow-sm border border-gray-100 hover:shadow-xl hover:shadow-gray-100 transition-all group">
                      <div className={`w-12 h-12 ${stat.bg} ${stat.color} rounded-2xl flex items-center justify-center mb-4 group-hover:scale-110 transition-transform`}>
                        <stat.icon size={24} />
                      </div>
                      <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-1">{stat.label}</p>
                      <p className="text-xl font-black text-gray-900">{stat.value}</p>
                    </div>
                  ))}
                </div>
              );
            case 'categories':
              return (
                <div key="categories" className="space-y-6">
                  <div className="flex items-center justify-between px-2">
                    <h3 className="font-black text-gray-900 text-xl tracking-tight">Bike Brands</h3>
                    <button className="text-xs font-black text-primary-600 uppercase tracking-widest hover:bg-primary-50 px-4 py-2 rounded-xl transition-all">View All</button>
                  </div>
                  <div className="flex gap-6 overflow-x-auto pb-4 no-scrollbar">
                    {categories.map((cat) => (
                      <div key={cat.id} className="group flex-shrink-0 flex flex-col items-center justify-center w-28 h-32 bg-white rounded-[2.5rem] border border-gray-100 shadow-sm hover:border-primary-200 hover:shadow-xl hover:shadow-primary-50 transition-all cursor-pointer">
                        {getCategoryIcon(cat)}
                        <span className="mt-3 text-[11px] font-black text-gray-600 uppercase tracking-tighter text-center px-2 truncate w-full group-hover:text-primary-700">{cat.name}</span>
                      </div>
                    ))}
                  </div>
                </div>
              );
            case 'banner':
              const currentBanner = banners[currentBannerIndex] || { title: cms.title, text: cms.banner, buttonText: cms.btn };
              return (
                <div key="banner" className="space-y-4">
                  <div className="bg-gradient-to-br from-primary-600 to-indigo-800 rounded-[3.5rem] p-10 md:p-14 text-white relative overflow-hidden shadow-2xl shadow-primary-100 min-h-[220px] transition-all duration-700">
                    <div className="relative z-10 flex flex-col md:flex-row justify-between items-center h-full gap-8">
                      <div className="space-y-6 flex-1 text-center md:text-left">
                        <div className="inline-flex items-center gap-2 bg-white/10 backdrop-blur-md px-4 py-1.5 rounded-full">
                          <Zap size={14} className="text-yellow-400 fill-yellow-400" />
                          <span className="text-[10px] font-black uppercase tracking-widest">Limited Offer</span>
                        </div>
                        <h2 className="text-3xl md:text-4xl font-black leading-[1.1] max-w-md whitespace-pre-line">
                          {currentBanner.title || currentBanner.text || cms.banner}
                        </h2>
                        <div className="flex flex-wrap justify-center md:justify-start gap-4">
                          {currentBanner.buyEnabled ? (
                            <button 
                              onClick={() => handleBannerBuyClick(currentBanner)}
                              className="bg-yellow-400 text-black px-10 py-4 rounded-[1.5rem] font-black text-sm uppercase tracking-widest shadow-xl shadow-yellow-400/20 active:scale-95 hover:bg-yellow-300 transition-all flex items-center gap-3"
                            >
                              <ShoppingCart size={18} />
                              {currentBanner.buttonText || 'Buy Now'}
                            </button>
                          ) : (
                            <button className="bg-white text-primary-700 px-10 py-4 rounded-[1.5rem] font-black text-sm uppercase tracking-widest shadow-xl active:scale-95 hover:bg-gray-50 transition-all">
                              {cms.btn}
                            </button>
                          )}
                          <button className="bg-white/10 backdrop-blur-md text-white border border-white/20 px-8 py-4 rounded-[1.5rem] font-black text-sm uppercase tracking-widest hover:bg-white/20 transition-all">
                            Details
                          </button>
                        </div>
                      </div>
                      {(currentBanner.imageLink || currentBanner.imagePath) && (
                        <div className="w-48 h-48 md:w-64 md:h-64 rounded-[3rem] overflow-hidden border-8 border-white/10 shadow-2xl rotate-3 hover:rotate-0 transition-transform duration-500">
                          <img 
                            src={getImageUrl(currentBanner.imageLink || currentBanner.imagePath)} 
                            alt="Banner" 
                            className="w-full h-full object-cover"
                          />
                        </div>
                      )}
                    </div>
                    <div className="absolute -right-16 -bottom-16 opacity-10 transform -rotate-12 scale-150 pointer-events-none">
                      <ShoppingBag size={300} />
                    </div>
                  </div>
                  {banners.length > 1 && (
                    <div className="flex justify-center gap-3">
                      {banners.map((_, idx) => (
                        <div 
                          key={idx}
                          className={`h-2 rounded-full transition-all duration-500 ${idx === currentBannerIndex ? 'w-12 bg-primary-600' : 'w-2 bg-gray-200 hover:bg-gray-300'}`}
                        />
                      ))}
                    </div>
                  )}
                </div>
              );
            case 'hot_deals':
              return (
                <div key="hot_deals" className="space-y-6">
                  <div className="flex items-center justify-between px-2">
                    <h3 className="font-black text-gray-900 text-xl tracking-tight flex items-center gap-3">
                      Hot Deals
                      <span className="bg-red-500 text-white text-[10px] px-2 py-1 rounded-lg animate-pulse">LIVE</span>
                    </h3>
                    <button className="text-xs font-black text-primary-600 uppercase tracking-widest hover:bg-primary-50 px-4 py-2 rounded-xl transition-all">See All Deals</button>
                  </div>
                  <div className="flex gap-8 overflow-x-auto pb-8 no-scrollbar">
                    {hotDeals.map((deal) => (
                      <div key={deal.id} className="flex-shrink-0 w-64 bg-white rounded-[3rem] border border-gray-100 shadow-sm overflow-hidden group cursor-pointer hover:shadow-2xl hover:shadow-primary-100 transition-all duration-500">
                        <div className="h-56 bg-gray-50 relative overflow-hidden">
                          {deal.imageLink || deal.imagePath || deal.categoryImagePath || deal.categoryImageLink ? (
                            <img 
                              src={getImageUrl(deal.imageLink || deal.imagePath || deal.categoryImagePath || deal.categoryImageLink)} 
                              alt={deal.name}
                              className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-700" 
                            />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center text-gray-300">
                              <Package size={48} />
                            </div>
                          )}
                          <div className="absolute top-5 left-5 bg-white/90 backdrop-blur-md text-red-600 px-4 py-2 rounded-2xl text-[10px] font-black uppercase tracking-[0.2em] shadow-lg flex items-center gap-2">
                            <Zap size={12} className="fill-current" />
                            Hot
                          </div>
                          <button 
                            onClick={(e) => { e.stopPropagation(); handleQuickAdd(deal); }}
                            className="absolute bottom-4 right-4 p-4 bg-primary-600 text-white rounded-2xl shadow-xl shadow-primary-200 transform translate-y-20 group-hover:translate-y-0 transition-transform duration-500"
                          >
                            <Plus size={24} />
                          </button>
                        </div>
                        <div className="p-8 space-y-3">
                          <div className="flex items-center justify-between">
                            <span className="text-[10px] font-black text-gray-400 uppercase tracking-widest">{deal.categoryName || 'Spare Part'}</span>
                            <div className="flex items-center gap-1 text-amber-500">
                              <Star size={12} className="fill-current" />
                              <span className="text-[10px] font-black">4.8</span>
                            </div>
                          </div>
                          <h4 className="font-black text-gray-900 text-lg truncate leading-tight">{deal.name}</h4>
                          <div className="flex items-end justify-between">
                            <div className="space-y-1">
                              <p className="text-primary-600 font-black text-2xl leading-none">₹{deal.sellingPrice.toLocaleString()}</p>
                              <div className="flex items-center gap-2">
                                <span className="text-gray-400 text-xs font-bold line-through">₹{deal.mrp.toLocaleString()}</span>
                                <span className="text-green-500 text-[10px] font-black uppercase tracking-widest">{Math.round((1 - deal.sellingPrice/deal.mrp)*100)}% Off</span>
                              </div>
                            </div>
                            <div className={`text-[10px] font-black uppercase tracking-widest px-3 py-1.5 rounded-full ${deal.stock > 0 ? 'bg-green-50 text-green-600' : 'bg-red-50 text-red-600'}`}>
                              {deal.stock > 0 ? 'In Stock' : 'Out of Stock'}
                            </div>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              );
            case 'recent_orders':
              return (
                <div key="recent_orders" className="space-y-6">
                  <div className="flex items-center justify-between px-2">
                    <h3 className="font-black text-gray-900 text-xl tracking-tight">Recent Orders</h3>
                    <button className="text-xs font-black text-primary-600 uppercase tracking-widest hover:bg-primary-50 px-4 py-2 rounded-xl transition-all">Track All</button>
                  </div>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    {(recentOrders || []).map((order) => (
                      <div key={order.id} className="p-6 bg-white border border-gray-100 rounded-[2.5rem] shadow-sm hover:shadow-xl hover:shadow-gray-100 transition-all duration-500 group relative">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-5">
                            <div className={`p-4 rounded-[1.5rem] transition-colors ${
                              order.status === 'DELIVERED' ? 'bg-blue-50 text-blue-600' : 'bg-amber-50 text-amber-600'
                            }`}>
                              {order.status === 'DELIVERED' ? <CheckCircle size={24} /> : <Clock size={24} />}
                            </div>
                            <div>
                              <p className="font-black text-gray-900 text-base">Order #{order.id}</p>
                              <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest mt-1">
                                {new Date(order.orderDate).toLocaleDateString('en-IN', { month: 'short', day: 'numeric', year: 'numeric' })} • {order.items?.length || 0} Items
                              </p>
                            </div>
                          </div>
                          <div className="text-right">
                            <p className="font-black text-gray-900 text-lg">₹{(order.totalAmount || 0).toLocaleString()}</p>
                            <p className={`text-[9px] font-black uppercase tracking-widest mt-1 ${order.status === 'DELIVERED' ? 'text-green-500' : 'text-amber-500'}`}>{order.status}</p>
                          </div>
                        </div>
                        
                        <div className="mt-6 flex items-center justify-between">
                          {order.status === 'DELIVERED' && (
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                const itemsToReorder = order.items.map((it: any) => ({
                                  productId: it.productId,
                                  name: it.name || it.productName,
                                  price: it.price,
                                  quantity: it.quantity,
                                  partNumber: it.partNumber,
                                  image: it.image || it.imagePath
                                }));
                                reorder(itemsToReorder);
                              }}
                              className="px-6 py-2 bg-primary-600 text-white rounded-xl text-[10px] font-black uppercase tracking-widest hover:bg-primary-700 transition-all"
                            >
                              Reorder
                            </button>
                          )}
                          <div 
                            onClick={() => window.location.href = `/order-status/${order.id}`}
                            className="p-2 bg-gray-50 rounded-xl text-gray-400 hover:bg-primary-600 hover:text-white transition-all cursor-pointer"
                          >
                            <ChevronRight size={20} />
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

        {/* Analytics Section - Refined */}
        {(currentUser?.roles?.includes(ROLE_ADMIN) || currentUser?.roles?.includes(ROLE_SUPER_MANAGER)) && (
        <div className="bg-white p-10 rounded-[3.5rem] shadow-sm border border-gray-100 mb-12">
          <div className="flex flex-col md:flex-row md:items-center justify-between mb-10 gap-6">
            <div>
              <h3 className="font-black text-gray-900 text-2xl tracking-tight">Sales Performance</h3>
              <p className="text-gray-400 text-sm font-bold uppercase tracking-widest mt-1">Real-time revenue tracking</p>
            </div>
            <div className="flex items-center bg-gray-50 p-1.5 rounded-[1.5rem] border border-gray-100">
              {(['DAILY', 'WEEKLY', 'MONTHLY'] as const).map((p) => (
                <button
                  key={p}
                  onClick={() => setPeriod(p)}
                  className={`px-6 py-2.5 rounded-[1.2rem] text-[10px] font-black uppercase tracking-widest transition-all ${
                    period === p ? 'bg-white text-primary-600 shadow-md' : 'text-gray-400 hover:text-gray-600'
                  }`}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>
          <div className="h-[350px] w-full relative min-h-0 min-w-0">
            {chartData && chartData.length > 0 ? (
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <defs>
                  <linearGradient id="colorSales" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#4f46e5" stopOpacity={0.15}/>
                    <stop offset="95%" stopColor="#4f46e5" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f8fafc" />
                <XAxis 
                  dataKey="name" 
                  axisLine={false} 
                  tickLine={false} 
                  tick={{fontSize: 11, fontWeight: 800, fill: '#cbd5e1'}}
                  dy={15}
                />
                <YAxis hide />
                <Tooltip 
                  cursor={{ stroke: '#4f46e5', strokeWidth: 2, strokeDasharray: '5 5' }}
                  contentStyle={{borderRadius: '24px', border: 'none', boxShadow: '0 20px 25px -5px rgb(0 0 0 / 0.1)', padding: '16px 20px'}}
                  itemStyle={{fontSize: '14px', fontWeight: 900, color: '#4f46e5'}}
                  labelStyle={{fontSize: '10px', fontWeight: 800, color: '#94a3b8', textTransform: 'uppercase', marginBottom: '4px'}}
                />
                <Area 
                  type="monotone" 
                  dataKey="sales" 
                  stroke="#4f46e5" 
                  strokeWidth={5}
                  fillOpacity={1} 
                  fill="url(#colorSales)" 
                  animationDuration={2000}
                />
              </AreaChart>
            </ResponsiveContainer>
            ) : (
              <div className="h-full flex items-center justify-center text-gray-400 font-bold uppercase tracking-widest text-sm">
                No data available for this period
              </div>
            )}
          </div>
        </div>
        )}
      </div>

      {/* WhatsApp Quick Order Button */}
      <a 
        href="https://wa.me/91XXXXXXXXXX?text=I want to order some spare parts" 
        target="_blank" 
        rel="noopener noreferrer"
        className="fixed right-6 bottom-32 z-50 p-4 bg-[#25D366] text-white rounded-full shadow-2xl shadow-green-200 hover:scale-110 active:scale-95 transition-all animate-bounce"
        title="Quick Order via WhatsApp"
      >
        <MessageSquare size={28} fill="currentColor" />
      </a>

      {/* Quick Action Bottom Nav - Modern Glassmorphism */}
      <div className="fixed bottom-8 left-1/2 -translate-x-1/2 flex items-center bg-white/70 backdrop-blur-2xl border border-white/40 shadow-[0_20px_50px_rgba(0,0,0,0.15)] rounded-[2.5rem] px-8 py-4 gap-10 z-50 transition-transform hover:scale-[1.02]">
        <button className="text-primary-600 transition-transform active:scale-90" title="Dashboard"><BarChart2 size={26} /></button>
        <button className="text-gray-400 hover:text-primary-600 transition-all active:scale-90" title="Shop"><ShoppingBag size={26} /></button>
        <div className="relative -mt-14">
          <div className="absolute inset-0 bg-primary-600 rounded-3xl blur-2xl opacity-30 animate-pulse"></div>
          <button className="w-16 h-16 bg-primary-600 rounded-3xl flex items-center justify-center text-white shadow-2xl shadow-primary-200 relative z-10 active:scale-90 transition-transform" title="Quick Add">
            <Plus size={32} strokeWidth={3} />
          </button>
        </div>
        <button className="text-gray-400 hover:text-primary-600 transition-all active:scale-90" title="Cart"><ShoppingCart size={26} /></button>
        <button className="text-gray-400 hover:text-primary-600 transition-all active:scale-90" title="Settings"><Settings size={26} /></button>
      </div>
    </div>
  );
};

export default MobileDashboard;

