# Error Reporting

`lib/services/error_reporter.dart` is the central app error hook.

It currently captures:

- Flutter framework errors.
- Platform dispatcher errors.
- Uncaught zone errors.
- Dio API failures through `ApiErrorInterceptor`.

The metadata sanitizer removes sensitive keys such as token, authorization, password, and PIN before logging.

## Provider Wiring

When a provider is chosen, wire it inside `ErrorReporter.recordError`:

- Sentry: call `Sentry.captureException(error, stackTrace: stack)`.
- Firebase Crashlytics: call `FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal)`.

Keep all feature code reporting through `ErrorReporter`; do not call provider SDKs directly from screens.
