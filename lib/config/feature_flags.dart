import 'package:flutter/foundation.dart';

class FeatureFlags {
  const FeatureFlags._();

  static bool get isAppleReviewSurface =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get cryptoUiEnabled => !isAppleReviewSurface;
}
