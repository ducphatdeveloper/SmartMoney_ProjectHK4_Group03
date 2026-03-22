import 'package:flutter/material.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_item_widget.dart';

/// Widget hiển thị nhóm giao dịch theo ngày (dùng trong chế độ grouped)
class TransactionDateGroup extends StatelessWidget {
  final String dateLabel;
  final List<dynamic> transactions;
  final Function(dynamic) onTransactionTap;

  const TransactionDateGroup({
    super.key,
    required this.dateLabel,
    required this.transactions,
    required this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header ngày
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              dateLabel,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        // Danh sách giao dịch của ngày đó
        ...transactions.map((transaction) {
          return TransactionItemWidget(
            transaction: transaction,
            onTap: () => onTransactionTap(transaction),
          );
        }),
      ],
    );
  }
}

