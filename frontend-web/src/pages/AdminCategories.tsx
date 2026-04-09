import React, { useEffect, useState } from 'react';
import api from '../services/api';
import { LayoutGrid, Settings, Trash2, Edit2, Move, Image as ImageIcon, Box } from 'lucide-react';

type Category = { 
  id: number; 
  name: string; 
  description?: string; 
  imagePath?: string; 
  imageLink?: string;
  displayOrder?: number;
  iconCodePoint?: number;
};

const AdminCategories: React.FC = () => {
  const [categories, setCategories] = useState<Category[]>([]);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [imagePath, setImagePath] = useState('');
  const [imageLink, setImageLink] = useState('');
  const [displayOrder, setDisplayOrder] = useState(0);
  const [iconCodePoint, setIconCodePoint] = useState<number | undefined>(undefined);
  const [editing, setEditing] = useState<Category | null>(null);
  const [assignPartNumber, setAssignPartNumber] = useState('');
  const [assignCategoryId, setAssignCategoryId] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const res = await api.get('categories');
      setCategories(res.data || []);
    } catch (e: any) {
      setError('Failed to load categories');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const submit = async () => {
    if (!name.trim()) return;
    setLoading(true);
    setError('');
    try {
      const payload = { 
        name, 
        description, 
        imagePath, 
        imageLink,
        displayOrder,
        iconCodePoint
      };
      
      if (editing) {
        await api.put(`categories/${editing.id}`, payload);
      } else {
        await api.post('categories', payload);
      }
      resetForm();
      await load();
    } catch {
      setError('Save failed');
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setName('');
    setDescription('');
    setImagePath('');
    setImageLink('');
    setDisplayOrder(0);
    setIconCodePoint(undefined);
    setEditing(null);
  };

  const del = async (id: number) => {
    if (!confirm('Delete this category?')) return;
    setLoading(true);
    setError('');
    try {
      await api.delete(`categories/${id}`);
      await load();
    } catch {
      setError('Delete failed');
    } finally {
      setLoading(false);
    }
  };

  const assign = async () => {
    const pn = assignPartNumber.trim();
    const cid = Number(assignCategoryId);
    if (!pn || !cid) return;
    setLoading(true);
    setError('');
    try {
      // Search for product by part number
      const searchRes = await api.get(`/products/search?query=${encodeURIComponent(pn)}&size=1`);
      const products = searchRes.data.content || [];
      const product = products.find((p: any) => p.partNumber.toLowerCase() === pn.toLowerCase());
      
      if (!product) throw new Error('Product not found with this part number');
      
      const body = { ...product, categoryId: cid };
      await api.put(`/products/${product.id}`, body);
      setAssignPartNumber('');
      setAssignCategoryId('');
      alert('Category assigned to product successfully');
    } catch (e: any) {
      setError(e.response?.data?.message || e.message || 'Assign failed');
    } finally {
      setLoading(false);
    }
  };

  const renderCategory = (c: Category) => {
    return (
      <div key={c.id} className="p-3 rounded border border-gray-200 flex items-center justify-between mb-2 bg-white">
        <div>
          <div className="font-bold flex items-center gap-2">
            {c.name}
          </div>
          {c.description && <div className="text-sm text-gray-500">{c.description}</div>}
        </div>
        <div className="flex gap-2">
            <button 
              onClick={(e) => { 
                e.preventDefault();
                e.stopPropagation();
                setEditing(c); 
                setName(c.name); 
                setDescription(c.description || ''); 
                setImagePath(c.imagePath || ''); 
                setImageLink(c.imageLink || '');
                setDisplayOrder(c.displayOrder || 0);
                setIconCodePoint(c.iconCodePoint);
                window.scrollTo({ top: 0, behavior: 'smooth' });
              }} 
              className="p-2 rounded-lg bg-primary-50 text-primary-700 hover:bg-primary-100 transition-all"
            >
              <Edit2 size={18} />
            </button>
            <button 
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                del(c.id);
              }} 
              className="p-2 rounded-lg bg-red-50 text-red-600 hover:bg-red-100 transition-all"
            >
              <Trash2 size={18} />
            </button>
          </div>
      </div>
    );
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Category Management</h1>
      </div>
      
      {error && <div className="p-4 rounded-xl bg-red-50 text-red-700 border border-red-100 font-medium">{error}</div>}
      
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <div className="bg-white p-6 rounded-2xl border border-gray-200 shadow-sm">
            <h2 className="text-lg font-bold mb-4 text-gray-800">{editing ? 'Edit Category' : 'Create New Category'}</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="md:col-span-2 space-y-1">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1">Name</label>
                <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Category name" className="w-full border border-gray-200 rounded-xl px-4 py-2.5 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none transition-all" />
              </div>
              <div className="md:col-span-2 space-y-1">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1">Description</label>
                <input value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Short description" className="w-full border border-gray-200 rounded-xl px-4 py-2.5 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none transition-all" />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1">Internal Image Path</label>
                <input value={imagePath} onChange={(e) => setImagePath(e.target.value)} placeholder="e.g. uploads/cat1.png" className="w-full border border-gray-200 rounded-xl px-4 py-2.5 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none transition-all" />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1">External Image Link</label>
                <input value={imageLink} onChange={(e) => setImageLink(e.target.value)} placeholder="https://..." className="w-full border border-gray-200 rounded-xl px-4 py-2.5 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none transition-all" />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1">Display Order</label>
                <input type="number" value={displayOrder} onChange={(e) => setDisplayOrder(parseInt(e.target.value) || 0)} placeholder="0" className="w-full border border-gray-200 rounded-xl px-4 py-2.5 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none transition-all" />
              </div>
              <div className="md:col-span-2 space-y-1">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1">Material Icon Code Point</label>
                <div className="flex gap-4 items-center">
                  <input type="number" value={iconCodePoint || ''} onChange={(e) => setIconCodePoint(e.target.value ? parseInt(e.target.value) : undefined)} placeholder="e.g. 59504" className="flex-grow border border-gray-200 rounded-xl px-4 py-2.5 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none transition-all" />
                  {iconCodePoint && (
                    <div className="w-12 h-12 bg-gray-50 rounded-xl flex items-center justify-center border border-gray-100">
                      <span className="material-icons" style={{ fontSize: '24px' }}>{String.fromCharCode(iconCodePoint)}</span>
                    </div>
                  )}
                </div>
                <p className="text-[10px] text-gray-400 font-bold uppercase tracking-widest mt-1">Leave empty to use category name as fallback icon.</p>
              </div>
            </div>
            <div className="mt-6 flex gap-3">
              <button onClick={submit} disabled={loading || !name.trim()} className="px-6 py-2.5 rounded-xl bg-primary-600 text-white font-bold hover:bg-primary-700 transition-all shadow-lg shadow-primary-200 active:scale-[0.98] disabled:opacity-50">
                {editing ? 'Update Category' : 'Create Category'}
              </button>
              {editing && (
                <button onClick={resetForm} className="px-6 py-2.5 rounded-xl bg-gray-100 text-gray-600 font-bold hover:bg-gray-200 transition-all">Cancel</button>
              )}
            </div>
          </div>

          <div className="bg-white p-6 rounded-2xl border border-gray-200 shadow-sm">
            <h2 className="text-lg font-bold mb-4 text-gray-800">All Categories</h2>
            {loading && categories.length === 0 ? (
              <div className="flex justify-center py-10">
                <div className="w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
              </div>
            ) : (
              <div className="space-y-1">
                {/* Simplified flat list showing parents, as hierarchical data needs deeper structure handling */}
                {categories.map(c => renderCategory(c))}
                {categories.length === 0 && <div className="text-center py-10 text-gray-500 font-medium">No categories found.</div>}
              </div>
            )}
          </div>
        </div>

        <div className="space-y-6">
          <div className="bg-white p-6 rounded-2xl border border-gray-200 shadow-sm">
            <h2 className="text-lg font-bold mb-4 text-gray-800">Quick Assignment</h2>
            <p className="text-sm text-gray-500 mb-4 font-medium">Assign a category to a product by its Part Number.</p>
            <div className="space-y-4">
              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1">Product Part Number</label>
                <input value={assignPartNumber} onChange={(e) => setAssignPartNumber(e.target.value)} placeholder="e.g. PN-12345" className="w-full border border-gray-200 rounded-xl px-4 py-2.5 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none transition-all" />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1">Target Category</label>
                <select value={assignCategoryId} onChange={(e) => setAssignCategoryId(e.target.value)} className="w-full border border-gray-200 rounded-xl px-4 py-2.5 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none transition-all bg-white">
                  <option value="">Select Category</option>
                  {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
              </div>
              <button onClick={assign} disabled={loading || !assignPartNumber || !assignCategoryId} className="w-full py-3 rounded-xl bg-blue-600 text-white font-bold hover:bg-blue-700 transition-all shadow-lg shadow-blue-200 active:scale-[0.98] disabled:opacity-50">
                Assign Category
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default AdminCategories;
