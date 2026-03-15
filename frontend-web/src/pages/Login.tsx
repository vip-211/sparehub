
import React, { useState, useEffect } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useLanguage } from '../context/LanguageContext';
import AuthService from '../services/auth.service';
import { API_BASE_URL } from '../services/api';

const Login: React.FC = () => {
  const { t } = useLanguage();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [otp, setOtp] = useState('');
  const [isOtpLogin, setIsOtpLogin] = useState(false);
  const [otpSent, setOtpSent] = useState(false);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [showPassword, setShowPassword] = useState(false);

  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    const user = AuthService.getCurrentUser();
    if (user) {
      navigate('/dashboard');
    }
  }, [navigate]);

  const handleSendOtp = async () => {
    if (!email || !email.includes('@')) {
      setMessage(t('login.email') + ' ' + t('common.error'));
      return;
    }
    setLoading(true);
    try {
      await AuthService.sendOtp(email);
      setOtpSent(true);
      setMessage(t('login.otp') + ' ' + t('common.success'));
    } catch (err: any) {
      setMessage(err.response?.data?.message || t('common.error'));
    } finally {
      setLoading(false);
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
      () => {
        const from = (location.state as any)?.from?.pathname || '/dashboard';
        navigate(from, { replace: true });
        window.location.reload();
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

  const handleGoogleLogin = () => {
    // Redirect to backend for Google OAuth
    window.location.href = `${API_BASE_URL}/auth/google`;
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8 bg-white p-10 rounded-xl shadow-lg">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
            {t('login.title')}
          </h2>
          <p className="mt-2 text-center text-sm text-gray-600">
            {t('login.subtitle')}
          </p>
        </div>
        
        <form className="mt-8" onSubmit={handleLogin}>
          {message && (
            <div className={`p-4 rounded-lg text-sm border-l-4 ${message.includes(t('common.success')) ? 'bg-green-50 border-green-400 text-green-700' : 'bg-red-50 border-red-400 text-red-700'}`}>
              {message}
            </div>
          )}
          
          <div className="mb-4 mt-4">
            <label className="block text-gray-700 font-medium mb-2">{t('login.email')}</label>
            <input
              type="email"
              className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>

          {isOtpLogin ? (
            <div className="mb-6">
              <label className="block text-gray-700 font-medium mb-2">{t('login.otp')}</label>
              <div className="flex space-x-2">
                <input
                  type="text"
                  className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                  value={otp}
                  onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                  required={isOtpLogin}
                  placeholder="6-digit OTP"
                />
                <button
                  type="button"
                  onClick={handleSendOtp}
                  className="bg-primary-100 text-primary-700 px-3 py-2 rounded-lg hover:bg-primary-200 transition font-medium whitespace-nowrap text-sm"
                  disabled={loading || !email || !email.includes('@')}
                >
                  {otpSent ? t('login.resendOtp') : t('login.sendOtp')}
                </button>
              </div>
            </div>
          ) : (
            <div className="mb-6">
              <label className="block text-gray-700 font-medium mb-2">{t('login.password')}</label>
              <div className="relative">
                <input
                  type={showPassword ? 'text' : 'password'}
                  className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 pr-10"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required={!isOtpLogin}
                />
                <button
                  type="button"
                  className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-500 hover:text-gray-700"
                  onClick={() => setShowPassword(!showPassword)}
                >
                  {showPassword ? (
                    <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268-2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                    </svg>
                  ) : (
                    <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l18 18" />
                    </svg>
                  )}
                </button>
              </div>
            </div>
          )}

          <div className="flex items-center justify-between mb-6">
            <button
              type="button"
              onClick={() => {
                setIsOtpLogin(!isOtpLogin);
                setOtpSent(false);
                setOtp('');
              }}
              className="text-sm font-medium text-primary-600 hover:text-primary-500"
            >
              {isOtpLogin ? t('login.switchPass') : t('login.switchOtp')}
            </button>
            <Link to="/forgot-password" title={t('login.forgotPass')} className="text-sm font-medium text-primary-600 hover:text-primary-500">
              {t('login.forgotPass')}
            </Link>
          </div>

          <button
            type="submit"
            className="w-full bg-primary-600 text-white py-2.5 rounded-lg font-bold hover:bg-primary-700 transition"
            disabled={loading}
          >
            {loading ? t('common.loading') : (isOtpLogin ? t('login.otpButton') : t('login.button'))}
          </button>
        </form>

        <div className="mt-6">
          <div className="relative">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-gray-300"></div>
            </div>
            <div className="relative flex justify-center text-sm">
              <span className="px-2 bg-white text-gray-500">{t('login.or')}</span>
            </div>
          </div>

          <div className="mt-6">
            <button
              onClick={handleGoogleLogin}
              disabled={loading}
              className="w-full flex items-center justify-center px-4 py-2 border border-gray-300 rounded-lg shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 transition"
            >
              <img
                className="h-5 w-5 mr-2"
                src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg"
                alt="Google"
              />
              {t('login.google')}
            </button>
          </div>
        </div>

        <p className="mt-8 text-center text-sm text-gray-600">
          {t('login.noAccount')}{' '}
          <Link to="/register" className="font-medium text-primary-600 hover:text-primary-500">
            {t('login.register')}
          </Link>
        </p>
      </div>
    </div>
  );
};

export default Login;
