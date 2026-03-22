import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_item_widget.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_date_group.dart';

/// Widget danh sách giao dịch (Journal hoặc Grouped mode)
class TransactionListView extends StatelessWidget {
  const TransactionListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        if (provider.isGroupedMode) {
          return const TransactionGroupedList();
        } else {
          return const TransactionJournalList();
        }
      },
    );
  }
}

/// Chế độ Nhật ký (gom theo ngày)
class TransactionJournalList extends StatelessWidget {
  const TransactionJournalList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        if (provider.journalGroups.isEmpty && !provider.isLoading) {
          return _buildEmptyState(Icons.receipt_long);
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: provider.journalGroups.length,
          itemBuilder: (context, index) {
            final group = provider.journalGroups[index];

            return Column(
              children: [
                // Tiêu đề nhóm ngày
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.date.day.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            group.displayDateLabel,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        FormatHelper.formatVND(group.netAmount),
                        style: TextStyle(
                          color: group.netAmount >= 0 ? Colors.greenAccent : Colors.orange.shade600,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Danh sách giao dịch
                ...group.transactions.map((transaction) {
                  return TransactionItemWidget(
                    transaction: transaction,
                    onTap: () {
                      // TODO: Navigate to transaction detail
                    },
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Chưa có giao dịch nào',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

/// Chế độ Nhóm (gom theo danh mục → sau đó gom theo ngày)
class TransactionGroupedList extends StatelessWidget {
  const TransactionGroupedList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        if (provider.groupedCategories.isEmpty && !provider.isLoading) {
          return _buildEmptyState(Icons.category);
        }

        // 👇 Tạo map displayDateLabel từ journalGroups
        // Backend đã gửi displayDateLabel sẵn, chỉ cần lấy ra
        final dateLabelsMap = <String, String>{};
        for (final journalGroup in provider.journalGroups) {
          // Key: ngày (YYYY-MM-DD format từ DateTime)
          final dateKey = journalGroup.date.toString().split(' ')[0];
          // Value: displayDateLabel từ backend (VD: "Chủ Nhật, 15/03/2026")
          dateLabelsMap[dateKey] = journalGroup.displayDateLabel;
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: provider.groupedCategories.length,
          itemBuilder: (context, index) {
            final group = provider.groupedCategories[index];
            
            // 👇 Gom giao dịch theo ngày, lấy displayDateLabel từ map
            final transactionsByDate = _groupByDate(group.transactions, dateLabelsMap);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ExpansionTile(
                title: Row(
                  children: [
                    // Icon danh mục
                    if (group.categoryIconUrl != null)
                      Image.network(
                        group.categoryIconUrl!,
                        width: 40,
                        height: 40,
                        errorBuilder: (_, __, ___) => _buildDefaultIcon(),
                      )
                    else
                      _buildDefaultIcon(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.categoryName,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${group.transactionCount} giao dịch',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      FormatHelper.formatVND(group.totalAmount),
                      style: TextStyle(
                        color: group.categoryType == true ? Colors.green : Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                children: [
                  // 👇 Hiển thị displayDateLabel + giao dịch
                  ...transactionsByDate.entries.map((entry) {
                    return TransactionDateGroup(
                      dateLabel: entry.key,
                      transactions: entry.value,
                      onTransactionTap: (transaction) {},
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 👇 Gom giao dịch theo ngày
  Map<String, List<dynamic>> _groupByDate(
    List<dynamic> transactions,
    Map<String, String> dateLabelsMap,
  ) {
    final Map<String, List<dynamic>> grouped = {};

    // Bước 1: Gom transaction theo ngày
    for (var transaction in transactions) {
      final transDate = transaction.transDate as DateTime;
      final dateKey = transDate.toString().split(' ')[0]; // "2026-03-15"
      
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(transaction);
    }

    // Bước 2: Chuyển key thành displayDateLabel từ backend
    final result = <String, List<dynamic>>{};
    for (final entry in grouped.entries) {
      // Lấy displayDateLabel từ map (backend gửi), nếu không có thì dùng dateKey
      final displayLabel = dateLabelsMap[entry.key] ?? entry.key;
      result[displayLabel] = entry.value;
    }
    return result;
  }

  Widget _buildDefaultIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.blue[700],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.category, color: Colors.white),
    );
  }

  Widget _buildEmptyState(IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Chưa có giao dịch nào',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

