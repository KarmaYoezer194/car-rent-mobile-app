// Widget tests for the shared loading/error/empty states (Section 28,
// rules 3/4/9) — used on nearly every screen in the app, so a regression
// here would be widely visible.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:car_rent/widgets/loading_widget.dart';

void main() {
  testWidgets('LoadingWidget shows a pulsing brand mark and optional message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoadingWidget(message: 'Loading cars…')),
    );
    // The brand mark pulses on an infinite loop (Curves.easeInOut, repeat:
    // reverse) rather than settling, so a bounded pump — not pumpAndSettle,
    // which would hang forever — is enough to let its first frame render.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(LucideIcons.car), findsOneWidget);
    expect(find.text('Loading cars…'), findsOneWidget);
  });

  testWidgets('ErrorStateWidget shows the message and a retry button when provided', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ErrorStateWidget(message: 'Something went wrong.', onRetry: () => retried = true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Something went wrong.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('ErrorStateWidget hides the retry action when none is given', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ErrorStateWidget(message: 'Something went wrong.')),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('EmptyStateWidget shows its message and optional action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EmptyStateWidget(
          message: "You haven't posted a car yet.",
          actionLabel: 'Post a Car',
          onAction: () => tapped = true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text("You haven't posted a car yet."), findsOneWidget);
    await tester.tap(find.text('Post a Car'));
    expect(tapped, isTrue);
  });
}
