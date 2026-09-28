import 'package:car_rent/core/theme/app_theme.dart';
import 'package:car_rent/features/auth/screens/login_screen.dart';
import 'package:car_rent/features/auth/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Login and Register render without any layout overflow on a small phone
/// (320 x 640), in both themes. Nothing here taps a button, so the screens
/// never reach for their Firebase-backed services.
///
/// Only overflow errors fail the test: the test host has no spell-check
/// service, so text fields with spell check on (name, phone) report that
/// instead — an environment limitation, not a layout problem.
void main() {
  for (final brightness in Brightness.values) {
    for (final (name, screen) in [('Login', const LoginScreen()), ('Register', const RegisterScreen())]) {
      testWidgets('$name fits a small phone (${brightness.name})', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final errors = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details.exceptionAsString());
        addTearDown(() => FlutterError.onError = previous);

        await tester.pumpWidget(MaterialApp(theme: AppTheme.of(brightness), home: screen));
        await tester.pump(const Duration(seconds: 1));

        expect(errors.where((e) => e.contains('overflowed')), isEmpty);
      });
    }
  }
}
