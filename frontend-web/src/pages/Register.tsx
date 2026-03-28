import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import AuthService from '../services/auth.service';
import { useLanguage } from '../context/LanguageContext';
import { ROLE_RETAILER, ROLE_MECHANIC, ROLE_WHOLESALER, ROLE_SUPER_MANAGER, ROLE_ADMIN } from '../services/constants';
import api from '../services/api';
import { motion, AnimatePresence } from 'framer-motion';
import { 
  User, 
  Mail, 
  Phone, 
  Lock, 
  Eye, 
  EyeOff, 
  UserPlus, 
  MapPin, 
  Smartphone,
  ShieldCheck,
  ArrowRight,
  AlertCircle,
  CheckCircle2,
  Languages,
  Briefcase
} from 'lucide-react';

const Register = () => {
  const { t, language, toggleLanguage } = useLanguage();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [role, setRole] = useState(ROLE_WHOLESALER);
  const [otp, setOtp] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [address, setAddress] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);
  const [allowedRoles, setAllowedRoles] = useState<string[]>([ROLE_WHOLESALER, ROLE_RETAILER, ROLE_MECHANIC]);
  const navigate = useNavigate();

  useEffect(() => {
    const fetchSettings = async () => {
      try {
        const res = await api.get('admin/settings');
        const s = res.data as Array<{ settingKey: string; settingValue: string }>;
        const allowed = s.find(x => x.settingKey === 'ALLOWED_REG_ROLES')?.settingValue;
        if (allowed) {
          const parts = allowed.split(',').map(p => p.trim()).filter(Boolean);
          setAllowedRoles(parts);
          if (!parts.includes(role)) {
            setRole(parts[0] || ROLE_MECHANIC);
          }
        }
      } catch {
        // ignore
      }
    };
    fetchSettings();
  }, []);

  const handleSendOtp = async () => {
    if (!email || !email.includes('@')) {
      setMessage(t('login.email') + ' ' + t('common.error'));
      return;
    }
    setLoading(true);
    try {
      await AuthService.sendOtp(email, 'signup');
      setOtpSent(true);
      setMessage(t('login.otp') + ' ' + t('common.success'));
    } catch (err: any) {
      const resMessage =
        (err.response &&
          err.response.data &&
          err.response.data.message) ||
        err.message ||
        err.toString();
      setMessage(`${t('common.error')}: ${resMessage}`);
    } finally {
      setLoading(false);
    }
  };

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    console.log('handleRegister started. otpSent:', otpSent, 'otp:', otp);
    
    if (!otpSent) {
      setMessage('Please click "Send OTP" first.');
      return;
    }
    
    if (!otp || otp.length !== 6) {
      setMessage('Please enter the 6-digit OTP you received.');
      return;
    }

    if (!name || !email || !password || !phone) {
      setMessage('Please fill in all required fields.');
      return;
    }

    setMessage('');
    setLoading(true);

    try {
      console.log('Registering user with:', { name, email, role, phone, otp });
      const result = await AuthService.register(name, email, password, role, phone, '', otp, address);
      console.log('Registration success result:', result);
      
      setMessage(`${t('common.success')}! Registration completed successfully. Redirecting...`);
      setLoading(false);
      setTimeout(() => {
        navigate('/pending-approval');
      }, 3000);
    } catch (error: any) {
      console.error('Registration error details:', error);
      const resMessage =
        (error.response &&
          error.response.data &&
          error.response.data.message) ||
        error.message ||
        error.toString();

      setLoading(false);
      setMessage(`Registration failed: ${resMessage}`);
    }
  };

  const handleGoogleLogin = async () => {
    setMessage('');
    setLoading(true);
    try {
      setMessage('Google SSO is currently being updated. Please use the form above.');
    } catch (error: any) {
      setMessage(error.message || 'Google login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#F8FAFC] flex flex-col items-center justify-center py-12 px-4 sm:px-6 lg:px-8 relative overflow-hidden">
      {/* Background decorative elements */}
      <div className="absolute top-0 left-0 w-full h-full overflow-hidden -z-10">
        <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-primary-100/30 rounded-full blur-3xl"></div>
        <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] bg-primary-100/20 rounded-full blur-3xl"></div>
      </div>

      {/* Language Toggle */}
      <motion.button
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        onClick={toggleLanguage}
        className="absolute top-6 right-6 flex items-center gap-2 px-4 py-2 bg-white border border-gray-200 rounded-full shadow-sm hover:shadow-md transition-all text-sm font-medium text-gray-700 z-10"
      >
        <Languages size={18} className="text-primary-600" />
        {language === 'en' ? 'हिन्दी' : 'English'}
      </motion.button>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="max-w-2xl w-full space-y-8"
      >
        <div className="text-center">
          <motion.div 
            initial={{ scale: 0.5, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ delay: 0.2 }}
            className="mx-auto h-24 w-24 bg-white rounded-3xl flex items-center justify-center shadow-xl shadow-gray-200 mb-6 overflow-hidden border border-gray-100"
          >
            <img src="/logo.png" alt="Logo" className="w-full h-full object-contain p-2" />
          </motion.div>
          <h2 className="text-4xl font-black text-gray-900 tracking-tight">
            {t('reg.title')}
          </h2>
          <p className="mt-3 text-gray-500 font-medium">
            {t('reg.subtitle')}
          </p>
        </div>

        <div className="bg-white p-8 sm:p-10 rounded-[2.5rem] border border-gray-100 shadow-2xl shadow-gray-200/50">
          <form className="space-y-6" onSubmit={handleRegister}>
            <AnimatePresence mode="wait">
              {message && (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  exit={{ opacity: 0, height: 0 }}
                  className={`p-4 rounded-2xl text-sm flex items-center gap-3 ${
                    message.includes(t('common.success')) 
                      ? 'bg-green-50 text-green-700 border border-green-100' 
                      : 'bg-red-50 text-red-700 border border-red-100'
                  }`}
                >
                  {message.includes(t('common.success')) ? <CheckCircle2 size={18} /> : <AlertCircle size={18} />}
                  <span className="font-medium">{message}</span>
                </motion.div>
              )}
            </AnimatePresence>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Full Name */}
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1 block">
                  {t('reg.name')}
                </label>
                <div className="relative group">
                  <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-gray-400 group-focus-within:text-primary-600 transition-colors">
                    <User size={18} />
                  </div>
                  <input
                    type="text"
                    className="block w-full pl-11 pr-4 py-3.5 bg-gray-50 border border-gray-100 text-gray-900 text-sm rounded-2xl focus:ring-2 focus:ring-primary-500 focus:border-transparent focus:bg-white transition-all outline-none font-medium"
                    placeholder="John Doe"
                    value={name}
                    onChange={(e) => setName(e.target.value.slice(0, 100))}
                    required
                  />
                </div>
              </div>

              {/* Email */}
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1 block">
                  {t('reg.email')}
                </label>
                <div className="relative group">
                  <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-gray-400 group-focus-within:text-primary-600 transition-colors">
                    <Mail size={18} />
                  </div>
                  <input
                    type="email"
                    className="block w-full pl-11 pr-4 py-3.5 bg-gray-50 border border-gray-100 text-gray-900 text-sm rounded-2xl focus:ring-2 focus:ring-primary-500 focus:border-transparent focus:bg-white transition-all outline-none font-medium"
                    placeholder="name@company.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value.slice(0, 100))}
                    required
                  />
                </div>
              </div>

              {/* Phone */}
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1 block">
                  {t('reg.phone')}
                </label>
                <div className="relative group">
                  <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-gray-400 group-focus-within:text-primary-600 transition-colors">
                    <Phone size={18} />
                  </div>
                  <input
                    type="tel"
                    className="block w-full pl-11 pr-4 py-3.5 bg-gray-50 border border-gray-100 text-gray-900 text-sm rounded-2xl focus:ring-2 focus:ring-primary-500 focus:border-transparent focus:bg-white transition-all outline-none font-medium"
                    placeholder="+91 9876543210"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value.slice(0, 20))}
                    required
                  />
                </div>
              </div>

              {/* Password */}
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1 block">
                  {t('reg.password')}
                </label>
                <div className="relative group">
                  <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-gray-400 group-focus-within:text-primary-600 transition-colors">
                    <Lock size={18} />
                  </div>
                  <input
                    type={showPassword ? 'text' : 'password'}
                    className="block w-full pl-11 pr-12 py-3.5 bg-gray-50 border border-gray-100 text-gray-900 text-sm rounded-2xl focus:ring-2 focus:ring-primary-500 focus:border-transparent focus:bg-white transition-all outline-none font-medium"
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    minLength={6}
                  />
                  <button
                    type="button"
                    className="absolute inset-y-0 right-0 pr-4 flex items-center text-gray-400 hover:text-gray-600 transition-colors"
                    onClick={() => setShowPassword(!showPassword)}
                  >
                    {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </div>
              </div>

              {/* Role Selection */}
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1 block">
                  {t('reg.role')}
                </label>
                <div className="relative group">
                  <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-gray-400 group-focus-within:text-primary-600 transition-colors">
                    <Briefcase size={18} />
                  </div>
                  <select
                    className="block w-full pl-11 pr-4 py-3.5 bg-gray-50 border border-gray-100 text-gray-900 text-sm rounded-2xl focus:ring-2 focus:ring-primary-500 focus:border-transparent focus:bg-white transition-all outline-none font-medium appearance-none"
                    value={role}
                    onChange={(e) => setRole(e.target.value)}
                  >
                    {allowedRoles.includes(ROLE_WHOLESALER) && (
                      <option value={ROLE_WHOLESALER}>{t('role.wholesaler')}</option>
                    )}
                    {allowedRoles.includes(ROLE_RETAILER) && (
                      <option value={ROLE_RETAILER}>{t('role.retailer')}</option>
                    )}
                    {allowedRoles.includes(ROLE_MECHANIC) && (
                      <option value={ROLE_MECHANIC}>{t('role.mechanic')}</option>
                    )}
                    {allowedRoles.includes(ROLE_SUPER_MANAGER) && (
                      <option value={ROLE_SUPER_MANAGER}>{t('role.admin')}</option>
                    )}
                    {allowedRoles.includes(ROLE_ADMIN) && (
                      <option value={ROLE_ADMIN}>{t('role.admin')}</option>
                    )}
                  </select>
                </div>
              </div>

              {/* OTP Section */}
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1 block">
                  {t('login.otp')}
                </label>
                <div className="flex gap-2">
                  <div className="relative flex-1 group">
                    <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-gray-400 group-focus-within:text-primary-600 transition-colors">
                      <Smartphone size={18} />
                    </div>
                    <input
                      type="text"
                      className="block w-full pl-11 pr-4 py-3.5 bg-gray-50 border border-gray-100 text-gray-900 text-sm rounded-2xl focus:ring-2 focus:ring-primary-500 focus:border-transparent focus:bg-white transition-all outline-none font-medium"
                      value={otp}
                      onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                      required={otpSent}
                      placeholder="6-digit OTP"
                      disabled={!otpSent}
                    />
                  </div>
                  <button
                    type="button"
                    onClick={handleSendOtp}
                    disabled={loading || !email || !email.includes('@')}
                    className="px-5 py-2 bg-primary-50 text-primary-700 rounded-2xl hover:bg-primary-100 transition-colors font-bold text-sm whitespace-nowrap disabled:opacity-50"
                  >
                    {otpSent ? t('login.resendOtp') : t('login.sendOtp')}
                  </button>
                </div>
              </div>
            </div>

            {/* Address */}
            <div className="space-y-1.5">
              <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1 block">
                {t('reg.address')}
              </label>
              <div className="relative group">
                <div className="absolute top-4 left-4 flex items-start pointer-events-none text-gray-400 group-focus-within:text-primary-600 transition-colors">
                  <MapPin size={18} />
                </div>
                <textarea
                  className="block w-full pl-11 pr-4 py-3.5 bg-gray-50 border border-gray-100 text-gray-900 text-sm rounded-2xl focus:ring-2 focus:ring-primary-500 focus:border-transparent focus:bg-white transition-all outline-none font-medium"
                  value={address}
                  onChange={(e) => setAddress(e.target.value)}
                  rows={3}
                  placeholder="Enter your business address..."
                ></textarea>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full group relative flex items-center justify-center py-4 px-4 bg-primary-600 hover:bg-primary-700 text-white rounded-[1.25rem] font-black transition-all shadow-xl shadow-primary-200 active:scale-[0.98] disabled:opacity-70 disabled:active:scale-100"
            >
              {loading ? (
                <div className="flex items-center gap-2">
                  <div className="w-5 h-5 border-3 border-white/30 border-t-white rounded-full animate-spin"></div>
                  <span>{t('common.loading')}</span>
                </div>
              ) : (
                <div className="flex items-center gap-2">
                  <UserPlus size={20} />
                  <span>{t('reg.button')}</span>
                  <ArrowRight size={18} className="ml-1 group-hover:translate-x-1 transition-transform" />
                </div>
              )}
            </button>
          </form>

          <div className="mt-8">
            <div className="relative">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-gray-100"></div>
              </div>
              <div className="relative flex justify-center text-xs font-bold uppercase tracking-widest">
                <span className="px-4 bg-white text-gray-400">{t('login.or')}</span>
              </div>
            </div>

            <div className="mt-6">
              <button
                onClick={handleGoogleLogin}
                disabled={loading}
                className="w-full flex items-center justify-center gap-3 px-4 py-3.5 border border-gray-200 rounded-[1.25rem] text-sm font-bold text-gray-700 bg-white hover:bg-gray-50 hover:border-gray-300 transition-all active:scale-[0.98]"
              >
                <img
                  className="h-5 w-5"
                  src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg"
                  alt="Google"
                />
                {t('login.google')}
              </button>
            </div>
          </div>
        </div>

        <p className="text-center text-sm font-medium text-gray-500">
          {t('reg.hasAccount')}{' '}
          <Link to="/login" className="text-primary-600 font-bold hover:text-primary-700 transition-colors ml-1 underline decoration-primary-200 underline-offset-4">
            {t('reg.login')}
          </Link>
        </p>
      </motion.div>
    </div>
  );
};

export default Register;
