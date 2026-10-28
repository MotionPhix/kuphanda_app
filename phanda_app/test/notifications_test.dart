import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/api/api_models.dart';

void main() {
  test('parses a notification payload from the API', () {
    final notification = AppNotification.fromJson(<String, Object?>{
      'id': 12,
      'category': 'class',
      'title': 'Form 4: new maths paper',
      'body': 'MSCE Biology 2023 Paper 2 has been added to the library.',
      'data': <String, Object?>{'route': 'library'},
      'sent_at': '2026-10-28T13:20:00+00:00',
    });

    expect(notification.id, 12);
    expect(notification.category, 'class');
    expect(notification.title, 'Form 4: new maths paper');
    expect(notification.body, contains('MSCE Biology'));
    expect(notification.sentAt, isNotNull);
    expect(notification.sentAt!.toUtc().hour, 13);
  });

  test('falls back safely when fields are missing', () {
    final notification = AppNotification.fromJson(const <String, Object?>{});

    expect(notification.id, 0);
    expect(notification.category, 'general');
    expect(notification.title, isEmpty);
    expect(notification.body, isEmpty);
    expect(notification.sentAt, isNull);
  });
}
