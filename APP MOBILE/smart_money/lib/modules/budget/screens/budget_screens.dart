import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:smart_money/modules/budget/models/budget_models.dart'; // Đã sửa thành chữ thường
import 'package:smart_money/modules/budget/screens/add_budget_screens.dart';
import 'package:smart_money/modules/budget/screens/budget_details_screens.dart';
import 'package:smart_money/modules/transaction/models/transaction_models.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<BudgetModel> budgets = [];

  /// 👉 GIẢ LẬP TỔNG TIỀN TỪ CÁC VÍ
  final double totalWalletAmount = 30000000;

  final transactions = [
    TransactionModel(
      id: '1',
      categoryId: 'food',
      amount: 50000,
      date: DateTime.now(),
    ),
    TransactionModel(
      id: '2',
      categoryId: 'food',
      amount: 70000,
      date: DateTime.now(),
    ),
  ];

  void addBudget() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBudgetScreen()),
    );
    if (result != null) {
      setState(() => budgets.add(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalBudget = budgets.fold(0.0, (sum, b) => sum + b.amount);
    final remaining = (totalWalletAmount - totalBudget).clamp(
      0,
      double.infinity,
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Ngân sách")),
      floatingActionButton: FloatingActionButton(
        onPressed: addBudget,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _budgetPieChart(totalBudget.toDouble(), remaining.toDouble()),
          const SizedBox(height: 24),
          _budgetList(),
        ],
      ),
    );
  }

  // ================= PIE CHART =================

  Widget _budgetPieChart(double totalBudget, double remaining) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            "Phân bổ ngân sách",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 60,
                sections: _buildSections(totalBudget, remaining),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Tổng ngân sách: ${totalBudget.toInt()} đ / ${totalWalletAmount.toInt()} đ",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(
    double totalBudget,
    double remaining,
  ) {
    final colors = [
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.green,
      Colors.pink,
    ];

    final sections = <PieChartSectionData>[];

    for (int i = 0; i < budgets.length; i++) {
      final b = budgets[i];
      sections.add(
        PieChartSectionData(
          value: b.amount,
          color: colors[i % colors.length],
          radius: 50,
          title: "${(b.amount / totalWalletAmount * 100).toInt()}%",
          titleStyle: const TextStyle(fontSize: 12),
        ),
      );
    }

    if (remaining > 0) {
      sections.add(
        PieChartSectionData(
          value: remaining,
          color: Colors.grey.shade700,
          radius: 45,
          title: "Còn lại",
          titleStyle: const TextStyle(fontSize: 11),
        ),
      );
    }

    return sections;
  }

  // ================= LIST =================

  Widget _budgetList() {
    if (budgets.isEmpty) {
      return const Center(child: Text("Chưa có ngân sách"));
    }

    return Column(
      children: budgets.map((b) {
        final spent = transactions
            .where((t) => t.categoryId == b.categoryId)
            .fold(0.0, (s, t) => s + t.amount);

        final percent = spent / b.amount;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: CircleAvatar(child: Icon(b.icon)),
            title: Text(b.name),
            subtitle: Text(
              "${spent.toInt()} / ${b.amount.toInt()} đ",
              style: TextStyle(color: percent > 1 ? Colors.red : Colors.grey),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BudgetDetailScreen(
                    budget: b,
                    transactions: transactions
                        .where((t) => t.categoryId == b.categoryId)
                        .toList(),
                  ),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}
