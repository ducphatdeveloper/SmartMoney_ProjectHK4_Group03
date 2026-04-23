import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';

/// Widget thanh trượt ngang chọn ngày (Ngày, Tuần, Tháng, etc)
class TransactionDateSlider extends StatefulWidget {
  final ScrollController scrollController;

  const TransactionDateSlider({
    super.key,
    required this.scrollController,
  });

  @override
  State<TransactionDateSlider> createState() => _TransactionDateSliderState();
}

class _TransactionDateSliderState extends State<TransactionDateSlider> {
  int _lastScrolledIndex = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<TransactionProvider>();
    _scrollToCurrentIndex(provider);
  }

  void _scrollToCurrentIndex(TransactionProvider provider) {
    const double ITEM_WIDTH = 140.0;

    if (provider.dateRanges.isEmpty || provider.currentIndex == _lastScrolledIndex) {
      return;
    }

    _lastScrolledIndex = provider.currentIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) return;

      try {
        final scrollPosition = widget.scrollController.position;
        final screenWidth = MediaQuery.of(context).size.width;
        final maxScroll = scrollPosition.maxScrollExtent;

        final itemStartOffset = provider.currentIndex * ITEM_WIDTH;
        final itemCenterOffset = itemStartOffset + (ITEM_WIDTH / 2);
        final targetOffset = itemCenterOffset - (screenWidth / 2);
        final clampedOffset = targetOffset.clamp(0.0, maxScroll);

        widget.scrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        debugPrint('❌ [ScrollError] $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const double ITEM_WIDTH = 140.0;

    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        return Container(
          height: 48,
          color: Colors.black87,
          child: ListView.builder(
            controller: widget.scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: provider.dateRanges.length,
            itemBuilder: (context, index) {
              final range = provider.dateRanges[index];
              final isSelected = provider.selectedDateRange == range;

              return SizedBox(
                width: ITEM_WIDTH,
                child: GestureDetector(
                  onTap: () => provider.selectDateRange(context, range),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? Colors.green : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        range.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Widget label cho mode đặc biệt (Tất cả / Tùy chỉnh)
class TransactionSpecialModeLabel extends StatelessWidget {
  final String label;

  const TransactionSpecialModeLabel({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.black87,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.access_time, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              context.read<TransactionProvider>().changeDateRangeMode(context, 'MONTHLY');
            },
            child: const Icon(Icons.close, color: Colors.grey, size: 18),
          ),
        ],
      ),
    );
  }
}

