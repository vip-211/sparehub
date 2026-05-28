
import React, { useState, useEffect, useMemo } from 'react';
import api, { API_BASE_URL } from '../services/api';
import { useLanguage } from '../context/LanguageContext';
import { Search, Plus, FileText, Download, Trash2, Calendar, User, Phone, Tag, Hash, ShoppingCart, DollarSign, Percent, FileCheck, X, Upload, Eye, Camera, Loader2 } from 'lucide-react';
import Skeleton from '../components/Skeleton';
import { ROLE_ADMIN, ROLE_SUPER_MANAGER } from '../services/constants';
import AuthService from '../services/auth.service';

const Purchases = () => {
  const { tp } = useLanguage();
  const currentUser = AuthService.getCurrentUser();
  const isAdmin = currentUser?.roles?.includes(ROLE_ADMIN) || currentUser?.roles?.includes(ROLE_SUPER_MANAGER);

  if (!isAdmin) {
    window.location.href = '/dashboard';
    return null;
  }

  const [purchases, setPurchases] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [showAddForm, setShowAddForm] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [isScanning, setIsScanning] = useState(false);
  const [suggestions, setSuggestions] = useState<any[]>([]);
  const [showSuggestions, setShowSuggestions] = useState(false);

  const [newPurchase, setNewPurchase] = useState({
    supplierName: '',
    supplierMobile: '',
    invoiceNumber: '',
    purchaseDate: new Date().toISOString().split('T')[0],
    items: [
      {
        productName: '',
        partNumber: '',
        quantity: 0,
        costPrice: 0,
        sellingPrice: 0,
        gst: 0,
        totalAmount: 0
      }
    ],
    discount: 0,
    totalAmount: 0,
    quantity: 0,
    notes: '',
    billImageUrl: '',
    billPdfUrl: ''
  });

  const fetchPurchases = async () => {
    setLoading(true);
    try {
      const res = await api.get('purchases');
      setPurchases(res.data);
    } catch (err) {
      console.error('Error fetching purchases:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPurchases();
  }, []);

  useEffect(() => {
    const fetchSuggestions = async () => {
      if (searchTerm.length < 2) {
        setSuggestions([]);
        return;
      }
      try {
        const res = await api.get(`products/suggest?query=${encodeURIComponent(searchTerm)}`);
        setSuggestions(res.data || []);
      } catch (err) {
        console.error('Failed to fetch suggestions', err);
      }
    };

    const timer = setTimeout(fetchSuggestions, 300);
    return () => clearTimeout(timer);
  }, [searchTerm]);

  useEffect(() => {
    let grandTotal = 0;
    const updatedItems = newPurchase.items.map(item => {
      const qty = Number(item.quantity) || 0;
      const price = Number(item.costPrice) || 0;
      const gst = Number(item.gst) || 0;
      const itemTotal = (qty * price) + gst;
      grandTotal += itemTotal;
      return { ...item, totalAmount: itemTotal };
    });

    const finalTotal = grandTotal - (Number(newPurchase.discount) || 0);
    const totalQty = newPurchase.items.reduce((sum, item) => sum + (Number(item.quantity) || 0), 0);

    if (JSON.stringify(newPurchase.items) !== JSON.stringify(updatedItems) || newPurchase.totalAmount !== finalTotal || newPurchase.quantity !== totalQty) {
      setNewPurchase(prev => ({
        ...prev,
        items: updatedItems,
        totalAmount: finalTotal,
        quantity: totalQty
      }));
    }
  }, [newPurchase.items, newPurchase.discount]);

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!searchTerm) {
      fetchPurchases();
      return;
    }
    setLoading(true);
    try {
      const res = await api.get(`purchases/search?query=${searchTerm}`);
      setPurchases(res.data);
    } catch (err) {
      console.error('Error searching purchases:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>, type: 'image' | 'pdf') => {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploading(true);
    const formData = new FormData();
    formData.append('file', file);

    try {
      const res = await api.post('files/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      if (type === 'image') {
        setNewPurchase({ ...newPurchase, billImageUrl: res.data.url });
      } else {
        setNewPurchase({ ...newPurchase, billPdfUrl: res.data.url });
      }
    } catch (err) {
      alert('Upload failed');
    } finally {
      setUploading(false);
    }
  };

  const handleScanBill = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setIsScanning(true);
    const formData = new FormData();
    formData.append('file', file);

    try {
      const res = await api.post('purchases/scan-bill', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      
      const data = typeof res.data === 'string' ? JSON.parse(res.data) : res.data;
      
      if (data.error) {
        alert(data.error);
        return;
      }

      setNewPurchase(prev => ({
        ...prev,
        supplierName: data.supplierName || prev.supplierName,
        invoiceNumber: data.invoiceNumber || prev.invoiceNumber,
        purchaseDate: data.purchaseDate || prev.purchaseDate,
        items: data.items && data.items.length > 0 ? data.items.map((item: any) => ({
          productName: item.productName || '',
          partNumber: item.partNumber || '',
          quantity: item.quantity || 0,
          costPrice: item.costPrice || 0,
          sellingPrice: item.sellingPrice || 0,
          gst: item.gst || 0,
          totalAmount: item.totalAmount || 0
        })) : prev.items,
        discount: data.discount || 0,
        totalAmount: data.totalAmount || 0,
        notes: data.notes || `Total items detected: ${data.totalQuantity || 0}`
      }));
      
      alert('Bill scanned successfully!');
    } catch (err) {
      console.error('Scan error:', err);
      alert('Failed to scan bill. Please try again or enter manually.');
    } finally {
      setIsScanning(false);
    }
  };

  const [editingDaily, setEditingDaily] = useState<{ date: string, amount: number } | null>(null);

  const handleUpdateDailyPaid = async (date: string, amount: number) => {
    try {
      await api.put(`purchases/daily-paid?date=${date}&amount=${amount}`);
      setEditingDaily(null);
      fetchPurchases();
    } catch (err) {
      alert('Failed to update daily paid amount');
    }
  };

  const groupedPurchases = useMemo(() => {
    const groups: { [key: string]: any[] } = {};
    purchases.forEach(p => {
      const date = p.purchaseDate;
      if (!groups[date]) groups[date] = [];
      groups[date].push(p);
    });
    return Object.keys(groups).sort((a, b) => b.localeCompare(a)).map(date => ({
      date,
      items: groups[date],
      totalBought: groups[date].reduce((sum, item) => sum + (item.totalAmount || 0), 0),
      totalDaily: groups[date].reduce((sum, item) => sum + (item.dailyAmount || 0), 0),
      totalRemaining: groups[date].reduce((sum, item) => sum + (item.remainingAmount || 0), 0)
    }));
  }, [purchases]);

  const grandTotals = useMemo(() => {
    return purchases.reduce((acc, p) => ({
      totalPurchase: acc.totalPurchase + (p.totalAmount || 0),
      totalDaily: acc.totalDaily + (p.dailyAmount || 0),
      totalRemaining: acc.totalRemaining + (p.remainingAmount || 0)
    }), { totalPurchase: 0, totalDaily: 0, totalRemaining: 0 });
  }, [purchases]);

  const addItem = () => {
    setNewPurchase({
      ...newPurchase,
      items: [
        ...newPurchase.items,
        {
          productName: '',
          partNumber: '',
          quantity: 0,
          costPrice: 0,
          sellingPrice: 0,
          gst: 0,
          totalAmount: 0
        }
      ]
    });
  };

  const removeItem = (index: number) => {
    if (newPurchase.items.length === 1) return;
    const updatedItems = [...newPurchase.items];
    updatedItems.splice(index, 1);
    setNewPurchase({ ...newPurchase, items: updatedItems });
  };

  const handleItemChange = (index: number, field: string, value: any) => {
    const updatedItems = [...newPurchase.items];
    updatedItems[index] = { ...updatedItems[index], [field]: value };
    setNewPurchase({ ...newPurchase, items: updatedItems });
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaving(true);
    try {
      await api.post('purchases', newPurchase);
      setShowAddForm(false);
      resetForm();
      fetchPurchases();
    } catch (err) {
      alert('Failed to save purchase');
    } finally {
      setIsSaving(false);
    }
  };

  const resetForm = () => {
    setNewPurchase({
      supplierName: '',
      supplierMobile: '',
      invoiceNumber: '',
      purchaseDate: new Date().toISOString().split('T')[0],
      items: [
        {
          productName: '',
          partNumber: '',
          quantity: 0,
          costPrice: 0,
          sellingPrice: 0,
          gst: 0,
          totalAmount: 0
        }
      ],
      discount: 0,
    totalAmount: 0,
    quantity: 0,
    notes: '',
    billImageUrl: '',
    billPdfUrl: ''
    });
  };

  const handleDelete = async (id: number) => {
    if (!window.confirm('Are you sure you want to delete this purchase?')) return;
    try {
      await api.delete(`purchases/${id}`);
      fetchPurchases();
    } catch (err) {
      alert('Failed to delete purchase');
    }
  };

  const exportExcel = async () => {
    try {
      const res = await api.get('purchases/export/excel', { responseType: 'blob' });
      const url = window.URL.createObjectURL(new Blob([res.data]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', 'purchases.xlsx');
      document.body.appendChild(link);
      link.click();
    } catch (err) {
      alert('Failed to export Excel');
    }
  };

  const getImageUrl = (path: string) => {
    if (!path) return '';
    if (path.startsWith('http')) return path;
    const base = API_BASE_URL.endsWith('/api') ? API_BASE_URL.replace('/api', '') : API_BASE_URL;
    return `${base}${path.startsWith('/') ? '' : '/'}${path}`;
  };

  return (
    <div className="p-4 md:p-6 max-w-7xl mx-auto space-y-6">
      {/* Header Section */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-black text-gray-900 tracking-tight flex items-center gap-2">
            <ShoppingCart className="w-8 h-8 text-primary-600" />
            Purchases
          </h1>
          <p className="text-gray-500 font-medium">Manage your inventory procurement and bills</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={exportExcel}
            className="flex items-center gap-2 px-4 py-2.5 bg-emerald-50 text-emerald-700 rounded-xl font-bold hover:bg-emerald-100 transition-all border border-emerald-100"
          >
            <Download className="w-4 h-4" />
            Export Excel
          </button>
          <button
            onClick={() => setShowAddForm(true)}
            className="flex items-center gap-2 px-6 py-2.5 bg-primary-600 text-white rounded-xl font-bold hover:bg-primary-700 transition-all shadow-lg shadow-primary-200 active:scale-95"
          >
            <Plus className="w-5 h-5" />
            Add Purchase
          </button>
        </div>
      </div>

      {/* Grand Totals Summary */}
      {!loading && purchases.length > 0 && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-gradient-to-br from-primary-500 to-primary-600 rounded-3xl p-6 text-white shadow-lg shadow-primary-200">
            <div className="flex items-center gap-3 mb-2 opacity-80">
              <ShoppingCart className="w-5 h-5" />
              <span className="text-sm font-bold uppercase tracking-wider">Total Purchase</span>
            </div>
            <div className="text-3xl font-black">₹{grandTotals.totalPurchase.toLocaleString()}</div>
          </div>
          <div className="bg-gradient-to-br from-emerald-500 to-emerald-600 rounded-3xl p-6 text-white shadow-lg shadow-emerald-200">
            <div className="flex items-center gap-3 mb-2 opacity-80">
              <DollarSign className="w-5 h-5" />
              <span className="text-sm font-bold uppercase tracking-wider">Total Daily Paid</span>
            </div>
            <div className="text-3xl font-black">₹{grandTotals.totalDaily.toLocaleString()}</div>
          </div>
          <div className="bg-gradient-to-br from-rose-500 to-rose-600 rounded-3xl p-6 text-white shadow-lg shadow-rose-200">
            <div className="flex items-center gap-3 mb-2 opacity-80">
              <FileText className="w-5 h-5" />
              <span className="text-sm font-bold uppercase tracking-wider">Total Remaining</span>
            </div>
            <div className="text-3xl font-black">₹{grandTotals.totalRemaining.toLocaleString()}</div>
          </div>
        </div>
      )}

      {/* Search Bar */}
      <form onSubmit={handleSearch} className="flex gap-3">
        <div className="relative flex-1">
          <Search className="w-5 h-5 text-gray-400 absolute left-4 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            onFocus={() => setShowSuggestions(true)}
            onBlur={() => setTimeout(() => setShowSuggestions(false), 200)}
            placeholder="Search by supplier, product, or invoice number..."
            className="w-full pl-12 pr-4 py-3.5 rounded-2xl border border-gray-200 focus:outline-none focus:ring-4 focus:ring-primary-50 focus:border-primary-400 transition-all text-gray-700 font-medium shadow-sm"
          />
          
          {showSuggestions && suggestions.length > 0 && (
            <div className="absolute top-full left-0 right-0 mt-2 bg-white border border-gray-100 rounded-2xl shadow-2xl z-[100] overflow-hidden">
              {suggestions.map((s, idx) => (
                <button
                  key={idx}
                  onClick={() => {
                    setSearchTerm(s.name);
                    setShowSuggestions(false);
                  }}
                  className="w-full text-left px-5 py-4 hover:bg-primary-50 flex items-center justify-between group/item transition-colors border-b border-gray-50 last:border-0"
                >
                  <div className="flex items-center gap-4">
                    <div className="p-2 bg-gray-50 text-gray-400 group-hover/item:bg-white group-hover/item:text-primary-500 rounded-xl transition-colors">
                      <Search size={16} />
                    </div>
                    <div>
                      <div className="font-bold text-gray-900 group-hover/item:text-primary-600 transition-colors">{s.name}</div>
                      <div className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">{s.partNumber}</div>
                    </div>
                  </div>
                  <div className="flex flex-col items-end">
                    <div className="text-xs font-black text-primary-600">₹{s.price}</div>
                    <div className={`text-[9px] font-black uppercase tracking-tighter ${s.stock > 0 ? 'text-emerald-500' : 'text-rose-500'}`}>
                      {s.stock > 0 ? `${s.stock} in stock` : 'Out of Stock'}
                    </div>
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>
        <button
          type="submit"
          className="px-8 py-3.5 bg-gray-900 text-white rounded-2xl font-bold hover:bg-black transition-all active:scale-95 shadow-lg shadow-gray-200"
        >
          Search
        </button>
      </form>

      {/* Content Section */}
      <div className="bg-white rounded-3xl shadow-sm border border-gray-100 overflow-hidden">
        {loading ? (
          <div className="p-8 space-y-4">
            {[1, 2, 3].map((i) => <Skeleton key={i} className="h-20 w-full rounded-2xl" />)}
          </div>
        ) : purchases.length === 0 ? (
          <div className="p-20 text-center space-y-4">
            <div className="w-20 h-20 bg-gray-50 rounded-full flex items-center justify-center mx-auto">
              <FileText className="w-10 h-10 text-gray-300" />
            </div>
            <div>
              <h3 className="text-xl font-bold text-gray-900">No purchases found</h3>
              <p className="text-gray-500">Try searching with different terms or add a new purchase.</p>
            </div>
          </div>
        ) : (
          <div className="space-y-8">
            {groupedPurchases.map((group) => (
              <div key={group.date} className="bg-white rounded-3xl border border-gray-100 shadow-sm overflow-hidden">
                <div className="px-6 py-4 bg-gray-50/50 border-b border-gray-100 flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <Calendar className="w-5 h-5 text-primary-600" />
                    <span className="text-lg font-black text-gray-900">{group.date}</span>
                  </div>
                  <div className="flex flex-col items-end gap-2">
                      {group.totalBought > 0 && (
                        <div className="flex items-center gap-2 bg-blue-100 text-blue-700 px-4 py-1.5 rounded-full">
                          <ShoppingCart className="w-4 h-4" />
                          <span className="text-sm font-bold">Total Money: ₹{group.totalBought.toLocaleString()}</span>
                        </div>
                      )}
                      <div className="flex items-center gap-2 bg-emerald-100 text-emerald-700 px-4 py-1.5 rounded-full group/edit">
                        <DollarSign className="w-4 h-4" />
                        {editingDaily?.date === group.date ? (
                          <div className="flex items-center gap-2">
                            <input
                              type="number"
                              autoFocus
                              className="w-24 bg-white border border-emerald-300 rounded px-2 py-0.5 text-sm focus:outline-none"
                              value={editingDaily.amount}
                              onChange={(e) => setEditingDaily({ ...editingDaily, amount: Number(e.target.value) })}
                              onKeyDown={(e) => {
                                if (e.key === 'Enter') handleUpdateDailyPaid(group.date, editingDaily.amount);
                                if (e.key === 'Escape') setEditingDaily(null);
                              }}
                            />
                            <button onClick={() => handleUpdateDailyPaid(group.date, editingDaily.amount)} className="text-xs font-bold hover:underline">Save</button>
                            <button onClick={() => setEditingDaily(null)} className="text-xs font-bold hover:underline">Cancel</button>
                          </div>
                        ) : (
                          <div className="flex items-center gap-2 cursor-pointer" onClick={() => setEditingDaily({ date: group.date, amount: group.totalDaily })}>
                            <span className="text-sm font-bold">Bought Money: ₹{group.totalDaily.toLocaleString()}</span>
                            <span className="text-[10px] opacity-0 group-hover/edit:opacity-100 transition-opacity">(Click to edit)</span>
                          </div>
                        )}
                      </div>
                      {(group.totalDaily - group.totalBought) !== 0 && (
                        <div className={`flex items-center gap-2 px-4 py-1.5 rounded-full ${
                          (group.totalDaily - group.totalBought) > 0 
                            ? 'bg-emerald-100 text-emerald-700' 
                            : 'bg-rose-100 text-rose-700'
                        }`}>
                          <FileText className="w-4 h-4" />
                          <span className="text-sm font-bold">
                            Remaining: ₹{(group.totalDaily - group.totalBought).toLocaleString()}
                          </span>
                        </div>
                      )}
                    </div>
                </div>
                <div className="overflow-x-auto">
                  <table className="w-full text-left border-collapse">
                    <thead>
                      <tr className="bg-white border-b border-gray-50">
                        <th className="px-6 py-4 text-xs font-bold text-gray-400 uppercase tracking-wider">Invoice</th>
                        <th className="px-6 py-4 text-xs font-bold text-gray-400 uppercase tracking-wider">Supplier</th>
                        <th className="px-6 py-4 text-xs font-bold text-gray-400 uppercase tracking-wider">Product</th>
                        <th className="px-6 py-4 text-xs font-bold text-gray-400 uppercase tracking-wider">Amount</th>
                        <th className="px-6 py-4 text-xs font-bold text-gray-400 uppercase tracking-wider">Daily / Remaining</th>
                        <th className="px-6 py-4 text-xs font-bold text-gray-400 uppercase tracking-wider">Bills</th>
                        <th className="px-6 py-4 text-xs font-bold text-gray-400 uppercase tracking-wider text-right">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-50">
                      {group.items.map((p) => (
                        <React.Fragment key={p.id}>
                          {p.items && p.items.length > 0 ? (
                            p.items.map((item: any, idx: number) => (
                              <tr key={`${p.id}-${idx}`} className="hover:bg-gray-50/50 transition-colors group">
                                {idx === 0 && (
                                  <>
                                    <td className="px-6 py-4" rowSpan={p.items.length}>
                                      <span className="text-sm font-bold text-gray-900">#{p.invoiceNumber}</span>
                                    </td>
                                    <td className="px-6 py-4" rowSpan={p.items.length}>
                                      <div className="flex flex-col">
                                        <span className="text-sm font-bold text-gray-900">{p.supplierName}</span>
                                        <span className="text-xs font-medium text-gray-400">{p.supplierMobile}</span>
                                      </div>
                                    </td>
                                  </>
                                )}
                                <td className="px-6 py-4">
                                  <div className="flex flex-col">
                                    <span className="text-sm font-bold text-gray-900">{item.productName}</span>
                                    <span className="text-xs font-medium text-primary-600 bg-primary-50 px-2 py-0.5 rounded-md inline-block w-fit">
                                      {item.partNumber}
                                    </span>
                                  </div>
                                </td>
                                <td className="px-6 py-4">
                                  <div className="flex flex-col">
                                    <span className="text-sm font-black text-gray-900">₹{item.totalAmount?.toLocaleString()}</span>
                                    <span className="text-[10px] font-bold text-gray-400 uppercase tracking-tighter">
                                      {item.quantity} x ₹{item.costPrice} + ₹{item.gst} GST
                                    </span>
                                  </div>
                                </td>
                                {idx === 0 && (
                                  <>
                                    <td className="px-6 py-4" rowSpan={p.items.length}>
                                      <div className="flex flex-col gap-1">
                                          {p.dailyAmount > 0 && (
                                              <span className="text-xs font-bold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-md w-fit">
                                                  Daily: ₹{p.dailyAmount.toLocaleString()}
                                              </span>
                                          )}
                                          {p.remainingAmount > 0 && (
                                              <span className="text-xs font-bold text-red-600 bg-red-50 px-2 py-0.5 rounded-md w-fit">
                                                  Remaining: ₹{p.remainingAmount.toLocaleString()}
                                              </span>
                                          )}
                                          {p.discount > 0 && (
                                              <span className="text-xs font-bold text-blue-600 bg-blue-50 px-2 py-0.5 rounded-md w-fit">
                                                  Discount: ₹{p.discount.toLocaleString()}
                                              </span>
                                          )}
                                          {!(p.dailyAmount > 0) && !(p.remainingAmount > 0) && !(p.discount > 0) && (
                                              <span className="text-sm text-gray-300">-</span>
                                          )}
                                      </div>
                                    </td>
                                    <td className="px-6 py-4" rowSpan={p.items.length}>
                                      <div className="flex gap-2">
                                        {p.billImageUrl && (
                                          <a href={getImageUrl(p.billImageUrl)} target="_blank" rel="noreferrer" className="p-2 bg-blue-50 text-blue-600 rounded-lg hover:bg-blue-100 transition-colors" title="View Image">
                                            <Eye className="w-4 h-4" />
                                          </a>
                                        )}
                                        {p.billPdfUrl && (
                                          <a href={getImageUrl(p.billPdfUrl)} target="_blank" rel="noreferrer" className="p-2 bg-red-50 text-red-600 rounded-lg hover:bg-red-100 transition-colors" title="View PDF">
                                            <FileText className="w-4 h-4" />
                                          </a>
                                        )}
                                      </div>
                                    </td>
                                    <td className="px-6 py-4 text-right" rowSpan={p.items.length}>
                                      <button
                                        onClick={() => handleDelete(p.id)}
                                        className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-all opacity-0 group-hover:opacity-100"
                                      >
                                        <Trash2 className="w-5 h-5" />
                                      </button>
                                    </td>
                                  </>
                                )}
                              </tr>
                            ))
                          ) : (
                            <tr key={p.id} className="hover:bg-gray-50/50 transition-colors group">
                              <td className="px-6 py-4">
                                <span className="text-sm font-bold text-gray-900">#{p.invoiceNumber}</span>
                              </td>
                              <td className="px-6 py-4">
                                <div className="flex flex-col">
                                  <span className="text-sm font-bold text-gray-900">{p.supplierName}</span>
                                  <span className="text-xs font-medium text-gray-400">{p.supplierMobile}</span>
                                </div>
                              </td>
                              <td className="px-6 py-4" colSpan={2}>
                                <span className="text-sm text-gray-400 italic">No products recorded</span>
                              </td>
                              <td className="px-6 py-4">
                                <div className="flex flex-col gap-1">
                                    {p.dailyAmount > 0 && (
                                        <span className="text-xs font-bold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-md w-fit">
                                            Daily: ₹{p.dailyAmount.toLocaleString()}
                                        </span>
                                    )}
                                    {p.remainingAmount > 0 && (
                                        <span className="text-xs font-bold text-red-600 bg-red-50 px-2 py-0.5 rounded-md w-fit">
                                            Remaining: ₹{p.remainingAmount.toLocaleString()}
                                        </span>
                                    )}
                                    {p.discount > 0 && (
                                        <span className="text-xs font-bold text-blue-600 bg-blue-50 px-2 py-0.5 rounded-md w-fit">
                                            Discount: ₹{p.discount.toLocaleString()}
                                        </span>
                                    )}
                                    {!(p.dailyAmount > 0) && !(p.remainingAmount > 0) && !(p.discount > 0) && (
                                        <span className="text-sm text-gray-300">-</span>
                                    )}
                                </div>
                              </td>
                              <td className="px-6 py-4">
                                <div className="flex gap-2">
                                  {p.billImageUrl && (
                                    <a href={getImageUrl(p.billImageUrl)} target="_blank" rel="noreferrer" className="p-2 bg-blue-50 text-blue-600 rounded-lg hover:bg-blue-100 transition-colors" title="View Image">
                                      <Eye className="w-4 h-4" />
                                    </a>
                                  )}
                                  {p.billPdfUrl && (
                                    <a href={getImageUrl(p.billPdfUrl)} target="_blank" rel="noreferrer" className="p-2 bg-red-50 text-red-600 rounded-lg hover:bg-red-100 transition-colors" title="View PDF">
                                      <FileText className="w-4 h-4" />
                                    </a>
                                  )}
                                </div>
                              </td>
                              <td className="px-6 py-4 text-right">
                                <button
                                  onClick={() => handleDelete(p.id)}
                                  className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-all opacity-0 group-hover:opacity-100"
                                >
                                  <Trash2 className="w-5 h-5" />
                                </button>
                              </td>
                            </tr>
                          )}
                        </React.Fragment>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Add Form Modal */}
      {showAddForm && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-[100] flex items-center justify-center p-4">
          <div className="bg-white rounded-[2rem] w-full max-w-4xl max-h-[90vh] overflow-hidden shadow-2xl flex flex-col">
            <div className="px-8 py-6 border-b border-gray-100 flex items-center justify-between bg-gray-50/50">
              <div>
                <h2 className="text-2xl font-black text-gray-900">Add New Purchase</h2>
                <p className="text-sm text-gray-500 font-medium">Record a new procurement entry</p>
              </div>
              <button onClick={() => setShowAddForm(false)} className="p-2 hover:bg-white rounded-full transition-colors border border-transparent hover:border-gray-200">
                <X className="w-6 h-6 text-gray-400" />
              </button>
            </div>

            <form onSubmit={handleSave} className="flex-grow overflow-y-auto p-8 space-y-8">
              {/* Supplier Info Section */}
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <h3 className="text-xs font-black text-gray-400 uppercase tracking-[0.2em] flex items-center gap-2">
                    <User className="w-3 h-3" /> Supplier Information
                  </h3>
                  <div className="flex items-center gap-3">
                    <label className={`flex items-center gap-2 px-3 py-1.5 bg-emerald-50 text-emerald-600 rounded-lg font-bold hover:bg-emerald-100 transition-all text-xs cursor-pointer ${isScanning ? 'opacity-50 cursor-not-allowed' : ''}`}>
                      {isScanning ? <Loader2 className="w-4 h-4 animate-spin" /> : <Camera className="w-4 h-4" />}
                      {isScanning ? 'Scanning...' : 'Scan Bill Photo'}
                      <input type="file" accept="image/*" className="hidden" onChange={handleScanBill} disabled={isScanning} />
                    </label>
                    <button
                      type="button"
                      onClick={addItem}
                      className="flex items-center gap-2 px-3 py-1.5 bg-primary-50 text-primary-600 rounded-lg font-bold hover:bg-primary-100 transition-all text-xs"
                    >
                      <Plus className="w-4 h-4" />
                      Add Another Product
                    </button>
                  </div>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                  <div className="space-y-2">
                    <label className="text-sm font-bold text-gray-700 ml-1">Supplier Name *</label>
                    <div className="relative">
                      <User className="w-4 h-4 text-gray-400 absolute left-4 top-1/2 -translate-y-1/2" />
                      <input
                        required
                        value={newPurchase.supplierName}
                        onChange={(e) => setNewPurchase({ ...newPurchase, supplierName: e.target.value })}
                        className="w-full pl-11 pr-4 py-3 rounded-xl border border-gray-200 focus:ring-4 focus:ring-primary-50 focus:border-primary-400 outline-none transition-all font-medium"
                        placeholder="e.g. Bharat Spares"
                      />
                    </div>
                  </div>
                  <div className="space-y-2">
                    <label className="text-sm font-bold text-gray-700 ml-1">Mobile Number</label>
                    <div className="relative">
                      <Phone className="w-4 h-4 text-gray-400 absolute left-4 top-1/2 -translate-y-1/2" />
                      <input
                        value={newPurchase.supplierMobile}
                        onChange={(e) => setNewPurchase({ ...newPurchase, supplierMobile: e.target.value })}
                        className="w-full pl-11 pr-4 py-3 rounded-xl border border-gray-200 focus:ring-4 focus:ring-primary-50 focus:border-primary-400 outline-none transition-all font-medium"
                        placeholder="10 digit mobile"
                      />
                    </div>
                  </div>
                  <div className="space-y-2">
                    <label className="text-sm font-bold text-gray-700 ml-1">Invoice Number *</label>
                    <div className="relative">
                      <Hash className="w-4 h-4 text-gray-400 absolute left-4 top-1/2 -translate-y-1/2" />
                      <input
                        required
                        value={newPurchase.invoiceNumber}
                        onChange={(e) => setNewPurchase({ ...newPurchase, invoiceNumber: e.target.value })}
                        className="w-full pl-11 pr-4 py-3 rounded-xl border border-gray-200 focus:ring-4 focus:ring-primary-50 focus:border-primary-400 outline-none transition-all font-medium"
                        placeholder="INV-2024-001"
                      />
                    </div>
                  </div>
                </div>
              </div>

              {/* Items Section */}
              <div className="space-y-6">
                {newPurchase.items.map((item, index) => (
                  <div key={index} className="space-y-6 p-6 bg-gray-50/50 rounded-[2rem] border border-gray-100 relative group/item">
                    {newPurchase.items.length > 1 && (
                      <button
                        type="button"
                        onClick={() => removeItem(index)}
                        className="absolute -top-2 -right-2 p-2 bg-white text-rose-500 rounded-full shadow-md border border-rose-100 hover:bg-rose-50 transition-all opacity-0 group-hover/item:opacity-100"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    )}
                    
                    <div className="space-y-4">
                      <h3 className="text-xs font-black text-gray-400 uppercase tracking-[0.2em] flex items-center gap-2">
                        <Tag className="w-3 h-3" /> Product {index + 1}
                      </h3>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        <div className="space-y-2">
                          <label className="text-sm font-bold text-gray-700 ml-1">Product Name *</label>
                          <input
                            required
                            value={item.productName}
                            onChange={(e) => handleItemChange(index, 'productName', e.target.value)}
                            className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-4 focus:ring-primary-50 focus:border-primary-400 outline-none transition-all font-medium bg-white"
                            placeholder="e.g. Brake Pads"
                          />
                        </div>
                        <div className="space-y-2">
                          <label className="text-sm font-bold text-gray-700 ml-1">Part Number</label>
                          <input
                            value={item.partNumber}
                            onChange={(e) => handleItemChange(index, 'partNumber', e.target.value)}
                            className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-4 focus:ring-primary-50 focus:border-primary-400 outline-none transition-all font-medium bg-white"
                            placeholder="SKU-8821"
                          />
                        </div>
                      </div>
                    </div>

                    <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
                      <div className="space-y-2">
                        <label className="text-xs font-black text-gray-500 ml-1">Quantity</label>
                        <input
                          type="number"
                          required
                          value={item.quantity}
                          onChange={(e) => handleItemChange(index, 'quantity', Number(e.target.value))}
                          className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:bg-white outline-none transition-all font-bold text-lg bg-white"
                        />
                      </div>
                      <div className="space-y-2">
                        <label className="text-xs font-black text-gray-500 ml-1">Cost Price (ea)</label>
                        <div className="relative">
                          <span className="absolute left-4 top-1/2 -translate-y-1/2 font-bold text-gray-400">₹</span>
                          <input
                            type="number"
                            required
                            value={item.costPrice}
                            onChange={(e) => handleItemChange(index, 'costPrice', Number(e.target.value))}
                            className="w-full pl-8 pr-4 py-3 rounded-xl border border-gray-200 focus:bg-white outline-none transition-all font-bold text-lg bg-white"
                          />
                        </div>
                      </div>
                      <div className="space-y-2">
                        <label className="text-xs font-black text-gray-500 ml-1">GST/Tax (Total)</label>
                        <div className="relative">
                          <span className="absolute left-4 top-1/2 -translate-y-1/2 font-bold text-gray-400">₹</span>
                          <input
                            type="number"
                            value={item.gst}
                            onChange={(e) => handleItemChange(index, 'gst', Number(e.target.value))}
                            className="w-full pl-8 pr-4 py-3 rounded-xl border border-gray-200 focus:bg-white outline-none transition-all font-bold text-lg bg-white"
                          />
                        </div>
                      </div>
                      <div className="space-y-2">
                        <label className="text-xs font-black text-gray-500 ml-1">Item Total</label>
                        <div className="relative">
                          <span className="absolute left-4 top-1/2 -translate-y-1/2 font-bold text-gray-400">₹</span>
                          <input
                            readOnly
                            value={item.totalAmount}
                            className="w-full pl-8 pr-4 py-3 rounded-xl border border-gray-100 bg-gray-50 outline-none font-bold text-lg text-gray-600"
                          />
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              {/* Summary Section */}
              <div className="bg-primary-50/50 p-6 rounded-[2rem] border border-primary-100 space-y-4">
                <h3 className="text-xs font-black text-primary-400 uppercase tracking-[0.2em] flex items-center gap-2">
                  <DollarSign className="w-3 h-3" /> Final Summary
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-2">
                    <label className="text-sm font-bold text-gray-700 ml-1">Discount Amount</label>
                    <div className="relative">
                      <span className="absolute left-4 top-1/2 -translate-y-1/2 font-bold text-gray-400">₹</span>
                      <input
                        type="number"
                        value={newPurchase.discount}
                        onChange={(e) => setNewPurchase({ ...newPurchase, discount: Number(e.target.value) })}
                        className="w-full pl-8 pr-4 py-3 rounded-xl border border-gray-200 focus:ring-4 focus:ring-primary-50 focus:border-primary-400 outline-none transition-all font-bold text-lg bg-white"
                        placeholder="0"
                      />
                    </div>
                  </div>
                  <div className="space-y-2">
                    <label className="text-sm font-bold text-gray-700 ml-1">Grand Total</label>
                    <div className="relative">
                      <span className="absolute left-4 top-1/2 -translate-y-1/2 font-bold text-primary-600">₹</span>
                      <input
                        readOnly
                        value={newPurchase.totalAmount}
                        className="w-full pl-8 pr-4 py-3 rounded-xl border-2 border-primary-200 bg-white outline-none font-black text-xl text-primary-700"
                      />
                    </div>
                  </div>
                </div>
              </div>

              {/* Attachments Section */}
              <div className="space-y-4">
                <h3 className="text-xs font-black text-gray-400 uppercase tracking-[0.2em] flex items-center gap-2">
                  <FileCheck className="w-3 h-3" /> Bill Attachments
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-3">
                    <label className="text-sm font-bold text-gray-700 flex items-center gap-2">
                      <Upload className="w-4 h-4" /> Bill Image
                    </label>
                    <div className="flex items-center gap-4">
                        <input
                            type="file"
                            accept="image/*"
                            onChange={(e) => handleFileUpload(e, 'image')}
                            className="hidden"
                            id="image-upload"
                        />
                        <label
                            htmlFor="image-upload"
                            className="flex-1 border-2 border-dashed border-gray-200 rounded-2xl p-4 text-center cursor-pointer hover:border-primary-400 hover:bg-primary-50/30 transition-all"
                        >
                            {newPurchase.billImageUrl ? (
                                <span className="text-primary-600 font-bold flex items-center justify-center gap-2">
                                    <CheckCircle className="w-5 h-5" /> Image Selected
                                </span>
                            ) : (
                                <span className="text-gray-400 font-medium">Click to upload image</span>
                            )}
                        </label>
                        {newPurchase.billImageUrl && (
                            <button type="button" onClick={() => setNewPurchase({...newPurchase, billImageUrl: ''})} className="p-2 text-red-500 hover:bg-red-50 rounded-lg">
                                <Trash2 className="w-5 h-5" />
                            </button>
                        )}
                    </div>
                  </div>
                  <div className="space-y-3">
                    <label className="text-sm font-bold text-gray-700 flex items-center gap-2">
                      <FileText className="w-4 h-4" /> Bill PDF
                    </label>
                    <div className="flex items-center gap-4">
                        <input
                            type="file"
                            accept="application/pdf"
                            onChange={(e) => handleFileUpload(e, 'pdf')}
                            className="hidden"
                            id="pdf-upload"
                        />
                        <label
                            htmlFor="pdf-upload"
                            className="flex-1 border-2 border-dashed border-gray-200 rounded-2xl p-4 text-center cursor-pointer hover:border-primary-400 hover:bg-primary-50/30 transition-all"
                        >
                            {newPurchase.billPdfUrl ? (
                                <span className="text-primary-600 font-bold flex items-center justify-center gap-2">
                                    <CheckCircle className="w-5 h-5" /> PDF Selected
                                </span>
                            ) : (
                                <span className="text-gray-400 font-medium">Click to upload PDF</span>
                            )}
                        </label>
                        {newPurchase.billPdfUrl && (
                            <button type="button" onClick={() => setNewPurchase({...newPurchase, billPdfUrl: ''})} className="p-2 text-red-500 hover:bg-red-50 rounded-lg">
                                <Trash2 className="w-5 h-5" />
                            </button>
                        )}
                    </div>
                  </div>
                </div>
              </div>

              {/* Notes */}
              <div className="space-y-2">
                <label className="text-sm font-bold text-gray-700 ml-1">Notes</label>
                <textarea
                  value={newPurchase.notes}
                  onChange={(e) => setNewPurchase({ ...newPurchase, notes: e.target.value })}
                  className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-4 focus:ring-primary-50 focus:border-primary-400 outline-none transition-all font-medium min-h-[100px]"
                  placeholder="Additional details about this purchase..."
                />
              </div>

              {/* Date */}
              <div className="space-y-2">
                <label className="text-sm font-bold text-gray-700 ml-1 flex items-center gap-2">
                  <Calendar className="w-4 h-4" /> Purchase Date
                </label>
                <input
                  type="date"
                  required
                  value={newPurchase.purchaseDate}
                  onChange={(e) => setNewPurchase({ ...newPurchase, purchaseDate: e.target.value })}
                  className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-4 focus:ring-primary-50 focus:border-primary-400 outline-none transition-all font-bold"
                />
              </div>
            </form>

            <div className="px-8 py-6 border-t border-gray-100 flex items-center justify-end gap-4 bg-gray-50/50">
              <button
                type="button"
                onClick={() => setShowAddForm(false)}
                className="px-6 py-2.5 text-gray-600 font-bold hover:text-gray-900 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                disabled={isSaving || uploading}
                className="px-10 py-2.5 bg-primary-600 text-white rounded-xl font-bold hover:bg-primary-700 transition-all shadow-lg shadow-primary-100 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
              >
                {isSaving ? 'Saving...' : 'Save Purchase'}
                {!isSaving && <FileCheck className="w-5 h-5" />}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

const CheckCircle = ({ className }: { className?: string }) => (
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={className}><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
);

export default Purchases;
