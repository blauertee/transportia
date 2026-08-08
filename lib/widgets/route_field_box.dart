import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/validation_toast.dart';
import '../utils/haptics.dart';
import '../theme/app_colors.dart';
import 'search/journey_segment.dart';
import 'skeletons/skeleton_shimmer.dart';

/// The origin and destination of a search, stacked in travel order.
///
/// They read top to bottom rather than side by side because the search
/// options sit *between* them: the journey's stages only mean anything in
/// sequence, and a horizontal pair has no between to put them in.
class RouteFieldBox extends StatefulWidget {
  const RouteFieldBox({
    super.key,
    required this.fromController,
    required this.toController,
    this.fromFocusNode,
    this.toFocusNode,
    this.showMyLocationDefault = false,
    required this.accentColor,
    required this.onSwapRequested,
    required this.layerLink,
    this.fromLoading = false,
    this.toLoading = false,
    this.middle,
  });

  final TextEditingController fromController;
  final TextEditingController toController;
  final FocusNode? fromFocusNode;
  final FocusNode? toFocusNode;
  final bool showMyLocationDefault;
  final Color accentColor;
  final bool Function() onSwapRequested;
  final LayerLink layerLink;
  final bool fromLoading;
  final bool toLoading;

  /// Sits between the two fields, sharing their gutter so the rail continues
  /// the line the two markers start and end.
  ///
  /// Callers drop it while a field has focus: the suggestions overlay hangs
  /// off the bottom of this box, and it belongs under the field being typed
  /// into rather than under everything the journey could be.
  final Widget? middle;

  @override
  State<RouteFieldBox> createState() => _RouteFieldBoxState();
}

class _RouteFieldBoxState extends State<RouteFieldBox> {
  bool _swapPressed = false;

  @override
  void initState() {
    super.initState();
    widget.fromController.addListener(_onChanged);
    widget.fromFocusNode?.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant RouteFieldBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fromController != widget.fromController) {
      oldWidget.fromController.removeListener(_onChanged);
      widget.fromController.addListener(_onChanged);
    }
    if (oldWidget.fromFocusNode != widget.fromFocusNode) {
      oldWidget.fromFocusNode?.removeListener(_onChanged);
      widget.fromFocusNode?.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.fromController.removeListener(_onChanged);
    widget.fromFocusNode?.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: widget.layerLink,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.black.withValues(alpha: 0.1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EndpointRow(
              marker: _EndpointDot(color: widget.accentColor, filled: false),
              trailing: _buildSwapButton(context),
              child: _InlineField(
                controller: widget.fromController,
                focusNode: widget.fromFocusNode,
                hintText: 'From',
                isFromField: true,
                showMyLocationDefault: widget.showMyLocationDefault,
                accentColor: widget.accentColor,
                showLoading: widget.fromLoading,
              ),
            ),
            if (widget.middle case final middle?) ...[
              const SizedBox(height: 14),
              middle,
              const SizedBox(height: 14),
            ] else
              Padding(
                padding: const EdgeInsets.only(
                  left: journeyGutterWidth,
                  top: 2,
                  bottom: 2,
                ),
                child: Container(
                  height: 1,
                  color: AppColors.black.withValues(alpha: 0.08),
                ),
              ),
            _EndpointRow(
              marker: _EndpointDot(color: widget.accentColor, filled: true),
              child: _InlineField(
                controller: widget.toController,
                focusNode: widget.toFocusNode,
                hintText: 'To',
                isFromField: false,
                showMyLocationDefault: false,
                accentColor: widget.accentColor,
                showLoading: widget.toLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwapButton(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final fromText = widget.fromController.text;
        final toText = widget.toController.text;
        if (fromText.isEmpty && toText.isEmpty) {
          showValidationToast(context, "Supply at least one location to swap");
          return;
        }
        final swapped = widget.onSwapRequested();
        if (!swapped) return;
        Haptics.mediumTick();
      },
      onTapDown: (_) => setState(() => _swapPressed = true),
      onTapUp: (_) => setState(() => _swapPressed = false),
      onTapCancel: () => setState(() => _swapPressed = false),
      child: Semantics(
        button: true,
        label: 'Swap origin and destination',
        child: AnimatedScale(
          duration: const Duration(milliseconds: 100),
          scale: _swapPressed ? 0.92 : 1.0,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _swapPressed
                  ? AppColors.white.withValues(alpha: 0.92)
                  : AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.black.withValues(alpha: 0.1)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              LucideIcons.arrowUpDown,
              size: 16,
              color: widget.accentColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// One endpoint: its marker in the shared gutter, its field, and whatever
/// sits at the trailing edge.
class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.marker,
    required this.child,
    this.trailing,
  });

  final Widget marker;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: journeyGutterWidth,
          child: Center(
            // Onto the rail's centre line rather than the gutter's, so the
            // markers and the rail sit on one straight line.
            child: Transform.translate(
              offset: const Offset(
                -(journeyGutterWidth - journeyRailWidth) / 2,
                0,
              ),
              child: marker,
            ),
          ),
        ),
        Expanded(child: child),
        if (trailing case final trailing?) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }
}

class _EndpointDot extends StatelessWidget {
  const _EndpointDot({required this.color, required this.filled});

  final Color color;

  /// Hollow for where you start, solid for where you end — the convention
  /// every map app already taught people.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: filled ? color : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}

class _InlineField extends StatelessWidget {
  const _InlineField({
    required this.controller,
    required this.hintText,
    required this.isFromField,
    required this.showMyLocationDefault,
    required this.accentColor,
    this.focusNode,
    this.showLoading = false,
  });

  final TextEditingController controller;
  final String hintText;
  final bool isFromField;
  final bool showMyLocationDefault;
  final Color accentColor;
  final FocusNode? focusNode;
  final bool showLoading;

  @override
  Widget build(BuildContext context) {
    final wantsOverlay =
        isFromField &&
        showMyLocationDefault &&
        controller.text.isEmpty &&
        !(focusNode?.hasFocus ?? false);
    final isFocused = focusNode?.hasFocus ?? false;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: wantsOverlay ? 1.0 : 0.0),
      builder: (context, overlayT, _) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            CupertinoTextField(
              controller: controller,
              focusNode: focusNode,
              placeholder:
                  (isFromField &&
                      showMyLocationDefault &&
                      controller.text.isEmpty &&
                      !isFocused)
                  ? ''
                  : hintText,
              placeholderStyle: TextStyle(
                color: AppColors.black.withValues(alpha: 0.4),
                fontSize: 16,
              ),
              style: TextStyle(color: AppColors.black, fontSize: 16),
              cursorColor: AppColors.accentOf(context),
              decoration: null,
              padding: const EdgeInsets.symmetric(vertical: 8),
              maxLines: 1,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.text,
            ),
            IgnorePointer(
              ignoring: overlayT < 0.01,
              child: Opacity(
                opacity: overlayT,
                child: Transform.translate(
                  offset: Offset(0, (1 - overlayT) * 4),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: (1 - overlayT) * 2.0,
                      sigmaY: (1 - overlayT) * 2.0,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => focusNode?.requestFocus(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.mousePointer2,
                            size: 18,
                            color: accentColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'My Location',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: !showLoading
                    ? const SizedBox.shrink()
                    : IgnorePointer(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SkeletonShimmer(
                            baseColor: const Color(0xFFE2E7EC),
                            highlightColor: const Color(0xFFF7F9FC),
                            period: const Duration(milliseconds: 1100),
                            child: Container(
                              constraints: const BoxConstraints(
                                maxWidth: 160,
                                minWidth: 96,
                              ),
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E7EC),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
