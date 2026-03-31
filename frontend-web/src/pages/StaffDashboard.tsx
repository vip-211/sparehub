
import React, { useState, useEffect } from 'react';
import api from '../services/api';
import { ShoppingBag, CheckCircle, Truck, MapPin, Search } from 'lucide-react';
import { ROLE_STAFF } from '../services/constants';
import AuthService from '../services/auth.service';

const StaffDashboard = () => {
  const [orders, setOrders] = useState<any[]>([]);
  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('orders');
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    fetchOrders();
    fetchUsers();
  }, []);

  const fetchOrders = async () => {
    try {
      // Reusing admin orders endpoint or staff-specific if it exists. 
      // Assuming admin orders works for staff too for now.
      const res = await api.get('admin/orders');
      setOrders(res.data);
    } catch (err) {
      console.error('Error fetching orders:', err);
    } finally {
      setLoading(false);
    }
  };

  const fetchUsers = async () => {
    try {
      const res = await api.get('admin/users');
      setUsers(res.data);
    } catch (err) {
      console.error('Error fetching users:', err);
    }
  };

  const updateOrderStatus = async (orderId: number, status: string) => {
    try {
      await api.put(`orders/${orderId}/status?status=${status}`);
      fetchOrders();
    } catch (err) {
      console.error('Error updating status:', err);
      alert('Failed to update order status');
    }
  };

  const filteredOrders = (orders || []).filter(order => 
    order.id.toString().includes(searchTerm) || 
    order.customerName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    order.deliveredByName?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const filteredUsers = (users || []).filter(user => 
    user.name?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    user.email?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  if (loading) return <div className="p-10 text-center">Loading Dashboard...</div>;

  return (
    <div className="container mx-auto p-6">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Staff Dashboard</h1>
        <div className="relative">
          <span className="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-400">
            <Search size={18} />
          </span>
          <input
            type="text"
            placeholder="Search..."
            className="pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none w-64"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-8">
        <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center space-x-4">
          <div className="p-3 rounded-lg bg-blue-100 text-blue-600">
            <ShoppingBag size={24} />
          </div>
          <div>
            <p className="text-gray-500 text-sm">Active Orders</p>
            <p className="text-2xl font-bold">{(orders || []).filter(o => o.status !== 'DELIVERED' && o.status !== 'CANCELLED').length}</p>
          </div>
        </div>
        <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center space-x-4">
          <div className="p-3 rounded-lg bg-indigo-100 text-indigo-600">
            <MapPin size={24} />
          </div>
          <div>
            <p className="text-gray-500 text-sm">Total Users</p>
            <p className="text-2xl font-bold">{(users || []).length}</p>
          </div>
        </div>
      </div>

      <div className="flex border-b border-gray-200 mb-6">
        <button
          className={`px-6 py-2 font-medium ${activeTab === 'orders' ? 'text-primary-600 border-b-2 border-primary-600' : 'text-gray-500'}`}
          onClick={() => setActiveTab('orders')}
        >
          Manage Orders
        </button>
        <button
          className={`px-6 py-2 font-medium ${activeTab === 'deliveries' ? 'text-primary-600 border-b-2 border-primary-600' : 'text-gray-500'}`}
          onClick={() => setActiveTab('deliveries')}
        >
          Deliveries Tracking
        </button>
        <button
          className={`px-6 py-2 font-medium ${activeTab === 'users' ? 'text-primary-600 border-b-2 border-primary-600' : 'text-gray-500'}`}
          onClick={() => setActiveTab('users')}
        >
          User Locations
        </button>
      </div>

      {activeTab === 'orders' && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Order ID</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Customer</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Address</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Delivered By</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {filteredOrders.map((order) => (
                <tr key={order.id}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">#{order.id}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{order.customerName}</td>
                  <td className="px-6 py-4 text-sm text-gray-500 max-w-xs truncate">{order.customerAddress || 'N/A'}</td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`px-2 py-1 text-xs font-semibold rounded-full ${
                      order.status === 'PENDING' ? 'bg-yellow-100 text-yellow-800' : 
                      order.status === 'OUT_FOR_DELIVERY' ? 'bg-blue-100 text-blue-800' : 
                      order.status === 'DELIVERED' ? 'bg-blue-100 text-blue-800' : 
                      'bg-gray-100 text-gray-800'
                    }`}>
                      {order.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{order.deliveredByName || '-'}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium flex items-center space-x-3">
                    {order.status !== 'DELIVERED' && order.status !== 'CANCELLED' && (
                      <>
                        <button
                          onClick={() => updateOrderStatus(order.id, 'OUT_FOR_DELIVERY')}
                          className="text-blue-600 hover:text-blue-900 flex items-center"
                          title="Mark as In Transit"
                        >
                          <Truck size={18} className="mr-1" />
                          <span>In Transit</span>
                        </button>
                        <button
                          onClick={() => updateOrderStatus(order.id, 'DELIVERED')}
                          className="text-blue-600 hover:text-blue-900 flex items-center"
                          title="Mark as Delivered"
                        >
                          <CheckCircle size={18} className="mr-1" />
                          <span>Delivered</span>
                        </button>
                      </>
                    )}
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
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Delivery Person</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Customer</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {filteredOrders
                .filter(o => o.status === 'OUT_FOR_DELIVERY' || o.status === 'DELIVERED')
                .map((order) => (
                <tr key={order.id}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">#{order.id}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-700 font-semibold">{order.deliveredByName || 'Unknown'}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{order.customerName}</td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`px-2 py-1 text-xs font-semibold rounded-full ${
                      order.status === 'OUT_FOR_DELIVERY' ? 'bg-blue-100 text-blue-800' : 'bg-indigo-100 text-indigo-800'
                    }`}>
                      {order.status === 'OUT_FOR_DELIVERY' ? 'Delivering...' : 'Delivered'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {activeTab === 'users' && (
        <div className="space-y-4">
          <div className="hidden md:block bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <table className="min-w-full divide-y divide-gray-100">
              <thead className="bg-gray-50/50">
                <tr>
                  <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">User Details</th>
                  <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Role</th>
                  <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Location / Address</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-100">
                {filteredUsers.map((user) => (
                  <tr key={user.id} className="hover:bg-gray-50/50 transition">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-primary-100 text-primary-700 flex items-center justify-center font-black text-sm uppercase">
                          {(user.name || 'U').charAt(0)}
                        </div>
                        <div>
                          <div className="font-bold text-gray-900">{user.name}</div>
                          <div className="text-xs text-gray-500">{user.email}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="px-2.5 py-1 bg-gray-100 text-gray-600 rounded-lg text-[10px] font-black uppercase tracking-wider">
                        {user.role?.name || user.role}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-500">
                      <div className="flex items-start gap-2 max-w-xs">
                        <MapPin size={16} className="text-gray-400 mt-0.5 shrink-0" />
                        <span className="truncate">{user.address || 'No address provided'}</span>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="md:hidden space-y-4">
            {filteredUsers.map((user) => (
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
                  <span className="px-2.5 py-1 bg-gray-100 text-gray-600 rounded-lg text-[10px] font-black uppercase tracking-wider">
                    {user.role?.name || user.role}
                  </span>
                </div>
                <div className="pt-3 border-t border-gray-50 flex items-start gap-2">
                  <MapPin size={16} className="text-gray-400 mt-0.5 shrink-0" />
                  <p className="text-xs font-medium text-gray-600 leading-relaxed">
                    {user.address || 'No address provided'}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default StaffDashboard;
