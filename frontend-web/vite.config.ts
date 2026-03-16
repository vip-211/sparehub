
import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const hasRemote = !!env.VITE_API_BASE
  return {
    plugins: [react()],
    define: {
      global: 'window',
      'process.env': {},
    },
    server: {
      proxy: hasRemote
        ? {}
        : {
            '/api': {
              target: 'http://localhost:8080',
              changeOrigin: true,
            },
            '/ws': {
              target: 'ws://localhost:8080',
              ws: true,
            },
          },
    },
  }
})
