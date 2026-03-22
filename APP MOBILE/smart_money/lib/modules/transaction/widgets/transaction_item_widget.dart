// modules/transaction/widgets/transaction_item_widget.dart
// Widget hiển thị một giao dịch (dùng TransactionResponse từ backend)

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';

class TransactionItemWidget extends StatelessWidget {
  final TransactionResponse transaction;
  final VoidCallback? onTap;

  const TransactionItemWidget({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // categoryType: true = Thu (xanh), false = Chi (đỏ)
    final isIncome = transaction.categoryType;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Icon danh mục
            _buildCategoryIcon(),
            const SizedBox(width: 12),

            // Thông tin
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tên danh mục
                  Text(
                    transaction.categoryName ?? 'Không có danh mục',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Ghi chú (nếu có)
                  if (transaction.note != null && transaction.note!.isNotEmpty)
                    Text(
                      transaction.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),

                  // Với ai (nếu có)
                  if (transaction.withPerson != null && transaction.withPerson!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Với: ${transaction.withPerson}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Số tiền
            Text(
              '${isIncome ? '+' : '-'}${FormatHelper.formatNumber(transaction.amount)}',
              style: TextStyle(
                color: isIncome ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build icon danh mục
  Widget _buildCategoryIcon() {
    // Cố gắng load icon từ URL
    if (transaction.categoryIconUrl != null && transaction.categoryIconUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: transaction.categoryIconUrl!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        imageBuilder: (context, imageProvider) {
          return Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
            ),
          );
        },
        placeholder: (context, url) {
          return _buildPlaceholderIcon();
        },
        errorWidget: (context, url, error) {
          return _buildPlaceholderIcon();
        },
      );
    }

    // Fallback placeholder
    return _buildPlaceholderIcon();
  }

  /// Widget placeholder icon
  Widget _buildPlaceholderIcon() {
    final isIncome = transaction.categoryType;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isIncome
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
        color: isIncome ? Colors.green : Colors.red,
        size: 20,
      ),
    );
  }
}

