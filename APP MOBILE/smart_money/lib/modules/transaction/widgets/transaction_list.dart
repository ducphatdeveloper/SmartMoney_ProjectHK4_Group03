import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';
import 'package:smart_money/modules/transaction/screens/transaction_edit_screen.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_day_group.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_detail_sheet.dart';

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

/// Chế độ Nhật ký (gom theo ngày) — dùng TransactionDayGroup [3.5]
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

            // Dùng TransactionDayGroup [3.5] — widget nhóm theo ngày mới
            return TransactionDayGroup(
              date: group.date,
              displayDateLabel: group.displayDateLabel,
              transactions: group.transactions,
              netAmount: group.netAmount,
              onTapTransaction: (tx) => _showDetailSheet(context, tx),
            );
          },
        );
      },
    );
  }

  /// Hiện bottom sheet chi tiết giao dịch
  void _showDetailSheet(BuildContext context, TransactionResponse transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailSheet(
        transaction: transaction,
        onEdit: () {
          Navigator.pop(context); // đóng sheet trước
          _navigateToEdit(context, transaction);
        },
        onDelete: () {
          Navigator.pop(context); // đóng sheet trước
          _confirmDelete(context, transaction);
        },
      ),
    );
  }

  /// Navigate sang màn sửa giao dịch
  void _navigateToEdit(BuildContext context, TransactionResponse transaction) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionEditScreen(transaction: transaction),
      ),
    );

    // Nếu sửa thành công → provider đã tự reload trong updateTransaction
    if (result == true) {
      // UI tự cập nhật qua Consumer
    }
  }

  /// Xác nhận xóa giao dịch
  void _confirmDelete(BuildContext context, TransactionResponse transaction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Xóa giao dịch', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có chắc muốn xóa giao dịch này?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // đóng dialog
              final provider = Provider.of<TransactionProvider>(context, listen: false);
              final success = await provider.deleteTransaction(transaction.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã xóa giao dịch'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.errorMessage ?? 'Có lỗi xảy ra'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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

        // Tạo map displayDateLabel từ journalGroups
        final dateLabelsMap = <String, String>{};
        for (final journalGroup in provider.journalGroups) {
          final dateKey = journalGroup.date.toString().split(' ')[0];
          dateLabelsMap[dateKey] = journalGroup.displayDateLabel;
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: provider.groupedCategories.length,
          itemBuilder: (context, index) {
            final group = provider.groupedCategories[index];

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ExpansionTile(
                title: Row(
                  children: [
                    // Icon danh mục — convert filename thành Cloudinary URL
                    _buildCategoryIcon(group.categoryIconUrl, group.categoryType ?? false),
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
                  // Hiển thị từng giao dịch trong nhóm — bấm vào mở detail sheet
                  ...group.transactions.map((transaction) {
                    return ListTile(
                      leading: const Icon(Icons.receipt_outlined, color: Colors.grey, size: 20),
                      title: Text(
                        transaction.note ?? transaction.categoryName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: Text(
                        FormatHelper.formatDisplayDate(transaction.transDate),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      trailing: Text(
                        FormatHelper.formatVND(transaction.amount),
                        style: TextStyle(
                          color: transaction.categoryType ? Colors.green : Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => _showDetailSheet(context, transaction),
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

  /// Hiện bottom sheet chi tiết giao dịch
  void _showDetailSheet(BuildContext context, TransactionResponse transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailSheet(
        transaction: transaction,
        onEdit: () {
          Navigator.pop(context);
          _navigateToEdit(context, transaction);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(context, transaction);
        },
      ),
    );
  }

  /// Navigate sang màn sửa
  void _navigateToEdit(BuildContext context, TransactionResponse transaction) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionEditScreen(transaction: transaction),
      ),
    );
  }

  /// Xác nhận xóa
  void _confirmDelete(BuildContext context, TransactionResponse transaction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Xóa giao dịch', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có chắc muốn xóa giao dịch này?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<TransactionProvider>(context, listen: false);
              await provider.deleteTransaction(transaction.id);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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

  // ----- Build category icon từ filename → Cloudinary URL -----
  Widget _buildCategoryIcon(String? iconUrl, bool categoryType) {
    final cloudinaryUrl = IconHelper.buildCloudinaryUrl(iconUrl);
    
    if (cloudinaryUrl != null && cloudinaryUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: cloudinaryUrl,
        width: 40,
        height: 40,
        imageBuilder: (context, imageProvider) {
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
          );
        },
        placeholder: (_, __) => _buildDefaultIcon(),
        errorWidget: (_, __, ___) => _buildDefaultIcon(),
      );
    }
    
    return _buildDefaultIcon();
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
