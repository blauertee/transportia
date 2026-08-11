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
import 'package:transportia/widgets/search/traveller_strip.dart';

/// Counts the drag callbacks the card reports.
///
/// The map screen turns `onDragStart` into a periodic haptic pulse, so a drag
/// reported by scrolling is a phone that buzzes while you read a list.
class _DragLog {
  int starts = 0;
  int ends = 0;

  bool get isBalanced => starts == ends;

  @override
  String toString() => 'starts=$starts ends=$ends';
}

class _Host extends StatefulWidget {
  const _Host({required this.log});

  final _DragLog log;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
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
            onShowMap: () {},
            onFromPressed: () {},
            onToPressed: () {},
            isFromFavourite: false,
            isToFavourite: false,
            onToggleFromFavourite: () {},
            onToggleToFavourite: () {},
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
  // Short by default so the body actually overflows and has somewhere to
  // scroll to; a card taller than its content would pass without exercising
  // anything.
  Size viewSize = const Size(400, 420),
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_Host(log: log));
  await tester.pump();
  return tester.state<_HostState>(find.byType(_Host));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('scrolling the body never reports a sheet drag', (tester) async {
    // The card used to hand a body drag to the sheet, which meant reading a
    // list buzzed: onDragStart is a periodic haptic pulse. Only the handle
    // moves the card now.
    final log = _DragLog();
    await _pump(tester, log);

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    expect(log.starts, 0, reason: 'scrolling is not a drag of the card');
    expect(log.ends, 0);
  });

  testWidgets('the body scrolls', (tester) async {
    final log = _DragLog();
    await _pump(tester, log);

    // The card's body is the outermost scrollable; sections inside it have
    // their own.
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(
      position.maxScrollExtent,
      greaterThan(0),
      reason: 'nothing to scroll',
    );

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0));
  });

  testWidgets(
    'dragging the handle still moves the card, and reports both ends',
    (tester) async {
      final log = _DragLog();
      await _pump(tester, log);

      // The handle is the grab bar just below the top of the card.
      await tester.drag(
        find.byType(BottomCard),
        const Offset(0, 60),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(log.isBalanced, isTrue, reason: '\$log');
    },
  );

  testWidgets('the Search button clears the floating nav bar', (tester) async {
    // The bar is a sibling painted over the card, so the card has to leave
    // room for it or the primary action ends up underneath.
    final log = _DragLog();
    await _pump(tester, log, viewSize: const Size(400, 900));

    final search = tester.getRect(find.text('Search'));
    final card = tester.getRect(find.byType(BottomCard));

    expect(
      card.bottom - search.bottom,
      greaterThanOrEqualTo(FloatingNavBar.reservedHeight),
      reason: 'Search sits under the nav bar',
    );
  });

  testWidgets('the fields start where everything else on the card does', (
    tester,
  ) async {
    // The origin field used to sit at the gutter while the stages sat a gap
    // further in, which put two text edges on one card.
    // Tall enough that the spine below the fields is laid out.
    await _pump(tester, _DragLog(), viewSize: const Size(400, 900));

    final field = tester.getRect(find.byType(EditableText).first);
    final strip = tester.getRect(find.byType(TravellerStrip));
    expect(field.left, closeTo(strip.left, 0.5));
  });
}
