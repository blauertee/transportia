import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/routing_options.dart';
import 'package:transportia/models/transit_mode_group.dart';
import 'package:transportia/models/transitous/enums.dart';
import 'package:transportia/models/transitous/server_config.dart';
import 'package:transportia/widgets/options/icon_controls.dart';
import 'package:transportia/widgets/search/journey_spine.dart';
import 'package:transportia/widgets/search/street_leg_section.dart';

/// Holds the options the way the search screen will, so a tap on a control
/// comes back as a rebuilt spine rather than only as a callback.
class _Host extends StatefulWidget {
  const _Host({required this.initial});

  final RoutingOptions initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late RoutingOptions options = widget.initial;
  int viaTaps = 0;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 380,
            child: JourneySpine(
              options: options,
              capabilities: ServerConfig.fallback,
              onChanged: (next) => setState(() => options = next),
              onAddViaStop: () => viaTaps++,
            ),
          ),
        ),
      ),
    );
  }
}

Future<_HostState> _pumpSpine(
  WidgetTester tester, {
  RoutingOptions initial = RoutingOptions.defaults,
}) async {
  // Tall enough that an expanded stage is on screen and so tappable; the
  // default 800x600 surface would push the last stage past the bottom.
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_Host(initial: initial));
  return tester.state<_HostState>(find.byType(_Host));
}

/// An icon-only pick that is actually on screen.
///
/// `AnimatedCrossFade` keeps the collapsed branch in the tree behind an
/// `IgnorePointer`, so "is it offered" has to mean "can it be pressed".
Finder _pick(String label) => find
    .byWidgetPredicate((w) => w is IconPick && w.label == label)
    .hitTestable();

Finder _valueChip(String label) => find
    .byWidgetPredicate((w) => w is ValueChip && w.label == label)
    .hitTestable();

Finder _modeChip(String label) => find
    .byWidgetPredicate((w) => w is ModeChip && w.label == label)
    .hitTestable();

Future<void> _open(WidgetTester tester, String headline) async {
  await tester.tap(find.text(headline));
  await tester.pumpAndSettle();
}

/// Lets an on-screen message time out, so it does not outlive the test.
Future<void> _quiet(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 2));

void main() {
  testWidgets('collapsed sections summarise the current state', (tester) async {
    await _pumpSpine(tester);

    expect(find.text('TO THE STATION'), findsOneWidget);
    expect(find.text('PUBLIC TRANSPORT'), findsOneWidget);
    expect(find.text('FROM THE STATION'), findsOneWidget);

    // Both street legs default to a quarter-hour walk.
    expect(find.text('Walk · 15 min'), findsNWidgets(2));
    expect(find.text('All transport · unlimited changes'), findsOneWidget);
  });

  testWidgets('the summary follows a mile mode without expanding it', (
    tester,
  ) async {
    await _pumpSpine(
      tester,
      initial: RoutingOptions.defaults.copyWith(
        firstMileMode: TransitMode.bike,
        maxFirstMileTime: const Duration(minutes: 90),
      ),
    );

    expect(find.text('Bike · 1 h 30'), findsOneWidget);
    expect(find.text('Walk · 15 min'), findsOneWidget);
  });

  testWidgets('opening one stage leaves the others closed', (tester) async {
    await _pumpSpine(tester);
    expect(_pick('Rental'), findsNothing);

    await _open(tester, 'TO THE STATION');
    // One street leg is open, so each mile mode is offered exactly once.
    expect(_pick('Rental'), findsOneWidget);
    expect(_pick('Park & ride'), findsOneWidget);
    expect(_pick('No reservation needed'), findsNothing);

    await _open(tester, 'PUBLIC TRANSPORT');
    // Stages expand independently, so both stay open.
    expect(_pick('Rental'), findsOneWidget);
    expect(_pick('No reservation needed'), findsOneWidget);

    await _open(tester, 'TO THE STATION');
    expect(_pick('Rental'), findsNothing);
    expect(_pick('No reservation needed'), findsOneWidget);
  });

  testWidgets('a mile mode announces itself, since the icon cannot', (
    tester,
  ) async {
    final host = await _pumpSpine(tester);
    await _open(tester, 'TO THE STATION');

    await tester.tap(_pick('Rental'));
    await tester.pump();

    expect(host.options.firstMileMode, TransitMode.rental);
    expect(find.text('Rental to the station'), findsOneWidget);

    // And it clears itself rather than sitting over the card.
    await _quiet(tester);
    expect(find.text('Rental to the station'), findsNothing);
  });

  testWidgets('every street mode the defaults editor can store is offered', (
    tester,
  ) async {
    // A plain car arriving from stored defaults used to light up nothing and
    // be summarised as walking.
    await _pumpSpine(
      tester,
      initial: RoutingOptions.defaults.copyWith(firstMileMode: TransitMode.car),
    );
    expect(find.text('Car · 15 min'), findsOneWidget);

    await _open(tester, 'TO THE STATION');
    for (final mode in RoutingOptions.streetModeChoices) {
      expect(
        _pick(mileModeLabel(mode)),
        findsOneWidget,
        reason: '${mode.wireName} has no pick',
      );
    }
  });

  group('transport', () {
    testWidgets('"All transport" holds only while nothing is narrowed', (
      tester,
    ) async {
      final host = await _pumpSpine(tester);
      await _open(tester, 'PUBLIC TRANSPORT');

      await tester.tap(_pick('Boat'));
      await tester.pump();

      expect(find.text('All transport · unlimited changes'), findsNothing);
      expect(host.options.transitModes, isNotEmpty);
      expect(host.options.transitModes, isNot(contains(TransitMode.ferry)));

      await tester.tap(_pick('Boat'));
      await tester.pump();

      expect(find.text('All transport · unlimited changes'), findsOneWidget);
      // Everything on sends nothing, so a mode added upstream is not
      // silently excluded by an enumerated list.
      expect(host.options.transitModes, isEmpty);
      await _quiet(tester);
    });

    testWidgets('a mode from the dropdown comes back as a chip', (
      tester,
    ) async {
      final host = await _pumpSpine(tester);
      await _open(tester, 'PUBLIC TRANSPORT');

      await tester.tap(_pick('More transport'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flights'));
      await tester.pump();

      expect(host.options.transitModes, contains(TransitMode.airplane));
      // The icon row still carries the whole selection, so the collapsed
      // summary cannot lie about it.
      expect(_modeChip('Flights'), findsOneWidget);

      await tester.tap(_modeChip('Flights'));
      await tester.pump();

      expect(host.options.transitModes, isNot(contains(TransitMode.airplane)));
      expect(_modeChip('Flights'), findsNothing);
      await _quiet(tester);
    });

    testWidgets('the transfer limit reads as a number then as unlimited', (
      tester,
    ) async {
      final host = await _pumpSpine(tester);
      await _open(tester, 'PUBLIC TRANSPORT');

      await tester.tap(_valueChip('Maximum changes'));
      await tester.pumpAndSettle();

      final slider = tester.widget<OptionSlider>(find.byType(OptionSlider));
      expect(slider.max, RoutingOptions.unlimitedTransfersSliderValue);

      slider.onChanged(2);
      await tester.pump();
      expect(host.options.maxTransfers, 2);
      expect(find.text('All transport · max 2 changes'), findsOneWidget);

      slider.onChanged(RoutingOptions.unlimitedTransfersSliderValue.toDouble());
      await tester.pump();
      // Unlimited omits the parameter rather than sending a large number.
      expect(host.options.maxTransfers, isNull);
      expect(find.text('All transport · unlimited changes'), findsOneWidget);
      await _quiet(tester);
    });
  });

  group('bike carriage', () {
    testWidgets('appears with a bike at both ends, already on', (tester) async {
      final host = await _pumpSpine(tester);
      await _open(tester, 'PUBLIC TRANSPORT');
      expect(_pick('Bike carried on board'), findsNothing);

      await _open(tester, 'TO THE STATION');
      await tester.tap(_pick('Bike'));
      await tester.pumpAndSettle();
      // One end is not enough: the bike is being left at the station.
      expect(_pick('Bike carried on board'), findsNothing);

      await _open(tester, 'FROM THE STATION');
      await tester.tap(_pick('Bike').last);
      await tester.pumpAndSettle();

      expect(_pick('Bike carried on board'), findsOneWidget);
      expect(host.options.requireBikeTransport, isTrue);
      expect(host.options.bikeCarriageIsManual, isFalse);
      await _quiet(tester);
    });

    testWidgets('stays the rider\'s to turn off', (tester) async {
      final host = await _pumpSpine(
        tester,
        initial: RoutingOptions.defaults.copyWith(
          firstMileMode: TransitMode.bike,
          lastMileMode: TransitMode.bike,
        ),
      );
      await _open(tester, 'PUBLIC TRANSPORT');

      await tester.tap(_pick('Bike carried on board'));
      await tester.pump();

      expect(host.options.requireBikeTransport, isFalse);
      expect(host.options.bikeCarriageIsManual, isTrue);
      expect(find.text('Bike not carried'), findsOneWidget);
      expect(_pick('Bike not carried'), findsOneWidget);
      await _quiet(tester);
    });

    testWidgets('retires once a bike leaves one end', (tester) async {
      final host = await _pumpSpine(
        tester,
        initial: RoutingOptions.defaults.copyWith(
          firstMileMode: TransitMode.bike,
          lastMileMode: TransitMode.bike,
          bikeCarriageOverride: false,
        ),
      );
      await _open(tester, 'FROM THE STATION');
      await tester.tap(_pick('Walk'));
      await tester.pumpAndSettle();

      expect(host.options.bikeCarriageIsManual, isFalse);
      expect(host.options.requireBikeTransport, isFalse);

      await _open(tester, 'PUBLIC TRANSPORT');
      expect(_pick('Bike not carried'), findsNothing);
      expect(_pick('Bike carried on board'), findsNothing);
      await _quiet(tester);
    });
  });

  group('traveller', () {
    testWidgets('step-free keeps its name and says what it did', (
      tester,
    ) async {
      final host = await _pumpSpine(tester);

      expect(find.text('Step-free'), findsOneWidget);
      await tester.tap(find.text('Step-free'));
      await tester.pump();

      expect(host.options.wheelchairAccessibleOnly, isTrue);
      expect(find.text('Step-free only'), findsOneWidget);
      await _quiet(tester);
    });

    testWidgets('pace hides its sliders until asked, cycling until it cycles', (
      tester,
    ) async {
      await _pumpSpine(tester);
      expect(find.text('Walking'), findsNothing);

      await tester.tap(_pick('Pace'));
      await tester.pumpAndSettle();

      expect(find.text('Walking'), findsOneWidget);
      // Nothing in the journey cycles yet, so no cycling speed applies.
      expect(find.text('Cycling'), findsNothing);

      await _open(tester, 'TO THE STATION');
      await tester.tap(_pick('Bike'));
      await tester.pumpAndSettle();

      expect(find.text('Cycling'), findsOneWidget);
      await _quiet(tester);
    });
  });

  testWidgets('the via picker is left to the screen that owns the search', (
    tester,
  ) async {
    final host = await _pumpSpine(tester);
    await _open(tester, 'PUBLIC TRANSPORT');

    await tester.tap(_pick('Travel through a stop'));
    await tester.pump();

    expect(host.viaTaps, 1);
  });

  testWidgets('a tooltip does not outlive the layout it pointed at', (
    tester,
  ) async {
    await _pumpSpine(tester);
    await _open(tester, 'TO THE STATION');

    // Held rather than tester.longPress, which lifts the finger and so
    // dismisses the tooltip on its way out.
    final held = await tester.startGesture(tester.getCenter(_pick('Rental')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    // The picks carry no text of their own, so this is the bubble.
    expect(find.text('Rental'), findsOneWidget);

    // Picking a mode moves the row out from under the finger, so no exit
    // gesture ever fires and the bubble would otherwise strand itself.
    await tester.tap(_pick('Bike'));
    await tester.pump();
    expect(find.text('Rental'), findsNothing);

    await held.up();
    await _quiet(tester);
  });

  test('the extras the dropdown offers all have a name', () {
    for (final mode in TransitModeGroup.extras) {
      expect(TransitModeGroup.extraLabel(mode), isNotEmpty);
    }
  });
}
