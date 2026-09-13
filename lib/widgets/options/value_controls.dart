import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// Value controls shared by the search screen and the defaults editor.
///
/// They live here rather than beside either one, so neither has to import the
/// other's folder to reuse a control.

class QuickValueCard extends StatelessWidget {
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const QuickValueCard({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentWash(accent) : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : const Color(0x14000000),
          ),
        ),
        child: Center(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: selected ? accent : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class StepperSelector extends StatefulWidget {
  final double value;
  final double minValue;
  final double maxValue;
  final double step;
  final String label;
  final String Function(double) displayBuilder;
  final ValueChanged<double> onChanged;

  const StepperSelector({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.step,
    required this.label,
    required this.displayBuilder,
    required this.onChanged,
  });

  @override
  State<StepperSelector> createState() => StepperSelectorState();
}

class StepperSelectorState extends State<StepperSelector> {
  double _dragOffset = 0;
  Timer? _repeatTimer;
  int _holdDirection = 0;

  bool get _canIncrement => widget.value < widget.maxValue - widget.step / 2;

  bool get _canDecrement => widget.value > widget.minValue + widget.step / 2;

  int get _stepDecimals {
    final stepString = widget.step.toString();
    if (stepString.contains('.')) {
      return stepString.split('.').last.length;
    }
    return 0;
  }

  double _normalize(double value) {
    final decimals = _stepDecimals;
    if (decimals == 0) return value.roundToDouble();
    final factor = math.pow(10, decimals).toDouble();
    return (value * factor).round() / factor;
  }

  void _change(double delta) {
    double newValue = widget.value + delta;
    newValue = newValue.clamp(widget.minValue, widget.maxValue);
    newValue = _normalize(newValue);
    if ((newValue - widget.value).abs() >= 0.0001) {
      widget.onChanged(newValue);
    }
  }

  void _startHold(int direction) {
    if ((direction > 0 && !_canIncrement) ||
        (direction < 0 && !_canDecrement)) {
      return;
    }
    if (_holdDirection == direction) return;
    _holdDirection = direction;
    _change(direction * widget.step);
    _repeatTimer?.cancel();
    _repeatTimer = Timer(const Duration(milliseconds: 420), () {
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
        if ((_holdDirection > 0 && !_canIncrement) ||
            (_holdDirection < 0 && !_canDecrement)) {
          _stopHold();
        } else {
          _change(_holdDirection * widget.step);
        }
      });
    });
  }

  void _stopHold() {
    _holdDirection = 0;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  void _handleDragStart(DragStartDetails details) {
    _dragOffset = 0;
    _stopHold();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _dragOffset += details.delta.dx;
    if (_dragOffset >= 14) {
      _startHold(1);
      _dragOffset = 0;
    } else if (_dragOffset <= -14) {
      _startHold(-1);
      _dragOffset = 0;
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    _dragOffset = 0;
    _stopHold();
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0x0F000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x11000000)),
        ),
        child: Row(
          children: [
            _StepperArrow(
              icon: LucideIcons.chevronLeft,
              enabled: _canDecrement,
              color: accent,
              onTapDown: () => _startHold(-1),
              onTapUp: _stopHold,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.displayBuilder(widget.value),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(widget.label, style: AppText.caption),
                ],
              ),
            ),
            _StepperArrow(
              icon: LucideIcons.chevronRight,
              enabled: _canIncrement,
              color: accent,
              onTapDown: () => _startHold(1),
              onTapUp: _stopHold,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;

  const _StepperArrow({
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onTapDown,
    required this.onTapUp,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => onTapDown() : null,
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapUp,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? color : color.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
