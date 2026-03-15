
import api from './api';
import { ROLE_MECHANIC, ROLE_RETAILER, ROLE_WHOLESALER, ROLE_ADMIN, ROLE_STAFF, ROLE_SUPER_MANAGER } from './constants';

const register = (name, email, password, role, phone, countryCode, otp, address) => {
  // Normalize role
  let finalRole = role;
  if (role === 'mechanic') finalRole = ROLE_MECHANIC;
  if (role === 'retailer') finalRole = ROLE_RETAILER;
  if (role === 'wholesaler') finalRole = ROLE_WHOLESALER;
  if (role === 'admin') finalRole = ROLE_ADMIN;
  if (role === 'staff') finalRole = ROLE_STAFF;
  if (role === 'supermanager') finalRole = ROLE_SUPER_MANAGER;

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

const sendOtp = (email) => {
  return api.post('/auth/send-otp', { email });
};

const login = async (email, password) => {
  const response = await api.post('/auth/signin', {
    email,
    password,
  });
  if (response.data.token) {
    // Normalize roles in the response for consistency
    if (response.data.roles) {
      response.data.roles = response.data.roles.map(r => {
        if (r === 'mechanic') return ROLE_MECHANIC;
        if (r === 'retailer') return ROLE_RETAILER;
        if (r === 'wholesaler') return ROLE_WHOLESALER;
        if (r === 'admin') return ROLE_ADMIN;
        if (r === 'staff') return ROLE_STAFF;
        if (r === 'supermanager') return ROLE_SUPER_MANAGER;
        return r;
      });
    }
    localStorage.setItem('user', JSON.stringify(response.data));
  }
  return response.data;
};

const loginWithOtp = async (email, otp) => {
  const response = await api.post('/auth/otp-login', {
    email,
    otp,
  });
  if (response.data.token) {
    // Normalize roles in the response for consistency
    if (response.data.roles) {
      response.data.roles = response.data.roles.map(r => {
        if (r === 'mechanic') return ROLE_MECHANIC;
        if (r === 'retailer') return ROLE_RETAILER;
        if (r === 'wholesaler') return ROLE_WHOLESALER;
        if (r === 'admin') return ROLE_ADMIN;
        if (r === 'staff') return ROLE_STAFF;
        if (r === 'supermanager') return ROLE_SUPER_MANAGER;
        return r;
      });
    }
    localStorage.setItem('user', JSON.stringify(response.data));
  }
  return response.data;
};

const logout = () => {
  localStorage.removeItem('user');
};

const googleLogin = async (email, name) => {
  const response = await api.post('/auth/google', { email, name });
  if (response.data.token) {
    // Normalize roles in the response for consistency
    if (response.data.roles) {
      response.data.roles = response.data.roles.map(r => {
        if (r === 'mechanic') return ROLE_MECHANIC;
        if (r === 'retailer') return ROLE_RETAILER;
        if (r === 'wholesaler') return ROLE_WHOLESALER;
        if (r === 'admin') return ROLE_ADMIN;
        if (r === 'staff') return ROLE_STAFF;
        if (r === 'supermanager') return ROLE_SUPER_MANAGER;
        return r;
      });
    }
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
