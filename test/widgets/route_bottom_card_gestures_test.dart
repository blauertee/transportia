import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/routing_options.dart';
import 'package:transportia/models/time_selection.dart';
import 'package:transportia/models/transitous/server_config.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/widgets/floating_nav_bar.dart';
import 'package:transportia/widgets/route_bottom_card.dart';

/// Counts the drag callbacks the card reports.
///
/// The map screen turns `onDragStart` into a periodic haptic pulse and only
/// `onDragEnd` stops it, so a start without a matching end leaves the phone
/// buzzing until the app is killed. Balance is the whole invariant.
class _DragLog {
  int starts = 0;
  int ends = 0;

  bool get isBalanced => starts == ends;

  @override
  String toString() => 'starts=$starts ends=$ends';
}

/// Rebuilds the card so the test can flip `canScrollBody` mid-gesture, which
/// is what the real sheet does the moment a drag reaches the top stop.
class _Host extends StatefulWidget {
  const _Host({required this.log, required this.initialCanScrollBody});

  final _DragLog log;
  final bool initialCanScrollBody;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late bool canScrollBody = widget.initialCanScrollBody;

  void setCanScrollBody(bool value) => setState(() => canScrollBody = value);

  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 900)),
          child: BottomCard(
            isCollapsed: false,
            collapseProgress: 0,
            onHandleTap: () {},
            onDragStart: () => widget.log.starts++,
            onDragUpdate: (_) {},
            onDragEnd: (_) => widget.log.ends++,
            fromCtrl: _fromCtrl,
            toCtrl: _toCtrl,
            fromFocusNode: _fromFocus,
            toFocusNode: _toFocus,
            showMyLocationDefault: false,
            onUnfocus: () {},
            onSwapRequested: () => true,
            options: RoutingOptions.defaults,
            storedOptions: RoutingOptions.defaults,
            capabilities: ServerConfig.fallback,
            onOptionsChanged: (_) {},
            onResetOptions: () {},
            onSaveOptionsAsDefault: () {},
            onAddViaStop: () {},
            onFromPressed: () {},
            onToPressed: () {},
            isFromFavourite: false,
            isToFavourite: false,
            onToggleFromFavourite: () {},
            onToggleToFavourite: () {},
            canScrollBody: canScrollBody,
            fullProgress: 0,
            routeFieldLink: LayerLink(),
            fromLoading: false,
            toLoading: false,
            fromSelection: null,
            toSelection: null,
            onSearch: (_) {},
            timeSelectionLayerLink: LayerLink(),
            onTimeSelectionTap: () {},
            timeSelection: TimeSelection.now(),
            recentTrips: const [],
            onRecentTripTap: (_) {},
            savedTrips: const [],
            onSavedTripTap: (_) {},
            onSeeAllSavedTrips: () {},
            favorites: const [],
            onFavoriteTap: (_) {},
            hasLocationPermission: true,
          ),
        ),
      ),
    );
  }
}

Future<_HostState> _pump(
  WidgetTester tester,
  _DragLog log, {
  required bool canScrollBody,
  // Short by default so the body actually overflows and can be scrolled;
  // a card taller than its content never overscrolls, and a test of the
  // overscroll hand-over would pass without exercising anything.
  Size viewSize = const Size(400, 420),
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_Host(log: log, initialCanScrollBody: canScrollBody));
  await tester.pump();
  return tester.state<_HostState>(find.byType(_Host));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('a body drag that reaches the top stop still reports its end', (
    tester,
  ) async {
    // Dragging the body up raises the card; the instant it arrives,
    // canScrollBody flips. Rebuilding the recognizer away mid-drag used to
    // swallow the end, and a disposed recognizer reports no cancel either.
    final log = _DragLog();
    final host = await _pump(tester, log, canScrollBody: false);

    final gesture = await tester.startGesture(const Offset(200, 220));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(log.starts, 1, reason: 'the drag should have moved the card');

    host.setCanScrollBody(true);
    await tester.pump();

    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(log.isBalanced, isTrue, reason: '$log');
    expect(log.ends, 1);
  });

  testWidgets('a pull-down that lowers the card still reports its end', (
    tester,
  ) async {
    // The pull-down's whole job is to lower the card, which clears
    // canScrollBody — so a guard on it made the end of that very gesture
    // unreachable.
    final log = _DragLog();
    final host = await _pump(tester, log, canScrollBody: true);

    // Down from the top of the list: nothing left to scroll, so it overscrolls
    // and the card takes over.
    final gesture = await tester.startGesture(const Offset(200, 220));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    expect(log.starts, 1, reason: 'the pull-down should have moved the card');

    // Which is exactly what clears canScrollBody.
    host.setCanScrollBody(false);
    await tester.pump();

    await gesture.up();
    await tester.pumpAndSettle();

    expect(log.isBalanced, isTrue, reason: '$log');
  });

  testWidgets('a drag interrupted before it ends still reports its end', (
    tester,
  ) async {
    // A recognizer cancelled after it was accepted does report an end of its
    // own, so this holds without the explicit cancel handler — it is here to
    // keep the latch from breaking that, since the latch now decides whether
    // an end is passed on at all.
    final log = _DragLog();
    await _pump(tester, log, canScrollBody: false);

    final gesture = await tester.startGesture(const Offset(200, 220));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(log.starts, 1);

    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(log.isBalanced, isTrue, reason: '$log');
  });

  testWidgets('a card torn down mid-drag does not leave the drag open', (
    tester,
  ) async {
    final log = _DragLog();
    await _pump(tester, log, canScrollBody: false);

    final gesture = await tester.startGesture(const Offset(200, 220));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(log.starts, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(log.isBalanced, isTrue, reason: '$log');
    await gesture.up();
  });

  testWidgets('the Search button clears the floating nav bar', (tester) async {
    // The bar is a sibling painted over the card, so the card has to leave
    // room for it or the primary action ends up underneath.
    final log = _DragLog();
    await _pump(
      tester,
      log,
      canScrollBody: true,
      viewSize: const Size(400, 900),
    );

    final search = tester.getRect(find.text('Search'));
    final card = tester.getRect(find.byType(BottomCard));

    expect(
      card.bottom - search.bottom,
      greaterThanOrEqualTo(FloatingNavBar.reservedHeight),
      reason: 'Search sits under the nav bar',
    );
  });
}
