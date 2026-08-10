import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:transportia/theme/journey_metrics.dart';
import 'package:transportia/widgets/journey/spine_node.dart';
import 'package:transportia/widgets/journey/spine_row.dart';

const Color _c = Color(0xFF007185);

/// The line height the rows are told to centre against.
const double _lineHeight = 18;

// Names are kept short on purpose: the test font gives every glyph a full
// em square, so a realistic stop name wraps to two lines and a rect's centre
// stops being its first line's centre.
/// A run of rows of every shape the spine has: a ring that starts a leg, a
/// minor stop inside it, and a terminus. If the columns line up across these
/// three they line up everywhere.
Widget _run() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    SpineRow(
      firstLineHeight: _lineHeight,
      node: const SpineNode(icon: LucideIcons.footprints, color: _c),
      railColor: _c,
      railDashed: true,
      railTopInset: JourneyMetrics.ring,
      time: const Text('14:22', key: Key('t0')),
      body: const Text('Chaus', key: Key('b0')),
      meta: const Text('map', key: Key('m0')),
    ),
    SpineRow(
      firstLineHeight: _lineHeight,
      node: const SpineNode(icon: LucideIcons.trainFront, color: _c),
      railColor: _c,
      railTopInset: JourneyMetrics.ring,
      time: const Text('14:28', key: Key('t1')),
      body: const Text('Natur', key: Key('b1')),
      meta: const Text('Track 2', key: Key('m1')),
    ),
    SpineRow(
      firstLineHeight: _lineHeight,
      node: const SpineDot(color: _c),
      nodeCenter: 12,
      railColor: _c,
      time: const Text('14:37', key: Key('t2')),
      body: const Text('Ost', key: Key('b2')),
      meta: const Text('Track 9', key: Key('m2')),
    ),
    SpineRow(
      firstLineHeight: _lineHeight,
      node: const SpineNode(icon: LucideIcons.flag, color: _c, filled: true),
      time: const Text('15:24', key: Key('t3')),
      body: const Text('Term', key: Key('b3')),
      meta: const Text('Track 3', key: Key('m3')),
    ),
  ],
);

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      // An explicit line height, because that is what the row centres against
      // and what the app's own spine styles pin down.
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 15, height: _lineHeight / 15),
        child: Align(alignment: Alignment.topCenter, child: _run()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Set<double> _edges(
  WidgetTester tester,
  List<String> keys,
  double Function(Rect) pick,
) {
  return {
    for (final k in keys)
      pick(tester.getRect(find.byKey(Key(k)))).roundToDouble(),
  };
}

void main() {
  testWidgets('every time ends on one edge', (tester) async {
    await _pump(tester);
    // Asserted by rect, not by presence: "aligned" is the whole request, and a
    // row could render all four columns and still put them anywhere.
    expect(
      _edges(tester, ['t0', 't1', 't2', 't3'], (r) => r.right),
      hasLength(1),
    );
  });

  testWidgets('every name starts on one edge', (tester) async {
    await _pump(tester);
    expect(
      _edges(tester, ['b0', 'b1', 'b2', 'b3'], (r) => r.left),
      hasLength(1),
    );
  });

  testWidgets('every platform ends on one edge', (tester) async {
    await _pump(tester);
    expect(
      _edges(tester, ['m0', 'm1', 'm2', 'm3'], (r) => r.right),
      hasLength(1),
    );
  });

  testWidgets('a name clears the rail rather than overlapping it', (
    tester,
  ) async {
    await _pump(tester);
    final body = tester.getRect(find.byKey(const Key('b1')));
    final node = tester.getRect(find.byType(SpineNode).at(1));
    expect(body.left, greaterThanOrEqualTo(node.right));
  });

  testWidgets('a node and its own text sit on the same line', (tester) async {
    await _pump(tester);
    // A stop name level with some other row's marker would read as belonging
    // to that row.
    final node = tester.getRect(find.byType(SpineNode).at(1));
    final body = tester.getRect(find.byKey(const Key('b1')));
    expect(body.center.dy, closeTo(node.center.dy, 2.0));
  });

  testWidgets('a minor stop keeps the same columns as a ring', (tester) async {
    await _pump(tester);
    // The dot is smaller and sits higher, but nothing in the text moves.
    final dot = tester.getRect(find.byType(SpineDot));
    final node = tester.getRect(find.byType(SpineNode).first);
    expect(dot.center.dx, closeTo(node.center.dx, 0.5));
  });
}
