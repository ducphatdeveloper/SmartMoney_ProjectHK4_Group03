// expired_budget_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/budget_provider.dart';

class ExpiredBudgetScreen extends StatelessWidget {
  const ExpiredBudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BudgetProvider>();

    final expired = provider.budgets
        .where((b) => b.expired)
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Ngân sách đã kết thúc"),
        backgroundColor: Colors.black,
      ),
      body: expired.isEmpty
          ? const Center(
        child: Text("Không có ngân sách đã kết thúc",
            style: TextStyle(color: Colors.white)),
      )
          : ListView.builder(
        itemCount: expired.length,
        itemBuilder: (_, i) {
          final b = expired[i];
          return ListTile(
            title: Text(
              b.categories.isNotEmpty
                  ? b.categories.first.ctgName
                  : "Tất cả",
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              "${b.spentAmount} / ${b.amount}",
              style: const TextStyle(color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}