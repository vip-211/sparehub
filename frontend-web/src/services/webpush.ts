import { initializeApp } from 'firebase/app';
import { getMessaging, onMessage, getToken, isSupported } from 'firebase/messaging';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY || '',
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || '',
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || '',
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET || '',
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || '',
  appId: import.meta.env.VITE_FIREBASE_APP_ID || '',
};

export async function initWebPush() {
  try {
    const supported = await isSupported();
    if (!supported) return;
    // Guard: ensure required Firebase config is present
    const requiredKeys: Array<keyof typeof firebaseConfig> = [
      'apiKey',
      'projectId',
      'messagingSenderId',
      'appId',
    ];
    const missing = requiredKeys.filter((k) => !firebaseConfig[k]);
    if (missing.length) {
      console.info(
        'WebPush disabled: missing Firebase config keys:',
        missing.join(', ')
      );
      return; // Skip cleanly if not configured
    }
    const app = initializeApp(firebaseConfig);
    const messaging = getMessaging(app);

    if (typeof Notification !== 'undefined' && Notification.permission !== 'granted') {
      const permission = await Notification.requestPermission();
      if (permission !== 'granted') {
        return; // Respect user choice
      }
    }

    // Optional: retrieve FCM web token (useful if you want to persist per user)
    try {
      const vapidKey = import.meta.env.VITE_FIREBASE_VAPID_KEY || undefined;
      const reg = await navigator.serviceWorker?.getRegistration();
      await getToken(
        messaging,
        {
          ...(vapidKey ? { vapidKey } : {}),
          ...(reg ? { serviceWorkerRegistration: reg } : {}),
        } as any
      );
    } catch {}

    onMessage(messaging, (payload) => {
      const data = {
        route: payload.data?.route ?? 'offers',
        offerType: payload.data?.offerType ?? undefined,
        role: payload.data?.role ?? undefined,
        title: payload.notification?.title ?? payload.data?.title ?? 'New Notification',
        message: payload.notification?.body ?? payload.data?.message ?? '',
        imageUrl: payload.data?.imageUrl ?? undefined,
      };
      window.dispatchEvent(new CustomEvent('webpush', { detail: data }));
    });
  } catch (e) {
    console.warn('WebPush init failed:', e);
  }
}
