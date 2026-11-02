import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/core/widgets/common.dart';

/// A sheet that creates its controllers outside and disposes them when
/// showModalBottomSheet returns disposes them mid-animation: the field goes on
/// using a dead controller, and the framework answers with
/// "Failed assertion: '_dependents.isEmpty'". TextControllers exists so that
/// cannot happen; this test fails if a sheet goes back to the old shape.
void main() {
  testWidgets('a sheet that owns its controllers closes cleanly',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => TextControllers(
                  initialTexts: ['A biology mock'],
                  builder: (context, controllers) => Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: TextField(controller: controllers.first),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    // Type, then close while the field still holds a value.
    await tester.enterText(find.byType(TextField), 'Biology mock 2024');
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(TextField))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
