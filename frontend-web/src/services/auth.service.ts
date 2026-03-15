
import api from './api';
import { ROLE_MECHANIC, ROLE_RETAILER, ROLE_WHOLESALER, ROLE_ADMIN, ROLE_STAFF, ROLE_SUPER_MANAGER } from './constants';

const normalizeRoles = (roles: string[] | undefined) => {
  if (!roles) return [];
  return roles.map(r => {
    const roleLower = r.toLowerCase();
    if (roleLower === 'mechanic') return ROLE_MECHANIC;
    if (roleLower === 'retailer') return ROLE_RETAILER;
    if (roleLower === 'wholesaler') return ROLE_WHOLESALER;
    if (roleLower === 'admin') return ROLE_ADMIN;
    if (roleLower === 'staff') return ROLE_STAFF;
    if (roleLower === 'supermanager') return ROLE_SUPER_MANAGER;
    return r;
  });
};

const register = (name: string, email: string, password: string, role: string, phone: string, countryCode: string, otp: string, address: string) => {
  // Normalize role for request
  let finalRole = role;
  const roleLower = role.toLowerCase();
  if (roleLower === 'mechanic') finalRole = ROLE_MECHANIC;
  else if (roleLower === 'retailer') finalRole = ROLE_RETAILER;
  else if (roleLower === 'wholesaler') finalRole = ROLE_WHOLESALER;
  else if (roleLower === 'admin') finalRole = ROLE_ADMIN;
  else if (roleLower === 'staff') finalRole = ROLE_STAFF;
  else if (roleLower === 'supermanager') finalRole = ROLE_SUPER_MANAGER;

  return api.post('/auth/signup', {
    name,
    email,
    password,
    role: finalRole,
    phone,
    countryCode,
    otp,
    address,
  });
};

const sendOtp = (email: string) => {
  return api.post('/auth/send-otp', { email });
};

const login = async (email: string, password: string) => {
  const response = await api.post('/auth/signin', {
    email,
    password,
  });
  if (response.data.token) {
    response.data.roles = normalizeRoles(response.data.roles);
    localStorage.setItem('user', JSON.stringify(response.data));
  }
  return response.data;
};

const loginWithOtp = async (email: string, otp: string) => {
  const response = await api.post('/auth/otp-login', {
    email,
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
  const response = await api.post('/auth/google', { email, name });
  if (response.data.token) {
    response.data.roles = normalizeRoles(response.data.roles);
    localStorage.setItem('user', JSON.stringify(response.data));
  }
  return response.data;
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
  getRoles,
  getCurrentUser
};

export default AuthService;
