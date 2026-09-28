import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts any [Stream] into a [Listenable] so go_router's `refreshListenable`
/// can re-run its `redirect` callback whenever the stream emits.
///
/// Used with `AuthService.authStateChanges` so sign-in/sign-out immediately
/// re-evaluates route guards, instead of only on the next navigation.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
