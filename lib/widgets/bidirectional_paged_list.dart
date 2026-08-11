import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'load_more_button.dart';

/// How far past the top of the list to sit when a "See previous" button is
/// there, so the button is visible without being the first thing read.
const double kSeePreviousScrollOffset = 40.0;

/// A list that can grow at both ends, anchored so that loading earlier items
/// does not move the ones already on screen.
///
/// [items] is one list; [centerIndex] says where the anchor sits inside it.
/// Items before the anchor are laid out in a reverse-growth sliver above it,
/// items from the anchor onwards in a normal sliver below.
class BidirectionalPagedList<T> extends StatelessWidget {
  const BidirectionalPagedList({
    super.key,
    required this.controller,
    required this.centerKey,
    required this.items,
    required this.centerIndex,
    required this.itemBuilder,
    required this.hasPrevious,
    required this.hasNext,
    required this.isLoadingPrevious,
    required this.isLoadingNext,
    required this.onLoadPrevious,
    required this.onLoadNext,
    this.padding = EdgeInsets.zero,
    this.trailingExtent = 0,
  });

  final ScrollController controller;

  /// Identifies the anchor sliver. Must be unique within the scroll view and
  /// stable across rebuilds.
  final Key centerKey;

  final List<T> items;
  final int centerIndex;
  final Widget Function(T item) itemBuilder;

  final bool hasPrevious;
  final bool hasNext;
  final bool isLoadingPrevious;
  final bool isLoadingNext;
  final VoidCallback onLoadPrevious;
  final VoidCallback onLoadNext;

  /// Applied to both item slivers, not to the trailing spacer.
  final EdgeInsetsGeometry padding;

  /// Empty space kept below the last item, for chrome floating over the list.
  final double trailingExtent;

  List<T> get _beforeItems => items.sublist(0, centerIndex);
  List<T> get _afterItems => items.sublist(centerIndex);

  @override
  Widget build(BuildContext context) {
    final beforeItems = _beforeItems;
    final afterItems = _afterItems;

    return CustomScrollView(
      controller: controller,
      center: centerKey,
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildBefore(beforeItems, index),
              childCount: beforeItems.length + (hasPrevious ? 1 : 0),
            ),
          ),
        ),
        SliverPadding(
          key: centerKey,
          padding: padding,
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildAfter(afterItems, index),
              childCount: afterItems.length + (hasNext ? 1 : 0),
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: trailingExtent)),
      ],
    );
  }

  /// Within a reverse-growth sliver, delegate index 0 is adjacent to the
  /// center anchor, so items are listed nearest-first with the "See previous"
  /// button last — farthest away, requiring a scroll up to reach it.
  Widget _buildBefore(List<T> beforeItems, int index) {
    if (index < beforeItems.length) {
      return itemBuilder(beforeItems[beforeItems.length - 1 - index]);
    }
    return LoadMoreButton(
      onTap: onLoadPrevious,
      isLoading: isLoadingPrevious,
      label: 'See previous',
      icon: LucideIcons.chevronUp,
    );
  }

  Widget _buildAfter(List<T> afterItems, int index) {
    if (index < afterItems.length) return itemBuilder(afterItems[index]);
    return LoadMoreButton(onTap: onLoadNext, isLoading: isLoadingNext);
  }
}

/// Scrolls just past a "See previous" button that has appeared at the top, so
/// riders see there is more above without landing on the button itself.
///
/// Call after the frame that first renders the button.
void scrollPastSeePrevious(ScrollController controller) {
  if (!controller.hasClients) return;
  final minExtent = controller.position.minScrollExtent;
  controller.jumpTo(minExtent + kSeePreviousScrollOffset);
}
