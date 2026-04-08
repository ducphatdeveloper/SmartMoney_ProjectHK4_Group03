import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';

/// Widget hiển thị tóm tắt Thu/Chi
class TransactionSummary extends StatelessWidget {
  const TransactionSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        if (provider.journalGroups.isEmpty && !provider.isLoading) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: Tiền vào - Tiền ra
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tiền vào', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        FormatHelper.formatVND(provider.totalIncome),
                        style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Tiền ra', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        FormatHelper.formatVND(provider.totalExpense),
                        style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.grey),
              ),
              // Row 2: Còn lại
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Còn lại', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    FormatHelper.formatVND(provider.netTotal),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Widget nút báo cáo — gọi [onTap] khi user bấm để toggle chế độ báo cáo inline
class TransactionReportButton extends StatelessWidget {
  /// Callback khi bấm nút — thường là `() => setState(() => _isReportMode = true)`
  final VoidCallback? onTap;

  const TransactionReportButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.green),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.bar_chart, color: Colors.green, size: 18),
          label: const Text(
            'Xem báo cáo cho giai đoạn này',
            style: TextStyle(
                color: Colors.green, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

