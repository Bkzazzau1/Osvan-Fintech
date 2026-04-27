/// Placeholder notification service (FCM temporarily disabled until
/// google-services.json is provided). All methods are no-ops to avoid
/// build failures and runtime crashes while we pause push setup.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> initAndRegister() async {}
  Future<void> unregister() async {}
  Future<void> dispose() async {}
}
