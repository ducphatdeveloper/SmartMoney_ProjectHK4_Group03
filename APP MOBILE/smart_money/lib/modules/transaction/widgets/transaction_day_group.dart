// ===========================================================
// [3.5] TransactionDayGroup — Widget nhóm giao dịch theo ngày
// ===========================================================
// Hiển thị 1 nhóm giao dịch trong cùng 1 ngày.
// Layout (theo ảnh Money Lover):
//   Header:
//     - Số ngày (to, bold) VD: "23"
//     - Column: displayDateLabel backend gửi + "tháng 3 2026"
//     - Spacer
//     - Tổng ròng ngày (đỏ nếu âm, xanh nếu dương)
//   Body:
//     - Mỗi giao dịch: icon | tên + ghi chú | số tiền
//     - Bấm vào → callback onTapTransaction
// ===========================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';

class TransactionDayGroup extends StatelessWidget {
  final DateTime date;                                    // ngày nhóm
  final String displayDateLabel;                          // label từ backend: "Hôm nay", "Thứ Sáu, 14/03"
  final List<TransactionResponse> transactions;           // danh sách giao dịch trong ngày
  final double netAmount;                                 // tổng ròng (thu - chi) ngày đó
  final Function(TransactionResponse) onTapTransaction;   // callback khi bấm vào giao dịch

  const TransactionDayGroup({
    super.key,
    required this.date,
    required this.displayDateLabel,
    required this.transactions,
    required this.netAmount,
    required this.onTapTransaction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          // ===== Header nhóm ngày =====
          _buildDayHeader(),

          // ===== Danh sách giao dịch trong ngày =====
          ...transactions.asMap().entries.map((entry) {
            final index = entry.key;
            final tx = entry.value;
            return Column(
              children: [
                _buildTransactionRow(tx),
                // Divider giữa các giao dịch (trừ item cuối)
                if (index < transactions.length - 1)
                  Divider(
                    color: Colors.grey[800],
                    height: 1,
                    indent: 68,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ===== Widget: Header nhóm ngày =====
  Widget _buildDayHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Số ngày (to, bold)
          Text(
            date.day.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),

          // Tên thứ + tháng năm
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // displayDateLabel từ backend
                Text(
                  displayDateLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // "tháng 3 2026"
                Text(
                  'month ${date.month} ${date.year}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Tổng ròng ngày
          Text(
            FormatHelper.formatVND(netAmount),
            style: TextStyle(
              color: netAmount >= 0 ? Colors.green : Colors.red,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ===== Widget: 1 dòng giao dịch =====
  Widget _buildTransactionRow(TransactionResponse tx) {
    final isIncome = tx.categoryType;

    return InkWell(
      onTap: () => onTapTransaction(tx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Icon category
            _buildCategoryIcon(tx),
            const SizedBox(width: 12),

            // Tên category + ghi chú
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.categoryName ?? 'No category',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (tx.note != null && tx.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        tx.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Số tiền
            Text(
              '${isIncome ? '+' : '-'}${FormatHelper.formatNumber(tx.amount)}',
              style: TextStyle(
                color: isIncome ? Colors.green : Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Widget: Icon category =====
  Widget _buildCategoryIcon(TransactionResponse tx) {
    // Convert filename thành Cloudinary URL đầy đủ
    final cloudinaryUrl = IconHelper.buildCloudinaryUrl(tx.categoryIconUrl);
    
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
        placeholder: (_, __) => _buildFallbackIcon(tx.categoryType),
        errorWidget: (_, __, ___) => _buildFallbackIcon(tx.categoryType),
      );
    }
    return _buildFallbackIcon(tx.categoryType);
  }

  // ===== Widget: Fallback icon =====
  Widget _buildFallbackIcon(bool isIncome) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isIncome
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
        color: isIncome ? Colors.green : Colors.red,
        size: 18,
      ),
    );
  }
}

