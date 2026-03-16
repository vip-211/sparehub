
import React, { useState, useEffect } from 'react';
import { Routes, Route, Navigate, Link, useNavigate, useLocation } from 'react-router-dom';
import AuthService from './services/auth.service';
import Login from './pages/Login';
import Register from './pages/Register';
import AdminDashboard from './pages/AdminDashboard';
import StaffDashboard from './pages/StaffDashboard';
import WholesalerDashboard from './pages/WholesalerDashboard';
import OrderTracking from './pages/OrderTracking';
import Shop from './pages/Shop';
import Cart from './pages/Cart';
import { useCart } from './context/CartContext';
import { useAuth } from './context/AuthContext';
import { useLanguage } from './context/LanguageContext';
import OrderStatus from './pages/OrderStatus';
import { ROLE_ADMIN, ROLE_SUPER_MANAGER, ROLE_WHOLESALER, ROLE_STAFF } from './services/constants';
import AIChatbot from './components/AIChatbot';
import AdminCategories from './pages/AdminCategories';
import MobileDashboard from './pages/MobileDashboard';

const App: React.FC = () => {
  const { currentUser, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const { count } = useCart();
  const { language, toggleLanguage, t } = useLanguage();

  const logOut = () => {
    logout();
    navigate('/login');
  };

  const isAdminOrSuper = currentUser?.roles?.includes(ROLE_ADMIN) || currentUser?.roles?.includes(ROLE_SUPER_MANAGER);
  const isAuthPage = location.pathname === '/login' || location.pathname === '/register';

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {!isAuthPage && (
        <nav className="bg-white shadow-sm px-4 py-3 flex flex-col md:flex-row justify-between items-center space-y-3 md:space-y-0 sticky top-0 z-50">
          <div className="flex items-center justify-between w-full md:w-auto">
            <Link to="/" className="text-xl font-bold text-primary-600">
              SpareHub
            </Link>
          </div>

          <div className="flex flex-wrap justify-center items-center gap-3 md:gap-4 w-full md:w-auto">
            <div className="flex items-center bg-primary-50 px-3 py-1.5 rounded-full border border-primary-100 shadow-sm">
              <span className="text-xs font-bold text-primary-700 mr-2 uppercase">Translator</span>
              <button
                onClick={toggleLanguage}
                className="px-3 py-1 text-xs font-bold bg-white border-2 border-primary-600 rounded-lg text-primary-600 hover:bg-primary-600 hover:text-white transition-all shadow-sm"
              >
                {language === 'en' ? 'हिन्दी' : 'English'}
              </button>
            </div>
            
            {currentUser ? (
              <>
                <span className="text-gray-600 font-medium hidden sm:inline">Welcome, {currentUser.name || currentUser.email}</span>
                {isAdminOrSuper && (
                  <>
                    <Link to="/admin" className="text-gray-600 hover:text-primary-600 font-medium">
                      {t('role.admin')}
                    </Link>
                    <Link to="/admin-categories" className="text-gray-600 hover:text-primary-600 font-medium">
                      Categories
                    </Link>
                  </>
                )}
                {currentUser?.roles.includes(ROLE_WHOLESALER) && (
                  <Link to="/wholesaler" className="text-gray-600 hover:text-primary-600 font-medium">
                    {t('role.wholesaler')}
                  </Link>
                )}
                {currentUser?.roles.includes(ROLE_STAFF) && (
                  <Link to="/staff" className="text-gray-600 hover:text-primary-600 font-medium">
                    {t('role.staff')}
                  </Link>
                )}
                {!currentUser?.roles.includes(ROLE_STAFF) && (
                  <>
                    <Link to="/shop" className="text-gray-600 hover:text-primary-600 font-medium">
                      {t('shop.title')}
                    </Link>
                    <Link to="/cart" className="relative text-gray-600 hover:text-primary-600 font-medium">
                      {t('shop.cart')}
                      {count > 0 && (
                        <span className="ml-1 inline-block text-xs px-2 py-0.5 rounded-full bg-primary-600 text-white">
                          {count}
                        </span>
                      )}
                    </Link>
                  </>
                )}
                <button
                  onClick={logOut}
                  className="text-gray-600 hover:text-red-600 font-medium"
                >
                  {t('shop.logout')}
                </button>
              </>
            ) : (
              <>
                <Link to="/login" className="text-gray-600 hover:text-primary-600 font-medium">
                  {t('login.title')}
                </Link>
                <Link to="/register" className="bg-primary-600 text-white px-4 py-2 rounded-lg hover:bg-primary-700 transition font-medium">
                  {t('reg.title')}
                </Link>
              </>
            )}
          </div>
        </nav>
      )}

      <main className={`flex-grow ${!isAuthPage ? 'p-4 md:p-6 w-full max-w-7xl mx-auto' : ''}`}>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          <Route path="/dashboard" element={<MobileDashboard />} />
          <Route
            path="/track/:id"
            element={
              currentUser ? <OrderTracking /> : <Navigate to="/login" />
            }
          />
          <Route
            path="/shop"
            element={
              currentUser ? <Shop /> : <Navigate to="/login" />
            }
          />
          <Route
            path="/cart"
            element={
              currentUser ? <Cart /> : <Navigate to="/login" />
            }
          />
          <Route
            path="/order/:id"
            element={
              currentUser ? <OrderStatus /> : <Navigate to="/login" />
            }
          />
          <Route
            path="/admin/*"
            element={
              isAdminOrSuper ? (
                <AdminDashboard />
              ) : (
                <Navigate to="/login" />
              )
            }
          />
          <Route
            path="/admin-categories"
            element={
              isAdminOrSuper ? <AdminCategories /> : <Navigate to="/login" />
            }
          />
          <Route
            path="/staff/*"
            element={
              currentUser?.roles.includes(ROLE_STAFF) ? (
                <StaffDashboard />
              ) : (
                <Navigate to="/login" />
              )
            }
          />
          <Route
            path="/wholesaler/*"
            element={
              currentUser?.roles.includes(ROLE_WHOLESALER) ? (
                <WholesalerDashboard />
              ) : (
                <Navigate to="/login" />
              )
            }
          />
          <Route path="/" element={<Navigate to={currentUser ? (isAdminOrSuper ? '/admin' : (currentUser.roles?.includes(ROLE_WHOLESALER) ? '/wholesaler' : (currentUser.roles?.includes(ROLE_STAFF) ? '/staff' : '/shop'))) : '/login'} replace />} />
        </Routes>
      </main>

      {!isAuthPage && (
        <footer className="bg-white border-t border-gray-200 py-4 px-6 text-center text-gray-500 text-sm">
          © 2026 SpareHub. All rights reserved.
        </footer>
      )}
      {currentUser && <AIChatbot />}
    </div>
  );
};

export default App;
