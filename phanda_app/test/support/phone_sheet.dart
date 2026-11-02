import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives sheets the way the phone does: 360 × 820 dp with a keyboard taking
/// the bottom 300 dp.
///
/// Both sheet bugs found on hardware were invisible to tests that used the
/// default 800 × 600 surface: fields ended up behind the keyboard, and
/// controllers were disposed while the sheet was still closing. A sheet opened
/// through this harness is measured against the real geometry.
class PhoneSheet {
  PhoneSheet(this.tester);

  final WidgetTester tester;

  static const double width = 360;
  static const double height = 820;
  static const double keyboard = 300;

  double get keyboardTop => height - keyboard;

  /// The space a sheet may use without being covered.
  double get visibleBottom => keyboardTop;

  void install() {
    tester.view.physicalSize = const Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2.0;
    tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 24);
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 2);
    addTearDown(tester.view.reset);
  }

  /// Pumps [home] with a button that opens [sheet], then opens it.
  Future<void> open(Widget home, Future<void> Function(BuildContext) sheet) async {
    install();
    await tester.pumpWidget(home);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-sheet')));
    await tester.pumpAndSettle();
    expect(sheet, isNotNull);
  }

  /// Every field and button a learner has to reach, above the keyboard line.
  ///
  /// A long form scrolls inside its sheet, so a field further down is scrolled
  /// into view first: what matters is that it can be reached and seen, not that
  /// the whole form fits at once.
  Future<void> expectReachable(
    Finder finder, {
    String? reason,
    bool scroll = false,
  }) async {
    if (scroll) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }
    final rect = tester.getRect(finder);
    expect(
      rect.bottom,
      lessThanOrEqualTo(visibleBottom + 0.5),
      reason: reason ??
          'this ends at ${rect.bottom.toStringAsFixed(1)} dp, '
              'below the keyboard line at $visibleBottom dp',
    );
    expect(rect.top, greaterThanOrEqualTo(0));
  }
}

/// A screen with one button that opens a sheet, for the harness above.
Widget sheetHost(Future<void> Function(BuildContext context) open) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            key: const ValueKey('open-sheet'),
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}


