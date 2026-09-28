import 'package:car_rent/core/router/animated_branch_container.dart';
import 'package:car_rent/core/router/page_transitions.dart';
import 'package:car_rent/core/widgets/motion/entrance.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnimatedBranchContainer', () {
    Widget host(int index, List<String> taps) => MaterialApp(
          home: AnimatedBranchContainer(
            currentIndex: index,
            children: [
              for (final name in ['home', 'profile'])
                GestureDetector(onTap: () => taps.add(name), child: SizedBox.expand(child: Text(name))),
            ],
          ),
        );

    double opacityOf(WidgetTester tester, String text) => tester
        .widget<AnimatedOpacity>(find.ancestor(of: find.text(text), matching: find.byType(AnimatedOpacity)))
        .opacity;

    testWidgets('only the active tab receives taps', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(host(0, taps));
      await tester.tapAt(const Offset(100, 100));
      expect(taps, ['home']);

      await tester.pumpWidget(host(1, taps));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(100, 100));
      expect(taps, ['home', 'profile']);
    });

    testWidgets('switching tabs crossfades instead of snapping', (tester) async {
      await tester.pumpWidget(host(0, []));
      expect(opacityOf(tester, 'home'), 1);
      expect(opacityOf(tester, 'profile'), 0);

      await tester.pumpWidget(host(1, []));
      // Target opacities flip immediately; the rendered fade takes time.
      expect(opacityOf(tester, 'profile'), 1);
      await tester.pump(AppMotion.tabSwitch ~/ 2);
      // AnimatedOpacity renders through a FadeTransition; read its value.
      Animation<double> fade() => tester
          .widget<FadeTransition>(
            find
                .descendant(
                  of: find.ancestor(of: find.text('profile'), matching: find.byType(AnimatedOpacity)),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity;
      expect(fade().value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(fade().value, 1);
    });

    testWidgets('keeps every tab mounted, so each keeps its state', (tester) async {
      await tester.pumpWidget(host(0, []));
      await tester.pumpWidget(host(1, []));
      await tester.pumpAndSettle();
      expect(find.text('home', skipOffstage: false), findsOneWidget);
      expect(find.text('profile'), findsOneWidget);
    });
  });

  testWidgets('page transitions switch off when the OS asks to reduce motion', (tester) async {
    late Widget built;
    const child = SizedBox(key: Key('page'));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            built = AppMotion.slideFade(context, kAlwaysDismissedAnimation, kAlwaysDismissedAnimation, child);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(identical(built, child), isTrue);
  });

  testWidgets('tabs slide directionally (right-hand tabs wait right, left-hand left); Home fades up', (tester) async {
    Offset restOf(String text) => tester
        .widget<AnimatedSlide>(find.ancestor(of: find.text(text, skipOffstage: false), matching: find.byType(AnimatedSlide)))
        .offset;
    await tester.pumpWidget(MaterialApp(
      home: AnimatedBranchContainer(
        currentIndex: 2,
        children: const [Text('home'), Text('post'), Text('booking'), Text('profile')],
      ),
    ));
    // Home keeps the gentle fade + rise: it rests just below, not beside.
    expect(restOf('home').dx, 0);
    expect(restOf('home').dy, greaterThan(0));
    expect(restOf('post').dx, lessThan(0));
    expect(restOf('booking'), Offset.zero);
    expect(restOf('profile').dx, greaterThan(0));
  });

  testWidgets('Pressable lifts on mouse hover and settles back when the mouse leaves', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Center(child: Pressable(onTap: () {}, child: const SizedBox(width: 100, height: 100))),
    ));
    Matrix4 transform() =>
        tester.widget<AnimatedContainer>(find.descendant(of: find.byType(Pressable), matching: find.byType(AnimatedContainer))).transform!;
    expect(transform(), Matrix4.diagonal3Values(1, 1, 1));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(Pressable)));
    await tester.pumpAndSettle();
    expect(transform().getMaxScaleOnAxis(), greaterThan(1));
    expect(transform().getTranslation().y, lessThan(0));

    await mouse.moveTo(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(transform().getMaxScaleOnAxis(), 1);
  });
}
