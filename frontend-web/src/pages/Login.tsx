import React, { useState, useEffect } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useLanguage } from '../context/LanguageContext';
import AuthService from '../services/auth.service';
import { useAuth } from '../context/AuthContext';
import { API_BASE_URL } from '../services/api';
import { motion, AnimatePresence } from 'framer-motion';
import { 
  Mail, 
  Lock, 
  Eye, 
  EyeOff, 
  LogIn, 
  Languages, 
  Smartphone,
  ShieldCheck,
  ArrowRight,
  AlertCircle,
  CheckCircle2
} from 'lucide-react';

const Login: React.FC = () => {
  const { t, language, toggleLanguage } = useLanguage();
  const { setCurrentUser } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [otp, setOtp] = useState('');
  const [isOtpLogin, setIsOtpLogin] = useState(false);
  const [otpSent, setOtpSent] = useState(false);
  const [loading, setLoading] = useState(false);
  const [sendingOtp, setSendingOtp] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const [message, setMessage] = useState('');
  const [showPassword, setShowPassword] = useState(false);

  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    // Only redirect if we have a fully authenticated user
    const user = AuthService.getCurrentUser();
    if (user && user.token) {
      if (user.status === 'PENDING') {
        navigate('/pending-approval', { replace: true });
      } else {
        const from = (location.state as any)?.from?.pathname || '/dashboard';
        navigate(from, { replace: true });
      }
    }
  }, [navigate, location.state]);

  useEffect(() => {
    let timer: any;
    if (countdown > 0) {
      timer = setInterval(() => {
        setCountdown((prev) => prev - 1);
      }, 1000);
    }
    return () => clearInterval(timer);
  }, [countdown]);

  const handleSendOtp = async () => {
    if (!email || !email.includes('@')) {
      setMessage(t('login.email') + ' ' + t('common.error'));
      return;
    }
    if (countdown > 0) return;

    setSendingOtp(true);
    setMessage('');
    try {
      const res = await AuthService.sendOtp(email, 'login');
      setOtpSent(true);
      const backendMsg = res.data?.message || (t('login.otp') + ' ' + t('common.success'));
      setMessage(backendMsg);
      setCountdown(60);
    } catch (err: any) {
      const resMessage =
        (err.response &&
          err.response.data &&
          err.response.data.message) ||
        err.message ||
        err.toString();
      
      if (err.response?.status === 429) {
        setMessage('Too many requests. Please wait a minute.');
        setCountdown(60);
      } else {
        setMessage(resMessage || t('common.error'));
      }
    } finally {
      setSendingOtp(false);
    }
  };

  const handleLogin = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setMessage('');
    setLoading(true);

    const loginPromise = isOtpLogin 
      ? AuthService.loginWithOtp(email, otp)
      : AuthService.login(email, password);

    loginPromise.then(
      (response) => {
        // response from login/loginWithOtp already includes the user data via response.data in axios
        const user = response; 
        setCurrentUser(user); // Update context
        
        if (user?.status === 'PENDING') {
          navigate('/pending-approval', { replace: true });
        } else {
          const from = (location.state as any)?.from?.pathname || '/dashboard';
          navigate(from, { replace: true });
        }
      },
      (error) => {
        const resMessage =
          (error.response &&
            error.response.data &&
            error.response.data.message) ||
          error.message ||
          error.toString();

        setLoading(false);
        setMessage(resMessage);
      }
    );
  };

  const handleGoogleLogin = async () => {
    setMessage('');
    setLoading(true);
    try {
      // In a real app, you would use a Google SDK to get the email and name.
      // Since we don't have the SDK integrated here, we'll try to use the AuthService
      // if we had the data. For now, since the backend expects a POST,
      // we'll show an error message instead of doing a GET redirect which fails.
      setMessage('Google SSO is currently being updated. Please use Email/OTP login.');
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
        className="absolute top-6 right-6 flex items-center gap-2 px-4 py-2 bg-white border border-gray-200 rounded-full shadow-sm hover:shadow-md transition-all text-sm font-medium text-gray-700"
      >
        <Languages size={18} className="text-primary-600" />
        {language === 'en' ? 'हिन्दी' : 'English'}
      </motion.button>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="max-w-md w-full space-y-8"
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
            {t('login.title')}
          </h2>
          <p className="mt-3 text-gray-500 font-medium">
            {t('login.subtitle')}
          </p>
        </div>

        <div className="bg-white p-8 sm:p-10 rounded-[2.5rem] border border-gray-100 shadow-2xl shadow-gray-200/50">
          <form className="space-y-6" onSubmit={handleLogin}>
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
            
            <div className="space-y-5">
              <div className="relative group">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1 mb-1.5 block">
                  {t('login.email')}
                </label>
                <div className="relative">
                  <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-gray-400 group-focus-within:text-primary-600 transition-colors">
                    <Mail size={18} />
                  </div>
                  <input
                    type="text"
                    className="block w-full pl-11 pr-4 py-3.5 bg-gray-50 border border-gray-100 text-gray-900 text-sm rounded-2xl focus:ring-2 focus:ring-primary-500 focus:border-transparent focus:bg-white transition-all outline-none font-medium"
                    placeholder="Email or Mobile Number"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                  />
                </div>
              </div>

              {isOtpLogin ? (
                <motion.div
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  className="space-y-1.5"
                >
                  <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1 block">
                    {t('login.otp')}
                  </label>
                  <div className="flex gap-2">
                    <div className="relative flex-1">
                      <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-gray-400">
                        <Smartphone size={18} />
                      </div>
                      <input
                        type="text"
                        className="block w-full pl-11 pr-4 py-3.5 bg-gray-50 border border-gray-100 text-gray-900 text-sm rounded-2xl focus:ring-2 focus:ring-primary-500 focus:border-transparent focus:bg-white transition-all outline-none font-medium"
                        value={otp}
                        onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                        required={isOtpLogin}
                        placeholder="6-digit OTP"
                      />
                    </div>
                    <button
                      type="button"
                      onClick={handleSendOtp}
                      disabled={sendingOtp || loading || countdown > 0 || !email || !email.includes('@')}
                      className="px-5 py-2 bg-primary-50 text-primary-700 rounded-2xl hover:bg-primary-100 transition-colors font-bold text-sm whitespace-nowrap disabled:opacity-50 flex items-center gap-2"
                    >
                      {sendingOtp ? (
                        <div className="w-4 h-4 border-2 border-primary-700/30 border-t-primary-700 rounded-full animate-spin"></div>
                      ) : null}
                      {countdown > 0 ? `Wait ${countdown}s` : (otpSent ? t('login.resendOtp') : t('login.sendOtp'))}
                    </button>
                  </div>
                </motion.div>
              ) : (
                <motion.div
                  initial={{ opacity: 0, x: 10 }}
                  animate={{ opacity: 1, x: 0 }}
                  className="relative group"
                >
                  <label className="text-xs font-bold text-gray-500 uppercase tracking-wider ml-1 mb-1.5 block">
                    {t('login.password')}
                  </label>
                  <div className="relative">
                    <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-gray-400 group-focus-within:text-primary-600 transition-colors">
                      <Lock size={18} />
                    </div>
                    <input
                      type={showPassword ? 'text' : 'password'}
                      className="block w-full pl-11 pr-12 py-3.5 bg-gray-50 border border-gray-100 text-gray-900 text-sm rounded-2xl focus:ring-2 focus:ring-primary-500 focus:border-transparent focus:bg-white transition-all outline-none font-medium"
                      placeholder="••••••••"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      required={!isOtpLogin}
                    />
                    <button
                      type="button"
                      className="absolute inset-y-0 right-0 pr-4 flex items-center text-gray-400 hover:text-gray-600 transition-colors"
                      onClick={() => setShowPassword(!showPassword)}
                    >
                      {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                    </button>
                  </div>
                </motion.div>
              )}
            </div>

            <div className="flex items-center justify-between pt-1">
              <button
                type="button"
                onClick={() => {
                  setIsOtpLogin(!isOtpLogin);
                  setOtpSent(false);
                  setOtp('');
                }}
                className="text-sm font-bold text-primary-600 hover:text-primary-700 transition-colors flex items-center gap-1.5"
              >
                {isOtpLogin ? <Lock size={14} /> : <Smartphone size={14} />}
                {isOtpLogin ? t('login.switchPass') : t('login.switchOtp')}
              </button>
              <Link to="/forgot-password" title={t('login.forgotPass')} className="text-sm font-bold text-gray-400 hover:text-primary-600 transition-colors">
                {t('login.forgotPass')}
              </Link>
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
                  <LogIn size={20} />
                  <span>{isOtpLogin ? t('login.otpButton') : t('login.button')}</span>
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
          {t('login.noAccount')}{' '}
          <Link to="/register" className="text-primary-600 font-bold hover:text-primary-700 transition-colors ml-1 underline decoration-primary-200 underline-offset-4">
            {t('login.register')}
          </Link>
        </p>
      </motion.div>
    </div>
  );
};

export default Login;
