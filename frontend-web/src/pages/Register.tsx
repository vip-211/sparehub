
import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import AuthService from '../services/auth.service';
import { useLanguage } from '../context/LanguageContext';
import { ROLE_RETAILER, ROLE_MECHANIC, ROLE_WHOLESALER, ROLE_SUPER_MANAGER, ROLE_ADMIN } from '../services/constants';

const Register = () => {
  const { t } = useLanguage();
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
  const navigate = useNavigate();

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

  const handleRegister = (e: React.FormEvent) => {
    e.preventDefault();
    if (!otpSent) {
      setMessage(t('login.otp') + ' ' + t('common.error'));
      return;
    }
    setMessage('');
    setLoading(true);

    AuthService.register(name, email, password, role, phone, '', otp, address).then(
      () => {
        setMessage(`${t('common.success')}! Welcome ${name}.`);
        setLoading(false);
        setTimeout(() => {
          navigate('/login');
        }, 2000);
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

  return (
    <div className="max-w-xl mx-auto bg-white p-6 sm:p-8 rounded-xl shadow-md mt-6 sm:mt-10 border border-gray-100">
      <h2 className="text-2xl font-bold mb-6 text-center text-gray-800">{t('reg.title')}</h2>
      <form onSubmit={handleRegister}>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="mb-4">
            <label className="block text-gray-700 font-medium mb-2">{t('reg.name')}</label>
            <input
              type="text"
              className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
            />
          </div>
          <div className="mb-4">
            <label className="block text-gray-700 font-medium mb-2">{t('reg.email')}</label>
            <input
              type="email"
              className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="mb-4">
            <label className="block text-gray-700 font-medium mb-2">Phone Number</label>
            <input
              type="tel"
              className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              required
            />
          </div>
          <div className="mb-4">
            <label className="block text-gray-700 font-medium mb-2">{t('reg.password')}</label>
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 pr-10"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                minLength={6}
              />
              <button
                type="button"
                className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-500 hover:text-gray-700"
                onClick={() => setShowPassword(!showPassword)}
              >
                {showPassword ? (
                  <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                ) : (
                  <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l18 18" />
                  </svg>
                )}
              </button>
            </div>
          </div>
          <div className="mb-4">
            <label className="block text-gray-700 font-medium mb-2">{t('reg.location')}</label>
            <div className="flex space-x-2">
              <button
                type="button"
                onClick={handleSendOtp}
                className="w-full bg-primary-100 text-primary-700 px-4 py-2 rounded-lg hover:bg-primary-200 transition text-sm font-medium"
                disabled={loading || !email || !email.includes('@')}
              >
                {otpSent ? t('login.resendOtp') : t('login.sendOtp')}
              </button>
            </div>
          </div>
        </div>
        {otpSent && (
          <div className="mb-4">
            <label className="block text-gray-700 font-medium mb-2">{t('login.otp')}</label>
            <input
              type="text"
              className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              value={otp}
              onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
              required
              placeholder="6-digit OTP"
            />
          </div>
        )}
        <div className="mb-4">
          <label className="block text-gray-700 font-medium mb-2">{t('reg.role')}</label>
          <select
            className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
            value={role}
            onChange={(e) => setRole(e.target.value)}
          >
            <option value={ROLE_WHOLESALER}>{t('role.wholesaler')}</option>
            <option value={ROLE_RETAILER}>{t('role.retailer')}</option>
            <option value={ROLE_MECHANIC}>{t('role.mechanic')}</option>
            <option value={ROLE_SUPER_MANAGER}>{t('role.admin')}</option>
            <option value={ROLE_ADMIN}>{t('role.admin')}</option>
          </select>
        </div>
        <div className="mb-6">
          <label className="block text-gray-700 font-medium mb-2">{t('reg.address')}</label>
          <textarea
            className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            rows={3}
          ></textarea>
        </div>
        <button
          type="submit"
          className="w-full bg-primary-600 text-white py-2.5 rounded-lg font-bold hover:bg-primary-700 transition"
          disabled={loading}
        >
          {loading ? t('common.loading') : t('reg.button')}
        </button>
      </form>
      {message && (
        <div className={`mt-4 p-3 rounded-lg text-sm text-center border-l-4 ${message.includes(t('common.success')) ? 'bg-green-50 border-green-400 text-green-700' : 'bg-red-50 border-red-400 text-red-700'}`}>
          {message}
        </div>
      )}
      <p className="mt-8 text-center text-sm text-gray-600">
        {t('reg.hasAccount')}{' '}
        <Link to="/login" className="font-medium text-primary-600 hover:text-primary-500">
          {t('reg.login')}
        </Link>
      </p>
    </div>
  );
};

export default Register;
