
import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import App from './App'
import './index.css'
import { CartProvider } from './context/CartContext'
import { AuthProvider } from './context/AuthContext'
import { LanguageProvider } from './context/LanguageContext'
import { initWebPush } from './services/webpush'
import ErrorBoundary from './components/ErrorBoundary'
import api from './services/api'

(window as any).global = window

// Register Firebase messaging SW for web push
if ('serviceWorker' in navigator) {
  const swUrl = `${import.meta.env.BASE_URL}firebase-messaging-sw.js`
  navigator.serviceWorker
    .register(swUrl)
    .then(() => {
      initWebPush()
    })
    .catch(() => {
      // Fallback attempt from root
      navigator.serviceWorker
        .register('/firebase-messaging-sw.js')
        .then(() => initWebPush())
        .catch(() => initWebPush())
    })
}

// Try to set favicon from server LOGO_URL (if accessible). Falls back silently.
const setFavicon = (href: string) => {
  const ensureLink = (rel: string, type?: string) => {
    let link = document.querySelector(`link[rel="${rel}"]`) as HTMLLinkElement | null
    if (!link) {
      link = document.createElement('link')
      link.rel = rel
      if (type) link.type = type
      document.head.appendChild(link)
    }
    link.href = href
  }
  ensureLink('icon')
  ensureLink('apple-touch-icon')
}

;(async () => {
  // Public fallback from env for unauthenticated pages
  try {
    const publicLogo = import.meta.env.VITE_LOGO_URL as string | undefined
    if (publicLogo && (publicLogo.startsWith('http') || publicLogo.startsWith('/'))) {
      setFavicon(publicLogo)
    }
  } catch {
    // ignore
  }

  try {
    const res = await api.get('admin/settings')
    const settings: Array<{ settingKey: string; settingValue: string }> = res.data || []
    const logo = settings.find(s => s.settingKey === 'LOGO_URL')?.settingValue?.trim()
    if (logo && (logo.startsWith('http') || logo.startsWith('/'))) {
      setFavicon(logo)
    }
  } catch {
    // Ignore errors (e.g., unauthenticated); default favicon remains
  }
})()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <LanguageProvider>
        <AuthProvider>
          <CartProvider>
            <ErrorBoundary>
              <App />
            </ErrorBoundary>
          </CartProvider>
        </AuthProvider>
      </LanguageProvider>
    </BrowserRouter>
  </React.StrictMode>,
)
