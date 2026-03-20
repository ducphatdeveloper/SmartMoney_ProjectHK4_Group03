import 'package:flutter/material.dart';
import 'package:smart_money/modules/Transaction/models/transaction_models.dart';
import 'package:smart_money/modules/Transaction/widgets/transaction_items_screens.dart';

class TransactionList extends StatelessWidget {
  final List<TransactionModel> transactions;

  const TransactionList({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(child: Text("Chưa có giao dịch"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (_, index) {
        return TransactionItem(transaction: transactions[index]);
      },
    );
  }
}