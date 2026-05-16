# Performance Checklist

Use this when validating Android, iPhone, and release builds.

## Local Quality Gate

```powershell
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

## Real-Device Requirement

The workspace machine currently exposes only desktop/browser devices unless a phone
or emulator is connected. Do not judge mobile performance from debug desktop/web.
Use at least:

- One mid-range Android device.
- One iPhone TestFlight build.

## Device Profiling

Run on a real Android device or iPhone in profile mode:

```powershell
flutter run --profile
```

Then open Flutter DevTools and check:

- Flutter frames: avoid repeated red bars during dashboard scrolling and tab changes.
- Raster time: dashboard cards and bottom navigation should stay smooth after the blur reduction.
- Network tab/logs: wallet refresh should not fire more than once on dashboard entry.
- Memory: welcome images should not repeatedly spike after the first carousel pass.

## iOS Release

Codemagic now runs:

```bash
flutter pub get
flutter analyze
flutter test
flutter build ipa --release --export-options-plist=/Users/builder/export_options.plist
```

Use the TestFlight build for Apple-review-like performance checks.
