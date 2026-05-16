# Release Checklist

Use this before every Play Store, Codemagic, TestFlight, or App Store upload.

## Automated Checks

```powershell
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Codemagic runs the iOS equivalents before building the IPA.

## Manual Device Checks

- Login with Apple review/test account.
- Dashboard opens without raw API errors.
- Wallet balance shows loading, retry, or real balance, never raw `not found`.
- Send Money: search country, select country, enter amount, continue.
- Cards tab opens; Add Card uses `/cards/create`.
- Settings routes open: PIN, password, limits, close account.
- Offline/slow network: app keeps a usable screen and retry action.

## Profiling

Run on at least one Android device and one iPhone/TestFlight build:

```powershell
flutter run --profile
```

Inspect DevTools for frame jank, repeated wallet requests, memory spikes, and slow API calls.
