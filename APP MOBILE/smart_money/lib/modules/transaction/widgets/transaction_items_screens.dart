import 'package:flutter/material.dart';
import 'package:smart_money/modules/Transaction/models/transaction_models.dart';

class TransactionItem extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionItem({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _buildIcon(isIncome),
            const SizedBox(width: 12),
            _buildInfo(),
            _buildAmount(isIncome),
          ],
        ),
      ),
    );
  }

  // ================= ICON =================

  Widget _buildIcon(bool isIncome) {
    return CircleAvatar(
      radius: 22,
      backgroundColor:
          isIncome ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
      child: Icon(
        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
        color: isIncome ? Colors.green : Colors.red,
      ),
    );
  }

  // ================= INFO =================

  Widget _buildInfo() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            transaction.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(transaction.date),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ================= AMOUNT =================

  Widget _buildAmount(bool isIncome) {
    return Text(
      "${isIncome ? '+' : '-'}${transaction.amount.abs().toInt()} đ",
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: isIncome ? Colors.green : Colors.red,
      ),
    );
  }

  // ================= HELPERS =================

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }
}
