import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/widgets/bidirectional_paged_list.dart';

/// Pumps a list of [items] anchored at [centerIndex], tall enough that every
/// row and both buttons are laid out.
Future<ScrollController> _pumpList(
  WidgetTester tester, {
  required List<String> items,
  required int centerIndex,
  bool hasPrevious = false,
  bool hasNext = false,
  VoidCallback? onLoadPrevious,
  VoidCallback? onLoadNext,
}) async {
  final controller = ScrollController();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BidirectionalPagedList<String>(
          controller: controller,
          centerKey: const ValueKey('center'),
          items: items,
          centerIndex: centerIndex,
          itemBuilder: (item) =>
              SizedBox(height: 40, child: Text(item, key: ValueKey(item))),
          hasPrevious: hasPrevious,
          hasNext: hasNext,
          isLoadingPrevious: false,
          isLoadingNext: false,
          onLoadPrevious: onLoadPrevious ?? () {},
          onLoadNext: onLoadNext ?? () {},
        ),
      ),
    ),
  );
  // The sliver above the anchor grows off the top of the viewport and is only
  // built once scrolled to, exactly as it is on the real screens.
  controller.jumpTo(controller.position.minScrollExtent);
  await tester.pump();
  return controller;
}

/// Vertical position of a widget on screen, for asserting reading order.
double _topOf(WidgetTester tester, String text) =>
    tester.getTopLeft(find.byKey(ValueKey(text))).dy;

void main() {
  group('a list that grows at both ends', () {
    testWidgets('reads in order across the anchor', (tester) async {
      await _pumpList(
        tester,
        items: const ['a', 'b', 'c', 'd'],
        centerIndex: 2,
      );

      // The reverse-growth sliver above the anchor lists its items
      // nearest-first, so getting this backwards would print b above a.
      expect(_topOf(tester, 'a'), lessThan(_topOf(tester, 'b')));
      expect(_topOf(tester, 'b'), lessThan(_topOf(tester, 'c')));
      expect(_topOf(tester, 'c'), lessThan(_topOf(tester, 'd')));
    });

    testWidgets('puts See previous above everything', (tester) async {
      await _pumpList(
        tester,
        items: const ['a', 'b', 'c'],
        centerIndex: 2,
        hasPrevious: true,
      );

      expect(find.text('See previous'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('See previous')).dy,
        lessThan(_topOf(tester, 'a')),
      );
    });

    testWidgets('puts Load more below everything', (tester) async {
      await _pumpList(
        tester,
        items: const ['a', 'b', 'c'],
        centerIndex: 1,
        hasNext: true,
      );

      expect(
        tester.getTopLeft(find.text('Load more')).dy,
        greaterThan(_topOf(tester, 'c')),
      );
    });

    testWidgets('offers no buttons when there is nothing more', (tester) async {
      await _pumpList(tester, items: const ['a', 'b'], centerIndex: 1);
      expect(find.text('See previous'), findsNothing);
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('an anchor at the end still lists everything', (tester) async {
      // Where the first page loads and nothing has been fetched before it.
      await _pumpList(tester, items: const ['a', 'b', 'c'], centerIndex: 0);
      expect(find.byKey(const ValueKey('a')), findsOneWidget);
      expect(_topOf(tester, 'a'), lessThan(_topOf(tester, 'c')));
    });

    testWidgets('the buttons ask for their own end', (tester) async {
      var loadedPrevious = false;
      var loadedNext = false;
      await _pumpList(
        tester,
        items: const ['a', 'b'],
        centerIndex: 1,
        hasPrevious: true,
        hasNext: true,
        onLoadPrevious: () => loadedPrevious = true,
        onLoadNext: () => loadedNext = true,
      );

      await tester.tap(find.text('See previous'));
      await tester.tap(find.text('Load more'));
      expect(loadedPrevious, isTrue);
      expect(loadedNext, isTrue);
    });
  });
}
