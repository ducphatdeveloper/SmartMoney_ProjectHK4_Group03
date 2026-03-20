import 'package:flutter/material.dart';
import 'package:smart_money/modules/Transaction/models/transaction_models.dart';
import 'package:smart_money/modules/Transaction/widgets/transaction_filter_screens.dart';
import 'package:smart_money/modules/Transaction/widgets/transaction_list_screens.dart';
import 'package:smart_money/modules/Transaction/widgets/transaction_summary_screens.dart';

class TransactionBookScreen extends StatefulWidget {
  final List<TransactionModel> transactions;

  const TransactionBookScreen({super.key, required this.transactions});

  @override
  State<TransactionBookScreen> createState() => _TransactionBookScreenState();
}

class _TransactionBookScreenState extends State<TransactionBookScreen> {
  int selectedFilter = 0; // 0: all, 1: expense, 2: income

  List<TransactionModel> get filteredTransactions {
    if (selectedFilter == 1) {
      return widget.transactions.where((t) => t.amount < 0).toList();
    }
    if (selectedFilter == 2) {
      return widget.transactions.where((t) => t.amount > 0).toList();
    }
    return widget.transactions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sổ giao dịch"), centerTitle: true),
      body: Column(
        children: [
          TransactionSummary(transactions: widget.transactions),
          TransactionFilterTabs(
            selectedIndex: selectedFilter,
            onChanged: (index) => setState(() => selectedFilter = index),
          ),
          Expanded(child: TransactionList(transactions: filteredTransactions)),
        ],
      ),
    );
  }
}