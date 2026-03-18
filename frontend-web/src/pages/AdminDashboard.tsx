
import React, { useState, useEffect, useCallback } from 'react';
import api, { API_BASE_URL } from '../services/api';
import { Link } from 'react-router-dom';
import { useLanguage } from '../context/LanguageContext';
import { Users, ShoppingBag, BarChart2, CheckCircle, XCircle, Plus, Package, UserPlus, Upload, Truck, Trash2, RotateCcw, Settings, Bell, MessageSquare, Search } from 'lucide-react';
import { ROLE_SUPER_MANAGER, ROLE_ADMIN, ROLE_MECHANIC, ROLE_RETAILER, ROLE_WHOLESALER, ROLE_STAFF } from '../services/constants';
import AuthService from '../services/auth.service';
import Skeleton from '../components/Skeleton';
import useSound from 'use-sound';
import SockJS from 'sockjs-client';
import Stomp from 'stompjs';

const AdminDashboard = () => {
  const { tp } = useLanguage();
  const currentUser = AuthService.getCurrentUser();
  const isSuperManager = currentUser?.roles?.includes(ROLE_SUPER_MANAGER);

  // Sound hook - using a public notification sound URL
  const [playNotification] = useSound('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3');

  const getImageUrl = (path: string) => {
    if (!path) return '';
    if (path.startsWith('http')) return path;
    const base = API_BASE_URL.endsWith('/api') ? API_BASE_URL.replace('/api', '') : API_BASE_URL;
    return `${base}${path.startsWith('/') ? '' : '/'}${path}`;
  };

  const [users, setUsers] = useState<any[]>([]);
  const [orders, setOrders] = useState<any[]>([]);
  const [products, setProducts] = useState<any[]>([]);
  const [pagination, setPagination] = useState({
    pageNumber: 0,
    pageSize: 10,
    totalElements: 0,
    totalPages: 0,
    last: true
  });
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('users');
  const [showAddProduct, setShowAddProduct] = useState(false);
  const [showEditProduct, setShowEditProduct] = useState(false);
  const [editingProduct, setEditingProduct] = useState<any>(null);
  const [showEditOrder, setShowEditOrder] = useState(false);
  const [editingOrder, setEditingOrder] = useState<any>(null);
  const [newProduct, setNewProduct] = useState({
    name: '',
    partNumber: '',
    mrp: '',
    sellingPrice: '',
    wholesalerPrice: '',
    retailerPrice: '',
    mechanicPrice: '',
    stock: '',
    wholesalerId: '',
    imagePath: '',
    description: '',
    categoryId: ''
  });
  const [uploading, setUploading] = useState(false);
  const [categories, setCategories] = useState<any[]>([]);
  const [showAddCategory, setShowAddCategory] = useState(false);
  const [showEditCategory, setShowEditCategory] = useState(false);
  const [editingCategory, setEditingCategory] = useState<any>(null);
  const [newCategory, setNewCategory] = useState({ name: '', description: '', imagePath: '', imageLink: '', parentId: '' });
  const [selectedExcelCategory, setSelectedExcelCategory] = useState<string>('');

  const [deletedUsers, setDeletedUsers] = useState<any[]>([]);
  const [deletedOrders, setDeletedOrders] = useState<any[]>([]);
  const [deletedProducts, setDeletedProducts] = useState<any[]>([]);

  const [settings, setSettings] = useState<any[]>([]);
  const [savingSettings, setSavingSettings] = useState(false);

  const [showAddUser, setShowAddUser] = useState(false);
  const [newUser, setNewUser] = useState({
    name: '',
    email: '',
    password: '',
    role: ROLE_MECHANIC,
    phone: '',
    address: ''
  });

  const [productSelectionMode, setProductSelectionMode] = useState(false);
  const [selectedProductIds, setSelectedProductIds] = useState<number[]>([]);
  const [userSearchTerm, setUserSearchTerm] = useState('');

  useEffect(() => { 
    const init = async () => {
      setLoading(true);
      try {
        await Promise.all([
          fetchUsers(),
          fetchOrders(),
          fetchProducts(),
          fetchCategories(),
          fetchDeletedItems(),
          fetchSettings()
        ]);
      } catch (err) {
        console.error("Initial fetch failed:", err);
      } finally {
        setLoading(false);
      }
    };
    init();
  }, []);

  const fetchSettings = async () => {
    try {
      const res = await api.get('/admin/settings');
      setSettings(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  const updateSetting = async (key: string, value: string) => {
    try {
      setSavingSettings(true);
      await api.post('/admin/settings', { settingKey: key, settingValue: value });
      fetchSettings();
    } catch (err) {
      console.error(err);
      alert('Failed to update setting');
    } finally {
      setSavingSettings(false);
    }
  };

  const getSetting = (key: string, defaultValue: string = 'false') => {
    const s = settings.find(s => s.settingKey === key);
    return s ? s.settingValue : defaultValue;
  };

  const fetchDeletedItems = async () => {
    try {
      const usersRes = await api.get('/admin/recycle-bin/users');
      setDeletedUsers(usersRes.data);
      const ordersRes = await api.get('/admin/recycle-bin/orders');
      setDeletedOrders(ordersRes.data);
      const productsRes = await api.get('/admin/recycle-bin/products');
      setDeletedProducts(productsRes.data);
    } catch (err) {
      console.error(err);
    }
  };

  const restoreUser = async (userId: number) => {
    try {
      await api.post(`/admin/recycle-bin/users/${userId}/restore`);
      fetchUsers();
      fetchDeletedItems();
    } catch (err) {
      console.error(err);
      alert('Failed to restore user');
    }
  };

  const restoreOrder = async (orderId: number) => {
    try {
      await api.post(`/admin/recycle-bin/orders/${orderId}/restore`);
      fetchOrders();
      fetchDeletedItems();
    } catch (err) {
      console.error(err);
      alert('Failed to restore order');
    }
  };

  const restoreProduct = async (productId: number) => {
    try {
      await api.post(`/admin/recycle-bin/products/${productId}/restore`);
      fetchProducts();
      fetchDeletedItems();
    } catch (err) {
      console.error(err);
      alert('Failed to restore product');
    }
  };

  const permanentDeleteUser = async (userId: number) => {
    if (!window.confirm('Are you sure you want to permanently delete this user? This cannot be undone.')) return;
    try {
      await api.delete(`/admin/recycle-bin/users/${userId}/permanent`);
      fetchDeletedItems();
    } catch (err) {
      console.error(err);
      alert('Failed to permanently delete user');
    }
  };

  const permanentDeleteOrder = async (orderId: number) => {
    if (!window.confirm('Are you sure you want to permanently delete this order? This cannot be undone.')) return;
    try {
      await api.delete(`/admin/recycle-bin/orders/${orderId}/permanent`);
      fetchDeletedItems();
    } catch (err) {
      console.error(err);
      alert('Failed to permanently delete order');
    }
  };

  const permanentDeleteProduct = async (productId: number) => {
    if (!window.confirm('Are you sure you want to permanently delete this product? This cannot be undone.')) return;
    try {
      await api.delete(`/admin/recycle-bin/products/${productId}/permanent`);
      fetchDeletedItems();
    } catch (err) {
      console.error(err);
      alert('Failed to permanently delete product');
    }
  };

  const handleEmptyRecycleBin = async () => {
    if (!window.confirm('Are you sure you want to empty the Recycle Bin? All deleted products will be permanently removed. This action cannot be undone.')) return;
    try {
      await api.delete('/products/empty-recycle-bin');
      fetchDeletedItems();
      alert('Recycle bin emptied successfully');
    } catch (err) {
      console.error(err);
      alert('Failed to empty recycle bin');
    }
  };

  const fetchUsers = async () => {
    try {
      const res = await api.get('/admin/users');
      setUsers(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  const fetchOrders = useCallback(async () => {
    try {
      const res = await api.get('/admin/orders');
      setOrders(res.data);
    } catch (err) {
      console.error(err);
    }
  }, []);

  useEffect(() => {
    // WebSocket setup for new orders
    const socketBaseUrl = API_BASE_URL.endsWith('/api') 
      ? API_BASE_URL.substring(0, API_BASE_URL.length - 4) 
      : API_BASE_URL;
    
    const socket = new SockJS(`${socketBaseUrl}/ws`);
    const stompClient = Stomp.over(socket);
    stompClient.debug = () => {}; // Disable debug logs

    stompClient.connect({}, () => {
      stompClient.subscribe('/topic/orders', (message) => {
        const orderData = JSON.parse(message.body);
        if (orderData.status === 'PENDING') {
          playNotification();
          fetchOrders(); // Refresh list
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
  }, [playNotification, fetchOrders]);

  const fetchCategories = async () => {
    try {
      const res = await api.get('/categories?rootsOnly=false');
      setCategories(res.data || []);
    } catch (err) {
      console.error(err);
    }
  };

  const handleExcelUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const formData = new FormData();
    formData.append('file', file);
    if (selectedExcelCategory) {
      formData.append('categoryId', selectedExcelCategory);
    }

    try {
      await api.post('/excel/upload', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });
      alert('Products imported successfully!');
      fetchProducts();
    } catch (err) {
      console.error(err);
      alert('Failed to import products.');
    }
  };

  const handleExcelDownload = async () => {
    try {
      const response = await api.get('/excel/download', {
        responseType: 'blob',
      });
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', 'products.xlsx');
      document.body.appendChild(link);
      link.click();
      link.remove();
    } catch (err) {
      console.error(err);
      alert('Failed to download excel sheet.');
    }
  };

  const fetchProducts = async (page = 0) => {
    try {
      const res = await api.get(`/products?page=${page}&size=10&sortBy=id&direction=desc`);
      setProducts(res.data.content);
      setPagination({
        pageNumber: res.data.pageNumber,
        pageSize: res.data.pageSize,
        totalElements: res.data.totalElements,
        totalPages: res.data.totalPages,
        last: res.data.last
      });
    } catch (err) {
      console.error(err);
    }
  };

  const getGroupedOrders = () => {
    const grouped = orders.reduce((acc: any, order) => {
      const name = order.customerName || 'Unknown User';
      if (!acc[name]) acc[name] = [];
      acc[name].push(order);
      return acc;
    }, {});
    return grouped;
  };

  const groupedOrders = getGroupedOrders();

  const handleEditOrder = async (orderId: number, items: any[]) => {
    try {
      await api.put(`/admin/orders/${orderId}/items`, items);
      setShowEditOrder(false);
      setEditingOrder(null);
      fetchOrders();
    } catch (err) {
      console.error(err);
      alert('Failed to update order');
    }
  };

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploading(true);
    const formData = new FormData();
    formData.append('file', file);

    try {
      const res = await api.post('/files/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      setNewProduct({ ...newProduct, imagePath: res.data.url });
    } catch (err) {
      alert('Failed to upload image');
    } finally {
      setUploading(false);
    }
  };

  const handleAddProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const res = await api.post('/products', {
        ...newProduct,
        mrp: parseFloat(String(newProduct.mrp)) || 0,
        sellingPrice: parseFloat(String(newProduct.sellingPrice)) || 0,
        wholesalerPrice: parseFloat(String(newProduct.wholesalerPrice)) || 0,
        retailerPrice: parseFloat(String(newProduct.retailerPrice)) || 0,
        mechanicPrice: parseFloat(String(newProduct.mechanicPrice)) || 0,
        stock: parseInt(String(newProduct.stock)) || 0,
        wholesalerId: newProduct.wholesalerId ? parseInt(newProduct.wholesalerId as any) : 1,
        categoryId: newProduct.categoryId ? parseInt(newProduct.categoryId as any) : undefined
      });
      setShowAddProduct(false);
      const savedProduct = res.data;
      if (!newProduct.categoryId && savedProduct.categoryName) {
        alert(`Product auto-categorized as: ${savedProduct.categoryName}`);
      }
      setNewProduct({ name: '', partNumber: '', mrp: '', sellingPrice: '', wholesalerPrice: '', retailerPrice: '', mechanicPrice: '', stock: '', imagePath: '', description: '', wholesalerId: '', categoryId: '' });
      fetchProducts();
    } catch (err) {
      console.error(err);
      alert('Failed to add product');
    }
  };

  const handleEditImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !editingProduct) return;

    setUploading(true);
    const formData = new FormData();
    formData.append('file', file);

    try {
      const res = await api.post('/files/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      setEditingProduct({ ...editingProduct, imagePath: res.data.url });
    } catch (err) {
      alert('Failed to upload image');
    } finally {
      setUploading(false);
    }
  };

  const handleUpdateProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await api.put(`/products/${editingProduct.id}`, {
        ...editingProduct,
        mrp: parseFloat(String(editingProduct.mrp)) || 0,
        sellingPrice: parseFloat(String(editingProduct.sellingPrice)) || 0,
        wholesalerPrice: parseFloat(String(editingProduct.wholesalerPrice)) || 0,
        retailerPrice: parseFloat(String(editingProduct.retailerPrice)) || 0,
        mechanicPrice: parseFloat(String(editingProduct.mechanicPrice)) || 0,
        stock: parseInt(String(editingProduct.stock)) || 0,
        categoryId: editingProduct.categoryId ? parseInt(editingProduct.categoryId as any) : undefined
      });
      setShowEditProduct(false);
      setEditingProduct(null);
      fetchProducts();
    } catch (err) {
      console.error(err);
      alert('Failed to update product');
    }
  };

  const handleAddUser = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await AuthService.register(
        newUser.name,
        newUser.email,
        newUser.password,
        newUser.role,
        newUser.phone,
        '',
        '',
        newUser.address
      );
      setShowAddUser(false);
      setNewUser({ name: '', email: '', password: '', role: ROLE_MECHANIC, phone: '', address: '' });
      fetchUsers();
    } catch (err) {
      console.error(err);
      alert('Failed to create user');
    }
  };

  const updateOrderStatus = async (orderId: number, status: string) => {
    try {
      await api.put(`/orders/${orderId}/status?status=${status}`);
      fetchOrders();
    } catch (err) {
      console.error(err);
      alert('Failed to update order status');
    }
  };

  const updateUserStatus = async (userId: number, status: string) => {
    try {
      await api.put(`/admin/users/${userId}/status?status=${status}`);
      fetchUsers();
    } catch (err) {
      console.error(err);
    }
  };

  const updateUserRole = async (userId: number, role: string) => {
    try {
      await api.put(`/admin/users/${userId}/role?roleName=${role}`);
      fetchUsers();
    } catch (err) {
      console.error(err);
      alert('Failed to update role');
    }
  };

  const handleAddCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await api.post('/categories', {
        ...newCategory,
        parentId: newCategory.parentId ? Number(newCategory.parentId) : null
      });
      setShowAddCategory(false);
      setNewCategory({ name: '', description: '', imagePath: '', imageLink: '', parentId: '' });
      fetchCategories();
    } catch (err) {
      console.error(err);
      alert('Failed to add category');
    }
  };

  const handleEditCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingCategory) return;
    try {
      await api.put(`/categories/${editingCategory.id}`, {
        ...editingCategory,
        parentId: editingCategory.parentId ? Number(editingCategory.parentId) : null
      });
      setShowEditCategory(false);
      setEditingCategory(null);
      fetchCategories();
    } catch (err) {
      console.error(err);
      alert('Failed to update category');
    }
  };

  const handleEditCategoryImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !editingCategory) return;

    setUploading(true);
    const formData = new FormData();
    formData.append('file', file);

    try {
      const res = await api.post('/files/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      setEditingCategory({ ...editingCategory, imagePath: res.data.url });
    } catch (err) {
      alert('Failed to upload category image');
    } finally {
      setUploading(false);
    }
  };

  const handleCategoryImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploading(true);
    const formData = new FormData();
    formData.append('file', file);

    try {
      const res = await api.post('/files/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      setNewCategory({ ...newCategory, imagePath: res.data.url });
    } catch (err) {
      alert('Failed to upload category image');
    } finally {
      setUploading(false);
    }
  };

  const renderStatsSkeletons = () => (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6 mb-10">
      {[1, 2, 3, 4].map((i) => (
        <div key={i} className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4">
          <Skeleton className="w-14 h-14 rounded-xl" />
          <div className="flex-1">
            <Skeleton className="w-20 h-3 mb-2" />
            <Skeleton className="w-24 h-6" />
          </div>
        </div>
      ))}
    </div>
  );

  const renderTableSkeletons = (cols: number) => (
    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
      <div className="bg-gray-50/50 px-6 py-4 border-b border-gray-100 flex gap-4">
        {[...Array(cols)].map((_, i) => (
          <Skeleton key={i} className="h-4 flex-1" />
        ))}
      </div>
      {[1, 2, 3, 4, 5].map((i) => (
        <div key={i} className="px-6 py-5 border-b border-gray-100 flex gap-4 items-center">
          {[...Array(cols)].map((_, j) => (
            <Skeleton key={j} className="h-5 flex-1" />
          ))}
        </div>
      ))}
    </div>
  );

  if (loading) return (
    <div className="container mx-auto p-4 md:p-6">
      <div className="flex justify-between items-center mb-8">
        <Skeleton className="w-64 h-10 rounded-xl" />
        <div className="flex gap-3">
          <Skeleton className="w-24 h-10 rounded-xl" />
          <Skeleton className="w-24 h-10 rounded-xl" />
        </div>
      </div>
      {renderStatsSkeletons()}
      <div className="flex gap-8 border-b border-gray-100 mb-8 pb-1">
        {[1, 2, 3, 4, 5].map(i => <Skeleton key={i} className="w-24 h-8 rounded-t-lg" />)}
      </div>
      {renderTableSkeletons(4)}
    </div>
  );

  return (
    <div className={`container mx-auto p-4 md:p-6 ${isSuperManager ? 'bg-purple-50 min-h-screen' : ''}`}>
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6 mb-8">
        <h1 className={`text-2xl md:text-3xl font-black ${isSuperManager ? 'text-purple-800' : 'text-gray-900'}`}>
          {isSuperManager ? 'Super Manager Panel' : 'Admin Panel'}
        </h1>
        <div className="flex flex-wrap gap-3">
          <div className="flex items-center gap-2 bg-white border border-gray-200 rounded-xl px-3 py-1.5 shadow-sm">
            <span className="text-[10px] font-black text-gray-400 uppercase">Category:</span>
            <select
              className="text-xs font-bold text-gray-700 bg-transparent outline-none border-none focus:ring-0"
              value={selectedExcelCategory}
              onChange={e => setSelectedExcelCategory(e.target.value)}
            >
              <option value="">Auto (AI)</option>
              {categories.map((c: any) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          </div>
          <label className="flex items-center gap-2 bg-green-600 text-white px-4 py-2.5 rounded-xl hover:bg-green-700 cursor-pointer transition shadow-lg shadow-green-100 font-bold text-sm">
            <Upload size={18} />
            <span>Import Excel</span>
            <input type="file" className="hidden" accept=".xlsx, .xls" onChange={handleExcelUpload} />
          </label>
          <button 
            onClick={handleExcelDownload}
            className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2.5 rounded-xl hover:bg-blue-700 transition shadow-lg shadow-blue-100 font-bold text-sm"
          >
            <Upload size={18} className="rotate-180" />
            <span>Export</span>
          </button>
          <button 
            onClick={() => setShowAddUser(true)}
            className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2.5 rounded-xl hover:bg-indigo-700 transition shadow-lg shadow-indigo-100 font-bold text-sm"
          >
            <UserPlus size={18} />
            <span>Add User</span>
          </button>
          <button 
            onClick={() => setShowAddProduct(true)}
            className="flex items-center gap-2 bg-primary-600 text-white px-4 py-2.5 rounded-xl hover:bg-primary-700 transition shadow-lg shadow-primary-100 font-bold text-sm"
          >
            <Plus size={18} />
            <span>Add Product</span>
          </button>
          <div className="relative group">
            <button className="flex items-center gap-2 bg-green-600 text-white px-4 py-2.5 rounded-xl hover:bg-green-700 transition shadow-lg shadow-green-100 font-bold text-sm">
              <Upload size={18} />
              <span>Bulk Import</span>
            </button>
            <div className="absolute right-0 mt-2 w-64 bg-white rounded-xl shadow-xl border border-gray-100 p-4 hidden group-hover:block z-50">
              <label className="block text-xs font-bold text-gray-500 uppercase mb-2">Target Category</label>
              <select
                className="w-full border border-gray-200 rounded-lg p-2 text-sm mb-3 outline-none focus:ring-2 focus:ring-green-500"
                value={selectedExcelCategory}
                onChange={e => setSelectedExcelCategory(e.target.value)}
              >
                <option value="">Auto-categorize</option>
                {categories.map((c: any) => (
                  <option key={c.id} value={c.id}>{c.name}</option>
                ))}
              </select>
              <input
                type="file"
                accept=".xlsx, .xls"
                onChange={handleExcelUpload}
                className="block w-full text-xs text-gray-500 file:mr-2 file:py-1 file:px-2 file:rounded-lg file:border-0 file:text-xs file:font-bold file:bg-green-50 file:text-green-700 hover:file:bg-green-100"
              />
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6 mb-10">
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4 hover:shadow-md transition">
          <div className={`p-4 rounded-xl ${isSuperManager ? 'bg-purple-100 text-purple-600' : 'bg-blue-100 text-blue-600'}`}>
            <Users size={24} />
          </div>
          <div>
            <p className="text-gray-400 text-xs font-bold uppercase tracking-wider">Total Users</p>
            <p className="text-2xl font-black text-gray-900">{users.length}</p>
          </div>
        </div>
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4 hover:shadow-md transition">
          <div className={`p-4 rounded-xl ${isSuperManager ? 'bg-purple-100 text-purple-600' : 'bg-green-100 text-green-600'}`}>
            <ShoppingBag size={24} />
          </div>
          <div>
            <p className="text-gray-400 text-xs font-bold uppercase tracking-wider">Total Orders</p>
            <p className="text-2xl font-black text-gray-900">{orders.length}</p>
          </div>
        </div>
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4 hover:shadow-md transition">
          <div className={`p-4 rounded-xl ${isSuperManager ? 'bg-purple-100 text-purple-600' : 'bg-yellow-100 text-yellow-600'}`}>
            <BarChart2 size={24} />
          </div>
          <div>
            <p className="text-gray-400 text-xs font-bold uppercase tracking-wider">Total Revenue</p>
            <p className="text-2xl font-black text-gray-900">₹{orders.reduce((acc, o) => acc + o.totalAmount, 0).toLocaleString()}</p>
          </div>
        </div>
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4 hover:shadow-md transition">
          <div className={`p-4 rounded-xl ${isSuperManager ? 'bg-purple-100 text-purple-600' : 'bg-orange-100 text-orange-600'}`}>
            <Package size={24} />
          </div>
          <div>
            <p className="text-gray-400 text-xs font-bold uppercase tracking-wider">Products</p>
            <p className="text-2xl font-black text-gray-900">{products.length}</p>
          </div>
        </div>
      </div>

      <div className="flex overflow-x-auto no-scrollbar border-b border-gray-100 mb-8 gap-2 md:gap-8 pb-1">
        {[
          { id: 'users', label: 'Users', icon: Users },
          { id: 'orders', label: 'Transactions', icon: ShoppingBag },
          { id: 'products', label: 'Inventory', icon: Package },
          { id: 'deliveries', label: 'Deliveries', icon: Truck },
          { id: 'recycle', label: 'Recycle Bin', icon: Trash2 },
          { id: 'categories', label: 'Categories', icon: Plus },
          { id: 'settings', label: 'Settings', icon: Settings },
        ].map((tab) => (
          <button
            key={tab.id}
            className={`flex items-center gap-2 px-4 py-3 font-bold text-sm whitespace-nowrap transition-all relative ${
              activeTab === tab.id 
                ? 'text-primary-600' 
                : 'text-gray-400 hover:text-gray-600'
            }`}
            onClick={() => setActiveTab(tab.id)}
          >
            <tab.icon size={18} />
            {tab.label}
            {activeTab === tab.id && (
              <div className="absolute bottom-0 left-0 right-0 h-1 bg-primary-600 rounded-t-full" />
            )}
          </button>
        ))}
      </div>

      {activeTab === 'users' && (
        <div className="space-y-4">
          <div className="flex flex-col md:flex-row gap-4 items-center justify-between mb-2">
            <div className="relative w-full md:max-w-md">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
              <input
                type="text"
                placeholder="Search users by name, email, or role..."
                className="w-full pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary-500 outline-none transition shadow-sm"
                value={userSearchTerm}
                onChange={(e) => setUserSearchTerm(e.target.value)}
              />
            </div>
            <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase">
              <Users size={16} />
              <span>{users.filter(u => 
                u.name.toLowerCase().includes(userSearchTerm.toLowerCase()) || 
                u.email.toLowerCase().includes(userSearchTerm.toLowerCase()) ||
                (u.role?.name || u.role).toLowerCase().includes(userSearchTerm.toLowerCase())
              ).length} Users Found</span>
            </div>
          </div>

          <div className="hidden md:block bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <table className="min-w-full divide-y divide-gray-100">
              <thead className="bg-gray-50/50">
                <tr>
                  <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">User Details</th>
                  <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Role & Permissions</th>
                  <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Status</th>
                  <th className="px-6 py-4 text-center text-xs font-bold text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-100">
                {users.filter(u => 
                  u.name.toLowerCase().includes(userSearchTerm.toLowerCase()) || 
                  u.email.toLowerCase().includes(userSearchTerm.toLowerCase()) ||
                  (u.role?.name || u.role).toLowerCase().includes(userSearchTerm.toLowerCase())
                ).map((user) => (
                  <tr key={user.id} className="hover:bg-gray-50/50 transition">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-primary-100 text-primary-700 flex items-center justify-center font-black text-sm uppercase">
                          {user.name.charAt(0)}
                        </div>
                        <div>
                          <div className="font-bold text-gray-900">{user.name}</div>
                          <div className="text-xs text-gray-500">{user.email}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <select 
                        value={user.role?.name || user.role}
                        onChange={(e) => updateUserRole(user.id, e.target.value)}
                        className="bg-gray-50 border border-gray-200 rounded-lg px-3 py-1.5 text-xs font-bold text-gray-700 focus:outline-none focus:ring-2 focus:ring-primary-500 transition"
                      >
                        <option value={ROLE_MECHANIC}>Mechanic</option>
                        <option value={ROLE_RETAILER}>Retailer</option>
                        <option value={ROLE_WHOLESALER}>Wholesaler</option>
                        <option value={ROLE_STAFF}>Staff</option>
                        <option value={ROLE_SUPER_MANAGER}>Super Manager</option>
                        <option value={ROLE_ADMIN}>Admin</option>
                      </select>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`px-3 py-1 text-[10px] font-black tracking-widest uppercase rounded-lg ${
                        user.status === 'PENDING' ? 'bg-yellow-100 text-yellow-700' : 'bg-green-100 text-green-700'
                      }`}>
                        {user.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-center">
                      <div className="flex items-center justify-center gap-2">
                        {user.status === 'PENDING' ? (
                          <button
                            onClick={() => updateUserStatus(user.id, 'ACTIVE')}
                            className="p-2 bg-green-50 text-green-600 rounded-lg hover:bg-green-100 transition"
                            title="Approve User"
                          >
                            <CheckCircle size={18} />
                          </button>
                        ) : (
                          <button
                            onClick={() => updateUserStatus(user.id, 'PENDING')}
                            className="p-2 bg-orange-50 text-orange-600 rounded-lg hover:bg-orange-100 transition"
                            title="Suspend User"
                          >
                            <XCircle size={18} />
                          </button>
                        )}
                        <button 
                          onClick={() => deleteUser(user.id)}
                          className="p-2 bg-red-50 text-red-600 rounded-lg hover:bg-red-100 transition"
                          title="Delete User"
                        >
                          <Trash2 size={18} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="md:hidden space-y-4">
            {users.filter(u => 
              u.name.toLowerCase().includes(userSearchTerm.toLowerCase()) || 
              u.email.toLowerCase().includes(userSearchTerm.toLowerCase()) ||
              (u.role?.name || u.role).toLowerCase().includes(userSearchTerm.toLowerCase())
            ).map((user) => (
              <div key={user.id} className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100 space-y-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 rounded-full bg-primary-100 text-primary-700 flex items-center justify-center font-black text-lg uppercase">
                      {user.name.charAt(0)}
                    </div>
                    <div>
                      <div className="font-black text-gray-900">{user.name}</div>
                      <div className="text-xs font-bold text-gray-400">{user.email}</div>
                    </div>
                  </div>
                  <span className={`px-3 py-1 text-[10px] font-black tracking-widest uppercase rounded-lg ${
                    user.status === 'PENDING' ? 'bg-yellow-100 text-yellow-700' : 'bg-green-100 text-green-700'
                  }`}>
                    {user.status}
                  </span>
                </div>
                
                <div className="flex items-center justify-between pt-2 border-t border-gray-50">
                  <div className="flex flex-col gap-1">
                    <span className="text-[10px] font-black text-gray-400 uppercase tracking-widest">Assign Role</span>
                    <select 
                      value={user.role?.name || user.role}
                      onChange={(e) => updateUserRole(user.id, e.target.value)}
                      className="bg-gray-50 border border-gray-200 rounded-lg px-3 py-1.5 text-xs font-bold text-gray-700"
                    >
                      <option value={ROLE_MECHANIC}>Mechanic</option>
                      <option value={ROLE_RETAILER}>Retailer</option>
                      <option value={ROLE_WHOLESALER}>Wholesaler</option>
                      <option value={ROLE_STAFF}>Staff</option>
                      <option value={ROLE_SUPER_MANAGER}>Super Manager</option>
                      <option value={ROLE_ADMIN}>Admin</option>
                    </select>
                  </div>
                  <div className="flex items-center gap-2">
                    {user.status === 'PENDING' ? (
                      <button
                        onClick={() => updateUserStatus(user.id, 'ACTIVE')}
                        className="p-3 bg-green-600 text-white rounded-xl shadow-lg shadow-green-100 transition"
                      >
                        <CheckCircle size={20} />
                      </button>
                    ) : (
                      <button
                        onClick={() => updateUserStatus(user.id, 'PENDING')}
                        className="p-3 bg-orange-500 text-white rounded-xl shadow-lg shadow-orange-100 transition"
                      >
                        <XCircle size={20} />
                      </button>
                    )}
                    <button 
                      onClick={() => deleteUser(user.id)}
                      className="p-3 bg-red-600 text-white rounded-xl shadow-lg shadow-red-100 transition"
                    >
                      <Trash2 size={20} />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {activeTab === 'orders' && (
        <div className="space-y-8">
          {Object.keys(groupedOrders).map((userName) => (
            <div key={userName} className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
              <div className="px-6 py-4 border-b border-gray-100 bg-gray-50/50 flex items-center justify-between">
                <h3 className="text-lg font-black text-gray-900 flex items-center gap-2">
                  <Users size={20} className="text-primary-600" />
                  Orders for {userName}
                </h3>
                <span className="text-xs font-bold text-gray-500 bg-white px-3 py-1 rounded-full border border-gray-100">
                  {groupedOrders[userName].length} Orders
                </span>
              </div>
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-100">
                  <thead className="bg-gray-50/30">
                    <tr>
                      <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Order Info</th>
                      <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Amount</th>
                      <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Status</th>
                      <th className="px-6 py-4 text-center text-xs font-bold text-gray-500 uppercase tracking-wider">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-100">
                    {groupedOrders[userName].map((order: any) => (
                      <tr key={order.id} className="hover:bg-gray-50/50 transition">
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className="text-xs font-black text-primary-700 bg-primary-50 px-2 py-1 rounded-md">#{order.id}</span>
                          <div className="text-[10px] text-gray-400 mt-1 font-bold">{new Date(order.createdAt).toLocaleDateString()}</div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="text-sm font-black text-gray-900">₹{order.totalAmount.toLocaleString()}</div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className={`px-3 py-1 text-[10px] font-black tracking-widest uppercase rounded-lg ${
                            order.status === 'PENDING' ? 'bg-yellow-100 text-yellow-700' : 
                            order.status === 'APPROVED' ? 'bg-blue-100 text-blue-700' : 
                            order.status === 'DELIVERED' ? 'bg-green-100 text-green-700' : 
                            'bg-gray-100 text-gray-700'
                          }`}>
                            {order.status}
                          </span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-center">
                          <div className="flex items-center justify-center gap-2">
                            <button 
                              onClick={() => { setEditingOrder(order); setShowEditOrder(true); }}
                              className="px-3 py-1.5 bg-gray-50 text-primary-600 rounded-lg text-xs font-bold hover:bg-primary-50 transition"
                            >
                              Edit
                            </button>
                            <select 
                              value={order.status}
                              onChange={(e) => updateOrderStatus(order.id, e.target.value)}
                              className="bg-gray-50 border border-gray-200 rounded-lg px-2 py-1 text-[10px] font-black text-gray-700 focus:outline-none focus:ring-2 focus:ring-primary-500 transition uppercase"
                            >
                              <option value="PENDING">PENDING</option>
                              <option value="APPROVED">APPROVED</option>
                              <option value="PACKED">PACKED</option>
                              <option value="OUT_FOR_DELIVERY">OUT_FOR_DELIVERY</option>
                              <option value="DELIVERED">DELIVERED</option>
                              <option value="CANCELLED">CANCELLED</option>
                            </select>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          ))}
          {orders.length === 0 && (
            <div className="bg-white rounded-2xl p-10 text-center border border-dashed border-gray-200">
              <ShoppingBag size={48} className="mx-auto text-gray-200 mb-4" />
              <p className="text-gray-400 font-bold">No orders found</p>
            </div>
          )}
        </div>
      )}

      {activeTab === 'products' && (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden overflow-x-auto">
          <div className="flex items-center justify-between p-4 border-b border-gray-100">
            {!productSelectionMode ? (
              <button
                onClick={() => setProductSelectionMode(true)}
                className="px-3 py-1.5 bg-gray-50 text-primary-700 rounded-lg text-xs font-bold hover:bg-primary-50 transition"
              >
                Select Multiple
              </button>
            ) : (
              <div className="flex items-center gap-2">
                <button
                  onClick={() => {
                    setProductSelectionMode(false);
                    setSelectedProductIds([]);
                  }}
                  className="px-3 py-1.5 bg-gray-50 text-gray-700 rounded-lg text-xs font-bold hover:bg-gray-100 transition"
                >
                  Cancel
                </button>
                <button
                  onClick={() => setSelectedProductIds(products.map((p: any) => p.id))}
                  className="px-3 py-1.5 bg-gray-50 text-primary-700 rounded-lg text-xs font-bold hover:bg-primary-50 transition"
                >
                  Select All
                </button>
                <button
                  onClick={async () => {
                    if (selectedProductIds.length === 0) return;
                    if (!window.confirm(`Delete ${selectedProductIds.length} selected products?`)) return;
                    try {
                      await api.post('/products/delete-bulk', selectedProductIds);
                      setSelectedProductIds([]);
                      setProductSelectionMode(false);
                      fetchProducts();
                    } catch (err) {
                      console.error(err);
                      alert('Bulk delete failed');
                    }
                  }}
                  className="px-3 py-1.5 bg-red-600 text-white rounded-lg text-xs font-bold hover:bg-red-700 transition"
                >
                  Delete Selected
                </button>
              </div>
            )}
            <div />
          </div>
          <table className="min-w-full divide-y divide-gray-100">
            <thead className="bg-gray-50/50">
              <tr>
                {productSelectionMode && (
                  <th className="px-4 py-4">
                    <input
                      type="checkbox"
                      checked={selectedProductIds.length === products.length && products.length > 0}
                      onChange={(e) => {
                        if (e.target.checked) {
                          setSelectedProductIds(products.map((p: any) => p.id));
                        } else {
                          setSelectedProductIds([]);
                        }
                      }}
                    />
                  </th>
                )}
                <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Product Name</th>
                <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Part Number</th>
                <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Pricing</th>
                <th className="px-6 py-4 text-center text-xs font-bold text-gray-500 uppercase tracking-wider">Stock</th>
                <th className="px-6 py-4 text-center text-xs font-bold text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-100">
              {products.map((product: any) => (
                <tr key={product.id} className="hover:bg-gray-50/50 transition">
                  {productSelectionMode && (
                    <td className="px-4 py-4">
                      <input
                        type="checkbox"
                        checked={selectedProductIds.includes(product.id)}
                        onChange={(e) => {
                          if (e.target.checked) {
                            setSelectedProductIds((prev) => [...new Set([...prev, product.id])]);
                          } else {
                            setSelectedProductIds((prev) => prev.filter((id) => id !== product.id));
                          }
                        }}
                      />
                    </td>
                  )}
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center gap-3">
                      {product.imagePath || product.imageLink || product.categoryImageLink || product.categoryImagePath ? (
                        <img src={getImageUrl(product.imagePath || product.imageLink || product.categoryImageLink || product.categoryImagePath)} alt={product.name} className="w-10 h-10 rounded-lg object-cover bg-gray-50 border border-gray-100" />
                      ) : (
                        <div className="w-10 h-10 rounded-lg bg-gray-50 flex items-center justify-center border border-gray-100">
                          <Package size={20} className="text-gray-300" />
                        </div>
                      )}
                      <div>
                        <div className="text-sm font-bold text-gray-900">{tp(product.name)}</div>
                        {product.categoryName && (
                          <div className="text-[10px] font-bold text-primary-600 bg-primary-50 px-1.5 py-0.5 rounded inline-block mt-1 uppercase tracking-wider">
                            {product.categoryName}
                          </div>
                        )}
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-xs font-bold text-gray-400 uppercase tracking-widest">{product.partNumber}</td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-xs text-gray-400 line-through">₹{product.mrp}</div>
                    <div className="text-sm font-black text-primary-700">₹{product.sellingPrice}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-center">
                    <span className={`px-3 py-1 rounded-lg text-xs font-black ${
                      product.stock < 10 ? 'bg-red-100 text-red-700' : 'bg-gray-100 text-gray-700'
                    }`}>
                      {product.stock}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-center">
                    <div className="flex items-center justify-center gap-2">
                      <button 
                        onClick={() => { setEditingProduct(product); setShowEditProduct(true); }}
                        className="px-3 py-1.5 bg-gray-50 text-primary-600 rounded-lg text-xs font-bold hover:bg-primary-100 transition"
                      >
                        Edit
                      </button>
                      <button 
                        onClick={async () => {
                          if (!window.confirm(`Delete product ${product.name}?`)) return;
                          try {
                            await api.delete(`/products/${product.id}`);
                            fetchProducts();
                          } catch (err) {
                            console.error(err);
                            alert('Failed to delete product');
                          }
                        }}
                        className="p-1.5 bg-red-50 text-red-600 rounded-lg hover:bg-red-100 transition"
                        title="Delete Product"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          
          {/* Pagination Controls */}
          {pagination.totalPages > 1 && (
            <div className="px-6 py-4 bg-gray-50/50 border-t border-gray-100 flex items-center justify-between">
              <div className="text-xs font-bold text-gray-500 uppercase tracking-wider">
                Showing {products.length} of {pagination.totalElements} products
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => fetchProducts(pagination.pageNumber - 1)}
                  disabled={pagination.pageNumber === 0}
                  className="px-4 py-2 bg-white border border-gray-200 rounded-lg text-xs font-bold text-gray-600 hover:bg-gray-50 disabled:opacity-50 transition shadow-sm"
                >
                  Previous
                </button>
                <div className="flex items-center gap-1">
                  {[...Array(pagination.totalPages)].map((_, i) => (
                    <button
                      key={i}
                      onClick={() => fetchProducts(i)}
                      className={`w-8 h-8 rounded-lg text-xs font-bold transition ${
                        pagination.pageNumber === i 
                          ? 'bg-primary-600 text-white shadow-md' 
                          : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
                      }`}
                    >
                      {i + 1}
                    </button>
                  ))}
                </div>
                <button
                  onClick={() => fetchProducts(pagination.pageNumber + 1)}
                  disabled={pagination.last}
                  className="px-4 py-2 bg-white border border-gray-200 rounded-lg text-xs font-bold text-gray-600 hover:bg-gray-50 disabled:opacity-50 transition shadow-sm"
                >
                  Next
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {activeTab === 'deliveries' && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Order</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Customer</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Address</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Delivery Person</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Action</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {orders
                .filter(o => o.status === 'OUT_FOR_DELIVERY' || o.status === 'DELIVERED')
                .map((order) => (
                <tr key={order.id}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">#{order.id}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{order.customerName}</td>
                  <td className="px-6 py-4 text-sm text-gray-500 max-w-xs truncate">{order.customerAddress || 'N/A'}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-700 font-semibold">{order.deliveredByName || 'Not assigned'}</td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`px-2 py-1 text-xs font-semibold rounded-full ${
                      order.status === 'OUT_FOR_DELIVERY' ? 'bg-blue-100 text-blue-800' : 'bg-green-100 text-green-800'
                    }`}>
                      {order.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    {order.status === 'OUT_FOR_DELIVERY' && (
                      <button
                        onClick={() => updateOrderStatus(order.id, 'DELIVERED')}
                        className="text-green-600 hover:text-green-900 flex items-center"
                      >
                        <CheckCircle size={18} className="mr-1" />
                        <span>Mark Delivered</span>
                      </button>
                    )}
                  </td>
                </tr>
              ))}
              {orders.filter(o => o.status === 'OUT_FOR_DELIVERY' || o.status === 'DELIVERED').length === 0 && (
                    <tr>
                      <td colSpan={6} className="px-6 py-10 text-center text-gray-500">No active or completed deliveries found.</td>
                    </tr>
                  )}
            </tbody>
          </table>
        </div>
      )}

      {activeTab === 'recycle' && (
        <div className="space-y-8">
          {/* Deleted Users */}
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-100 bg-gray-50/50">
              <h3 className="text-lg font-black text-gray-900 flex items-center gap-2">
                <Users size={20} className="text-primary-600" />
                Deleted Users
              </h3>
            </div>
            <div className="max-h-[28rem] overflow-y-auto">
              <table className="min-w-full divide-y divide-gray-100">
                <thead className="bg-gray-50/30">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">User</th>
                    <th className="px-6 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Role</th>
                    <th className="px-6 py-3 text-center text-xs font-bold text-gray-500 uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-100">
                  {deletedUsers.length > 0 ? deletedUsers.map((user) => (
                    <tr key={user.id} className="hover:bg-gray-50/50 transition">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="font-bold text-gray-900">{user.name}</div>
                        <div className="text-xs text-gray-500">{user.email}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className="text-xs font-bold text-gray-600">{user.role?.name || user.role}</span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-center">
                        <div className="flex items-center justify-center gap-2">
                          <button
                            onClick={() => restoreUser(user.id)}
                            className="p-2 bg-blue-50 text-blue-600 rounded-lg hover:bg-blue-100 transition flex items-center gap-2 text-xs font-bold"
                          >
                            <RotateCcw size={16} />
                            Restore
                          </button>
                          <button
                            onClick={() => permanentDeleteUser(user.id)}
                            className="p-2 bg-red-50 text-red-600 rounded-lg hover:bg-red-100 transition flex items-center gap-2 text-xs font-bold"
                          >
                            <Trash2 size={16} />
                            Delete Permanent
                          </button>
                        </div>
                      </td>
                    </tr>
                  )) : (
                    <tr>
                      <td colSpan={3} className="px-6 py-10 text-center text-gray-400 text-sm font-medium">No deleted users found</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Deleted Products */}
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-100 bg-gray-50/50 flex justify-between items-center">
              <h3 className="text-lg font-black text-gray-900 flex items-center gap-2">
                <Package size={20} className="text-primary-600" />
                Deleted Products
              </h3>
              {deletedProducts.length > 0 && (
                <button
                  onClick={handleEmptyRecycleBin}
                  className="px-4 py-2 bg-red-600 text-white rounded-xl hover:bg-red-700 transition shadow-lg shadow-red-100 font-bold text-xs flex items-center gap-2"
                >
                  <Trash2 size={16} />
                  Empty Recycle Bin
                </button>
              )}
            </div>
            <div className="max-h-[28rem] overflow-y-auto">
              <table className="min-w-full divide-y divide-gray-100">
                <thead className="bg-gray-50/30">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Product</th>
                    <th className="px-6 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Part Number</th>
                    <th className="px-6 py-3 text-center text-xs font-bold text-gray-500 uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-100">
                  {deletedProducts.length > 0 ? deletedProducts.map((product) => (
                    <tr key={product.id} className="hover:bg-gray-50/50 transition">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="font-bold text-gray-900">{product.name}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className="text-xs font-bold text-gray-400 uppercase tracking-widest">{product.partNumber}</span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-center">
                        <div className="flex items-center justify-center gap-2">
                          <button
                            onClick={() => restoreProduct(product.id)}
                            className="p-2 bg-blue-50 text-blue-600 rounded-lg hover:bg-blue-100 transition flex items-center gap-2 text-xs font-bold"
                          >
                            <RotateCcw size={16} />
                            Restore
                          </button>
                          <button
                            onClick={() => permanentDeleteProduct(product.id)}
                            className="p-2 bg-red-50 text-red-600 rounded-lg hover:bg-red-100 transition flex items-center gap-2 text-xs font-bold"
                          >
                            <Trash2 size={16} />
                            Delete Permanent
                          </button>
                        </div>
                      </td>
                    </tr>
                  )) : (
                    <tr>
                      <td colSpan={3} className="px-6 py-10 text-center text-gray-400 text-sm font-medium">No deleted products found</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Deleted Orders */}
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-100 bg-gray-50/50">
              <h3 className="text-lg font-black text-gray-900 flex items-center gap-2">
                <ShoppingBag size={20} className="text-primary-600" />
                Deleted Orders
              </h3>
            </div>
            <div className="max-h-[28rem] overflow-y-auto">
              <table className="min-w-full divide-y divide-gray-100">
                <thead className="bg-gray-50/30">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Order ID</th>
                    <th className="px-6 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Customer</th>
                    <th className="px-6 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Amount</th>
                    <th className="px-6 py-3 text-center text-xs font-bold text-gray-500 uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-100">
                  {deletedOrders.length > 0 ? deletedOrders.map((order) => (
                    <tr key={order.id} className="hover:bg-gray-50/50 transition">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className="text-xs font-black text-primary-700 bg-primary-50 px-2 py-1 rounded-md">#{order.id}</span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-bold text-gray-900">{order.customerName}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-black text-gray-900">₹{order.totalAmount.toLocaleString()}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-center">
                        <div className="flex items-center justify-center gap-2">
                          <button
                            onClick={() => restoreOrder(order.id)}
                            className="p-2 bg-blue-50 text-blue-600 rounded-lg hover:bg-blue-100 transition flex items-center gap-2 text-xs font-bold"
                          >
                            <RotateCcw size={16} />
                            Restore
                          </button>
                          <button
                            onClick={() => permanentDeleteOrder(order.id)}
                            className="p-2 bg-red-50 text-red-600 rounded-lg hover:bg-red-100 transition flex items-center gap-2 text-xs font-bold"
                          >
                            <Trash2 size={16} />
                            Delete Permanent
                          </button>
                        </div>
                      </td>
                    </tr>
                  )) : (
                    <tr>
                      <td colSpan={4} className="px-6 py-10 text-center text-gray-400 text-sm font-medium">No deleted orders found</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {activeTab === 'categories' && (
        <div className="space-y-6">
          <div className="flex justify-between items-center">
            <h3 className="text-lg font-black text-gray-900">Manage Categories</h3>
            <button
              onClick={() => setShowAddCategory(true)}
              className="bg-primary-600 text-white px-4 py-2 rounded-lg hover:bg-primary-700 font-bold text-sm transition"
            >
              Add Category
            </button>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {categories.map((category: any) => (
              <div key={category.id} className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden group">
                <div className="h-40 bg-gray-50 relative overflow-hidden">
                  {category.imageLink || category.imagePath ? (
                    <img src={getImageUrl(category.imageLink || category.imagePath)} alt={category.name} className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-gray-300">
                      <Package size={48} />
                    </div>
                  )}
                  <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-all flex items-center justify-center">
                    <button 
                      onClick={() => { setEditingCategory(category); setShowEditCategory(true); }}
                      className="bg-white text-gray-900 px-4 py-2 rounded-lg font-bold text-xs opacity-0 group-hover:opacity-100 transition-all transform translate-y-4 group-hover:translate-y-0"
                    >
                      Edit Category
                    </button>
                  </div>
                </div>
                <div className="p-4">
                  <h4 className="font-black text-gray-900 text-lg">{category.name}</h4>
                  <p className="text-gray-500 text-sm font-medium mt-1 line-clamp-2">{category.description || 'No description provided'}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {activeTab === 'settings' && (
        <div className="max-w-4xl mx-auto space-y-8">
          <div className="bg-white rounded-3xl shadow-xl shadow-gray-100/50 border border-gray-100 overflow-hidden">
            <div className="px-8 py-6 border-b border-gray-100 bg-gray-50/50">
              <h2 className="text-xl font-black text-gray-900 flex items-center gap-3">
                <Bell size={24} className="text-primary-600" />
                Notification Preferences
              </h2>
              <p className="text-gray-500 text-sm mt-1 font-medium">Choose how users get notified about new products.</p>
            </div>
            
            <div className="p-8 space-y-6">
              <div className="flex items-center justify-between p-6 bg-gray-50 rounded-2xl border border-gray-100 group hover:border-primary-200 transition-all">
                <div className="flex items-center gap-4">
                  <div className="p-3 bg-white rounded-xl shadow-sm text-primary-600 group-hover:scale-110 transition-transform">
                    <Bell size={24} />
                  </div>
                  <div>
                    <h3 className="font-bold text-gray-900">In-App Notifications</h3>
                    <p className="text-sm text-gray-500 font-medium">Show real-time alerts in the notification bar.</p>
                  </div>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input 
                    type="checkbox" 
                    className="sr-only peer" 
                    checked={getSetting('NOTIF_IN_APP_ENABLED', 'true') === 'true'}
                    onChange={(e) => updateSetting('NOTIF_IN_APP_ENABLED', e.target.checked ? 'true' : 'false')}
                  />
                  <div className="w-14 h-7 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[4px] after:left-[4px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary-600"></div>
                </label>
              </div>

              <div className="flex items-center justify-between p-6 bg-gray-50 rounded-2xl border border-gray-100 group hover:border-green-200 transition-all">
                <div className="flex items-center gap-4">
                  <div className="p-3 bg-white rounded-xl shadow-sm text-green-600 group-hover:scale-110 transition-transform">
                    <MessageSquare size={24} />
                  </div>
                  <div>
                    <h3 className="font-bold text-gray-900">WhatsApp Alerts</h3>
                    <p className="text-sm text-gray-500 font-medium">Send automatic WhatsApp messages to registered users.</p>
                  </div>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input 
                    type="checkbox" 
                    className="sr-only peer" 
                    checked={getSetting('NOTIF_WHATSAPP_ENABLED', 'false') === 'true'}
                    onChange={(e) => updateSetting('NOTIF_WHATSAPP_ENABLED', e.target.checked ? 'true' : 'false')}
                  />
                  <div className="w-14 h-7 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[4px] after:left-[4px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-green-600"></div>
                </label>
              </div>
            </div>
            
            <div className="px-8 py-4 bg-gray-50 border-t border-gray-100 flex items-center justify-between">
              <span className="text-xs font-bold text-gray-400 uppercase tracking-widest">
                {savingSettings ? 'Saving changes...' : 'All changes saved automatically'}
              </span>
              {savingSettings && (
                <div className="w-4 h-4 border-2 border-primary-200 border-t-primary-600 rounded-full animate-spin" />
              )}
            </div>
          </div>
        </div>
      )}

      {/* Modals for Adding User/Product/Order */}
      {showAddUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl max-w-md w-full p-6 shadow-2xl">
            <h3 className="text-xl font-bold mb-4">Create User Profile</h3>
            <form onSubmit={handleAddUser} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Full Name</label>
                <input
                  type="text"
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                  value={newUser.name}
                  onChange={e => setNewUser({...newUser, name: e.target.value})}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Email</label>
                <input
                  type="email"
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                  value={newUser.email}
                  onChange={e => setNewUser({...newUser, email: e.target.value})}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Password</label>
                <input
                  type="password"
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                  value={newUser.password}
                  onChange={e => setNewUser({...newUser, password: e.target.value})}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Role</label>
                <select
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                  value={newUser.role}
                  onChange={e => setNewUser({...newUser, role: e.target.value})}
                >
                  <option value={ROLE_MECHANIC}>Mechanic</option>
                  <option value={ROLE_RETAILER}>Retailer</option>
                  <option value={ROLE_WHOLESALER}>Wholesaler</option>
                  <option value={ROLE_STAFF}>Staff</option>
                  <option value={ROLE_SUPER_MANAGER}>Super Manager</option>
                  <option value={ROLE_ADMIN}>Admin</option>
                </select>
              </div>
              <div className="flex justify-end space-x-3 mt-6">
                <button type="button" onClick={() => setShowAddUser(false)} className="px-4 py-2 text-gray-600 hover:text-gray-800 font-medium">Cancel</button>
                <button type="submit" className="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 font-medium transition">Create Profile</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {showAddProduct && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl max-w-md w-full p-6 shadow-2xl">
            <h3 className="text-xl font-bold mb-4">Add New Product</h3>
            <form onSubmit={handleAddProduct} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Product Name</label>
                <input
                  type="text"
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                  value={newProduct.name}
                  onChange={e => setNewProduct({...newProduct, name: e.target.value})}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Part Number</label>
                <input
                  type="text"
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                  value={newProduct.partNumber}
                  onChange={e => setNewProduct({...newProduct, partNumber: e.target.value})}
                  required
                />
              </div>
              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">MRP</label>
                  <input
                    type="number"
                    className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                    value={newProduct.mrp}
                    onChange={e => setNewProduct({...newProduct, mrp: e.target.value})}
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">Selling Price</label>
                  <input
                    type="number"
                    className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                    value={newProduct.sellingPrice}
                    onChange={e => setNewProduct({...newProduct, sellingPrice: e.target.value})}
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">Initial Stock</label>
                  <input
                    type="number"
                    className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                    value={newProduct.stock}
                    onChange={e => setNewProduct({...newProduct, stock: e.target.value})}
                    required
                  />
                </div>
              </div>
              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider">Wholesaler Price</label>
                  <input
                    type="number"
                    className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none text-sm"
                    value={newProduct.wholesalerPrice}
                    onChange={e => setNewProduct({...newProduct, wholesalerPrice: e.target.value})}
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider">Retailer Price</label>
                  <input
                    type="number"
                    className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none text-sm"
                    value={newProduct.retailerPrice}
                    onChange={e => setNewProduct({...newProduct, retailerPrice: e.target.value})}
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider">Mechanic Price</label>
                  <input
                    type="number"
                    className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none text-sm"
                    value={newProduct.mechanicPrice}
                    onChange={e => setNewProduct({...newProduct, mechanicPrice: e.target.value})}
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Product Image</label>
                <div className="mt-1 flex items-center space-x-4">
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleImageUpload}
                    className="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-primary-50 file:text-primary-700 hover:file:bg-primary-100"
                    disabled={uploading}
                  />
                  {uploading && <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-primary-600"></div>}
                </div>
                {newProduct.imagePath && <p className="text-xs text-green-600 mt-1">Image uploaded!</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Product Image URL (Optional)</label>
                <input
                  type="text"
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                  value={newProduct.imagePath || ''}
                  onChange={e => setNewProduct({...newProduct, imagePath: e.target.value})}
                  placeholder="https://example.com/image.jpg"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Description</label>
                <textarea
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                  rows={3}
                  value={newProduct.description}
                  onChange={e => setNewProduct({...newProduct, description: e.target.value})}
                  placeholder="Enter product description..."
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Category</label>
                <select
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                  value={newProduct.categoryId}
                  onChange={e => setNewProduct({ ...newProduct, categoryId: e.target.value })}
                >
                  <option value="">Select category</option>
                  {categories.map((c: any) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
              </div>
              <div className="flex justify-end space-x-3 mt-6">
                <button type="button" onClick={() => setShowAddProduct(false)} className="px-4 py-2 text-gray-600 hover:text-gray-800 font-medium">Cancel</button>
                <button type="submit" className="bg-primary-600 text-white px-4 py-2 rounded-lg hover:bg-primary-700 font-medium transition">Add Product</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {showEditProduct && editingProduct && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl max-w-md w-full p-6 shadow-2xl">
            <h3 className="text-xl font-bold mb-4">Edit Product</h3>
            <form onSubmit={handleUpdateProduct} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Product Name</label>
                <input
                  type="text"
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                  value={editingProduct.name}
                  onChange={e => setEditingProduct({...editingProduct, name: e.target.value})}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Part Number</label>
                <input
                  type="text"
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                  value={editingProduct.partNumber}
                  onChange={e => setEditingProduct({...editingProduct, partNumber: e.target.value})}
                  required
                />
              </div>
              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">MRP</label>
                  <input
                    type="number"
                    className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                    value={editingProduct.mrp}
                    onChange={e => setEditingProduct({...editingProduct, mrp: e.target.value})}
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">Selling Price</label>
                  <input
                    type="number"
                    className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                    value={editingProduct.sellingPrice}
                    onChange={e => setEditingProduct({...editingProduct, sellingPrice: e.target.value})}
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">Stock</label>
                  <input
                    type="number"
                    className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                    value={editingProduct.stock}
                    onChange={e => setEditingProduct({...editingProduct, stock: e.target.value})}
                    required
                  />
                </div>
              </div>
              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider">Wholesaler Price</label>
                  <input
                    type="number"
                    className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none text-sm"
                    value={editingProduct.wholesalerPrice || ''}
                    onChange={e => setEditingProduct({...editingProduct, wholesalerPrice: e.target.value})}
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider">Retailer Price</label>
                  <input
                    type="number"
                    className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none text-sm"
                    value={editingProduct.retailerPrice || ''}
                    onChange={e => setEditingProduct({...editingProduct, retailerPrice: e.target.value})}
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider">Mechanic Price</label>
                  <input
                    type="number"
                    className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none text-sm"
                    value={editingProduct.mechanicPrice || ''}
                    onChange={e => setEditingProduct({...editingProduct, mechanicPrice: e.target.value})}
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Product Image</label>
                <div className="mt-1 flex items-center space-x-4">
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleEditImageUpload}
                    className="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-primary-50 file:text-primary-700 hover:file:bg-primary-100"
                    disabled={uploading}
                  />
                  {uploading && <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-primary-600"></div>}
                </div>
                {editingProduct.imagePath && <p className="text-xs text-green-600 mt-1">Image uploaded!</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Product Image URL (Optional)</label>
                <input
                  type="text"
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                  value={editingProduct.imagePath || ''}
                  onChange={e => setEditingProduct({...editingProduct, imagePath: e.target.value})}
                  placeholder="https://example.com/image.jpg"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Description</label>
                <textarea
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                  rows={3}
                  value={editingProduct.description || ''}
                  onChange={e => setEditingProduct({...editingProduct, description: e.target.value})}
                  placeholder="Enter product description..."
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Category</label>
                <select
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                  value={editingProduct.categoryId || ''}
                  onChange={e => setEditingProduct({ ...editingProduct, categoryId: e.target.value })}
                >
                  <option value="">Select category</option>
                  {categories.map((c: any) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
              </div>
              <div className="flex justify-end space-x-3 mt-6">
                <button type="button" onClick={() => { setShowEditProduct(false); setEditingProduct(null); }} className="px-4 py-2 text-gray-600 hover:text-gray-800 font-medium">Cancel</button>
                <button type="submit" className="bg-primary-600 text-white px-4 py-2 rounded-lg hover:bg-primary-700 font-medium transition">Update Product</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {showEditOrder && editingOrder && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl p-6 w-full max-w-2xl shadow-xl">
            <h3 className="text-xl font-bold mb-4">Edit Order #{editingOrder.id}</h3>
            <div className="max-h-96 overflow-y-auto mb-6">
              <table className="min-w-full divide-y divide-gray-200">
                <thead>
                  <tr>
                    <th className="text-left py-2">Item</th>
                    <th className="text-center py-2">Qty</th>
                    <th className="text-right py-2">Price</th>
                    <th className="text-right py-2">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {editingOrder.items.map((item: any, idx: number) => (
                    <tr key={idx}>
                      <td className="py-2">{tp(item.productName)}</td>
                      <td className="py-2 text-center">
                        <div className="flex items-center justify-center space-x-2">
                          <button 
                            onClick={() => {
                              const newItems = [...editingOrder.items];
                              if (newItems[idx].quantity > 1) {
                                newItems[idx].quantity--;
                                setEditingOrder({ ...editingOrder, items: newItems });
                              }
                            }}
                            className="w-8 h-8 rounded-full bg-gray-100 flex items-center justify-center font-bold hover:bg-gray-200 transition"
                          >-</button>
                          <span>{item.quantity}</span>
                          <button 
                            onClick={() => {
                              const newItems = [...editingOrder.items];
                              newItems[idx].quantity++;
                              setEditingOrder({ ...editingOrder, items: newItems });
                            }}
                            className="w-8 h-8 rounded-full bg-gray-100 flex items-center justify-center font-bold hover:bg-gray-200 transition"
                          >+</button>
                        </div>
                      </td>
                      <td className="py-2 text-right">₹{item.price}</td>
                      <td className="py-2 text-right">
                        <button 
                          onClick={() => {
                            const newItems = editingOrder.items.filter((_: any, i: number) => i !== idx);
                            setEditingOrder({ ...editingOrder, items: newItems });
                          }}
                          className="text-red-600"
                        >Remove</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="flex justify-between items-center border-t pt-4">
              <p className="text-lg font-bold">
                Total: ₹{editingOrder.items.reduce((acc: any, item: any) => acc + (item.price * item.quantity), 0).toFixed(2)}
              </p>
              <div className="flex space-x-3">
                <button 
                  onClick={() => { setShowEditOrder(false); setEditingOrder(null); }}
                  className="px-4 py-2 bg-gray-100 rounded-lg transition hover:bg-gray-200 font-bold"
                >Cancel</button>
                <button 
                  onClick={() => handleEditOrder(editingOrder.id, editingOrder.items)}
                  className="px-4 py-2 bg-primary-600 text-white rounded-lg transition hover:bg-primary-700 font-bold shadow-lg shadow-primary-100"
                >Save Changes</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {showAddCategory && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl max-w-md w-full p-8 shadow-2xl">
            <h3 className="text-2xl font-black text-gray-900 mb-6">Create New Category</h3>
            <form onSubmit={handleAddCategory} className="space-y-6">
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2 uppercase tracking-wider">Category Name</label>
                <input
                  type="text"
                  className="w-full border border-gray-200 rounded-xl p-3 focus:ring-2 focus:ring-primary-500 outline-none transition"
                  value={newCategory.name}
                  onChange={e => setNewCategory({...newCategory, name: e.target.value})}
                  required
                  placeholder="e.g. Engine Parts"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2 uppercase tracking-wider">Description</label>
                <textarea
                  className="w-full border border-gray-200 rounded-xl p-3 focus:ring-2 focus:ring-primary-500 outline-none transition"
                  rows={3}
                  value={newCategory.description}
                  onChange={e => setNewCategory({...newCategory, description: e.target.value})}
                  placeholder="What kind of parts are in this category?"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2 uppercase tracking-wider">Parent Category</label>
                <select
                  className="w-full border border-gray-200 rounded-xl p-3 focus:ring-2 focus:ring-primary-500 outline-none transition bg-white"
                  value={newCategory.parentId}
                  onChange={e => setNewCategory({...newCategory, parentId: e.target.value})}
                >
                  <option value="">None (Root Category)</option>
                  {categories.map((c: any) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2 uppercase tracking-wider">Category Image</label>
                <div className="mt-2 flex flex-col items-center p-6 border-2 border-dashed border-gray-200 rounded-2xl hover:border-primary-500 transition cursor-pointer relative group">
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleCategoryImageUpload}
                    className="absolute inset-0 opacity-0 cursor-pointer z-10"
                    disabled={uploading}
                  />
                  {newCategory.imageLink || newCategory.imagePath ? (
                    <img src={getImageUrl(newCategory.imageLink || newCategory.imagePath)} alt="Preview" className="w-full h-32 object-cover rounded-xl" />
                  ) : (
                    <>
                      <Upload className="text-gray-400 mb-2 group-hover:text-primary-500 transition" size={32} />
                      <span className="text-sm text-gray-500 font-medium">Click to upload category image</span>
                    </>
                  )}
                  {uploading && (
                    <div className="absolute inset-0 bg-white/80 flex items-center justify-center rounded-2xl z-20">
                      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
                    </div>
                  )}
                </div>
                <p className="text-[10px] text-gray-400 mt-2 text-center font-bold uppercase tracking-widest">This image will be used for all products in this category</p>
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2 uppercase tracking-wider">OR Image Link (External URL)</label>
                <input
                  type="url"
                  className="w-full border border-gray-200 rounded-xl p-3 focus:ring-2 focus:ring-primary-500 outline-none transition"
                  value={newCategory.imageLink}
                  onChange={e => setNewCategory({...newCategory, imageLink: e.target.value})}
                  placeholder="https://example.com/image.jpg"
                />
              </div>
              <div className="flex justify-end gap-3 pt-4">
                <button type="button" onClick={() => setShowAddCategory(false)} className="px-6 py-2 text-gray-500 hover:text-gray-700 font-bold transition">Cancel</button>
                <button type="submit" className="bg-primary-600 text-white px-8 py-2 rounded-xl hover:bg-primary-700 font-black shadow-lg shadow-primary-100 transition">Create Category</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {showEditCategory && editingCategory && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl max-w-md w-full p-8 shadow-2xl">
            <h3 className="text-2xl font-black text-gray-900 mb-6">Edit Category</h3>
            <form onSubmit={handleEditCategory} className="space-y-6">
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2 uppercase tracking-wider">Category Name</label>
                <input
                  type="text"
                  className="w-full border border-gray-200 rounded-xl p-3 focus:ring-2 focus:ring-primary-500 outline-none transition"
                  value={editingCategory.name}
                  onChange={e => setEditingCategory({...editingCategory, name: e.target.value})}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2 uppercase tracking-wider">Description</label>
                <textarea
                  className="w-full border border-gray-200 rounded-xl p-3 focus:ring-2 focus:ring-primary-500 outline-none transition"
                  rows={3}
                  value={editingCategory.description || ''}
                  onChange={e => setEditingCategory({...editingCategory, description: e.target.value})}
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2 uppercase tracking-wider">Parent Category</label>
                <select
                  className="w-full border border-gray-200 rounded-xl p-3 focus:ring-2 focus:ring-primary-500 outline-none transition bg-white"
                  value={editingCategory.parentId || ''}
                  onChange={e => setEditingCategory({...editingCategory, parentId: e.target.value})}
                >
                  <option value="">None (Root Category)</option>
                  {categories.filter(c => c.id !== editingCategory.id).map((c: any) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2 uppercase tracking-wider">Category Image</label>
                <div className="mt-2 flex flex-col items-center p-6 border-2 border-dashed border-gray-200 rounded-2xl hover:border-primary-500 transition cursor-pointer relative group">
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleEditCategoryImageUpload}
                    className="absolute inset-0 opacity-0 cursor-pointer z-10"
                    disabled={uploading}
                  />
                  {editingCategory.imageLink || editingCategory.imagePath ? (
                    <img src={getImageUrl(editingCategory.imageLink || editingCategory.imagePath)} alt="Preview" className="w-full h-32 object-cover rounded-xl" />
                  ) : (
                    <>
                      <Upload className="text-gray-400 mb-2 group-hover:text-primary-500 transition" size={32} />
                      <span className="text-sm text-gray-500 font-medium">Click to upload category image</span>
                    </>
                  )}
                  {uploading && (
                    <div className="absolute inset-0 bg-white/80 flex items-center justify-center rounded-2xl z-20">
                      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
                    </div>
                  )}
                </div>
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2 uppercase tracking-wider">OR Image Link (External URL)</label>
                <input
                  type="url"
                  className="w-full border border-gray-200 rounded-xl p-3 focus:ring-2 focus:ring-primary-500 outline-none transition"
                  value={editingCategory.imageLink || ''}
                  onChange={e => setEditingCategory({...editingCategory, imageLink: e.target.value})}
                  placeholder="https://example.com/image.jpg"
                />
              </div>
              <div className="flex justify-end gap-3 pt-4">
                <button type="button" onClick={() => setShowEditCategory(false)} className="px-6 py-2 text-gray-500 hover:text-gray-700 font-bold transition">Cancel</button>
                <button type="submit" className="bg-primary-600 text-white px-8 py-2 rounded-xl hover:bg-primary-700 font-black shadow-lg shadow-primary-100 transition">Save Changes</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default AdminDashboard;
