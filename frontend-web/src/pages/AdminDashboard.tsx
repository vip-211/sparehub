
import React, { useState, useEffect } from 'react';
import api from '../services/api';
import { Link } from 'react-router-dom';
import { useLanguage } from '../context/LanguageContext';
import { Users, ShoppingBag, BarChart2, CheckCircle, XCircle, Plus, Package, UserPlus, Upload, Truck } from 'lucide-react';
import { ROLE_SUPER_MANAGER, ROLE_ADMIN, ROLE_MECHANIC, ROLE_RETAILER, ROLE_WHOLESALER, ROLE_STAFF } from '../services/constants';
import AuthService from '../services/auth.service';

const AdminDashboard = () => {
  const { tp } = useLanguage();
  const currentUser = AuthService.getCurrentUser();
  const isSuperManager = currentUser?.roles.includes(ROLE_SUPER_MANAGER);

  const [users, setUsers] = useState<any[]>([]);
  const [orders, setOrders] = useState<any[]>([]);
  const [products, setProducts] = useState<any[]>([]);
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
    mrp: 0,
    sellingPrice: 0,
    wholesalerPrice: 0,
    retailerPrice: 0,
    mechanicPrice: 0,
    stock: 0,
    wholesalerId: '',
    imagePath: ''
  });
  const [uploading, setUploading] = useState(false);

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

  useEffect(() => {
    fetchUsers();
    fetchOrders();
    fetchProducts();
  }, []);

  const fetchUsers = async () => {
    try {
      const res = await api.get('/admin/users');
      setUsers(res.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const fetchOrders = async () => {
    try {
      const res = await api.get(isSuperManager ? '/admin/orders' : '/admin/orders');
      setOrders(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  const handleExcelUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const formData = new FormData();
    formData.append('file', file);

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

  const fetchProducts = async () => {
    try {
      const res = await api.get('/products');
      setProducts(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  const handleEditOrder = async (orderId, items) => {
    try {
      await api.post(`/orders/${orderId}/items`, { items });
      setShowEditOrder(false);
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
      await api.post('/products', {
        ...newProduct,
        mrp: parseFloat(newProduct.mrp),
        sellingPrice: parseFloat(newProduct.sellingPrice),
        stock: parseInt(newProduct.stock)
      });
      setShowAddProduct(false);
      setNewProduct({ name: '', partNumber: '', mrp: '', sellingPrice: '', stock: '', imagePath: '' });
      fetchProducts();
    } catch (err) {
      console.error(err);
      alert('Failed to add product');
    }
  };

  const handleUpdateProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await api.put(`/products/${editingProduct.id}`, {
        ...editingProduct,
        mrp: parseFloat(editingProduct.mrp),
        sellingPrice: parseFloat(editingProduct.sellingPrice),
        stock: parseInt(editingProduct.stock)
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

  const updateOrderStatus = async (orderId, status) => {
    try {
      await api.put(`/orders/${orderId}/status?status=${status}`);
      fetchOrders();
    } catch (err) {
      console.error(err);
      alert('Failed to update order status');
    }
  };

  const updateUserStatus = async (userId, status) => {
    try {
      await api.put(`/admin/users/${userId}/status?status=${status}`);
      fetchUsers();
    } catch (err) {
      console.error(err);
    }
  };

  const updateUserRole = async (userId, role) => {
    try {
      await api.put(`/admin/users/${userId}/role?roleName=${role}`);
      fetchUsers();
    } catch (err) {
      console.error(err);
      alert('Failed to update role');
    }
  };

  if (loading) return (
    <div className="flex flex-col items-center justify-center min-h-[60vh]">
      <div className="w-12 h-12 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin mb-4" />
      <p className="text-gray-500 font-medium">Loading Dashboard...</p>
    </div>
  );

  return (
    <div className={`container mx-auto p-4 md:p-6 ${isSuperManager ? 'bg-purple-50 min-h-screen' : ''}`}>
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6 mb-8">
        <h1 className={`text-2xl md:text-3xl font-black ${isSuperManager ? 'text-purple-800' : 'text-gray-900'}`}>
          {isSuperManager ? 'Super Manager Panel' : 'Admin Panel'}
        </h1>
        <div className="flex flex-wrap gap-3">
          <label className="flex items-center gap-2 bg-green-600 text-white px-4 py-2.5 rounded-xl hover:bg-green-700 cursor-pointer transition shadow-lg shadow-green-100 font-bold text-sm">
            <Upload size={18} />
            <span>Import</span>
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
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden overflow-x-auto">
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
              {users.map((user) => (
                <tr key={user.id} className="hover:bg-gray-50/50 transition">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="font-bold text-gray-900">{user.name}</div>
                    <div className="text-xs text-gray-500">{user.email}</div>
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
                    {user.status === 'PENDING' ? (
                      <button
                        onClick={() => updateUserStatus(user.id, 'ACTIVE')}
                        className="p-2 bg-green-50 text-green-600 rounded-lg hover:bg-green-100 transition"
                        title="Approve"
                      >
                        <CheckCircle size={18} />
                      </button>
                    ) : (
                      <button
                        onClick={() => updateUserStatus(user.id, 'PENDING')}
                        className="p-2 bg-orange-50 text-orange-600 rounded-lg hover:bg-orange-100 transition"
                        title="Suspend"
                      >
                        <XCircle size={18} />
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {activeTab === 'orders' && (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-100">
            <thead className="bg-gray-50/50">
              <tr>
                <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Order Info</th>
                <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Customer</th>
                <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Amount</th>
                <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Status</th>
                <th className="px-6 py-4 text-center text-xs font-bold text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-100">
              {orders.map((order) => (
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
                      {order.status === 'PENDING' && (
                        <>
                          <button
                            onClick={() => updateOrderStatus(order.id, 'APPROVED')}
                            className="p-1.5 bg-green-50 text-green-600 rounded-lg hover:bg-green-100 transition"
                            title="Approve Order"
                          >
                            <CheckCircle size={18} />
                          </button>
                          <button
                            onClick={() => updateOrderStatus(order.id, 'CANCELLED')}
                            className="p-1.5 bg-red-50 text-red-600 rounded-lg hover:bg-red-100 transition"
                            title="Cancel Order"
                          >
                            <XCircle size={18} />
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
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
                    if (!confirm(`Delete ${selectedProductIds.length} selected products?`)) return;
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
                      {product.imagePath ? (
                        <img src={product.imagePath} alt={product.name} className="w-10 h-10 rounded-lg object-cover bg-gray-50 border border-gray-100" />
                      ) : (
                        <div className="w-10 h-10 rounded-lg bg-gray-50 flex items-center justify-center border border-gray-100">
                          <Package size={20} className="text-gray-300" />
                        </div>
                      )}
                      <div className="text-sm font-bold text-gray-900">{tp(product.name)}</div>
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
                    <button 
                      onClick={() => { setEditingProduct(product); setShowEditProduct(true); }}
                      className="px-3 py-1.5 bg-gray-50 text-primary-600 rounded-lg text-xs font-bold hover:bg-primary-50 transition"
                    >
                      Edit
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
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
                  <td colSpan={5} className="px-6 py-10 text-center text-gray-500">No active or completed deliveries found.</td>
                </tr>
              )}
            </tbody>
          </table>
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
              <div className="grid grid-cols-2 gap-4">
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
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Initial Stock</label>
                <input
                  type="number"
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                  value={newProduct.stock}
                  onChange={e => setNewProduct({...newProduct, stock: parseInt(e.target.value)})}
                  required
                />
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
              <div className="grid grid-cols-2 gap-4">
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
              <div>
                <label className="block text-sm font-medium text-gray-700">Product Image URL</label>
                <input
                  type="text"
                  className="w-full border border-gray-300 rounded-lg p-2 mt-1 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                  value={editingProduct.imagePath || ''}
                  onChange={e => setEditingProduct({...editingProduct, imagePath: e.target.value})}
                  placeholder="https://example.com/image.jpg"
                />
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
                  {editingOrder.items.map((item, idx) => (
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
                            className="w-6 h-6 rounded-full bg-gray-100 flex items-center justify-center"
                          >-</button>
                          <span>{item.quantity}</span>
                          <button 
                            onClick={() => {
                              const newItems = [...editingOrder.items];
                              newItems[idx].quantity++;
                              setEditingOrder({ ...editingOrder, items: newItems });
                            }}
                            className="w-6 h-6 rounded-full bg-gray-100 flex items-center justify-center"
                          >+</button>
                        </div>
                      </td>
                      <td className="py-2 text-right">₹{item.price}</td>
                      <td className="py-2 text-right">
                        <button 
                          onClick={() => {
                            const newItems = editingOrder.items.filter((_, i) => i !== idx);
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
                Total: ₹{editingOrder.items.reduce((acc, item) => acc + (item.price * item.quantity), 0).toFixed(2)}
              </p>
              <div className="flex space-x-3">
                <button 
                  onClick={() => setShowEditOrder(false)}
                  className="px-4 py-2 bg-gray-100 rounded-lg"
                >Cancel</button>
                <button 
                  onClick={() => handleEditOrder(editingOrder.id, editingOrder.items)}
                  className="px-4 py-2 bg-primary-600 text-white rounded-lg"
                >Save Changes</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AdminDashboard;
