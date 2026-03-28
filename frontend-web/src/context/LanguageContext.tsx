import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';

type Language = 'en' | 'hi';

interface LanguageContextType {
  language: Language;
  toggleLanguage: () => void;
  t: (key: string) => string;
  tp: (name: string) => string;
}

const translations: Record<Language, Record<string, string>> = {
  en: {
    // Auth
    'login.title': 'Login',
    'login.welcome': 'Welcome to Parts Mitra',
    'login.email': 'Email or Mobile Number',
    'login.password': 'Password',
    'login.otp': 'OTP',
    'login.button': 'Login',
    'login.otpButton': 'Verify & Login',
    'login.sendOtp': 'Send OTP',
    'login.resendOtp': 'Resend OTP',
    'login.noAccount': "Don't have an account?",
    'login.register': 'Register here',
    'login.google': 'Sign in with Google',
    'login.switchOtp': 'Login with OTP',
    'login.switchPass': 'Login with Password',
    'login.subtitle': 'Enter your credentials to access your account',
    'login.forgotPass': 'Forgot Password?',
    'login.or': 'Or continue with',
    
    // Register
    'reg.title': 'Create Account',
    'reg.subtitle': 'Join Parts Mitra today',
    'reg.name': 'Full Name',
    'reg.email': 'Email Address',
    'reg.phone': 'Phone Number',
    'reg.password': 'Password',
    'reg.address': 'Business Address',
    'reg.role': 'Your Role',
    'reg.button': 'Register',
    'reg.hasAccount': 'Already have an account?',
    'reg.login': 'Login here',
    'reg.location': 'Capture Location',
    'reg.locationSuccess': 'Location Captured',

    // Roles
    'role.mechanic': 'Mechanic',
    'role.retailer': 'Retailer',
    'role.wholesaler': 'Wholesaler',
    'role.staff': 'Staff',
    'role.admin': 'Admin',

    // Dashboard/Shop
    'shop.title': 'Parts Mitra Shop',
    'shop.search': 'Search parts...',
    'shop.cart': 'Cart',
    'shop.empty': 'Your cart is empty.',
    'shop.orders': 'My Orders',
    'shop.profile': 'Profile',
    'shop.logout': 'Logout',
    'shop.addToCart': 'Add to Cart',
    'shop.outOfStock': 'Out of Stock',
    'shop.price': 'Price',
    'shop.stock': 'Stock',
    'shop.qty': 'Qty',
    'shop.subtotal': 'Subtotal',
    'shop.total': 'Total',
    'shop.checkout': 'Checkout',
    'shop.action': 'Action',
    'shop.placing': 'Placing Order...',
    'shop.orderSuccess': 'Order placed successfully.',
    'shop.orderFail': 'Failed to place order.',

    // Common
    'common.loading': 'Loading...',
    'common.error': 'Error',
    'common.success': 'Success',
    'common.save': 'Save',
    'common.cancel': 'Cancel',
    'common.delete': 'Delete',

    // Product Names
    'product.brakePad': 'Brake Pad',
    'product.oilFilter': 'Oil Filter',
    'product.clutchPlate': 'Clutch Plate',
    'product.sparkPlug': 'Spark Plug',
    'product.airFilter': 'Air Filter',
    'product.shockAbsorber': 'Shock Absorber',
    'product.headlight': 'Headlight',
    'product.tailLight': 'Tail Light',
    'product.sideMirror': 'Side Mirror',
    'product.wiperBlade': 'Wiper Blade',
    'product.battery': 'Battery',
    'product.tire': 'Tire',
    'product.engineOil': 'Engine Oil',
    'product.brakeFluid': 'Brake Fluid',
    'product.coolant': 'Coolant',
    'product.fuelPump': 'Fuel Pump',
    'product.radiator': 'Radiator',
    'product.alternator': 'Alternator',
    'product.starterMotor': 'Starter Motor',
    'product.brakeDisc': 'Brake Disc',
    'product.suspensionArm': 'Suspension Arm',
    'product.ballJoint': 'Ball Joint',
    'product.timingBelt': 'Timing Belt',
    'product.waterPump': 'Water Pump',
    'product.ignitionCoil': 'Ignition Coil',
    'product.wheelBearing': 'Wheel Bearing',
    'product.pistonRing': 'Piston Ring',
    'product.gasketSet': 'Gasket Set',
    'product.transmissionFluid': 'Transmission Fluid',
    'product.steeringRack': 'Steering Rack',
    'product.powerSteeringPump': 'Power Steering Pump',
    'product.absSensor': 'ABS Sensor',
    'product.oxygenSensor': 'Oxygen Sensor',
    'product.cabinFilter': 'Cabin Filter',
    'product.fuelFilter': 'Fuel Filter',
  },
  hi: {
    // Auth
    'login.title': 'लॉगिन',
    'login.welcome': 'पार्ट्स मित्रा में आपका स्वागत है',
    'login.email': 'ईमेल या मोबाइल नंबर',
    'login.password': 'पासवर्ड',
    'login.otp': 'ओटीपी (OTP)',
    'login.button': 'लॉगिन करें',
    'login.otpButton': 'सत्यापित करें और लॉगिन करें',
    'login.sendOtp': 'ओटीपी भेजें',
    'login.resendOtp': 'ओटीपी पुन: भेजें',
    'login.noAccount': 'क्या आपका खाता नहीं है?',
    'login.register': 'यहाँ पंजीकरण करें',
    'login.google': 'गूगल के साथ साइन इन करें',
    'login.switchOtp': 'ओटीपी के साथ लॉगिन करें',
    'login.switchPass': 'पासवर्ड के साथ लॉगिन करें',
    'login.subtitle': 'अपने खाते तक पहुँचने के लिए अपनी साख दर्ज करें',
    'login.forgotPass': 'पासवर्ड भूल गए?',
    'login.or': 'या इसके साथ जारी रखें',

    // Register
    'reg.title': 'खाता बनाएं',
    'reg.subtitle': 'आज ही पार्ट्स मित्रा से जुड़ें',
    'reg.name': 'पूरा नाम',
    'reg.email': 'ईमेल पता',
    'reg.phone': 'फ़ोन नंबर',
    'reg.password': 'पासवर्ड',
    'reg.address': 'व्यवसाय का पता',
    'reg.role': 'आपकी भूमिका',
    'reg.button': 'पंजीकरण करें',
    'reg.hasAccount': 'पहले से ही एक खाता है?',
    'reg.login': 'यहाँ लॉगिन करें',
    'reg.location': 'स्थान कैप्चर करें',
    'reg.locationSuccess': 'स्थान कैप्चर किया गया',

    // Roles
    'role.mechanic': 'मैकेनिक',
    'role.retailer': 'रिटेलर',
    'role.wholesaler': 'थोक विक्रेता',
    'role.staff': 'स्टाफ',
    'role.admin': 'एडमिन',

    // Dashboard/Shop
    'shop.title': 'पार्ट्स मित्रा शॉप',
    'shop.search': 'पार्ट्स खोजें...',
    'shop.cart': 'कार्ट',
    'shop.empty': 'आपकी कार्ट खाली है।',
    'shop.orders': 'मेरे ऑर्डर',
    'shop.profile': 'प्रोफ़ाइल',
    'shop.logout': 'लॉगआउट',
    'shop.addToCart': 'कार्ट में जोड़ें',
    'shop.outOfStock': 'स्टॉक में नहीं है',
    'shop.price': 'कीमत',
    'shop.stock': 'स्टॉक',
    'shop.qty': 'मात्रा',
    'shop.subtotal': 'उप-योग',
    'shop.total': 'कुल योग',
    'shop.checkout': 'चेकआउट',
    'shop.action': 'कार्य',
    'shop.placing': 'ऑर्डर दिया जा रहा है...',
    'shop.orderSuccess': 'ऑर्डर सफलतापूर्वक दिया गया।',
    'shop.orderFail': 'ऑर्डर देने में विफल।',

    // Common
    'common.loading': 'लोड हो रहा है...',
    'common.error': 'त्रुटि',
    'common.success': 'सफलता',
    'common.save': 'सहेजें',
    'common.cancel': 'रद्द करें',
    'common.delete': 'हटाएं',

    // Product Names
    'product.brakePad': 'ब्रेक पैड',
    'product.oilFilter': 'तेल फ़िल्टर',
    'product.clutchPlate': 'क्लच प्लेट',
    'product.sparkPlug': 'स्पार्क प्लग',
    'product.airFilter': 'एयर फिल्टर',
    'product.shockAbsorber': 'शॉक एब्जॉर्बर',
    'product.headlight': 'हेडलाइट',
    'product.tailLight': 'टेल लाइट',
    'product.sideMirror': 'साइड मिरर',
    'product.wiperBlade': 'वाइपर ब्लेड',
    'product.battery': 'बैटरी',
    'product.tire': 'टायर',
    'product.engineOil': 'इंजन तेल',
    'product.brakeFluid': 'ब्रेक द्रव',
    'product.coolant': 'शीतलक (Coolant)',
    'product.fuelPump': 'ईंधन पंप',
    'product.radiator': 'रेडिएटर',
    'product.alternator': 'अल्टरनेटर',
    'product.starterMotor': 'स्टार्टर मोटर',
    'product.brakeDisc': 'ब्रेक डिस्क',
    'product.suspensionArm': 'सस्पेंशन आर्म',
    'product.ballJoint': 'बॉल जॉइंट',
    'product.timingBelt': 'टाइमिंग बेल्ट',
    'product.waterPump': 'वॉटर पंप',
    'product.ignitionCoil': 'इग्निशन कॉइल',
    'product.wheelBearing': 'व्हील बेयरिंग',
    'product.pistonRing': 'पिस्टन रिंग',
    'product.gasketSet': 'गैस्केट सेट',
    'product.transmissionFluid': 'ट्रांसमिशन फ्लूइड',
    'product.steeringRack': 'स्टीयरिंग रैक',
    'product.powerSteeringPump': 'पावर स्टीयरिंग पंप',
    'product.absSensor': 'एबीएस सेंसर',
    'product.oxygenSensor': 'ऑक्सीजन सेंसर',
    'product.cabinFilter': 'कैबिन फिल्टर',
    'product.fuelFilter': 'ईंधन फिल्टर',
  }
};

const LanguageContext = createContext<LanguageContextType | undefined>(undefined);

export const LanguageProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [language, setLanguage] = useState<Language>(() => {
    return (localStorage.getItem('language') as Language) || 'en';
  });

  useEffect(() => {
    localStorage.setItem('language', language);
  }, [language]);

  const toggleLanguage = () => {
    setLanguage(prev => prev === 'en' ? 'hi' : 'en');
  };

  const t = (key: string): string => {
    return translations[language][key] || translations['en'][key] || key;
  };

  const tp = (name: string): string => {
    if (language === 'en') return name;
    
    // Normalize and search in the product mapping
    const normalized = name.toLowerCase().replace(/\s+/g, '');
    const productMap: Record<string, string> = {
      'brakepad': 'product.brakePad',
      'oilfilter': 'product.oilFilter',
      'clutchplate': 'product.clutchPlate',
      'sparkplug': 'product.sparkPlug',
      'airfilter': 'product.airFilter',
      'shockabsorber': 'product.shockAbsorber',
      'headlight': 'product.headlight',
      'taillight': 'product.tailLight',
      'sidemirror': 'product.sideMirror',
      'wiperblade': 'product.wiperBlade',
      'battery': 'product.battery',
      'tire': 'product.tire',
      'engineoil': 'product.engineOil',
      'brakefluid': 'product.brakeFluid',
      'coolant': 'product.coolant',
      'fuelpump': 'product.fuelPump',
      'radiator': 'product.radiator',
      'alternator': 'product.alternator',
      'statermotor': 'product.starterMotor',
      'startermotor': 'product.starterMotor',
      'brakedisc': 'product.brakeDisc',
      'suspensionarm': 'product.suspensionArm',
      'balljoint': 'product.ballJoint',
      'timingbelt': 'product.timingBelt',
      'waterpump': 'product.waterPump',
      'ignitioncoil': 'product.ignitionCoil',
      'wheelbearing': 'product.wheelBearing',
      'pistonring': 'product.pistonRing',
      'gasketset': 'product.gasketSet',
      'transmissionfluid': 'product.transmissionFluid',
      'steeringrack': 'product.steeringRack',
      'powersteeringpump': 'product.powerSteeringPump',
      'abssensor': 'product.absSensor',
      'oxygensensor': 'product.oxygenSensor',
      'cabinfilter': 'product.cabinFilter',
      'fuelfilter': 'product.fuelFilter',
      'clutch': 'product.clutchPlate',
      'brake': 'product.brakePad',
      'filter': 'product.oilFilter',
      'plug': 'product.sparkPlug'
    };
    
    const key = productMap[normalized];
    if (key) return t(key);
    return name;
  };

  return (
    <LanguageContext.Provider value={{ language, toggleLanguage, t, tp }}>
      {children}
    </LanguageContext.Provider>
  );
};

export const useLanguage = () => {
  const context = useContext(LanguageContext);
  if (context === undefined) {
    throw new Error('useLanguage must be used within a LanguageProvider');
  }
  return context;
};
