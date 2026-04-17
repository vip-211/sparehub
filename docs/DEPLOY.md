Backend (Render or Railway)
- Render:
  - Create PostgreSQL, copy DATABASE_URL
  - Create Web Service from repo root using spares-hub-server/render.yaml
  - Set env: DATABASE_URL
  - Deploy, health check: https://YOUR_HOST/api/products
- Railway:
  - Create PostgreSQL, copy DATABASE_URL
  - Create Service from the root Dockerfile (not the one in spares-hub-server)
  - Set env: DATABASE_URL
  - Ensure the service is named `inventory-system` or similar
  - Verify health check: https://YOUR_HOST/api/health

Flutter Web (GitHub Pages)
- Add secret FLUTTER_WEB_BASE_URL with https://YOUR_HOST/api in repo settings
- Push to main/master; the workflow builds and publishes to gh-pages
- Enable Pages to serve from gh-pages
- App base URL picked via --dart-define BASE_URL

React Frontend (Vercel)
- In Vercel, import repository, select frontend-web directory
- Add Environment Variable VITE_API_BASE=https://YOUR_HOST/api
- Deploy; Vercel will serve the built /dist

Android Distribution
- Ensure JDK 17; configure key.properties or env vars for signing
- Build:
  - flutter build appbundle --release --dart-define=BASE_URL=https://YOUR_HOST/api
  - flutter build apk --release --dart-define=BASE_URL=https://YOUR_HOST/api
- Upload AAB to Play Console (Internal testing), or share APK via Firebase App Distribution
