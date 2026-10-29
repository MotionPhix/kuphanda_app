import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Typesets `$...$` spans as mathematics inside ordinary prose.
///
/// Exam stems mix words and symbols: "When a polynomial $x^3 + kx^2 + x - k$ is
/// divided by $(x - k)$". Rendering the whole stem in the body font makes the
/// algebra read as prose, which is exactly what learners are being tested on.
///
/// The maths itself is real TeX, so fractions, roots, logs and superscripts are
/// laid out by a math engine rather than approximated with raised text.
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

    // Plain prose stays a Text widget: RichText would break ind.text in tests
    // and loses selectability for no benefit.
    if (!text.contains(r'$')) {
      return Text(text, style: base, textAlign: textAlign);
    }

    return RichText(
      textAlign: textAlign,
      text: TextSpan(style: base, children: _segments(context, base)),
    );
  }

  List<InlineSpan> _segments(BuildContext context, TextStyle base) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\$([^$]+)\$');
    var cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            match.group(1)!,
            textStyle: base.copyWith(fontSize: (base.fontSize ?? 16) * 1.02),
            onErrorFallback: (error) => Text(
              match.group(1)!,
              style: base.copyWith(fontFamily: 'serif', fontStyle: FontStyle.italic),
            ),
          ),
        ),
      );

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return spans;
  }
}
