import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';

type CartItem = {
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
  addItem: (item: Omit<CartItem, 'quantity' | 'isLocked' | 'bannerId' | 'offerId'>, qty?: number, isLocked?: boolean, bannerId?: number, offerId?: number) => void;
  removeItem: (productId: number) => void;
  updateQty: (productId: number, qty: number) => void;
  reorder: (items: Omit<CartItem, 'isLocked' | 'bannerId' | 'offerId'>[]) => void;
  clear: () => void;
  count: number;
  total: number;
};

const CartContext = createContext<CartContextValue | undefined>(undefined);

export const CartProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [items, setItems] = useState<CartItem[]>(() => {
    try {
      const raw = localStorage.getItem('cart');
      return raw ? JSON.parse(raw) : [];
    } catch {
      return [];
    }
  });

  useEffect(() => {
    try {
      localStorage.setItem('cart', JSON.stringify(items));
    } catch {}
  }, [items]);

  const addItem = (item: Omit<CartItem, 'quantity' | 'isLocked' | 'bannerId' | 'offerId'>, qty: number = 1, isLocked: boolean = false, bannerId?: number, offerId?: number) => {
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

  const clear = () => setItems([]);

  const reorder = (newItems: Omit<CartItem, 'isLocked' | 'bannerId' | 'offerId'>[]) => {
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
  const total = useMemo(() => items.reduce((acc, i) => acc + i.price * i.quantity, 0), [items]);

  const value: CartContextValue = {
    items,
    addItem,
    removeItem,
    updateQty,
    reorder,
    clear,
    count,
    total,
  };

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
};

export const useCart = () => {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error('useCart must be used within CartProvider');
  return ctx;
};
