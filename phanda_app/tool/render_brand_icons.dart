// Renders the launcher icon from the same mark the app shows on its welcome
// screen (`BrandMark` in lib/core/widgets/common.dart): a rounded green-soft tile,
// the `auto_stories_rounded` book glyph in brand green, and the rising-sun dot.
//
// Run with:  flutter test tool/render_brand_icons.dart
// Outputs:   build/icon/legacy.png (1024²), build/icon/adaptive.png (432², transparent)
//
// The geometry below mirrors BrandMark's factors (0.28 radius, 0.56 glyph, sun at
// 0.13/0.15 with 0.16 diameter). If that widget changes, this file must change with
// it - which is why it reads the same Material glyph by code point rather than
// shipping a hand-drawn copy.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _green = Color(0xFF0F5B3A);
const _greenSoft = Color(0xFFDDEBE1);
const _sun = Color(0xFFE3A33B);
const _paper = Color(0xFFF7F4EC);

Future<void> _loadIconsFont() async {
  const candidates = <String>[
    r'C:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
  ];

  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;

    final bytes = await file.readAsBytes();
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();

    return;
  }

  throw StateError('MaterialIcons font not found; pass the Flutter SDK font path.');
}

/// Draws the mark in a 100×100 coordinate space.
void _paintMark(Canvas canvas, {required double size, required bool background}) {
  final rect = Rect.fromLTWH(0, 0, size, size);

  if (background) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size * 0.28)),
      Paint()..color = _greenSoft,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(size * 0.011),
        Radius.circular(size * 0.28 - size * 0.011),
      ),
      Paint()
        ..color = _green.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.023,
    );
  }

  final glyphSize = size * 0.56;
  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(Icons.auto_stories_rounded.codePoint),
      style: TextStyle(
        fontFamily: 'MaterialIcons',
        fontSize: glyphSize,
        color: _green,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  painter.paint(
    canvas,
    Offset((size - painter.width) / 2, (size - painter.height) / 2),
  );

  final sunDiameter = size * 0.16;
  final sunCenter = Offset(
    size - size * 0.15 - sunDiameter / 2,
    size * 0.13 + sunDiameter / 2,
  );

  canvas.drawCircle(sunCenter, sunDiameter / 2, Paint()..color = _sun);
  canvas.drawCircle(
    sunCenter,
    sunDiameter / 2,
    Paint()
      ..color = background ? _greenSoft : _paper
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.03,
  );
}

Future<void> _write(String path, int pixels, {required bool background, double scale = 1}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final size = 100.0 * scale;
  final offset = (100.0 - size) / 2;

  canvas.save();
  // Everything below is authored in a 100×100 space; the image is `pixels` wide.
  canvas.scale(pixels / 100.0);
  canvas.translate(offset, offset);
  _paintMark(canvas, size: size, background: background);
  canvas.restore();

  final picture = recorder.endRecording();
  final image = await picture.toImage(pixels, pixels);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);

  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render launcher icons', () async {
    await _loadIconsFont();

    // Full-bleed square: launchers that do not mask still show the tile.
    await _write('build/icon/legacy.png', 1024, background: true);

    // Adaptive foreground: the system supplies the background and the mask, so the
    // mark sits inside the 66/108 safe zone (≈0.71 of the canvas).
    await _write('build/icon/adaptive.png', 432, background: false, scale: 0.71);

    expect(File('build/icon/legacy.png').existsSync(), isTrue);
    expect(File('build/icon/adaptive.png').existsSync(), isTrue);
  });
}
