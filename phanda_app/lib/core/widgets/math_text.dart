import 'package:flutter/material.dart';

/// Typesets `$...$` spans as mathematics inside ordinary prose.
///
/// Exam stems mix words and symbols: "When a polynomial $x^3 + kx^2 + x - k$ is
/// divided by $(x - k)$". Rendering the whole stem in the body font makes the
/// algebra read as prose, which is exactly what learners are being tested on.
/// Math runs are set in a serif italic face with raised exponents so the
/// expression is visibly a different kind of object.
class MathText extends StatelessWidget {
  const MathText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;

    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: base,
        children: _segments(base),
      ),
    );
  }

  List<InlineSpan> _segments(TextStyle base) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\$([^$]+)\$');
    var cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(_mathSpan(match.group(1)!, base));
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return spans;
  }

  InlineSpan _mathSpan(String expression, TextStyle base) {
    final math = base.copyWith(
      fontFamily: 'serif',
      fontFamilyFallback: const ['Georgia', 'Times New Roman', 'serif'],
      fontStyle: FontStyle.italic,
      letterSpacing: 0.2,
    );

    final children = <InlineSpan>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) return;
      children.add(TextSpan(text: buffer.toString(), style: math));
      buffer.clear();
    }

    for (var i = 0; i < expression.length; i++) {
      final char = expression[i];

      if (char == '^' || char == '_') {
        flush();
        final isSuperscript = char == '^';
        var value = '';

        if (i + 1 < expression.length && expression[i + 1] == '{') {
          final end = expression.indexOf('}', i + 2);
          value = expression.substring(i + 2, end < 0 ? expression.length : end);
          i = end < 0 ? expression.length : end;
        } else if (i + 1 < expression.length) {
          value = expression[i + 1];
          i += 1;
        }

        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Transform.translate(
              offset: Offset(0, isSuperscript ? 2 : -1),
              child: Text(
                value,
                style: math.copyWith(
                  fontSize: (base.fontSize ?? 16) * 0.62,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        );
        continue;
      }

      buffer.write(char);
    }

    flush();

    return TextSpan(children: children);
  }
}