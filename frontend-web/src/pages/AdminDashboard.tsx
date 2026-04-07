
import React, { useState, useEffect, useCallback, useMemo } from 'react';
import api, { API_BASE_URL } from '../services/api';
import { Link } from 'react-router-dom';
import { useLanguage } from '../context/LanguageContext';
import { Users, ShoppingBag, BarChart2, CheckCircle, XCircle, Plus, Package, UserPlus, Upload, Truck, Trash2, RotateCcw, Settings, Bell, MessageSquare, Search, Star, FileText, List, LayoutGrid, Store, ScanBarcode, Keyboard } from 'lucide-react';
import { ROLE_SUPER_MANAGER, ROLE_ADMIN, ROLE_MECHANIC, ROLE_RETAILER, ROLE_WHOLESALER, ROLE_STAFF } from '../services/constants';
import AuthService from '../services/auth.service';
import Skeleton from '../components/Skeleton';
import BarcodeScanner from '../components/BarcodeScanner';
import { useExternalScanner } from '../hooks/useExternalScanner';
import useSound from 'use-sound';
import SockJS from 'sockjs-client';
import Stomp from 'stompjs';

const AdminDashboard = () => {
  const { tp } = useLanguage();
  const currentUser = AuthService.getCurrentUser();
  const isSuperManager = currentUser?.roles?.includes(ROLE_SUPER_MANAGER);

  if (!currentUser) {
    window.location.href = '/login';
    return null;
  }

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
  const [editingDiscountPercent, setEditingDiscountPercent] = useState('0');
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
    categoryId: '',
    discountPercent: '0'
  });
  const [uploading, setUploading] = useState(false);
  const [categories, setCategories] = useState<any[]>([]);
  const [showAddCategory, setShowAddCategory] = useState(false);
  const [showEditCategory, setShowEditCategory] = useState(false);
  const [editingCategory, setEditingCategory] = useState<any>(null);
  const [salesReport, setSalesReport] = useState<{ totalSales: number; totalOrders: number } | null>(null);
  const [salesPeriod, setSalesPeriod] = useState<'DAILY'|'WEEKLY'|'MONTHLY'>('MONTHLY');
  const [newCategory, setNewCategory] = useState({ name: '', description: '', imagePath: '', imageLink: '' });
  const [selectedExcelCategory, setSelectedExcelCategory] = useState<string>('');

  const [deletedUsers, setDeletedUsers] = useState<any[]>([]);
  const [deletedOrders, setDeletedOrders] = useState<any[]>([]);
  const [deletedProducts, setDeletedProducts] = useState<any[]>([]);

  const [settings, setSettings] = useState<any[]>([]);
  const [localSettings, setLocalSettings] = useState<any[]>([]);
  const [savingSettings, setSavingSettings] = useState(false);

  const [showAddUser, setShowAddUser] = useState(false);
  const [newUser, setNewUser] = useState({
    name: '',
    email: '',
    password: '',
    role: ROLE_MECHANIC,
    phone: '',
    address: '',
    latitude: '',
    longitude: ''
  });

  const [productSelectionMode, setProductSelectionMode] = useState(false);
  const [selectedProductIds, setSelectedProductIds] = useState<number[]>([]);
  const [userSearchTerm, setUserSearchTerm] = useState('');
  const [productSearchTerm, setProductSearchTerm] = useState('');
  const [cashbackSearchTerm, setCashbackSearchTerm] = useState('');

  const [showPointsDialog, setShowPointsDialog] = useState(false);
  const [pointsUser, setPointsUser] = useState<any>(null);
  const [pointsAmount, setPointsAmount] = useState(0);
  const [pointsOperation, setPointsOperation] = useState('ADD');

  const [showEditUser, setShowEditUser] = useState(false);
  const [editingUserData, setEditingUserData] = useState<any>(null);
  const [editName, setEditName] = useState('');
  const [editEmail, setEditEmail] = useState('');
  const [editPhone, setEditPhone] = useState('');
  const [editAddress, setEditAddress] = useState('');
  const [editStatus, setEditStatus] = useState('ACTIVE');
  const [editPoints, setEditPoints] = useState<number>(0);
  const [editLatitude, setEditLatitude] = useState<number | ''>('');
  const [editLongitude, setEditLongitude] = useState<number | ''>('');

  const [orderRequests, setOrderRequests] = useState<any[]>([]);
  const [fetchingRequests, setFetchingRequests] = useState(false);

  const [billingUser, setBillingUser] = useState<any>(null);
  const [orderListView, setOrderListView] = useState<'list' | 'grid'>('list');
  const [orderQuery, setOrderQuery] = useState('');
  const [billingItems, setBillingItems] = useState<any[]>([]);
  const [billingDiscount, setBillingDiscount] = useState<number>(0);
  const [billingDiscountType, setBillingDiscountType] = useState<'RS' | '%'>('RS');
  const [billingSearchTerm, setBillingSearchTerm] = useState('');
  const [billingSearchResults, setBillingSearchResults] = useState<any[]>([]);
  const [showScanner, setShowScanner] = useState(false);
  const [scannerMode, setScannerMode] = useState<'camera' | 'external'>('camera');

  // Listen for external hardware scanner in Billing section
  useExternalScanner((code) => {
    if (activeTab === 'billing' || activeTab === 'invoicing') {
      handleExternalScan(code);
    }
  });

  const addProductToBill = (product: any) => {
    const existing = billingItems.find(i => i.id === product.id);
    if (existing) {
      setBillingItems(billingItems.map(i => i.id === product.id ? { ...i, quantity: i.quantity + 1 } : i));
    } else {
      setBillingItems([...billingItems, { ...product, quantity: 1 }]);
    }
    setBillingSearchTerm('');
    setBillingSearchResults([]);
  };

  const removeProductFromBill = (productId: number) => {
    setBillingItems((billingItems || []).filter(i => i.id !== productId));
  };

  const updateBillQuantity = (productId: number, qty: number) => {
    if (qty <= 0) {
      removeProductFromBill(productId);
    } else {
      setBillingItems(billingItems.map(i => i.id === productId ? { ...i, quantity: qty } : i));
    }
  };

  const generateInvoice = async () => {
    if (!billingUser || (billingItems || []).length === 0) return;
    try {
      const subtotal = (billingItems || []).reduce((acc, i) => acc + (i.sellingPrice * i.quantity), 0);
      const calculatedDiscount = billingDiscountType === '%' 
        ? (subtotal * (billingDiscount / 100)) 
        : billingDiscount;

      const payload = {
        customerId: billingUser.id,
        sellerId: currentUser.id,
        discountAmount: calculatedDiscount,
        items: billingItems.map(i => ({
          productId: i.id,
          productName: i.name,
          quantity: i.quantity,
          price: i.sellingPrice
        }))
      };
      await api.post(`admin/orders`, payload);
      alert('Invoice generated and reflected in customer orders!');
      setBillingUser(null);
      setBillingItems([]);
      setBillingDiscount(0);
      setBillingDiscountType('RS');
      fetchOrders();
    } catch (err) {
      console.error(err);
      alert('Failed to generate invoice');
    }
  };

  const handleBillSearch = async (term: string) => {
    setBillingSearchTerm(term);
    if (term.length >= 3) { // Increased to 3 for better auto-search performance
      try {
        const res = await api.get(`products/search?query=${term}&page=0&size=10&sortBy=id&direction=desc`);
        setBillingSearchResults(res.data.content || []);
      } catch (err) {
        console.error('Invoicing search error:', err);
        const results = (products || []).filter(p => 
          p.name.toLowerCase().includes(term.toLowerCase()) || 
          p.partNumber.toLowerCase().includes(term.toLowerCase())
        );
        setBillingSearchResults(results.slice(0, 5));
      }
    } else if (term.length === 0) {
      setBillingSearchResults([]);
    }
  };

  const handleExternalScan = async (code: string) => {
    try {
      // First try searching specifically for this code
      const res = await api.get(`products/search?query=${code}&page=0&size=5&sortBy=id&direction=desc`);
      const results = res.data.content || [];
      
      // If we find an exact match for part number, add it directly
      const exactMatch = results.find((p: any) => p.partNumber === code || p.barcode === code);
      if (exactMatch) {
        addProductToBill(exactMatch);
        setBillingSearchTerm('');
        setBillingSearchResults([]);
        return;
      }

      // If only one result, add it
      if (results.length === 1) {
        addProductToBill(results[0]);
        setBillingSearchTerm('');
        setBillingSearchResults([]);
        return;
      }

      // Otherwise just show the search results
      setBillingSearchTerm(code);
      setBillingSearchResults(results);
    } catch (err) {
      console.error('External scan handling error:', err);
      handleBillSearch(code);
    }
  };

  const handleManualBillSearch = async () => {
    if (!billingSearchTerm) return;
    try {
      const res = await api.get(`products/search?query=${billingSearchTerm}&page=0&size=20&sortBy=id&direction=desc`);
      setBillingSearchResults(res.data.content || []);
    } catch (err) {
      console.error('Manual invoicing search error:', err);
    }
  };

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
          fetchSettings(),
          fetchOrderRequests()
        ]);
      } catch (err) {
        console.error("Initial fetch failed:", err);
      } finally {
        setLoading(false);
      }
    };
    init();
  }, []);

  const fetchOrderRequests = async () => {
    try {
      setFetchingRequests(true);
      const res = await api.get('orders/custom-requests');
      setOrderRequests(res.data);
    } catch (err) {
      console.error(err);
    } finally {
      setFetchingRequests(false);
    }
  };

  const updateRequestStatus = async (requestId: number, status: string) => {
    try {
      await api.put(`orders/custom-requests/${requestId}/status?status=${status}`);
      fetchOrderRequests();
    } catch (err) {
      console.error(err);
      alert('Failed to update request status');
    }
  };

  const assignRequestToStaff = async (requestId: number, staffId: number) => {
    try {
      await api.put(`orders/custom-requests/${requestId}/status?status=PROCESSING&staffId=${staffId}`);
      fetchOrderRequests();
    } catch (err) {
      console.error(err);
      alert('Failed to assign staff');
    }
  };

  useEffect(() => {
    const fetchSales = async () => {
      try {
        const res = await api.get(`admin/sales`, { params: { type: salesPeriod } });
        const ts = res.data?.totalSales;
        const to = res.data?.totalOrders;
        setSalesReport({
          totalSales: typeof ts === 'number' ? ts : parseFloat(ts || 0),
          totalOrders: typeof to === 'number' ? to : parseInt(to || 0, 10),
        });
      } catch (err) {
        console.error('Failed to fetch sales report:', err);
      }
    };
    fetchSales();
  }, [salesPeriod]);

  useEffect(() => {
    const delayDebounceFn = setTimeout(() => {
      fetchProducts(0);
    }, 500);

    return () => clearTimeout(delayDebounceFn);
  }, [productSearchTerm]);

  const fetchSettings = async () => {
    try {
      const res = await api.get('admin/settings');
      setSettings(res.data);
      setLocalSettings(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  const updateSettingLocally = (key: string, value: string) => {
    setLocalSettings(prev => {
      const existing = prev.find(s => s.settingKey === key);
      if (existing) {
        return prev.map(s => s.settingKey === key ? { ...s, settingValue: value } : s);
      } else {
        return [...prev, { settingKey: key, settingValue: value }];
      }
    });
  };

  const saveAllSettings = async () => {
    try {
      setSavingSettings(true);
      await api.post('admin/settings/bulk', localSettings);
      setSettings([...localSettings]);
      alert('Settings saved successfully!');
    } catch (err) {
      console.error(err);
      alert('Failed to save settings');
    } finally {
      setSavingSettings(false);
    }
  };

  const getSetting = (key: string, defaultValue: string = 'false') => {
    const s = localSettings.find(s => s.settingKey === key);
    return s ? s.settingValue : defaultValue;
  };

  const fetchDeletedItems = async () => {
    try {
      const usersRes = await api.get('admin/recycle-bin/users');
      setDeletedUsers(usersRes.data);
      const ordersRes = await api.get('admin/recycle-bin/orders');
      setDeletedOrders(ordersRes.data);
      const productsRes = await api.get('admin/recycle-bin/products');
      setDeletedProducts(productsRes.data);
    } catch (err) {
      console.error(err);
    }
  };

  const restoreUser = async (userId: number) => {
    try {
      await api.post(`admin/recycle-bin/users/${userId}/restore`);
      fetchUsers();
      fetchDeletedItems();
    } catch (err) {
      console.error(err);
      alert('Failed to restore user');
    }
  };

  const restoreOrder = async (orderId: number) => {
    try {
      await api.post(`admin/recycle-bin/orders/${orderId}/restore`);
      fetchOrders();
      fetchDeletedItems();
    } catch (err) {
      console.error(err);
      alert('Failed to restore order');
    }
  };

  const restoreProduct = async (productId: number) => {
    try {
      await api.post(`admin/recycle-bin/products/${productId}/restore`);
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
      await api.delete(`admin/recycle-bin/users/${userId}/permanent`);
      fetchDeletedItems();
    } catch (err) {
      console.error(err);
      alert('Failed to permanently delete user');
    }
  };

  const permanentDeleteOrder = async (orderId: number) => {
    if (!window.confirm('Are you sure you want to permanently delete this order? This cannot be undone.')) return;
    try {
      await api.delete(`admin/recycle-bin/orders/${orderId}/permanent`);
      fetchDeletedItems();
    } catch (err) {
      console.error(err);
      alert('Failed to permanently delete order');
    }
  };

  const permanentDeleteProduct = async (productId: number) => {
    if (!window.confirm('Are you sure you want to permanently delete this product? This cannot be undone.')) return;
    try {
      await api.delete(`admin/recycle-bin/products/${productId}/permanent`);
      fetchDeletedItems();
    } catch (err) {
      console.error(err);
      alert('Failed to permanently delete product');
    }
  };

  const handleEmptyRecycleBin = async () => {
    if (!window.confirm('Are you sure you want to empty the Recycle Bin? All deleted products will be permanently removed. This action cannot be undone.')) return;
    try {
      await api.delete('products/empty-recycle-bin');
      fetchDeletedItems();
      alert('Recycle bin emptied successfully');
    } catch (err) {
      console.error(err);
      alert('Failed to empty recycle bin');
    }
  };

  const fetchUsers = async () => {
    try {
      const res = await api.get('admin/users');
      setUsers(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  const fetchOrders = useCallback(async () => {
    try {
      const res = await api.get('admin/orders');
      setOrders(res.data);
    } catch (err) {
      console.error(err);
    }
  }, []);

  useEffect(() => {
    // WebSocket setup for new orders and notifications
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
      stompClient.debug = () => {}; // Disable debug logs
      stompClient.reconnect_delay = 5000; // Auto-reconnect

      stompClient.connect({}, () => {
        console.log('WebSocket connected successfully');
        // 1. Subscribe to admin order updates
        stompClient.subscribe('/topic/admin/orders', () => {
          if (audioEnabled) {
            playNotification();
          }
          fetchOrders();
        });

        // 2. Subscribe to role-specific notifications for the current user
        if (currentUser?.roles) {
          currentUser.roles.forEach((role: string) => {
            stompClient.subscribe(`/topic/notifications/${role}`, (frame: any) => {
              if (frame.body) {
                try {
                  const data = JSON.parse(frame.body);
                  console.log('Received notification for role:', role, data);
                  if (audioEnabled) {
                    playNotification();
                  }
                } catch (e) {
                  console.error('Error parsing role notification:', e);
                }
              }
            });
          });
        }
      }, (error: any) => {
        if (import.meta.env.DEV) {
          console.warn('WebSocket connection error:', error);
        }
        // Try to connect to plain websocket as fallback if sockjs fails
        if (getSocketUrl().startsWith('https')) {
          const wsUrl = getSocketUrl().replace('http', 'ws') + '/websocket';
          console.log('Attempting fallback to plain WS:', wsUrl);
          // Pure WS implementation could be added here if needed
        }
      });
    } catch (e) {
      console.error('Socket initialization error:', e);
    }

    return () => {
      if (stompClient && stompClient.connected) {
        stompClient.disconnect(() => {});
      }
    };
  }, [playNotification, fetchOrders, currentUser?.roles]);

  const fetchCategories = async () => {
    try {
      const res = await api.get('categories');
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
      await api.post('excel/upload', formData, {
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
      const response = await api.get('excel/download', {
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
      const endpoint = productSearchTerm
        ? `products/search?query=${productSearchTerm}&page=${page}&size=10&sortBy=id&direction=desc`
        : `products?page=${page}&size=10&sortBy=id&direction=desc`;
      const res = await api.get(endpoint);
      setProducts(res.data.content || []);
      setPagination({
        pageNumber: res.data.pageNumber || 0,
        pageSize: res.data.pageSize || 10,
        totalElements: res.data.totalElements || 0,
        totalPages: res.data.totalPages || 0,
        last: res.data.last ?? true
      });
    } catch (err) {
      console.error(err);
      setProducts([]);
    }
  };

  const handleEditOrder = async (orderId: number, items: any[]) => {
    try {
      await api.put(`admin/orders/${orderId}/items`, items);
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
      const res = await api.post('files/upload', formData, {
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
      const res = await api.post('products', {
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
      const res = await api.post('files/upload', formData, {
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
      await api.put(`products/${editingProduct.id}`, {
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
      try {
        const res = await api.get('admin/users');
        const created = res.data.find((u: any) => u.email.toLowerCase() === newUser.email.toLowerCase());
        if (created) {
          const payload: any = {};
          if (newUser.latitude) payload.latitude = parseFloat(String(newUser.latitude));
          if (newUser.longitude) payload.longitude = parseFloat(String(newUser.longitude));
          if (Object.keys(payload).length > 0) {
            await api.put(`admin/users/${created.id}/profile`, payload);
          }
        }
      } catch {}
      setShowAddUser(false);
      setNewUser({ name: '', email: '', password: '', role: ROLE_MECHANIC, phone: '', address: '', latitude: '', longitude: '' });
      fetchUsers();
    } catch (err) {
      console.error(err);
      alert('Failed to create user');
    }
  };

  const useBrowserLocation = (onSet: (lat: number, lon: number) => void) => {
    if (!navigator.geolocation) {
      alert('Geolocation not supported by this browser');
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        onSet(pos.coords.latitude, pos.coords.longitude);
      },
      (err) => {
        console.error(err);
        alert('Failed to get current location');
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  };

  const openEditUser = (user: any) => {
    setEditingUserData(user);
    setEditName(user.name || '');
    setEditEmail(user.email || '');
    setEditPhone(user.phone || '');
    setEditAddress(user.address || '');
    setEditStatus(user.status || 'ACTIVE');
    setEditPoints(user.points || 0);
    setEditLatitude(typeof user.latitude === 'number' ? user.latitude : '');
    setEditLongitude(typeof user.longitude === 'number' ? user.longitude : '');
    setShowEditUser(true);
  };

  const saveEditUser = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingUserData) return;
    try {
      const payload: any = {};
      if (editName !== editingUserData.name) payload.name = editName;
      if (editEmail !== editingUserData.email) payload.email = editEmail;
      if (editPhone !== editingUserData.phone) payload.phone = editPhone;
      if (editAddress !== editingUserData.address) payload.address = editAddress;
      if (editStatus !== editingUserData.status) payload.status = editStatus;
      if (editPoints !== (editingUserData.points || 0)) payload.points = editPoints;
      if (editLatitude !== (editingUserData.latitude ?? '')) payload.latitude = editLatitude === '' ? null : editLatitude;
      if (editLongitude !== (editingUserData.longitude ?? '')) payload.longitude = editLongitude === '' ? null : editLongitude;
      await api.put(`admin/users/${editingUserData.id}/profile`, payload);
      setShowEditUser(false);
      setEditingUserData(null);
      fetchUsers();
    } catch (err) {
      console.error(err);
      alert('Failed to update user');
    }
  };

  const [audioEnabled, setAudioEnabled] = useState(false);

  const updateOrderStatus = async (orderId: number, status: string) => {
    try {
      await api.put(`orders/${orderId}/status?status=${status}`);
      fetchOrders();
    } catch (err: any) {
      console.error('Order status update failed:', err);
      const msg = err.response?.data?.message || err.response?.data || 'Failed to update order status';
      alert(typeof msg === 'string' ? msg : JSON.stringify(msg));
    }
  };

  const updateUserStatus = async (userId: number, status: string) => {
    try {
      await api.put(`admin/users/${userId}/status?status=${status}`);
      fetchUsers();
    } catch (err) {
      console.error(err);
    }
  };

  const updateUserRole = async (userId: number, role: string) => {
    try {
      await api.put(`admin/users/${userId}/role?roleName=${role}`);
      fetchUsers();
    } catch (err) {
      console.error(err);
      alert('Failed to update role');
    }
  };

  const deleteUser = async (userId: number) => {
    if (!window.confirm('Are you sure you want to delete this user?')) return;
    try {
      await api.delete(`admin/users/${userId}`);
      fetchUsers();
      fetchDeletedItems();
    } catch (err) {
      console.error(err);
      alert('Failed to delete user');
    }
  };

  const adjustUserPoints = async () => {
    if (!pointsUser) return;
    try {
      await api.put(`admin/users/${pointsUser.id}/points?points=${pointsAmount}&operation=${pointsOperation}`, {});
      setShowPointsDialog(false);
      setPointsUser(null);
      setPointsAmount(0);
      fetchUsers();
    } catch (err: any) {
      console.error(err);
      const msg = err.response?.data || 'Failed to adjust points';
      alert(typeof msg === 'string' ? msg : JSON.stringify(msg));
    }
  };

  const handleAddCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newCategory.name.trim()) {
      alert('Category name is required');
      return;
    }
    try {
      await api.post('categories', {
        ...newCategory
      });
      setShowAddCategory(false);
      setNewCategory({ name: '', description: '', imagePath: '', imageLink: '' });
      fetchCategories();
    } catch (err: any) {
      console.error(err);
      const msg = err.response?.data || 'Failed to add category';
      alert(typeof msg === 'string' ? msg : (msg.message || JSON.stringify(msg)));
    }
  };

  const handleEditCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingCategory) return;
    try {
      await api.put(`categories/${editingCategory.id}`, {
        ...editingCategory
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
      const res = await api.post('files/upload', formData, {
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
      const res = await api.post('files/upload', formData, {
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

  const logoUrl = getImageUrl(getSetting('LOGO_URL', ''));

  const handleLogoError = (e: React.SyntheticEvent<HTMLImageElement, Event>) => {
    const img = e.currentTarget;
    if (logoUrl && img.src !== logoUrl) {
      img.src = logoUrl;
    } else if (img.src !== '/logo.png') {
      img.src = '/logo.png';
    }
  };

  // Group orders by customer name for list/grid views
  const groupedOrdersMap: Record<string, any[]> = useMemo(() => {
    return (orders || []).reduce((acc: Record<string, any[]>, order: any) => {
      const key = order.customerName || `User ${order.customerId}`;
      if (!acc[key]) acc[key] = [];
      acc[key].push(order);
      return acc;
    }, {});
  }, [orders]);

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
        <div className="flex items-center gap-3">
          <img
            src="/logo.png"
            onError={handleLogoError}
            alt="Logo"
            className="h-10 w-auto rounded-xl border border-gray-200 bg-white p-1 shadow-sm"
          />
          <h1 className={`text-2xl md:text-3xl font-black ${isSuperManager ? 'text-purple-800' : 'text-gray-900'}`}>
            {isSuperManager ? 'Super Manager Panel' : 'Admin Panel'}
          </h1>
          <button
            onClick={() => {
              setAudioEnabled(!audioEnabled);
              if (!audioEnabled) {
                playNotification(); // Play once to satisfy browser interaction requirement
              }
            }}
            className={`p-2 rounded-xl transition-all shadow-sm flex items-center gap-2 text-xs font-bold ${
              audioEnabled 
                ? 'bg-blue-100 text-blue-700 border border-blue-200' 
                : 'bg-gray-100 text-gray-500 border border-gray-200'
            }`}
            title={audioEnabled ? 'Audio notifications enabled' : 'Click to enable audio notifications'}
          >
            <Bell size={18} className={audioEnabled ? 'animate-bounce' : ''} />
            <span className="hidden md:inline">{audioEnabled ? 'Audio ON' : 'Enable Audio'}</span>
          </button>
        </div>
        <div className="flex flex-wrap gap-3">
          <div className="flex items-center gap-2 bg-white border border-gray-200 rounded-xl px-3 py-1.5 shadow-sm">
            <span className="text-[10px] font-black text-gray-400 uppercase">Period:</span>
            <select
              className="text-xs font-bold text-gray-700 bg-transparent outline-none border-none focus:ring-0"
              value={salesPeriod}
              onChange={e => setSalesPeriod(e.target.value as any)}
            >
              <option value="DAILY">Daily</option>
              <option value="WEEKLY">Weekly</option>
              <option value="MONTHLY">Monthly</option>
            </select>
          </div>
          <div className="flex items-center gap-2 bg-white border border-gray-200 rounded-xl px-3 py-1.5 shadow-sm">
            <span className="text-[10px] font-black text-gray-400 uppercase">Category:</span>
            <select
              className="text-xs font-bold text-gray-700 bg-transparent outline-none border-none focus:ring-0"
              value={selectedExcelCategory}
              onChange={e => setSelectedExcelCategory(e.target.value)}
            >
              <option value="">Auto (AI)</option>
              {(categories || []).map((c: any) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          </div>
          <label className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2.5 rounded-xl hover:bg-blue-700 cursor-pointer transition shadow-lg shadow-blue-100 font-bold text-sm">
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
            <button className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2.5 rounded-xl hover:bg-blue-700 transition shadow-lg shadow-blue-100 font-bold text-sm">
              <Upload size={18} />
              <span>Bulk Import</span>
            </button>
            <div className="absolute right-0 mt-2 w-64 bg-white rounded-xl shadow-xl border border-gray-100 p-4 hidden group-hover:block z-50">
              <label className="block text-xs font-bold text-gray-500 uppercase mb-2">Target Category</label>
              <select
                className="w-full border border-gray-200 rounded-lg p-2 text-sm mb-3 outline-none focus:ring-2 focus:ring-blue-500"
                value={selectedExcelCategory}
                onChange={e => setSelectedExcelCategory(e.target.value)}
              >
                <option value="">Auto-categorize</option>
                {categories?.map((c: any) => (
                  <option key={c.id} value={c.id}>{c.name}</option>
                ))}
              </select>
              <input
                type="file"
                accept=".xlsx, .xls"
                onChange={handleExcelUpload}
                className="block w-full text-xs text-gray-500 file:mr-2 file:py-1 file:px-2 file:rounded-lg file:border-0 file:text-xs file:font-bold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
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
            <p className="text-2xl font-black text-gray-900">{(users || []).length}</p>
          </div>
        </div>
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4 hover:shadow-md transition">
          <div className={`p-4 rounded-xl ${isSuperManager ? 'bg-purple-100 text-purple-600' : 'bg-blue-100 text-blue-600'}`}>
            <ShoppingBag size={24} />
          </div>
          <div>
            <p className="text-gray-400 text-xs font-bold uppercase tracking-wider">Total Orders</p>
            <p className="text-2xl font-black text-gray-900">{salesReport?.totalOrders ?? (orders || []).length}</p>
          </div>
        </div>
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4 hover:shadow-md transition">
          <div className={`p-4 rounded-xl ${isSuperManager ? 'bg-purple-100 text-purple-600' : 'bg-yellow-100 text-yellow-600'}`}>
            <BarChart2 size={24} />
          </div>
          <div>
            <p className="text-gray-400 text-xs font-bold uppercase tracking-wider">Total Revenue</p>
            <p className="text-2xl font-black text-gray-900">₹{(salesReport?.totalSales ?? (orders || []).reduce((acc, o) => acc + (o.totalAmount || 0), 0)).toLocaleString()}</p>
          </div>
        </div>
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4 hover:shadow-md transition">
          <div className={`p-4 rounded-xl ${isSuperManager ? 'bg-purple-100 text-purple-600' : 'bg-orange-100 text-orange-600'}`}>
            <Package size={24} />
          </div>
          <div>
            <p className="text-gray-400 text-xs font-bold uppercase tracking-wider">Products</p>
            <p className="text-2xl font-black text-gray-900">{(products || []).length}</p>
          </div>
        </div>
      </div>

      <div className="flex overflow-x-auto no-scrollbar border-b border-gray-100 mb-8 gap-2 md:gap-8 pb-1">
        {[
          { id: 'users', label: 'Users', icon: Users },
          { id: 'orders', label: 'Transactions', icon: ShoppingBag },
          { id: 'requests', label: 'Order Requests', icon: MessageSquare },
          { id: 'invoicing', label: 'Invoicing', icon: FileText },
          { id: 'cashback', label: 'Cashback Points', icon: Star },
          { id: 'products', label: 'Inventory', icon: Package },
          { id: 'deliveries', label: 'Deliveries', icon: Truck },
          { id: 'recycle', label: 'Recycle Bin', icon: Trash2 },
          { id: 'categories', label: 'Categories', icon: Plus },
          { id: 'reports', label: 'Reports', icon: BarChart2 },
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
          {showEditUser && (
            <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center p-4 z-50">
              <div className="bg-white rounded-2xl shadow-xl max-w-lg w-full p-6">
                <h3 className="text-lg font-black text-gray-900 mb-4">Edit User</h3>
                <form onSubmit={saveEditUser} className="space-y-3">
                  <div>
                    <label className="block text-xs font-bold text-gray-500 uppercase">Name</label>
                    <input className="w-full border border-gray-300 rounded-lg p-2 mt-1" value={editName} onChange={e => setEditName(e.target.value)} />
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-gray-500 uppercase">Email</label>
                    <input className="w-full border border-gray-300 rounded-lg p-2 mt-1" value={editEmail} onChange={e => setEditEmail(e.target.value)} />
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-gray-500 uppercase">Mobile</label>
                    <input className="w-full border border-gray-300 rounded-lg p-2 mt-1" value={editPhone} onChange={e => setEditPhone(e.target.value)} />
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-gray-500 uppercase">Address</label>
                    <input className="w-full border border-gray-300 rounded-lg p-2 mt-1" value={editAddress} onChange={e => setEditAddress(e.target.value)} />
                  </div>
                  <div className="flex gap-3">
                    <div className="flex-1">
                      <label className="block text-xs font-bold text-gray-500 uppercase">Status</label>
                      <select className="w-full border border-gray-300 rounded-lg p-2 mt-1" value={editStatus} onChange={e => setEditStatus(e.target.value)}>
                        <option value="ACTIVE">ACTIVE</option>
                        <option value="PENDING">PENDING</option>
                        <option value="SUSPENDED">SUSPENDED</option>
                      </select>
                    </div>
                    <div className="flex-1">
                      <label className="block text-xs font-bold text-gray-500 uppercase">Points</label>
                      <input type="number" className="w-full border border-gray-300 rounded-lg p-2 mt-1" value={editPoints} onChange={e => setEditPoints(parseInt(e.target.value || '0', 10))} />
                    </div>
                  </div>
                  <div className="flex gap-3">
                    <div className="flex-1">
                      <label className="block text-xs font-bold text-gray-500 uppercase">Latitude</label>
                      <input className="w-full border border-gray-300 rounded-lg p-2 mt-1" value={editLatitude} onChange={e => setEditLatitude(e.target.value === '' ? '' : parseFloat(e.target.value))} />
                    </div>
                    <div className="flex-1">
                      <label className="block text-xs font-bold text-gray-500 uppercase">Longitude</label>
                      <input className="w-full border border-gray-300 rounded-lg p-2 mt-1" value={editLongitude} onChange={e => setEditLongitude(e.target.value === '' ? '' : parseFloat(e.target.value))} />
                    </div>
                  </div>
                  <div>
                    <button
                      type="button"
                      className="px-3 py-2 bg-gray-100 text-gray-700 rounded-lg mr-2"
                      onClick={() => useBrowserLocation((lat, lon) => { setEditLatitude(lat); setEditLongitude(lon); })}
                    >
                      Use Current Location
                    </button>
                  </div>
                  <div className="flex justify-end gap-2 pt-2">
                    <button type="button" className="px-4 py-2 rounded-lg bg-gray-100 text-gray-700" onClick={() => { setShowEditUser(false); setEditingUserData(null); }}>
                      Cancel
                    </button>
                    <button type="submit" className="px-4 py-2 rounded-lg bg-primary-600 text-white">
                      Save
                    </button>
                  </div>
                </form>
              </div>
            </div>
          )}
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
              <span>{(users || []).filter(u =>
                (u.name || '').toLowerCase().includes(userSearchTerm.toLowerCase()) ||
                (u.email || '').toLowerCase().includes(userSearchTerm.toLowerCase()) ||
                (u.role?.name || u.role || '').toString().toLowerCase().includes(userSearchTerm.toLowerCase())
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
                {(users || []).filter(u =>
                  (u.name || '').toLowerCase().includes(userSearchTerm.toLowerCase()) ||
                  (u.email || '').toLowerCase().includes(userSearchTerm.toLowerCase()) ||
                  (u.role?.name || u.role || '').toString().toLowerCase().includes(userSearchTerm.toLowerCase())
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
                          <div className="text-[10px] font-bold text-amber-600">Points: {user.points || 0}</div>
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
                        user.status === 'PENDING' ? 'bg-yellow-100 text-yellow-700' : 'bg-blue-100 text-blue-700'
                      }`}>
                        {user.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-center">
                      <div className="flex items-center justify-center gap-2">
                        <button
                          onClick={() => openEditUser(user)}
                          className="p-2 bg-gray-50 text-gray-700 rounded-lg hover:bg-gray-100 transition"
                          title="Edit User"
                        >
                          <FileText size={18} />
                        </button>
                        <button
                          onClick={() => {
                            setPointsUser(user);
                            setPointsAmount(0);
                            setPointsOperation('ADD');
                            setShowPointsDialog(true);
                          }}
                          className="p-2 bg-amber-50 text-amber-600 rounded-lg hover:bg-amber-100 transition"
                          title="Manage Points"
                        >
                          <Star size={18} />
                        </button>
                        {user.status === 'PENDING' ? (
                          <button
                            onClick={() => updateUserStatus(user.id, 'ACTIVE')}
                            className="p-2 bg-blue-50 text-blue-600 rounded-lg hover:bg-blue-100 transition"
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
            {(users || []).filter(u =>
              (u.name || '').toLowerCase().includes(userSearchTerm.toLowerCase()) ||
              (u.email || '').toLowerCase().includes(userSearchTerm.toLowerCase()) ||
              (u.role?.name || u.role || '').toString().toLowerCase().includes(userSearchTerm.toLowerCase())
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
                    user.status === 'PENDING' ? 'bg-yellow-100 text-yellow-700' : 'bg-blue-100 text-blue-700'
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
                        className="p-3 bg-blue-600 text-white rounded-xl shadow-lg shadow-blue-100 transition"
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
        <div className="space-y-6">
          <div className="flex flex-col md:flex-row gap-4 items-center justify-between mb-2">
            <div className="relative w-full md:max-w-md">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
              <input
                type="text"
                placeholder="Filter by customer name..."
                className="w-full pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary-500 outline-none transition shadow-sm"
                value={orderQuery}
                onChange={(e) => setOrderQuery(e.target.value)}
              />
            </div>
            <div className="flex items-center gap-2 bg-white p-1 rounded-xl border border-gray-200 shadow-sm">
              <button
                onClick={() => setOrderListView('list')}
                className={`px-4 py-2 rounded-lg text-xs font-black transition flex items-center gap-2 ${orderListView === 'list' ? 'bg-primary-600 text-white shadow-md' : 'text-gray-500 hover:bg-gray-50'}`}
              >
                <List size={16} />
                List
              </button>
              <button
                onClick={() => setOrderListView('grid')}
                className={`px-4 py-2 rounded-lg text-xs font-black transition flex items-center gap-2 ${orderListView === 'grid' ? 'bg-primary-600 text-white shadow-md' : 'text-gray-500 hover:bg-gray-50'}`}
              >
                <LayoutGrid size={16} />
                Grid
              </button>
            </div>
          </div>

          {orderListView === 'grid' ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
              {Object.keys(groupedOrdersMap)
                .filter(name => name.toLowerCase().includes(orderQuery.toLowerCase()))
                .map((userName) => {
                  const userOrders = groupedOrdersMap[userName] || [];
                  const firstOrder = userOrders[0];
                  if (!firstOrder) return null;
                  
                  // Try to find the user in our users list to get their shop image
                  const user = (users || []).find(u => u.name === userName || u.id === firstOrder.customerId);
                  
                  return (
                    <div key={userName} className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden hover:shadow-xl transition group cursor-pointer" onClick={() => setOrderQuery(userName)}>
                      <div className="aspect-video relative overflow-hidden bg-gray-100">
                        {user?.shopImagePath ? (
                          <img src={getImageUrl(user.shopImagePath)} alt={userName} className="w-full h-full object-cover group-hover:scale-110 transition duration-500" />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center">
                            <Store size={48} className="text-gray-300" />
                          </div>
                        )}
                        <div className="absolute top-3 right-3">
                          <span className="bg-primary-600 text-white text-[10px] font-black px-2 py-1 rounded-full shadow-lg">
                            {userOrders.length} Orders
                          </span>
                        </div>
                      </div>
                      <div className="p-4">
                        <h3 className="font-black text-gray-900 truncate">{userName}</h3>
                        <p className="text-[10px] text-gray-400 font-bold uppercase tracking-widest mt-1">
                          {user?.address || 'No address provided'}
                        </p>
                        <div className="mt-4 pt-4 border-t border-gray-50 flex items-center justify-between">
                          <div className="text-xs font-bold text-gray-500 uppercase tracking-widest">Recent Status</div>
                          <span className={`px-2 py-0.5 text-[8px] font-black tracking-widest uppercase rounded-md ${
                            firstOrder.status === 'PENDING' ? 'bg-yellow-100 text-yellow-700' :
                            firstOrder.status === 'APPROVED' ? 'bg-blue-100 text-blue-700' :
                            firstOrder.status === 'DELIVERED' ? 'bg-blue-100 text-blue-700' :
                            'bg-gray-100 text-gray-700'
                          }`}>
                            {firstOrder.status}
                          </span>
                        </div>
                      </div>
                    </div>
                  );
                })}
            </div>
          ) : (
            <div className="space-y-8">
              {Object.keys(groupedOrdersMap)
                .filter(name => name.toLowerCase().includes(orderQuery.toLowerCase()))
                .map((userName) => (
                <div key={userName} className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                  <div className="px-6 py-4 border-b border-gray-100 bg-gray-50/50 flex items-center justify-between">
                    <h3 className="text-lg font-black text-gray-900 flex items-center gap-2">
                      <Users size={20} className="text-primary-600" />
                      Orders for {userName}
                    </h3>
                    <span className="text-xs font-bold text-gray-500 bg-white px-3 py-1 rounded-full border border-gray-100">
                      {(groupedOrdersMap[userName] || []).length} Orders
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
                        {(groupedOrdersMap[userName] || []).map((order: any) => (
                          <tr key={order.id} className="hover:bg-gray-50/50 transition">
                            <td className="px-6 py-4 whitespace-nowrap">
                              <span className="text-xs font-black text-primary-700 bg-primary-50 px-2 py-1 rounded-md">#{order.id}</span>
                              <div className="text-[10px] text-gray-400 mt-1 font-bold">{order.createdAt ? new Date(order.createdAt).toLocaleDateString() : 'N/A'}</div>
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap">
                              <div className="text-sm font-black text-gray-900">₹{(order.totalAmount || 0).toLocaleString()}</div>
                          {(order.discountAmount || 0) > 0 && (
                            <div className="text-[10px] font-black text-orange-600 mt-1">
                              Discount: ₹{(order.discountAmount || 0).toLocaleString()}
                            </div>
                          )}
                          {order.pointsRedeemed > 0 && (
                            <div className="text-[10px] font-black text-amber-600 mt-1">
                              Redeemed: {order.pointsRedeemed} pts (₹{order.pointsRedeemed})
                            </div>
                          )}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap">
                              <span className={`px-3 py-1 text-[10px] font-black tracking-widest uppercase rounded-lg ${
                                order.status === 'PENDING' ? 'bg-yellow-100 text-yellow-700' :
                                order.status === 'APPROVED' ? 'bg-blue-100 text-blue-700' :
                                order.status === 'DELIVERED' ? 'bg-blue-100 text-blue-700' :
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
            </div>
          )}
          {(orders || []).length === 0 && (
            <div className="bg-white rounded-2xl p-10 text-center border border-dashed border-gray-200">
              <ShoppingBag size={48} className="mx-auto text-gray-200 mb-4" />
              <p className="text-gray-400 font-bold">No orders found</p>
            </div>
          )}
        </div>
      )}

      {activeTab === 'products' && (
        <div className="space-y-4">
          <div className="flex flex-col md:flex-row gap-4 items-center justify-between mb-2">
            <div className="relative w-full md:max-w-md">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
              <input
                type="text"
                placeholder="Search products by name or part number..."
                className="w-full pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary-500 outline-none transition shadow-sm"
                value={productSearchTerm}
                onChange={(e) => setProductSearchTerm(e.target.value)}
              />
            </div>
            <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase">
              <Package size={16} />
              <span>{pagination.totalElements} Products Found</span>
            </div>
          </div>

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
                  onClick={() => setSelectedProductIds((products || []).map((p: any) => p.id))}
                  className="px-3 py-1.5 bg-gray-50 text-primary-700 rounded-lg text-xs font-bold hover:bg-primary-50 transition"
                >
                  Select All
                </button>
                <button
                  onClick={async () => {
                    if (selectedProductIds.length === 0) return;
                    if (!window.confirm(`Delete ${selectedProductIds.length} selected products?`)) return;
                    try {
                      await api.post('products/delete-bulk', selectedProductIds);
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
                      checked={(selectedProductIds || []).length === (products || []).length && (products || []).length > 0}
                      onChange={(e) => {
                        if (e.target.checked) {
                          setSelectedProductIds((products || []).map((p: any) => p.id));
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
              {(products || []).map((product: any) => (
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
                        onClick={() => { 
                          setEditingProduct(product); 
                          // Calculate initial discount percent based on MRP and Selling Price
                          const mrp = parseFloat(product.mrp) || 0;
                          const selling = parseFloat(product.sellingPrice) || 0;
                          if (mrp > 0) {
                            const disc = ((mrp - selling) / mrp * 100).toFixed(0);
                            setEditingDiscountPercent(disc);
                          } else {
                            setEditingDiscountPercent('0');
                          }
                          setShowEditProduct(true); 
                        }}
                        className="px-3 py-1.5 bg-primary-50 text-primary-700 rounded-lg text-xs font-black hover:bg-primary-100 transition-all border border-primary-100 active:scale-95"
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
                Showing {(products || []).length} of {pagination.totalElements} products
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
              {(orders || [])
                .filter(o => o.status === 'OUT_FOR_DELIVERY' || o.status === 'DELIVERED')
                .map((order) => (
                <tr key={order.id}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">#{order.id}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{order.customerName}</td>
                  <td className="px-6 py-4 text-sm text-gray-500 max-w-xs truncate">{order.customerAddress || 'N/A'}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-700 font-semibold">{order.deliveredByName || 'Not assigned'}</td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`px-2 py-1 text-xs font-semibold rounded-full ${
                      order.status === 'OUT_FOR_DELIVERY' ? 'bg-blue-100 text-blue-800' : 'bg-indigo-100 text-indigo-800'
                    }`}>
                      {order.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    {order.status === 'OUT_FOR_DELIVERY' && (
                      <button
                        onClick={() => updateOrderStatus(order.id, 'DELIVERED')}
                        className="text-blue-600 hover:text-blue-900 flex items-center"
                      >
                        <CheckCircle size={18} className="mr-1" />
                        <span>Mark Delivered</span>
                      </button>
                    )}
                  </td>
                </tr>
              ))}
              {(orders || []).filter(o => o.status === 'OUT_FOR_DELIVERY' || o.status === 'DELIVERED').length === 0 && (
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
                  {(deletedUsers || []).length > 0 ? (deletedUsers || []).map((user) => (
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
              {(deletedProducts || []).length > 0 && (
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
                  {(deletedProducts || []).length > 0 ? (deletedProducts || []).map((product) => (
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
                  {(deletedOrders || []).length > 0 ? (deletedOrders || []).map((order) => (
                    <tr key={order.id} className="hover:bg-gray-50/50 transition">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className="text-xs font-black text-primary-700 bg-primary-50 px-2 py-1 rounded-md">#{order.id}</span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-bold text-gray-900">{order.customerName}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-black text-gray-900">₹{(order.totalAmount || 0).toLocaleString()}</div>
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

      {activeTab === 'invoicing' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <div className="space-y-6">
            <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm">
              <h3 className="font-bold text-gray-900 mb-4 uppercase tracking-widest text-xs">1. Select Customer</h3>
              <div className="space-y-3">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                  <input
                    type="text"
                    placeholder="Type name to filter users..."
                    className="w-full pl-10 pr-4 py-2 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary-500 outline-none transition text-sm"
                    onChange={(e) => {
                      const term = e.target.value.toLowerCase();
                      const select = document.getElementById('customer-select') as HTMLSelectElement;
                      if (!select) return;
                      const options = select.options;
                      for (let i = 0; i < options.length; i++) {
                        const option = options[i];
                        if (option.text.toLowerCase().includes(term) || option.value === "") {
                          option.style.display = "";
                        } else {
                          option.style.display = "none";
                        }
                      }
                    }}
                  />
                </div>
                <select 
                  id="customer-select"
                  className="w-full border border-gray-200 rounded-xl p-3 font-bold text-gray-700 outline-none focus:ring-2 focus:ring-primary-500 bg-gray-50"
                  value={billingUser?.id || ''}
                  onChange={(e) => setBillingUser((users || []).find(u => u.id === parseInt(e.target.value)))}
                >
                  <option value="">Choose a customer...</option>
                  {(users || []).map(u => (
                    <option key={u.id} value={u.id}>{u.name} ({u.roles?.join(', ') || 'User'})</option>
                  ))}
                </select>
              </div>
            </div>

            <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm">
              <h3 className="font-bold text-gray-900 mb-4 uppercase tracking-widest text-xs">2. Add Products</h3>
              <div className="flex gap-2">
                <div className="relative group">
                  <button
                    onClick={() => {
                      setScannerMode('camera');
                      setShowScanner(true);
                    }}
                    className="bg-white border border-gray-200 text-gray-700 p-3 rounded-xl hover:border-primary-500 hover:text-primary-600 transition shadow-sm h-full"
                    title="Scan Barcode"
                  >
                    <ScanBarcode size={20} />
                  </button>
                  <div className="absolute top-full left-0 mt-2 bg-white border border-gray-200 rounded-xl shadow-xl z-20 hidden group-hover:block overflow-hidden min-w-[180px]">
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
                <div className="relative flex-1">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
                  <input
                    type="text"
                    placeholder="Search products by name or part #..."
                    className="w-full pl-10 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary-500 outline-none transition"
                    value={billingSearchTerm}
                    onChange={(e) => handleBillSearch(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter') {
                        handleManualBillSearch();
                      }
                    }}
                  />
                  {(billingSearchResults || []).length > 0 && (
                    <div className="absolute top-full left-0 right-0 mt-2 bg-white border border-gray-200 rounded-xl shadow-xl z-10 overflow-hidden">
                      {(billingSearchResults || []).map(p => (
                        <div 
                          key={p.id} 
                          className="p-3 hover:bg-gray-50 cursor-pointer flex justify-between items-center border-b border-gray-50 last:border-0"
                          onClick={() => addProductToBill(p)}
                        >
                          <div>
                            <div className="font-bold text-sm text-gray-900">{p.name}</div>
                            <div className="text-[10px] text-gray-500">{p.partNumber}</div>
                          </div>
                          <div className="font-black text-primary-600 text-sm">₹{p.sellingPrice}</div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
                <button
                  onClick={handleManualBillSearch}
                  className="bg-primary-600 text-white p-3 rounded-xl hover:bg-primary-700 transition shadow-lg shadow-primary-100"
                >
                  <Search size={20} />
                </button>
              </div>
            </div>
          </div>

          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm flex flex-col min-h-[500px]">
            <h3 className="font-bold text-gray-900 mb-4 uppercase tracking-widest text-xs">3. Current Bill</h3>
            {billingUser && (
              <div className="mb-4 p-3 bg-primary-50 rounded-xl border border-primary-100 flex justify-between items-center">
                <div>
                  <div className="text-xs font-black text-primary-800 uppercase">Billing For</div>
                  <div className="font-bold text-primary-900">{billingUser.name}</div>
                </div>
                <button onClick={() => setBillingUser(null)} className="text-primary-600 hover:text-primary-800 transition">
                  <RotateCcw size={16} />
                </button>
              </div>
            )}
            
            <div className="flex-1 overflow-y-auto">
              {(billingItems || []).length === 0 ? (
                <div className="h-full flex flex-col items-center justify-center text-gray-400">
                  <ShoppingBag size={48} className="mb-2 opacity-20" />
                  <p className="font-bold">No items added yet</p>
                </div>
              ) : (
                <table className="min-w-full divide-y divide-gray-100">
                  <thead>
                    <tr>
                      <th className="py-2 text-left text-[10px] font-black text-gray-400 uppercase">Item</th>
                      <th className="py-2 text-center text-[10px] font-black text-gray-400 uppercase">Qty</th>
                      <th className="py-2 text-right text-[10px] font-black text-gray-400 uppercase">Total</th>
                      <th className="py-2 text-right"></th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {(billingItems || []).map(item => (
                      <tr key={item.id}>
                        <td className="py-3">
                          <div className="font-bold text-sm text-gray-900">{item.name}</div>
                          <div className="text-[10px] text-gray-500">₹{item.sellingPrice}</div>
                        </td>
                        <td className="py-3">
                          <div className="flex items-center justify-center gap-2">
                            <button onClick={() => updateBillQuantity(item.id, item.quantity - 1)} className="w-6 h-6 rounded-full bg-gray-100 flex items-center justify-center hover:bg-gray-200">-</button>
                            <span className="font-bold text-sm">{item.quantity}</span>
                            <button onClick={() => updateBillQuantity(item.id, item.quantity + 1)} className="w-6 h-6 rounded-full bg-gray-100 flex items-center justify-center hover:bg-gray-200">+</button>
                          </div>
                        </td>
                        <td className="py-3 text-right font-black text-sm text-gray-900">₹{(item.sellingPrice * item.quantity).toFixed(2)}</td>
                        <td className="py-3 text-right">
                          <button onClick={() => removeProductFromBill(item.id)} className="text-red-500 hover:text-red-700">
                            <Trash2 size={16} />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>

            <div className="mt-6 border-t border-gray-100 pt-6 space-y-4">
              <div className="flex justify-between items-center">
                <span className="text-gray-500 font-bold uppercase tracking-widest text-xs">Subtotal</span>
                <span className="text-lg font-bold text-gray-700">₹{(billingItems || []).reduce((acc, i) => acc + (i.sellingPrice * i.quantity), 0).toFixed(2)}</span>
              </div>
              
              <div className="flex flex-col gap-2 bg-orange-50 p-3 rounded-xl border border-orange-100">
                <div className="flex justify-between items-center">
                  <div className="flex items-center gap-2">
                    <Star size={16} className="text-orange-500" />
                    <span className="text-orange-700 font-bold uppercase tracking-widest text-[10px]">Discount</span>
                  </div>
                  <div className="flex bg-white rounded-lg p-0.5 border border-orange-200">
                    <button 
                      onClick={() => setBillingDiscountType('RS')}
                      className={`px-2 py-0.5 text-[10px] font-black rounded-md transition ${billingDiscountType === 'RS' ? 'bg-orange-500 text-white' : 'text-orange-400 hover:bg-orange-50'}`}
                    >
                      ₹
                    </button>
                    <button 
                      onClick={() => setBillingDiscountType('%')}
                      className={`px-2 py-0.5 text-[10px] font-black rounded-md transition ${billingDiscountType === '%' ? 'bg-orange-500 text-white' : 'text-orange-400 hover:bg-orange-50'}`}
                    >
                      %
                    </button>
                  </div>
                </div>
                <div className="flex items-center justify-end gap-2">
                  <span className="text-orange-700 font-bold text-xs">{billingDiscountType === 'RS' ? '₹' : '%'}</span>
                  <input
                    type="number"
                    className="w-20 bg-white border border-orange-200 rounded-lg px-2 py-1 text-right text-sm font-bold text-orange-700 focus:ring-2 focus:ring-orange-500 outline-none"
                    value={billingDiscount}
                    onChange={(e) => setBillingDiscount(Math.max(0, parseFloat(e.target.value) || 0))}
                  />
                </div>
                {billingDiscountType === '%' && billingDiscount > 0 && (
                  <div className="text-[10px] text-right text-orange-400 font-bold">
                    ≈ ₹{((billingItems || []).reduce((acc, i) => acc + (i.sellingPrice * i.quantity), 0) * (billingDiscount / 100)).toFixed(2)} off
                  </div>
                )}
              </div>

              <div className="flex justify-between items-center mb-4">
                <span className="text-gray-500 font-black uppercase tracking-widest text-xs">Total Payable</span>
                <span className="text-2xl font-black text-primary-600">
                  ₹{Math.max(0, (billingItems || []).reduce((acc, i) => acc + (i.sellingPrice * i.quantity), 0) - (billingDiscountType === '%' ? ((billingItems || []).reduce((acc, i) => acc + (i.sellingPrice * i.quantity), 0) * (billingDiscount / 100)) : billingDiscount)).toFixed(2)}
                </span>
              </div>
              <button
                disabled={!billingUser || (billingItems || []).length === 0}
                onClick={generateInvoice}
                className="w-full bg-primary-600 text-white py-4 rounded-xl font-black shadow-lg shadow-primary-100 hover:bg-primary-700 transition disabled:opacity-50 disabled:shadow-none flex items-center justify-center gap-2"
              >
                <FileText size={20} />
                Generate Invoice
              </button>
            </div>
          </div>
        </div>
      )}

      {showScanner && (
        <BarcodeScanner 
          initialMode={scannerMode}
          onScanSuccess={(text) => handleExternalScan(text)}
          onClose={() => setShowScanner(false)}
        />
      )}

      {activeTab === 'requests' && (
        <div className="space-y-4">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-xl font-bold text-gray-900">Custom Order Requests</h2>
            <button onClick={fetchOrderRequests} className="p-2 bg-gray-100 rounded-lg hover:bg-gray-200 transition">
              <RotateCcw size={20} className={fetchingRequests ? 'animate-spin' : ''} />
            </button>
          </div>
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <table className="min-w-full divide-y divide-gray-100">
              <thead className="bg-gray-50/50">
                <tr>
                  <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Request Details</th>
                  <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Customer</th>
                  <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Status</th>
                  <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Assigned Staff</th>
                  <th className="px-6 py-4 text-center text-xs font-bold text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-100">
                {(orderRequests || []).map((req) => (
                  <tr key={req.id} className="hover:bg-gray-50/50 transition">
                    <td className="px-6 py-4">
                      <div className="text-sm font-bold text-gray-900">{req.text}</div>
                      {req.photoPath && (
                        <a href={getImageUrl(req.photoPath)} target="_blank" rel="noreferrer" className="text-xs text-primary-600 hover:underline">View Photo</a>
                      )}
                      <div className="text-[10px] text-gray-400">{req.createdAt ? new Date(req.createdAt).toLocaleString() : 'N/A'}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{req.customerName}</td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`px-2 py-1 text-[10px] font-black uppercase rounded-lg ${
                        req.status === 'PENDING' ? 'bg-yellow-100 text-yellow-700' :
                        req.status === 'PROCESSING' ? 'bg-blue-100 text-blue-700' : 'bg-indigo-100 text-indigo-700'
                      }`}>
                        {req.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <select
                        value={req.assignedStaffId || ''}
                        onChange={(e) => assignRequestToStaff(req.id, parseInt(e.target.value))}
                        className="text-xs font-bold bg-gray-50 border border-gray-200 rounded-lg p-1"
                      >
                        <option value="">Unassigned</option>
                        {(users || []).filter(u => (u.role?.name || u.role) === ROLE_STAFF).map(s => (
                          <option key={s.id} value={s.id}>{s.name}</option>
                        ))}
                      </select>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-center">
                      <div className="flex gap-2 justify-center">
                        <button onClick={() => updateRequestStatus(req.id, 'PROCESSING')} className="text-xs font-bold text-blue-600 hover:underline">Process</button>
                        <button onClick={() => updateRequestStatus(req.id, 'COMPLETED')} className="text-xs font-bold text-blue-600 hover:underline">Complete</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {activeTab === 'reports' && (
        <div className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="bg-gradient-to-br from-blue-500 to-blue-600 p-6 rounded-2xl text-white shadow-lg shadow-blue-100">
              <h3 className="text-lg font-bold mb-2">Daily Performance</h3>
              <div className="text-3xl font-black mb-1">₹{salesReport?.totalSales?.toLocaleString() || '0'}</div>
              <div className="text-sm opacity-80">{salesReport?.totalOrders || '0'} Orders Today</div>
            </div>
            {/* You could fetch other periods here, but for now we reuse the report state */}
            <div className="bg-gradient-to-br from-indigo-500 to-indigo-600 p-6 rounded-2xl text-white shadow-lg shadow-indigo-100">
              <h3 className="text-lg font-bold mb-2">Active Inventory</h3>
              <div className="text-3xl font-black mb-1">{(products || []).length}</div>
              <div className="text-sm opacity-80">{(products || []).filter(p => p.stock <= 5).length} Low Stock Items</div>
            </div>
            <div className="bg-gradient-to-br from-purple-500 to-purple-600 p-6 rounded-2xl text-white shadow-lg shadow-purple-100">
              <h3 className="text-lg font-bold mb-2">User Growth</h3>
              <div className="text-3xl font-black mb-1">{(users || []).length}</div>
              <div className="text-sm opacity-80">{(users || []).filter(u => u.status === 'PENDING').length} Pending Approvals</div>
            </div>
          </div>
          
          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm">
            <h3 className="font-bold text-gray-900 mb-4">Detailed Reports</h3>
            <p className="text-sm text-gray-500">More charts and analytics coming soon to the web panel to match the mobile experience.</p>
          </div>
        </div>
      )}

      {activeTab === 'cashback' && (
        <div className="space-y-4">
          <div className="flex flex-col md:flex-row gap-4 items-center justify-between mb-2">
            <div className="relative w-full md:max-w-md">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
              <input
                type="text"
                placeholder="Search users by name or email..."
                className="w-full pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary-500 outline-none transition shadow-sm"
                value={cashbackSearchTerm}
                onChange={(e) => setCashbackSearchTerm(e.target.value)}
              />
            </div>
            <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase">
              <Star size={16} className="text-amber-500" />
              <span>{(users || []).filter(u => 
                (u.name.toLowerCase().includes(cashbackSearchTerm.toLowerCase()) || 
                 u.email.toLowerCase().includes(cashbackSearchTerm.toLowerCase())) &&
                (u.points > 0 || (orders || []).some(o => o.customerId === u.id && (o.pointsEarned > 0 || o.pointsRedeemed > 0)))
              ).length} Users with Point Activity</span>
            </div>
          </div>

          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-100">
              <thead className="bg-gray-50/50">
                <tr>
                  <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">User Details</th>
                  <th className="px-6 py-4 text-center text-xs font-bold text-gray-500 uppercase tracking-wider">Current Points</th>
                  <th className="px-6 py-4 text-center text-xs font-bold text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-100">
                {(users || []).filter(u => 
                  u.name.toLowerCase().includes(cashbackSearchTerm.toLowerCase()) || 
                  u.email.toLowerCase().includes(cashbackSearchTerm.toLowerCase())
                ).map((user) => {
                  const userOrders = (orders || []).filter(o => o.customerId === user.id && (o.pointsEarned > 0 || o.pointsRedeemed > 0));
                  return (
                    <React.Fragment key={user.id}>
                      <tr className="hover:bg-gray-50/50 transition">
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-full bg-amber-100 text-amber-700 flex items-center justify-center font-black text-sm uppercase">
                              {user.name.charAt(0)}
                            </div>
                            <div>
                              <div className="font-bold text-gray-900">{user.name}</div>
                              <div className="text-xs text-gray-500">{user.email}</div>
                            </div>
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-center">
                          <span className={`px-4 py-1.5 rounded-full text-sm font-black ${
                            (user.points || 0) >= 100 ? 'bg-indigo-100 text-indigo-700' : 'bg-amber-100 text-amber-700'
                          }`}>
                            {user.points || 0} pts
                          </span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-center">
                          <div className="flex items-center justify-center gap-2">
                            <button
                              onClick={() => {
                                setPointsUser(user);
                                setPointsAmount(0);
                                setPointsOperation('REDEEM');
                                setShowPointsDialog(true);
                              }}
                              className="px-3 py-1.5 bg-primary-600 text-white rounded-lg text-xs font-bold hover:bg-primary-700 transition"
                            >
                              Redeem Points
                            </button>
                          </div>
                        </td>
                      </tr>
                      {(userOrders || []).length > 0 && (
                        <tr>
                          <td colSpan={3} className="px-8 py-4 bg-gray-50/30">
                            <div className="space-y-2">
                              <h4 className="text-[10px] font-black text-gray-400 uppercase tracking-widest">Recent Activity</h4>
                              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2">
                                {userOrders.slice(0, 5).map((order: any) => (
                                  <div key={order.id} className="bg-white p-2 rounded-lg border border-gray-100 flex justify-between items-center">
                                    <span className="text-[10px] font-bold text-gray-400">#{order.id} • {order.createdAt ? new Date(order.createdAt).toLocaleDateString() : 'N/A'}</span>
                                    <div className="flex gap-2">
                                      {order.pointsEarned > 0 && <span className="text-[10px] font-black text-blue-600">+{order.pointsEarned} pts</span>}
                                      {order.pointsRedeemed > 0 && <span className="text-[10px] font-black text-red-600">-{order.pointsRedeemed} pts</span>}
                                    </div>
                                  </div>
                                ))}
                              </div>
                            </div>
                          </td>
                        </tr>
                      )}
                    </React.Fragment>
                  );
                })}
              </tbody>
            </table>
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
            {(categories || []).map((category: any) => (
              <div key={category.id} className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden group hover:shadow-md transition-shadow cursor-default">
                <div className="h-40 bg-gray-50 relative overflow-hidden">
                  {category.imageLink || category.imagePath ? (
                    <img src={getImageUrl(category.imageLink || category.imagePath)} alt={category.name} className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-gray-300">
                      <Package size={48} />
                    </div>
                  )}
                  <div className="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-all flex items-center justify-center gap-2">
                    <button
                      onClick={() => { setEditingCategory(category); setShowEditCategory(true); }}
                      className="bg-white text-gray-900 px-4 py-2 rounded-lg font-bold text-xs opacity-0 group-hover:opacity-100 transition-all transform translate-y-4 group-hover:translate-y-0 hover:bg-primary-50 hover:text-primary-600"
                    >
                      Edit
                    </button>
                    <button
                      onClick={async () => {
                        if (!window.confirm(`Delete category ${category.name}?`)) return;
                        try {
                          await api.delete(`/categories/${category.id}`);
                          fetchCategories();
                        } catch (err) {
                          console.error(err);
                          alert('Failed to delete category');
                        }
                      }}
                      className="bg-red-600 text-white px-4 py-2 rounded-lg font-bold text-xs opacity-0 group-hover:opacity-100 transition-all transform translate-y-4 group-hover:translate-y-0 hover:bg-red-700"
                    >
                      Delete
                    </button>
                  </div>
                </div>
                <div className="p-4 flex justify-between items-start">
                  <div>
                    <h4 className="font-black text-gray-900 text-lg">{category.name}</h4>
                    <p className="text-gray-500 text-sm font-medium mt-1 line-clamp-2">{category.description || 'No description provided'}</p>
                  </div>
                  <button
                    onClick={() => { setEditingCategory(category); setShowEditCategory(true); }}
                    className="p-2 text-gray-400 hover:text-primary-600 transition-colors md:hidden"
                  >
                    <Settings size={20} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {activeTab === 'settings' && (
        <div className="max-w-4xl mx-auto space-y-8 pb-20">
          <div className="bg-white rounded-3xl shadow-xl shadow-gray-100/50 border border-gray-100 overflow-hidden">
            <div className="px-8 py-6 border-b border-gray-100 bg-gray-50/50">
              <h2 className="text-xl font-black text-gray-900 flex items-center gap-3">
                <Settings size={24} className="text-primary-600" />
                Global System Settings
              </h2>
              <p className="text-gray-500 text-sm mt-1 font-medium">Configure core app behavior and external integrations.</p>
            </div>

            <div className="p-8 space-y-8">
              {/* Toggle Switches Section */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="flex items-center justify-between p-6 bg-gray-50 rounded-2xl border border-gray-100 group hover:border-primary-200 transition-all">
                  <div className="flex items-center gap-4">
                    <div className="p-3 bg-white rounded-xl shadow-sm text-primary-600">
                      <Bell size={24} />
                    </div>
                    <div>
                      <h3 className="font-bold text-gray-900">In-App Notifications</h3>
                      <p className="text-xs text-gray-500 font-medium">Real-time alerts for users.</p>
                    </div>
                  </div>
                  <label className="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      className="sr-only peer"
                      checked={getSetting('NOTIF_IN_APP_ENABLED', 'true') === 'true'}
                      onChange={(e) => updateSettingLocally('NOTIF_IN_APP_ENABLED', e.target.checked ? 'true' : 'false')}
                    />
                    <div className="w-12 h-6 bg-gray-200 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary-600"></div>
                  </label>
                </div>

                <div className="flex items-center justify-between p-6 bg-gray-50 rounded-2xl border border-gray-100 group hover:border-indigo-200 transition-all">
                  <div className="flex items-center gap-4">
                    <div className="p-3 bg-white rounded-xl shadow-sm text-indigo-600">
                      <MessageSquare size={24} />
                    </div>
                    <div>
                      <h3 className="font-bold text-gray-900">AI Chatbot</h3>
                      <p className="text-xs text-gray-500 font-medium">Enable/Disable AI assistant for all users.</p>
                    </div>
                  </div>
                  <label className="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      className="sr-only peer"
                      checked={getSetting('AI_CHATBOT_ENABLED', 'true') === 'true'}
                      onChange={(e) => updateSettingLocally('AI_CHATBOT_ENABLED', e.target.checked ? 'true' : 'false')}
                    />
                    <div className="w-12 h-6 bg-gray-200 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600"></div>
                  </label>
                </div>

                <div className="flex items-center justify-between p-6 bg-gray-50 rounded-2xl border border-gray-100 group hover:border-blue-200 transition-all">
                  <div className="flex items-center gap-4">
                    <div className="p-3 bg-white rounded-xl shadow-sm text-blue-600">
                      <MessageSquare size={24} />
                    </div>
                    <div>
                      <h3 className="font-bold text-gray-900">WhatsApp Alerts</h3>
                      <p className="text-xs text-gray-500 font-medium">Automated WhatsApp messages.</p>
                    </div>
                  </div>
                  <label className="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      className="sr-only peer"
                      checked={getSetting('NOTIF_WHATSAPP_ENABLED', 'false') === 'true'}
                      onChange={(e) => updateSettingLocally('NOTIF_WHATSAPP_ENABLED', e.target.checked ? 'true' : 'false')}
                    />
                    <div className="w-12 h-6 bg-gray-200 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                  </label>
                </div>

                <div className="flex items-center justify-between p-6 bg-gray-50 rounded-2xl border border-gray-100 group hover:border-amber-200 transition-all">
                  <div className="flex items-center gap-4">
                    <div className="p-3 bg-white rounded-xl shadow-sm text-amber-600">
                      <Truck size={24} />
                    </div>
                    <div>
                      <h3 className="font-bold text-gray-900">Global Force Local OTP</h3>
                      <p className="text-xs text-gray-500 font-medium">Bypass SMS gateway.</p>
                    </div>
                  </div>
                  <label className="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      className="sr-only peer"
                      checked={getSetting('FORCE_LOCAL_OTP', 'false') === 'true'}
                      onChange={(e) => updateSettingLocally('FORCE_LOCAL_OTP', e.target.checked ? 'true' : 'false')}
                    />
                    <div className="w-12 h-6 bg-gray-200 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-amber-600"></div>
                  </label>
                </div>

                <div className="flex items-center justify-between p-6 bg-gray-50 rounded-2xl border border-gray-100 group hover:border-primary-200 transition-all">
                  <div className="flex items-center gap-4">
                    <div className="p-3 bg-white rounded-xl shadow-sm text-primary-600">
                      <LayoutGrid size={24} />
                    </div>
                    <div>
                      <h3 className="font-bold text-gray-900">Global Theme Color</h3>
                      <p className="text-xs text-gray-500 font-medium">App-wide seed color.</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-4">
                    <input
                      type="color"
                      value={'#' + (parseInt(getSetting('THEME_SEED_COLOR', '4281236786')).toString(16).padStart(8, '0').slice(2))}
                      onChange={(e) => {
                        const hex = e.target.value.replace('#', '');
                        const argb = parseInt('FF' + hex, 16);
                        updateSettingLocally('THEME_SEED_COLOR', argb.toString());
                      }}
                      className="w-10 h-10 rounded-lg border-2 border-white shadow-sm cursor-pointer"
                    />
                    <label className="relative inline-flex items-center cursor-pointer">
                      <input
                        type="checkbox"
                        className="sr-only peer"
                        checked={getSetting('USE_GLOBAL_THEME_COLOR', 'false') === 'true'}
                        onChange={(e) => updateSettingLocally('USE_GLOBAL_THEME_COLOR', e.target.checked ? 'true' : 'false')}
                      />
                      <div className="w-12 h-6 bg-gray-200 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary-600"></div>
                    </label>
                  </div>
                </div>
              </div>

              {/* Text Inputs Section */}
              <div className="space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="p-6 bg-gray-50 rounded-2xl border border-gray-100">
                    <h3 className="font-bold text-gray-900 mb-2">Loyalty Points Percentage</h3>
                    <div className="flex items-center gap-3">
                      <input
                        type="number"
                        min={0}
                        max={100}
                        value={parseInt(getSetting('LOYALTY_PERCENT', '1'))}
                        onChange={(e) => updateSettingLocally('LOYALTY_PERCENT', e.target.value)}
                        className="w-full border border-gray-200 rounded-xl p-3 font-bold text-gray-700 outline-none focus:ring-2 focus:ring-primary-500"
                      />
                      <span className="text-gray-700 font-bold">%</span>
                    </div>
                  </div>
                  <div className="p-6 bg-gray-50 rounded-2xl border border-gray-100">
                    <h3 className="font-bold text-gray-900 mb-2">Minimum Points to Redeem</h3>
                    <div className="flex items-center gap-3">
                      <input
                        type="number"
                        min={0}
                        value={parseInt(getSetting('MIN_REDEEM_POINTS', '100'))}
                        onChange={(e) => updateSettingLocally('MIN_REDEEM_POINTS', e.target.value)}
                        className="w-full border border-gray-200 rounded-xl p-3 font-bold text-gray-700 outline-none focus:ring-2 focus:ring-primary-500"
                      />
                      <span className="text-gray-700 font-bold">pts</span>
                    </div>
                  </div>
                </div>

                <div className="space-y-4">
                  <h3 className="text-sm font-black text-gray-400 uppercase tracking-widest px-2">General App Config</h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className="space-y-1">
                      <label className="text-xs font-bold text-gray-500 ml-2">Logo URL</label>
                      <input
                        type="text"
                        placeholder="https://example.com/logo.png"
                        value={getSetting('LOGO_URL', '')}
                        onChange={(e) => updateSettingLocally('LOGO_URL', e.target.value)}
                        className="w-full border border-gray-200 rounded-xl p-3 text-sm font-medium text-gray-700 outline-none focus:ring-2 focus:ring-primary-500"
                      />
                    </div>
                    <div className="space-y-1">
                      <label className="text-xs font-bold text-gray-500 ml-2">Server Host</label>
                      <input
                        type="text"
                        placeholder="sparehub-0t47.onrender.com"
                        value={getSetting('SERVER_HOST', 'sparehub-0t47.onrender.com')}
                        onChange={(e) => updateSettingLocally('SERVER_HOST', e.target.value)}
                        className="w-full border border-gray-200 rounded-xl p-3 text-sm font-medium text-gray-700 outline-none focus:ring-2 focus:ring-primary-500"
                      />
                    </div>
                    <div className="space-y-1 md:col-span-2">
                      <label className="text-xs font-bold text-gray-500 ml-2">Google Client ID</label>
                      <input
                        type="text"
                        placeholder="Your Google OAuth Client ID"
                        value={getSetting('GOOGLE_CLIENT_ID', '')}
                        onChange={(e) => updateSettingLocally('GOOGLE_CLIENT_ID', e.target.value)}
                        className="w-full border border-gray-200 rounded-xl p-3 text-sm font-medium text-gray-700 outline-none focus:ring-2 focus:ring-primary-500"
                      />
                    </div>
                  </div>
                </div>

                <div className="space-y-4">
                  <h3 className="text-sm font-black text-gray-400 uppercase tracking-widest px-2">App Version & Updates</h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className="space-y-1">
                      <label className="text-xs font-bold text-gray-500 ml-2">Latest App Version</label>
                      <input
                        type="text"
                        placeholder="e.g. 1.0.1"
                        value={getSetting('LATEST_APP_VERSION', '1.0.0')}
                        onChange={(e) => updateSettingLocally('LATEST_APP_VERSION', e.target.value)}
                        className="w-full border border-gray-200 rounded-xl p-3 text-sm font-medium text-gray-700 outline-none focus:ring-2 focus:ring-primary-500"
                      />
                    </div>
                    <div className="space-y-1">
                      <label className="text-xs font-bold text-gray-500 ml-2">App Update URL</label>
                      <input
                        type="text"
                        placeholder="https://play.google.com/store/apps/details?id=..."
                        value={getSetting('APP_UPDATE_URL', '')}
                        onChange={(e) => updateSettingLocally('APP_UPDATE_URL', e.target.value)}
                        className="w-full border border-gray-200 rounded-xl p-3 text-sm font-medium text-gray-700 outline-none focus:ring-2 focus:ring-primary-500"
                      />
                    </div>
                  </div>
                </div>

                <div className="space-y-4">
                  <h3 className="text-sm font-black text-gray-400 uppercase tracking-widest px-2">User Registration Controls</h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {[
                      { key: 'ROLE_WHOLESALER', label: 'Wholesaler' },
                      { key: 'ROLE_RETAILER', label: 'Retailer' },
                      { key: 'ROLE_MECHANIC', label: 'Mechanic' },
                      { key: 'ROLE_STAFF', label: 'Staff' },
                      { key: 'ROLE_ADMIN', label: 'Admin' },
                      { key: 'ROLE_SUPER_MANAGER', label: 'Super Manager' },
                    ].map((r) => {
                      const allowed = getSetting('ALLOWED_REG_ROLES', 'ROLE_MECHANIC,ROLE_RETAILER,ROLE_WHOLESALER')
                        .split(',')
                        .map(s => s.trim());
                      const isChecked = allowed.includes(r.key);
                      const toggle = (checked: boolean) => {
                        const set = new Set(allowed);
                        if (checked) set.add(r.key);
                        else set.delete(r.key);
                        updateSettingLocally('ALLOWED_REG_ROLES', Array.from(set).join(','));
                      };
                      return (
                        <label key={r.key} className="flex items-center justify-between p-4 bg-gray-50 rounded-xl border border-gray-100">
                          <span className="font-bold text-gray-700">{r.label}</span>
                          <input
                            type="checkbox"
                            checked={isChecked}
                            onChange={(e) => toggle(e.target.checked)}
                          />
                        </label>
                      );
                    })}
                  </div>
                </div>

                <div className="flex justify-end pt-4">
                  <button
                    onClick={saveAllSettings}
                    disabled={savingSettings}
                    className="bg-primary-600 hover:bg-primary-700 text-white font-bold py-3 px-8 rounded-2xl shadow-lg shadow-primary-200 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                  >
                    {savingSettings ? (
                      <>
                        <RotateCcw className="animate-spin" size={20} />
                        Saving Settings...
                      </>
                    ) : (
                      <>
                        <CheckCircle size={20} />
                        Save All Settings
                      </>
                    )}
                  </button>
                </div>
              </div>
            </div>

            <div className="px-8 py-4 bg-gray-50 border-t border-gray-100 flex items-center justify-between">
              <span className="text-xs font-bold text-gray-400 uppercase tracking-widest">
                {savingSettings ? 'Saving changes...' : 'Review changes before saving'}
              </span>
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
                <label className="block text-sm font-medium text-gray-700">Mobile</label>
                <input
                  type="text"
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                  value={newUser.phone}
                  onChange={e => setNewUser({...newUser, phone: e.target.value})}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Address</label>
                <input
                  type="text"
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                  value={newUser.address}
                  onChange={e => setNewUser({...newUser, address: e.target.value})}
                />
              </div>
              <div className="flex gap-3">
                <div className="flex-1">
                  <label className="block text-sm font-medium text-gray-700">Latitude</label>
                  <input
                    type="text"
                    className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                    value={(newUser as any).latitude}
                    onChange={e => setNewUser({...newUser, latitude: e.target.value})}
                  />
                </div>
                <div className="flex-1">
                  <label className="block text-sm font-medium text-gray-700">Longitude</label>
                  <input
                    type="text"
                    className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                    value={(newUser as any).longitude}
                    onChange={e => setNewUser({...newUser, longitude: e.target.value})}
                  />
                </div>
              </div>
              <div>
                <button
                  type="button"
                  className="px-3 py-2 bg-gray-100 text-gray-700 rounded-lg"
                  onClick={() =>
                    useBrowserLocation((lat, lon) =>
                      setNewUser({ ...newUser, latitude: String(lat), longitude: String(lon) })
                    )
                  }
                >
                  Use Current Location
                </button>
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
                    onChange={e => {
                      const mrpVal = parseFloat(e.target.value) || 0;
                      const discount = parseFloat(newProduct.discountPercent) || 0;
                      const discountedPrice = mrpVal > 0 ? (mrpVal * (1 - discount / 100)).toFixed(2) : '0';
                      setNewProduct({
                        ...newProduct, 
                        mrp: e.target.value,
                        sellingPrice: discountedPrice,
                        wholesalerPrice: discountedPrice,
                        retailerPrice: discountedPrice,
                        mechanicPrice: discountedPrice
                      });
                    }}
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
              <div className="p-4 bg-primary-50 rounded-xl border border-primary-100">
                <div className="flex items-center justify-between mb-2">
                  <label className="block text-sm font-bold text-primary-800">Global Discount %</label>
                  <div className="flex items-center gap-2">
                    <input
                      type="number"
                      min="0"
                      max="100"
                      className="w-20 border border-primary-200 rounded-lg p-2 focus:ring-2 focus:ring-primary-500 outline-none text-sm font-bold"
                      value={newProduct.discountPercent}
                      onChange={e => {
                        const discount = parseFloat(e.target.value) || 0;
                        const mrp = parseFloat(newProduct.mrp) || 0;
                        const discountedPrice = mrp > 0 ? (mrp * (1 - discount / 100)).toFixed(2) : '0';
                        setNewProduct({
                          ...newProduct,
                          discountPercent: e.target.value,
                          sellingPrice: discountedPrice,
                          wholesalerPrice: discountedPrice,
                          retailerPrice: discountedPrice,
                          mechanicPrice: discountedPrice
                        });
                      }}
                    />
                    <span className="text-primary-800 font-bold">%</span>
                  </div>
                </div>
                <p className="text-[10px] text-primary-600 font-medium">
                  Entering a percentage will automatically calculate and set the Selling, Wholesaler, Retailer, and Mechanic prices based on the MRP.
                </p>
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
                {newProduct.imagePath && <p className="text-xs text-blue-600 mt-1">Image uploaded!</p>}
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
                  {(categories || []).map((c: any) => (
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
                    onChange={e => {
                      const mrpVal = parseFloat(e.target.value) || 0;
                      const discount = parseFloat(editingDiscountPercent) || 0;
                      const discountedPrice = mrpVal > 0 ? (mrpVal * (1 - discount / 100)).toFixed(2) : '0';
                      setEditingProduct({
                        ...editingProduct, 
                        mrp: e.target.value,
                        sellingPrice: discountedPrice,
                        wholesalerPrice: discountedPrice,
                        retailerPrice: discountedPrice,
                        mechanicPrice: discountedPrice
                      });
                    }}
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
              <div className="p-4 bg-primary-50 rounded-xl border border-primary-100">
                <div className="flex items-center justify-between mb-2">
                  <label className="block text-sm font-bold text-primary-800">Global Discount %</label>
                  <div className="flex items-center gap-2">
                    <input
                      type="number"
                      min="0"
                      max="100"
                      className="w-20 border border-primary-200 rounded-lg p-2 focus:ring-2 focus:ring-primary-500 outline-none text-sm font-bold"
                      value={editingDiscountPercent}
                      onChange={e => {
                        const discount = parseFloat(e.target.value) || 0;
                        const mrp = parseFloat(editingProduct.mrp) || 0;
                        const discountedPrice = mrp > 0 ? (mrp * (1 - discount / 100)).toFixed(2) : '0';
                        setEditingDiscountPercent(e.target.value);
                        setEditingProduct({
                          ...editingProduct,
                          sellingPrice: discountedPrice,
                          wholesalerPrice: discountedPrice,
                          retailerPrice: discountedPrice,
                          mechanicPrice: discountedPrice
                        });
                      }}
                    />
                    <span className="text-primary-800 font-bold">%</span>
                  </div>
                </div>
                <p className="text-[10px] text-primary-600 font-medium">
                  Modifying the percentage will recalculate the prices for all user roles based on the current MRP.
                </p>
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
                {editingProduct.imagePath && <p className="text-xs text-blue-600 mt-1">Image uploaded!</p>}
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
                  {(categories || []).map((c: any) => (
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
                  {(editingOrder?.items || []).map((item: any, idx: number) => (
                    <tr key={idx}>
                      <td className="py-2">{tp(item.productName)}</td>
                      <td className="py-2 text-center">
                        <div className="flex items-center justify-center space-x-2">
                          <button
                            onClick={() => {
                              const newItems = [...(editingOrder?.items || [])];
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
                              const newItems = [...(editingOrder?.items || [])];
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
                            const newItems = (editingOrder?.items || []).filter((_: any, i: number) => i !== idx);
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
                Total: ₹{(editingOrder?.items || []).reduce((acc: any, item: any) => acc + (item.price * item.quantity), 0).toFixed(2)}
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

      {showPointsDialog && pointsUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-[60]">
          <div className="bg-white rounded-2xl max-w-sm w-full p-8 shadow-2xl">
            <h3 className="text-xl font-black text-gray-900 mb-2">Manage Points</h3>
            <p className="text-sm text-gray-500 mb-6 font-bold">
              User: <span className="text-primary-600">{pointsUser.name}</span>
              <br />
              Current Balance: <span className="text-amber-600">{pointsUser.points || 0}</span>
            </p>
            
            <div className="space-y-4">
              <div>
                <label className="block text-xs font-black text-gray-400 uppercase mb-2">Operation</label>
                <select
                  value={pointsOperation}
                  onChange={(e) => setPointsOperation(e.target.value)}
                  className="w-full border border-gray-200 rounded-xl p-3 font-bold text-gray-700 outline-none focus:ring-2 focus:ring-primary-500"
                >
                  <option value="SET">Set Points</option>
                  <option value="ADD">Add Points</option>
                  <option value="SUBTRACT">Subtract Points</option>
                  <option value="REDEEM">Redeem Points</option>
                </select>
              </div>
              
              <div>
                <label className="block text-xs font-black text-gray-400 uppercase mb-2">Amount</label>
                <input
                  type="number"
                  value={pointsAmount}
                  onChange={(e) => setPointsAmount(parseInt(e.target.value) || 0)}
                  className="w-full border border-gray-200 rounded-xl p-3 font-bold text-gray-700 outline-none focus:ring-2 focus:ring-primary-500"
                  placeholder="Enter point amount..."
                />
              </div>

              <div className="flex gap-3 pt-4">
                <button
                  onClick={() => setShowPointsDialog(false)}
                  className="flex-1 px-4 py-3 text-gray-500 font-bold hover:bg-gray-50 rounded-xl transition"
                >
                  Cancel
                </button>
                <button
                  onClick={adjustUserPoints}
                  className="flex-1 bg-primary-600 text-white px-4 py-3 rounded-xl font-black shadow-lg shadow-primary-100 hover:bg-primary-700 transition"
                >
                  Apply
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AdminDashboard;
