
import api from './api';
import { ROLE_MECHANIC, ROLE_RETAILER, ROLE_WHOLESALER, ROLE_ADMIN, ROLE_STAFF, ROLE_SUPER_MANAGER } from './constants';

const normalizeRoles = (roles: any[] | undefined) => {
  if (!roles) return [];
  return roles.map(r => {
    // Handle both string roles and object roles (Spring Security)
    const roleStr = typeof r === 'string' ? r : (r.authority || r.name || String(r));
    const roleLower = roleStr.toLowerCase();
    if (roleLower === 'mechanic' || roleLower === 'role_mechanic') return ROLE_MECHANIC;
    if (roleLower === 'retailer' || roleLower === 'role_retailer') return ROLE_RETAILER;
    if (roleLower === 'wholesaler' || roleLower === 'role_wholesaler') return ROLE_WHOLESALER;
    if (roleLower === 'admin' || roleLower === 'role_admin') return ROLE_ADMIN;
    if (roleLower === 'staff' || roleLower === 'role_staff') return ROLE_STAFF;
    if (roleLower === 'supermanager' || roleLower === 'role_super_manager' || roleLower === 'super_manager') return ROLE_SUPER_MANAGER;
    return roleStr;
  });
};

const normalizeIdentifier = (identifier: string) => {
  const trimmed = identifier.trim();
  if (trimmed.includes('@')) {
    return trimmed.toLowerCase();
  }
  // If it's a phone number (only digits, or starting with +)
  const digitsOnly = trimmed.replace(/\D/g, '');
  if (digitsOnly.length >= 10) {
    // If it doesn't already have a country code (+), assume +91 (standard for this app)
    if (!trimmed.startsWith('+')) {
      // If it starts with country code without +, add +
      if (digitsOnly.length > 10 && (digitsOnly.startsWith('91'))) {
         return '+' + digitsOnly;
      }
      return '+91' + digitsOnly;
    }
  }
  return trimmed;
};

const register = async (name: string, email: string, password: string, role: string, phone: string, countryCode: string, otp: string, address: string) => {
  const normalizedEmail = email.toLowerCase().trim();
  console.log('AuthService.register called with:', { name, email: normalizedEmail, role, phone, otp });
  
  // Normalize role for request
  let finalRole = role;
  const roleLower = role.toLowerCase();
  
  // Handle both "MECHANIC" and "ROLE_MECHANIC"
  if (roleLower.includes('mechanic')) finalRole = ROLE_MECHANIC;
  else if (roleLower.includes('retailer')) finalRole = ROLE_RETAILER;
  else if (roleLower.includes('wholesaler')) finalRole = ROLE_WHOLESALER;
  else if (roleLower.includes('admin')) finalRole = ROLE_ADMIN;
  else if (roleLower.includes('staff')) finalRole = ROLE_STAFF;
  else if (roleLower.includes('supermanager') || roleLower.includes('super_manager')) finalRole = ROLE_SUPER_MANAGER;

  try {
    const response = await api.post('auth/signup', {
      name,
      email: normalizedEmail,
      password,
      role: finalRole,
      phone,
      countryCode,
      otp,
      address,
    });
    console.log('AuthService.register response:', response.data);
    return response.data;
  } catch (error) {
    console.error('AuthService.register error:', error);
    throw error;
  }
};

const sendOtp = (email: string, purpose: string = 'login') => {
  return api.post('auth/send-otp', { email: normalizeIdentifier(email), purpose });
};

const login = async (email: string, password: string) => {
  const normalizedEmail = normalizeIdentifier(email);
  const response = await api.post('auth/signin', {
    email: normalizedEmail,
    password,
  });
  if (response.data.token) {
    response.data.roles = normalizeRoles(response.data.roles);
    localStorage.setItem('user', JSON.stringify(response.data));
  }
  return response.data;
};

const loginWithOtp = async (email: string, otp: string) => {
  const normalizedEmail = normalizeIdentifier(email);
  const response = await api.post('auth/otp-login', {
    email: normalizedEmail,
    otp,
  });
  if (response.data.token) {
    response.data.roles = normalizeRoles(response.data.roles);
    localStorage.setItem('user', JSON.stringify(response.data));
  }
  return response.data;
};

const logout = () => {
  localStorage.removeItem('user');
};

const googleLogin = async (email: string, name: string) => {
  const response = await api.post('auth/google', { email: normalizeIdentifier(email), name });
  if (response.data.token) {
    response.data.roles = normalizeRoles(response.data.roles);
    localStorage.setItem('user', JSON.stringify(response.data));
  }
  return response.data;
};

const resetPassword = async (email: string, otp: string, newPassword: string) => {
  return api.post('auth/reset-password', { email: normalizeIdentifier(email), otp, newPassword });
};

const getRoles = () => {
  const user = getCurrentUser();
  return user ? user.roles : [];
};

const getCurrentUser = () => {
  try {
    const raw = localStorage.getItem('user');
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
};

const AuthService = {
  register,
  sendOtp,
  login,
  loginWithOtp,
  logout,
  googleLogin,
  resetPassword,
  getRoles,
  getCurrentUser
};

export default AuthService;
