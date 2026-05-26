# Play Store Deployment Guide

This project uses:

- Flutter Android app: `spare_parts_app_new`
- Render backend service: root `Dockerfile` deploying `backend`
- Supabase PostgreSQL database

## 1. Supabase production database

1. Open Supabase project settings and copy the pooled PostgreSQL connection string.
2. Use the URI form in Render, for example:
   `postgresql://postgres.<project-ref>:<password>@aws-...pooler.supabase.com:6543/postgres?sslmode=require`
3. Keep `sslmode=require`.
4. Run any required schema setup before public launch. The backend currently uses `spring.jpa.hibernate.ddl-auto=update`, which is convenient but should be replaced with explicit migrations before a larger production rollout.

## 2. Render backend

Deploy the root repo with the root `Dockerfile`.

Required Render environment variables:

- `DATABASE_URL`: Supabase pooled PostgreSQL URL
- `JWT_SECRET`: long random secret, at least 32 bytes
- `APP_CORS_ALLOWED_ORIGINS`: comma-separated web origins, such as `https://your-web-app.com,https://your-render-service.onrender.com`
- `MAIL_PROVIDER`: `SENDGRID`
- `SENDGRID_API_KEY`: production SendGrid key
- `SENDGRID_FROM_EMAIL`: verified sender email
- `FIREBASE_PROJECT_ID`: Firebase project id, if notifications are enabled
- `FIREBASE_SERVICE_ACCOUNT_JSON`: Firebase service account JSON, if notifications are enabled
- `DEMO_MODE`: `false`
- `OTP_MODE`: `EMAIL`

After deploy, verify:

```powershell
Invoke-WebRequest https://your-render-service.onrender.com/api/health
```

## 3. Android release signing

Release signing is configured from:

- `spare_parts_app_new/android/key.properties`
- `spare_parts_app_new/android/upload-keystore.jks`

Keep both files private. Do not delete the keystore after first Play upload. Google Play uses it to verify future updates.

## 4. Build the Play Store app bundle

From `spare_parts_app_new`:

```powershell
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=BASE_URL=https://your-render-service.onrender.com/api
```

Upload this file to Play Console:

```text
spare_parts_app_new/build/app/outputs/bundle/release/app-release.aab
```

For every later release, increment `version` in `spare_parts_app_new/pubspec.yaml`, for example:

```yaml
version: 1.0.1+2
```

## 5. Play Console checklist

1. Create the app in Google Play Console.
2. Set package name/application id: `com.partsmitra.app`.
3. Complete app access, ads declaration, content rating, target audience, data safety, and privacy policy.
4. Upload app icon, feature graphic, screenshots, short description, and full description.
5. Upload the `.aab` to Internal testing first.
6. Test login, OTP/email, product browsing, orders, notifications, camera/scanner, microphone, and location on a real Android device.
7. Promote to Closed testing or Production after testing passes.

## 6. Production checks before launch

- Rotate the old Gmail app password and JWT secret that were previously present in source history.
- Use only Render environment variables for secrets.
- Add Android package `com.partsmitra.app` in Firebase and replace `spare_parts_app_new/android/app/google-services.json`.
- Confirm Play Console declarations for camera, microphone, location, and notifications match the app behavior.
- Confirm Supabase backups are enabled.
- Confirm Render free-plan sleep is acceptable. For production, use a paid instance to avoid slow first requests.
