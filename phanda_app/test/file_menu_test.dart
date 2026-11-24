import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/models/subject.dart';
import 'package:kuphanda/features/documents/file_menu.dart';

/// These actions used to exist only on the Files screen, so removing that screen
/// would have removed them. They now live in their own widget and the Library
/// uses it too; these tests are what stops them disappearing in that deletion.

Document _document({bool personal = false}) {
  return Document(
    id: 'doc-1',
    title: 'Biology essay bank',
    subjectId: 'biology',
    form: 4,
    kind: personal ? DocumentKind.notes : DocumentKind.pastPaper,
    description: '',
    pages: 10,
    addedAt: DateTime(2026, 11, 20),
    personal: personal,
  );
}

LibraryEntry _entry({required bool onDevice, bool personal = false}) {
  return LibraryEntry(
    document: _document(personal: personal),
    subject: const Subject(
      id: 'biology',
      name: 'Biology',
      shortName: 'Biology',
      emoji: '🧬',
      color: Color(0xFF2E7D4F),
      forms: [3, 4],
      blurb: 'Living things and how they work.',
    ),
    asset: onDevice
        ? DocumentAsset(
            documentId: 'doc-1',
            fileName: 'biology.pdf',
            sizeBytes: 2048,
            addedAt: DateTime(2026, 11, 21),
            path: '/tmp/biology.pdf',
            remote: true,
          )
        : null,
  );
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('nothing is offered for a document that is not on the device',
      (tester) async {
    await tester.pumpWidget(
      _host(
        FileMenu(entry: _entry(onDevice: false), onRemove: () {}),
      ),
    );

    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('a downloaded file can be removed from the list', (tester) async {
    var removed = 0;

    await tester.pumpWidget(
      _host(
        FileMenu(entry: _entry(onDevice: true), onRemove: () => removed++),
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Remove file from device'), findsOneWidget);

    await tester.tap(find.text('Remove file from device'));
    await tester.pumpAndSettle();

    expect(removed, 1);
  });

  testWidgets('delete is offered only where the caller supplies it',
      (tester) async {
    await tester.pumpWidget(
      _host(
        FileMenu(entry: _entry(onDevice: true), onRemove: () {}),
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Delete document'), findsNothing);
  });

  testWidgets('an imported document can be deleted as well as removed',
      (tester) async {
    var deleted = 0;

    await tester.pumpWidget(
      _host(
        FileMenu(
          entry: _entry(onDevice: true, personal: true),
          onRemove: () {},
          onDelete: () => deleted++,
        ),
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete document'));
    await tester.pumpAndSettle();

    expect(deleted, 1);
  });
}
