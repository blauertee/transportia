import 'package:flutter/widgets.dart';
import '../models/time_selection.dart';
import '../theme/app_colors.dart';
import '../utils/time_utils.dart';
import 'bottom_overlay_card.dart';

/// How long the overlay takes to fade in and out.
const Duration _kTimeOverlayFadeDuration = Duration(milliseconds: 180);

/// Fully transparent: the overlay's own card dims what is behind it, so a
/// barrier colour here would dim it twice.
const Color _kTimeOverlayBarrierColor = Color(0x00000000);

/// How many days past today the date strip reaches.
const int _kSelectableDaysAhead = 30;

/// Shortcuts from the current time, offered under the wheels.
const List<Duration> _kQuickOffsets = [
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(hours: 1),
];

/// Row height of the time wheels; the highlight band behind them must match.
const double _kWheelItemExtent = 44;

/// Rows of the wheel visible at once: the selected one and two either side.
const int _kWheelVisibleRows = 5;

/// Day chip width and spacing; the strip scrolls by their sum to reveal one.
const double _kDayChipWidth = 76;
const double _kDayChipGap = 8;

/// How long a wheel or the date strip takes to travel to a value set by a
/// shortcut rather than by the finger.
const Duration _kJumpDuration = Duration(milliseconds: 280);

/// Shows [TimeSelectionOverlay] over the current screen, resolving once it has
/// closed however it was dismissed.
///
/// Not barrier-dismissible: the overlay has its own dismiss action, and a tap
/// outside it lands on the map or the field behind it.
Future<void> showTimeSelectionOverlay(
  BuildContext context, {
  required TimeSelection currentSelection,
  required ValueChanged<TimeSelection> onSelectionChanged,
  required VoidCallback onDismiss,
  bool showDepartArriveToggle = true,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Time selection',
    barrierColor: _kTimeOverlayBarrierColor,
    transitionDuration: _kTimeOverlayFadeDuration,
    pageBuilder: (context, _, __) => TimeSelectionOverlay(
      currentSelection: currentSelection,
      onSelectionChanged: onSelectionChanged,
      onDismiss: onDismiss,
      showDepartArriveToggle: showDepartArriveToggle,
    ),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class TimeSelectionOverlay extends StatefulWidget {
  const TimeSelectionOverlay({
    super.key,
    required this.currentSelection,
    required this.onSelectionChanged,
    required this.onDismiss,
    this.showDepartArriveToggle = true,
    this.now,
  });

  final TimeSelection currentSelection;
  final void Function(TimeSelection) onSelectionChanged;
  final VoidCallback onDismiss;
  final bool showDepartArriveToggle;

  /// The current time; read from the clock when null.
  final DateTime? now;

  @override
  State<TimeSelectionOverlay> createState() => _TimeSelectionOverlayState();
}

class _TimeSelectionOverlayState extends State<TimeSelectionOverlay> {
  late DateTime _selectedDate;
  late int _selectedHour;
  late int _selectedMinute;
  late bool _isArriveBy;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  DateTime _now() => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    // A "now" selection carries the moment it was made, which may be long
    // past; the wheels should open on the clock as it reads today.
    final initial = widget.currentSelection.isNow
        ? _now()
        : widget.currentSelection.dateTime;
    _selectedDate = DateTime(initial.year, initial.month, initial.day);
    _selectedHour = initial.hour;
    _selectedMinute = initial.minute;
    _isArriveBy = widget.currentSelection.isArriveBy;
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(
      initialItem: _selectedMinute,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  DateTime get _selectedDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedHour,
      _selectedMinute,
    );
  }

  /// Every day the strip offers: today through [_kSelectableDaysAhead] days
  /// ahead, stretched to reach a selection that already lies outside that.
  List<DateTime> get _selectableDays {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(
      today.year,
      today.month,
      today.day + _kSelectableDaysAhead,
    );
    return calendarDays(
      _selectedDate.isBefore(today) ? _selectedDate : today,
      _selectedDate.isAfter(lastDay) ? _selectedDate : lastDay,
    );
  }

  void _jumpTo(DateTime target) {
    setState(() {
      _selectedDate = DateTime(target.year, target.month, target.day);
      _selectedHour = target.hour;
      _selectedMinute = target.minute;
    });
    _spinWheel(_hourController, target.hour, Duration.hoursPerDay);
    _spinWheel(_minuteController, target.minute, Duration.minutesPerHour);
  }

  /// Turns a looping wheel to [value] the short way round.
  void _spinWheel(
    FixedExtentScrollController controller,
    int value,
    int valueCount,
  ) {
    if (!controller.hasClients) return;
    final current = controller.selectedItem;
    var steps = (value - current) % valueCount;
    if (steps > valueCount ~/ 2) steps -= valueCount;
    if (steps == 0) return;
    controller.animateToItem(
      current + steps,
      duration: _kJumpDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _handleConfirm() {
    final selection = TimeSelection(
      dateTime: _selectedDateTime,
      isArriveBy: _isArriveBy,
      isDefaultNow: false,
    );
    widget.onSelectionChanged(selection);
    widget.onDismiss();
  }

  void _handleSetNow() {
    widget.onSelectionChanged(TimeSelection.now());
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final now = _now();
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showDepartArriveToggle) ...[
          _DepartArriveToggle(
            isArriveBy: _isArriveBy,
            onChanged: (isArriveBy) => setState(() => _isArriveBy = isArriveBy),
          ),
          const SizedBox(height: 12),
        ],
        _DayStrip(
          days: _selectableDays,
          today: DateTime(now.year, now.month, now.day),
          selectedDate: _selectedDate,
          onChanged: (date) => setState(() => _selectedDate = date),
        ),
        const SizedBox(height: 12),
        _TimeWheels(
          hourController: _hourController,
          minuteController: _minuteController,
          onHourChanged: (hour) => setState(() => _selectedHour = hour),
          onMinuteChanged: (minute) => setState(() => _selectedMinute = minute),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final offset in _kQuickOffsets) ...[
              if (offset != _kQuickOffsets.first) const SizedBox(width: 8),
              Expanded(
                child: _QuickOffsetChip(
                  offset: offset,
                  onTap: () => _jumpTo(_now().add(offset)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionButton.secondary(
                label: 'Now',
                onTap: _handleSetNow,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton.primary(
                label: 'Confirm',
                onTap: _handleConfirm,
              ),
            ),
          ],
        ),
      ],
    );

    return BottomOverlayCard(
      title: 'Set time',
      maxHeightFactor: 0.8,
      padding: const EdgeInsets.all(16),
      onDismiss: widget.onDismiss,
      child: content,
    );
  }
}

/// Faint fill behind the overlay's controls, readable in either theme.
Color _controlFill() => AppColors.black.withValues(alpha: 0.06);

class _DepartArriveToggle extends StatelessWidget {
  const _DepartArriveToggle({
    required this.isArriveBy,
    required this.onChanged,
  });

  final bool isArriveBy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _controlFill(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleSegment(
              label: 'Depart at',
              isSelected: !isArriveBy,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ToggleSegment(
              label: 'Arrive by',
              isSelected: isArriveBy,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentOf(context)
              : const Color(0x00000000),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.solidWhite : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}

/// A sideways-scrolling row of days, one tap to pick any of them.
class _DayStrip extends StatefulWidget {
  const _DayStrip({
    required this.days,
    required this.today,
    required this.selectedDate,
    required this.onChanged,
  });

  final List<DateTime> days;
  final DateTime today;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<_DayStrip> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealSelected(animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant _DayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _revealSelected(animate: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scrolls the selected day into view with the day before it still showing,
  /// so it is plain there is more to the left.
  void _revealSelected({required bool animate}) {
    if (!_controller.hasClients) return;
    final index = widget.days.indexOf(widget.selectedDate);
    if (index < 0) return;
    final position = _controller.position;
    final target = ((index - 1) * (_kDayChipWidth + _kDayChipGap)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (animate) {
      _controller.animateTo(
        target,
        duration: _kJumpDuration,
        curve: Curves.easeOutCubic,
      );
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: widget.days.length,
        separatorBuilder: (_, __) => const SizedBox(width: _kDayChipGap),
        itemBuilder: (context, index) {
          final day = widget.days[index];
          return _DayChip(
            day: day,
            today: widget.today,
            isSelected: day == widget.selectedDate,
            onTap: () => widget.onChanged(day),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.today,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final DateTime today;
  final bool isSelected;
  final VoidCallback onTap;

  String get _dayName {
    if (day == today) return 'Today';
    if (day == DateTime(today.year, today.month, today.day + 1)) {
      return 'Tomorrow';
    }
    return formatWeekday(day);
  }

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? AppColors.solidWhite : AppColors.black;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: _kDayChipWidth,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentOf(context) : _controlFill(),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _dayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatDayMonth(day),
              style: TextStyle(
                fontSize: 12,
                color: foreground.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hour and minute wheels side by side over a band marking the chosen row.
class _TimeWheels extends StatelessWidget {
  const _TimeWheels({
    required this.hourController,
    required this.minuteController,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  final FixedExtentScrollController hourController;
  final FixedExtentScrollController minuteController;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kWheelItemExtent * _kWheelVisibleRows,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: _kWheelItemExtent,
            decoration: BoxDecoration(
              color: _controlFill(),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TimeWheel(
                key: const ValueKey('hourWheel'),
                controller: hourController,
                valueCount: Duration.hoursPerDay,
                onChanged: onHourChanged,
              ),
              Text(
                ':',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
              _TimeWheel(
                key: const ValueKey('minuteWheel'),
                controller: minuteController,
                valueCount: Duration.minutesPerHour,
                onChanged: onMinuteChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A looping wheel of two-digit values from 0 to [valueCount] - 1, so 59
/// runs straight on to 00 without winding back through the whole hour.
class _TimeWheel extends StatelessWidget {
  const _TimeWheel({
    super.key,
    required this.controller,
    required this.valueCount,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int valueCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: _kWheelItemExtent,
        physics: const FixedExtentScrollPhysics(),
        diameterRatio: 1.6,
        overAndUnderCenterOpacity: 0.4,
        onSelectedItemChanged: (index) => onChanged(index % valueCount),
        childDelegate: ListWheelChildLoopingListDelegate(
          children: [
            for (var value = 0; value < valueCount; value++)
              Center(
                child: Text(
                  value.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickOffsetChip extends StatelessWidget {
  const _QuickOffsetChip({required this.offset, required this.onTap});

  final Duration offset;
  final VoidCallback onTap;

  String get _label {
    if (offset.inMinutes < Duration.minutesPerHour) {
      return 'In ${offset.inMinutes} min';
    }
    return 'In ${offset.inHours} h';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _controlFill(),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            _label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton.primary({required this.label, required this.onTap})
    : isPrimary = true;

  const _ActionButton.secondary({required this.label, required this.onTap})
    : isPrimary = false;

  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.accentOf(context) : _controlFill(),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isPrimary ? AppColors.solidWhite : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}
