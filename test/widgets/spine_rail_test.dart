import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/utils/journey_progress.dart';
import 'package:transportia/widgets/journey/spine_rail.dart';

const Color _kLine = Color(0xFF1A3D8F);

/// Every line the rail draws, as (start y, end y, packed colour).
///
/// Recorded rather than rendered to pixels: the split is a fact about what is
/// painted, and reading it back off an image would turn an exact question
/// into a sampling one.
Future<List<({double top, double bottom, int color})>> _lines(
  WidgetTester tester, {
  required double travelled,
  bool dashed = false,
  double height = 100,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 40,
          height: height,
          child: SpineRail(color: _kLine, dashed: dashed, travelled: travelled),
        ),
      ),
    ),
  );

  final painter = tester.widget<CustomPaint>(find.byType(CustomPaint)).painter!;
  final recorder = ui.PictureRecorder();
  final canvas = _RecordingCanvas(Canvas(recorder));
  painter.paint(canvas, Size(40, height));
  return canvas.lines;
}

class _RecordingCanvas implements Canvas {
  _RecordingCanvas(this._inner);

  final Canvas _inner;
  final lines = <({double top, double bottom, int color})>[];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    // Packed, because `Paint` hands its colour back in a different colour
    // space than it was given and the two do not compare equal.
    lines.add((top: p1.dy, bottom: p2.dy, color: paint.color.toARGB32()));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      // Everything else the painter might do goes straight through.
      Function.apply((_inner as dynamic).noSuchMethod, [invocation]);
}

void main() {
  final solid = _kLine.toARGB32();
  final faded = _kLine
      .withValues(alpha: _kLine.a * kTravelledOpacity)
      .toARGB32();

  group('the line behind the traveller', () {
    testWidgets('a stretch nobody has reached is one solid line', (
      tester,
    ) async {
      final lines = await _lines(tester, travelled: 0);

      expect(lines, hasLength(1));
      expect(lines.single.color, solid);
      expect(lines.single.top, 0);
      expect(lines.single.bottom, 100);
    });

    testWidgets('a stretch part-ridden is two, split where you are', (
      tester,
    ) async {
      final lines = await _lines(tester, travelled: 0.4);

      expect(lines, hasLength(2));
      expect(lines.first.color, faded);
      expect(lines.first.top, 0);
      expect(lines.first.bottom, closeTo(40, 0.01));
      expect(lines.last.color, solid);
      expect(lines.last.top, closeTo(40, 0.01));
      expect(lines.last.bottom, 100);
    });

    testWidgets('a stretch entirely behind you is one faded line', (
      tester,
    ) async {
      final lines = await _lines(tester, travelled: 1);

      expect(lines, hasLength(1));
      expect(lines.single.color, faded);
    });

    testWidgets('faded is paler than solid but still drawn', (tester) async {
      // Pale rather than invisible: the journey behind you is still the
      // journey, and a rider checking which station they left reads it.
      final lines = await _lines(tester, travelled: 1);

      final alpha = Color(lines.single.color).a;
      expect(alpha, lessThan(_kLine.a));
      expect(alpha, greaterThan(0));
    });
  });

  group('a dotted line fades the same way', () {
    testWidgets('each dash takes one side or the other, never both', (
      tester,
    ) async {
      // Cutting a dash in half at this size would read as a printing fault.
      final lines = await _lines(tester, travelled: 0.5, dashed: true);

      expect(lines.length, greaterThan(4));
      expect(lines.map((l) => l.color).toSet(), {
        faded,
        solid,
      }, reason: 'both sides are drawn');
      for (final line in lines) {
        final behind = line.color == faded;
        final middle = (line.top + line.bottom) / 2;
        expect(
          behind,
          middle < 50,
          reason: 'a dash at $middle took the wrong side',
        );
      }
    });

    testWidgets('with nothing ridden every dash is solid', (tester) async {
      final lines = await _lines(tester, travelled: 0, dashed: true);
      expect(lines.map((l) => l.color).toSet(), {solid});
    });
  });
}
