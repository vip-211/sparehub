import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import api from '../services/api';

type CartItem = {
  id?: number;
  productId: number;
  name: string;
  price: number;
  partNumber?: string;
  image?: string;
  quantity: number;
  wholesalerId?: number;
  isLocked?: boolean;
  bannerId?: number;
  offerId?: number;
};

type CartContextValue = {
  items: CartItem[];
  addItem: (item: Omit<CartItem, 'quantity' | 'isLocked' | 'bannerId' | 'offerId' | 'id'>, qty?: number, isLocked?: boolean, bannerId?: number, offerId?: number) => void;
  removeItem: (productId: number) => void;
  updateQty: (productId: number, qty: number) => void;
  reorder: (items: Omit<CartItem, 'isLocked' | 'bannerId' | 'offerId' | 'id'>[]) => void;
  clear: () => void;
  count: number;
  subtotal: number;
  total: number;
  deliveryCharge: number;
  loading: boolean;
};

const CartContext = createContext<CartContextValue | undefined>(undefined);

export const CartProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [settings, setSettings] = useState<Record<string, string>>({});
  const [items, setItems] = useState<CartItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Fetch public settings for delivery logic
    const fetchSettings = async () => {
      try {
        const res = await fetch(`${import.meta.env.VITE_API_BASE_URL || '/api'}/settings/public`);
        if (res.ok) {
          const data = await res.json();
          const mapped: Record<string, string> = {};
          data.forEach((s: any) => mapped[s.key] = s.value);
          setSettings(mapped);
        }
      } catch (e) {
        console.error('Failed to fetch settings:', e);
      }
    };
    fetchSettings();
  }, []);

  // Fetch cart from backend on mount
  const fetchCart = async () => {
    try {
      setLoading(true);
      const user = JSON.parse(localStorage.getItem('user') || '{}');
      if (user && user.token) {
        const res = await api.get('/cart');
        if (res.data && res.data.items) {
          setItems(res.data.items);
        }
      } else {
        // Fallback to localStorage if not logged in
        const raw = localStorage.getItem('cart');
        if (raw) {
          setItems(JSON.parse(raw));
        }
      }
    } catch (e) {
      console.error('Failed to fetch cart:', e)
      // Fallback to localStorage
      const raw = localStorage.getItem('cart');
      if (raw) setItems(JSON.parse(raw));
    } finally {
      setLoading(false);
    }
  };

  // Sync cart with backend when items change
  const syncCart = async (newItems: CartItem[]) => {
    try {
      const user = JSON.parse(localStorage.getItem('user') || '{}');
      if (user && user.token) {
        await api.put('/cart', newItems);
      }
    } catch (e) {
      console.error('Failed to sync cart:', e);
    }
  };

  useEffect(() => {
    fetchCart();
  }, []);

  useEffect(() => {
    // Always sync to localStorage as backup
    try {
      localStorage.setItem('cart', JSON.stringify(items));
    } catch {}
    // Also sync to backend if we have items and not loading
    if (!loading && items.length >= 0) {
      syncCart(items);
    }
  }, [items]);

  const addItem = (item: Omit<CartItem, 'quantity' | 'isLocked' | 'bannerId' | 'offerId' | 'id'>, qty: number = 1, isLocked: boolean = false, bannerId?: number, offerId?: number) => {
    setItems((prev) => {
      const idx = prev.findIndex((p) => p.productId === item.productId);
      if (idx >= 0) {
        if (prev[idx].isLocked) return prev; // Prevent updating locked items
        const next = [...prev];
        next[idx] = { ...next[idx], quantity: next[idx].quantity + qty };
        return next;
      }
      return [...prev, { ...item, quantity: qty, isLocked, bannerId, offerId }];
    });
  };

  const removeItem = (productId: number) => {
    setItems((prev) => prev.filter((p) => p.productId !== productId));
  };

  const updateQty = (productId: number, qty: number) => {
    setItems((prev) =>
      prev.map((p) => {
        if (p.productId === productId) {
          if (p.isLocked) return p;
          return { ...p, quantity: Math.max(1, qty) };
        }
        return p;
      }),
    );
  };

  const clear = async () => {
    setItems([]);
    try {
      const user = JSON.parse(localStorage.getItem('user') || '{}');
      if (user && user.token) {
        await api.delete('/cart');
      }
    } catch (e) {
      console.error('Failed to clear cart:', e);
    }
  };

  const reorder = (newItems: Omit<CartItem, 'isLocked' | 'bannerId' | 'offerId' | 'id'>[]) => {
    setItems((prev) => {
      let current = [...prev];
      newItems.forEach((item) => {
        const idx = current.findIndex((p) => p.productId === item.productId);
        if (idx >= 0) {
          if (!current[idx].isLocked) {
            current[idx] = { ...current[idx], quantity: current[idx].quantity + item.quantity };
          }
        } else {
          current.push({ ...item, isLocked: false });
        }
      });
      return current;
    });
  };

  const count = useMemo(() => items.reduce((acc, i) => acc + i.quantity, 0), [items]);
  const subtotal = useMemo(() => items.reduce((acc, i) => acc + (i.price || 0) * i.quantity, 0), [items]);

  const deliveryCharge = useMemo(() => {
    if (subtotal === 0) return 0;
    const threshold = parseFloat(settings['DELIVERY_CHARGE_THRESHOLD'] || '1000');
    const charge = parseFloat(settings['DELIVERY_CHARGE_AMOUNT'] || '20');
    return subtotal < threshold ? charge : 0;
  }, [subtotal, settings]);

  const total = useMemo(() => subtotal + deliveryCharge, [subtotal, deliveryCharge]);

  const value: CartContextValue = {
    items,
    addItem,
    removeItem,
    updateQty,
    reorder,
    clear,
    count,
    subtotal,
    total,
    deliveryCharge,
    loading
  };

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
};

export const useCart = () => {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error('useCart must be used within CartProvider');
  return ctx;
};
