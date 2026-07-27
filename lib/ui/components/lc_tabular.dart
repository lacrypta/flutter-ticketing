import 'package:flutter/widgets.dart';

/// Renders text with genuinely monospaced digits.
///
/// **Why this exists.** `FontFeature.tabularFigures()` is a silent no-op in
/// Standerd — the font's GSUB feature list is exactly `aalt, case, ccmp, frac,
/// locl`, with no `tnum`. And its digits are aggressively proportional: a `1`
/// is roughly 57% the advance width of a `0`. Without this widget, a counter
/// ticking `9 → 10`, a running total, or a live timestamp visibly reflows and
/// jitters — which looks broken on a POS.
///
/// The fix is layout, not typography: every digit is placed in a fixed-width
/// slot sized to the font's widest digit, and centred within it. Non-digits
/// are laid out normally, so `18.250` and `12:04` keep natural separator
/// spacing.
///
/// Slot ratios were measured from the shipped `Standerd-*.ttf` `hmtx` tables.
class LcTabular extends StatelessWidget {
  const LcTabular(
    this.text, {
    this.style,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Widest-digit advance as a fraction of em, per weight. Interpolated for
  /// weights in between.
  static const Map<int, double> _slotRatio = {
    100: 0.598,
    400: 0.613,
    700: 0.630,
    800: 0.636,
  };

  static double _ratioFor(FontWeight weight) {
    final value = weight.value;
    final keys = _slotRatio.keys.toList()..sort();
    if (value <= keys.first) return _slotRatio[keys.first]!;
    if (value >= keys.last) return _slotRatio[keys.last]!;
    for (var i = 0; i < keys.length - 1; i++) {
      final lo = keys[i];
      final hi = keys[i + 1];
      if (value >= lo && value <= hi) {
        final t = (value - lo) / (hi - lo);
        return _slotRatio[lo]! + (_slotRatio[hi]! - _slotRatio[lo]!) * t;
      }
    }
    return _slotRatio[400]!;
  }

  @override
  Widget build(BuildContext context) {
    final effective = style ?? DefaultTextStyle.of(context).style;
    final fontSize = effective.fontSize ?? 14;
    final slot = fontSize * _ratioFor(effective.fontWeight ?? FontWeight.w400);

    // Group consecutive non-digits so they lay out as one run — splitting
    // every character would drop the font's kerning between letters.
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString()));
      buffer.clear();
    }

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final isDigit = rune >= 0x30 && rune <= 0x39;
      if (!isDigit) {
        buffer.write(char);
        continue;
      }
      flush();
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SizedBox(
            width: slot,
            child: Text(char, style: effective, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    flush();

    return Text.rich(
      TextSpan(children: spans, style: effective),
      textAlign: textAlign,
    );
  }
}
