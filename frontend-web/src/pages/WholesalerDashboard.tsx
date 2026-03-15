
import React, { useState, useEffect } from 'react';
import api from '../services/api';
import { Link } from 'react-router-dom';
import { useLanguage } from '../context/LanguageContext';
import { Package, ShoppingCart, TrendingUp, Upload } from 'lucide-react';

const WholesalerDashboard = () => {
  const { tp } = useLanguage();
  const [products, setProducts] = useState<any[]>([]);
  const [orders, setOrders] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('products');
  const [file, setFile] = useState<File | null>(null);
  const [selectedCategoryId, setSelectedCategoryId] = useState<string>('');
  const [categories, setCategories] = useState<any[]>([]);
  const [uploadStatus, setUploadStatus] = useState('');
  const [orderModalOpen, setOrderModalOpen] = useState(false);
  const [selectedProduct, setSelectedProduct] = useState<any | null>(null);
  const [orderQty, setOrderQty] = useState<number>(1);
  const [placing, setPlacing] = useState(false);
  const [orderMsg, setOrderMsg] = useState('');

  useEffect(() => {
    fetchProducts();
    fetchOrders();
    fetchCategories();
  }, []);

  const fetchCategories = async () => {
    try {
      const res = await api.get('/categories');
      setCategories(res.data || []);
    } catch (err) {
      console.error(err);
    }
  };

  const fetchProducts = async () => {
    try {
      const res = await api.get('/products/wholesaler');
      setProducts(res.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const fetchOrders = async () => {
    try {
      const res = await api.get('/orders/seller-orders');
      setOrders(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  const openOrderModal = (product) => {
    setSelectedProduct(product);
    setOrderQty(1);
    setOrderMsg('');
    setOrderModalOpen(true);
  };

  const placeOrder = async () => {
    if (!selectedProduct || orderQty <= 0) return;
    setPlacing(true);
    setOrderMsg('');
    try {
      await api.post('/orders', {
        sellerId: selectedProduct.wholesalerId,
        items: [
          {
            productId: selectedProduct.id,
            productName: selectedProduct.name,
            quantity: orderQty,
            price: selectedProduct.sellingPrice,
          }
        ],
      });
      setOrderMsg('Order placed successfully.');
      setOrderModalOpen(false);
      fetchOrders();
    } catch (err: any) {
      setOrderMsg(err?.response?.data?.message || 'Failed to place order.');
    } finally {
      setPlacing(false);
    }
  };

  const handleFileUpload = async (e) => {
    e.preventDefault();
    if (!file) return;

    const formData = new FormData();
    formData.append('file', file);
    if (selectedCategoryId) {
      formData.append('categoryId', selectedCategoryId);
    }

    try {
      setUploadStatus('Uploading...');
      await api.post('/excel/upload', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });
      setUploadStatus('Upload successful!');
      fetchProducts();
    } catch (err) {
      setUploadStatus('Upload failed.');
    }
  };

  const updateOrderStatus = async (orderId, status) => {
    try {
      await api.put(`/orders/${orderId}/status?status=${status}`);
      fetchOrders();
    } catch (err) {
      console.error(err);
    }
  };

  if (loading) return (
    <div className="flex flex-col items-center justify-center min-h-[60vh]">
      <div className="w-12 h-12 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin mb-4" />
      <p className="text-gray-500 font-medium">Loading Dashboard...</p>
    </div>
  );

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 mb-10">
        <div>
          <h1 className="text-3xl font-black text-gray-900 mb-2">Wholesaler Panel</h1>
          <p className="text-gray-500 font-medium">Manage your products and orders</p>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-6 mb-10">
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4 hover:shadow-md transition">
          <div className="bg-blue-100 p-4 rounded-xl text-blue-600">
            <Package size={24} />
          </div>
          <div>
            <p className="text-gray-400 text-xs font-bold uppercase tracking-wider">Total Products</p>
            <p className="text-2xl font-black text-gray-900">{products.length}</p>
          </div>
        </div>
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4 hover:shadow-md transition">
          <div className="bg-green-100 p-4 rounded-xl text-green-600">
            <ShoppingCart size={24} />
          </div>
          <div>
            <p className="text-gray-400 text-xs font-bold uppercase tracking-wider">Total Orders</p>
            <p className="text-2xl font-black text-gray-900">{orders.length}</p>
          </div>
        </div>
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4 hover:shadow-md transition">
          <div className="bg-yellow-100 p-4 rounded-xl text-yellow-600">
            <TrendingUp size={24} />
          </div>
          <div>
            <p className="text-gray-400 text-xs font-bold uppercase tracking-wider">Pending Orders</p>
            <p className="text-2xl font-black text-gray-900">{orders.filter(o => o.status === 'PENDING').length}</p>
          </div>
        </div>
      </div>

      <div className="flex overflow-x-auto no-scrollbar border-b border-gray-100 mb-8 gap-2 md:gap-8 pb-1">
        {[
          { id: 'products', label: 'Products', icon: Package },
          { id: 'orders', label: 'Orders', icon: ShoppingCart },
          { id: 'upload', label: 'Bulk Upload', icon: Upload },
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

      {activeTab === 'products' && (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-100">
            <thead className="bg-gray-50/50">
              <tr>
                <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Product Name</th>
                <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Part Number</th>
                <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Pricing</th>
                <th className="px-6 py-4 text-center text-xs font-bold text-gray-500 uppercase tracking-wider">Stock</th>
                <th className="px-6 py-4 text-center text-xs font-bold text-gray-500 uppercase tracking-wider">Action</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-100">
                {products.map((product) => (
                  <tr key={product.id} className="hover:bg-gray-50/50 transition">
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
                      <span className="px-3 py-1 rounded-lg bg-gray-100 text-xs font-black text-gray-700">
                        {product.stock}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-center">
                      <button
                        onClick={() => openOrderModal(product)}
                        className="px-3 py-1.5 bg-primary-50 text-primary-600 rounded-lg text-xs font-bold hover:bg-primary-100 transition"
                      >
                        Order
                      </button>
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
                <th className="px-6 py-4 text-center text-xs font-bold text-gray-500 uppercase tracking-wider">Action</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-100">
              {orders.map((order) => (
                <tr key={order.id} className="hover:bg-gray-50/50 transition">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className="text-xs font-black text-primary-700 bg-primary-50 px-2 py-1 rounded-md">#{order.id}</span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-bold text-gray-900">{order.customerName}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-black text-gray-900">₹{order.totalAmount.toLocaleString()}</td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`px-3 py-1 text-[10px] font-black tracking-widest uppercase rounded-lg ${
                      order.status === 'DELIVERED' ? 'bg-green-100 text-green-700' :
                      order.status === 'PENDING' ? 'bg-yellow-100 text-yellow-700' :
                      'bg-blue-100 text-blue-700'
                    }`}>
                      {order.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-center">
                    <div className="flex items-center justify-center gap-3">
                      {order.status === 'PENDING' && (
                        <button
                          onClick={() => updateOrderStatus(order.id, 'ACCEPTED')}
                          className="px-3 py-1.5 bg-primary-600 text-white rounded-lg text-xs font-bold hover:bg-primary-700 transition shadow-md shadow-primary-100"
                        >
                          Accept
                        </button>
                      )}
                      {order.status === 'ACCEPTED' && (
                        <button
                          onClick={() => updateOrderStatus(order.id, 'PACKED')}
                          className="px-3 py-1.5 bg-blue-600 text-white rounded-lg text-xs font-bold hover:bg-blue-700 transition shadow-md shadow-blue-100"
                        >
                          Mark Packed
                        </button>
                      )}
                      <Link
                        to={`/track/${order.id}`}
                        className="px-3 py-1.5 bg-gray-100 text-gray-700 rounded-lg text-xs font-bold hover:bg-gray-200 transition"
                      >
                        Track
                      </Link>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {activeTab === 'upload' && (
        <div className="bg-white p-8 rounded-xl shadow-sm border border-gray-100 max-w-lg mx-auto">
          <h3 className="text-lg font-bold mb-4">Bulk Product Upload</h3>
          <p className="text-gray-500 text-sm mb-6">Upload an Excel file with columns: Name, Part Number, MRP, Selling Price, Stock.</p>
          <form onSubmit={handleFileUpload} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Assign to Category (Optional)</label>
              <select
                className="w-full border border-gray-300 rounded-lg p-2 focus:ring-2 focus:ring-primary-500 outline-none"
                value={selectedCategoryId}
                onChange={e => setSelectedCategoryId(e.target.value)}
              >
                <option value="">Auto-categorize (by AI)</option>
                {categories.map((c: any) => (
                  <option key={c.id} value={c.id}>{c.name}</option>
                ))}
              </select>
            </div>
            <div className="border-2 border-dashed border-gray-200 rounded-xl p-8 text-center hover:border-primary-500 transition cursor-pointer">
              <Upload className="mx-auto text-gray-400 mb-2" size={32} />
              <input
                type="file"
                className="hidden"
                id="file-upload"
                onChange={(e) => setFile(e.target.files?.[0] || null)}
              />
              <label htmlFor="file-upload" className="text-primary-600 font-medium block cursor-pointer">
                {file ? file.name : 'Choose Excel File'}
              </label>
            </div>
            <button
              type="submit"
              className="w-full bg-primary-600 text-white py-2 rounded-lg font-bold hover:bg-primary-700 transition"
              disabled={!file}
            >
              Start Upload
            </button>
          </form>
          {uploadStatus && (
            <div className={`mt-4 p-3 rounded-lg text-sm text-center ${uploadStatus.includes('successful') ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-700'}`}>
              {uploadStatus}
            </div>
          )}
        </div>
      )}
      {orderModalOpen && selectedProduct && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div className="bg-white w-full max-w-md rounded-xl shadow-lg p-6">
            <h3 className="text-lg font-bold mb-2">Order {tp(selectedProduct.name)}</h3>
            <p className="text-gray-500 mb-4 text-sm">Part: {selectedProduct.partNumber}</p>
            <div className="space-y-3">
              <label className="block text-sm text-gray-700">Quantity</label>
              <input
                type="number"
                min={1}
                value={orderQty}
                onChange={(e) => setOrderQty(parseInt(e.target.value) || 1)}
                className="w-full border rounded-lg px-3 py-2"
              />
            </div>
            {orderMsg && <div className="mt-3 text-sm text-red-600">{orderMsg}</div>}
            <div className="mt-6 flex justify-end space-x-3">
              <button
                onClick={() => setOrderModalOpen(false)}
                className="px-4 py-2 rounded-lg bg-gray-100"
                disabled={placing}
              >
                Cancel
              </button>
              <button
                onClick={placeOrder}
                className="px-4 py-2 rounded-lg bg-primary-600 text-white hover:bg-primary-700"
                disabled={placing}
              >
                {placing ? 'Placing...' : 'Place Order'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default WholesalerDashboard;
