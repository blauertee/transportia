import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/utils/color_utils.dart';
import 'package:transportia/widgets/route_badge_pill.dart';

const Color _feedBackground = Color(0xFF0F62FE);
const Color _feedForeground = Color(0xFFFFFFFF);

Future<void> _pump(WidgetTester tester, Widget badge) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: badge),
  ),
);

void main() {
  group('the pill itself', () {
    testWidgets('prints the label in the colours it was handed', (
      tester,
    ) async {
      await _pump(
        tester,
        const RouteBadgePill(
          label: 'S41',
          background: _feedBackground,
          foreground: _feedForeground,
        ),
      );

      expect(find.text('S41'), findsOneWidget);

      final text = tester.widget<Text>(find.text('S41'));
      expect(text.style?.color, _feedForeground);

      final decoration =
          tester.widget<Container>(find.byType(Container)).decoration
              as BoxDecoration;
      expect(decoration.color, _feedBackground);
    });

    testWidgets('a long name is cut rather than allowed to overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        const SizedBox(
          width: 40,
          child: RouteBadgePill(
            label: 'RE 1 towards Magdeburg Hbf',
            background: _feedBackground,
            foreground: _feedForeground,
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sizes to its own text when no minimum is asked for', (
      tester,
    ) async {
      await _pump(
        tester,
        const RouteBadgePill(
          label: '1',
          background: _feedBackground,
          foreground: _feedForeground,
        ),
      );

      expect(
        tester.getSize(find.byType(RouteBadgePill)).width,
        lessThan(RouteBadgePill.stackedMinWidth),
      );
    });

    testWidgets('a stacked badge is held to a common width', (tester) async {
      await _pump(
        tester,
        const RouteBadgePill(
          label: '1',
          background: _feedBackground,
          foreground: _feedForeground,
          minWidth: RouteBadgePill.stackedMinWidth,
        ),
      );

      expect(
        tester.getSize(find.byType(RouteBadgePill)).width,
        greaterThanOrEqualTo(RouteBadgePill.stackedMinWidth),
      );
    });
  });

  // The badge itself takes resolved colours; deciding them is the call site's
  // job, and every site does it through one of these two helpers.
  group('the colour fallback the call sites share', () {
    test('a colour the feed names is used as given', () {
      expect(parseHexColorOr('#0F62FE', _feedForeground), _feedBackground);
    });

    test('a feed naming no colour gets the fallback', () {
      expect(parseHexColorOr(null, _feedForeground), _feedForeground);
      expect(parseHexColorOr('', _feedForeground), _feedForeground);
    });

    test('a colour the feed mangles gets the fallback, not a crash', () {
      expect(parseHexColorOr('not-a-colour', _feedForeground), _feedForeground);
      expect(parseHexColorOr('#12', _feedForeground), _feedForeground);
    });

    testWidgets('the accent stands in when the feed names no route colour', (
      tester,
    ) async {
      late Color resolved;
      await _pump(
        tester,
        Builder(
          builder: (context) {
            resolved = parseHexColorOrAccent(context, null);
            return const SizedBox.shrink();
          },
        ),
      );

      expect(resolved, isNotNull);
      expect(resolved, isNot(const Color(0x00000000)));
    });
  });
}
