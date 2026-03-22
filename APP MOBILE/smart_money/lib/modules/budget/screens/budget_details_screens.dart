import 'package:smart_money/modules/budget/models/budget_response.dart';
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:smart_money/modules/budget/screens/edit_details_screens.dart';

class BudgetDetailScreen extends StatefulWidget {
  final BudgetResponse budget;
  final List<TransactionResponse> transactions;

  const BudgetDetailScreen({
    super.key,
    required this.budget,
    required this.transactions,
  });

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  late BudgetResponse budget;

  @override
  void initState() {
    super.initState();
    budget = widget.budget;
  }

  @override
  Widget build(BuildContext context) {
    /// ================= TÍNH TOÁN AN TOÀN =================

    final spent = widget.transactions.fold<double>(0, (s, t) => s + t.amount);

    /// tránh chia cho 0
    final double total = budget.amount <= 0 ? 1 : budget.amount;

    final remaining = total - spent;

    final percent = (spent / total).clamp(0.0, 1.0);

    final isOver = spent > total;

    /// mock tháng trước (an toàn)
    final lastMonthSpent = spent * 0.75;
    final diffPercent = lastMonthSpent == 0
        ? 0
        : (((spent - lastMonthSpent) / lastMonthSpent) * 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: Text("Budget #${budget.id}"),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _editBudget),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _pieChart(percent, spent, total),
          const SizedBox(height: 24),
          _summary(spent, remaining, isOver),
          if (isOver) _warning(),
          const SizedBox(height: 24),
          _compare(diffPercent),
          const SizedBox(height: 24),
          _transactionList(),
        ],
      ),
    );
  }

  // ================= PIE CHART =================

  Widget _pieChart(double percent, double spent, double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 260, // TO HƠN
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 90,
                sectionsSpace: 3,
                sections: [
                  PieChartSectionData(
                    value: spent <= 0 ? 0.1 : spent,
                    color: Colors.orange,
                    radius: 70,
                    title: "${(percent * 100).toInt()}%",
                    titleStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PieChartSectionData(
                    value: (total - spent).clamp(0, double.infinity),
                    color: Colors.grey.shade700,
                    radius: 65,
                    title: "",
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "${spent.toInt()} / ${budget.amount.toInt()} đ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ================= SUMMARY =================

  Widget _summary(double spent, double remaining, bool isOver) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _info("Mục tiêu", budget.amount),
        _info("Đã chi", spent),
        _info(
          isOver ? "Vượt" : "Còn lại",
          remaining.abs(),
          color: isOver ? Colors.red : Colors.green,
        ),
      ],
    );
  }

  Widget _info(String label, double value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          "${value.toInt()} đ",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color ?? Colors.white,
          ),
        ),
      ],
    );
  }

  // ================= WARNING =================

  Widget _warning() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "Bạn đã vượt quá ngân sách!",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // ================= COMPARE =================

  Widget _compare(int diff) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("So với tháng trước"),
          Row(
            children: [
              Icon(
                diff >= 0 ? Icons.trending_up : Icons.trending_down,
                color: diff >= 0 ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 4),
              Text(
                "${diff.abs()}%",
                style: TextStyle(
                  color: diff >= 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= TRANSACTIONS =================

  Widget _transactionList() {
    if (widget.transactions.isEmpty) {
      return const Center(child: Text("Chưa có giao dịch"));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Giao dịch", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...widget.transactions.map((t) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.money),
              title: Text("${t.amount.toInt()} đ"),
              subtitle: Text("${t.transDate.day}/${t.transDate.month}/${t.transDate.year}"),
            ),
          );
        }),
      ],
    );
  }

  // ================= EDIT =================

  void _editBudget() async {
    final updated = await Navigator.push<BudgetResponse>(
      context,
      MaterialPageRoute(builder: (_) => EditBudgetDetailScreen(budget: budget)),
    );

    if (updated != null) {
      final oldAmount = budget.amount;

      setState(() {
        budget = updated;
      });

      final diff = updated.amount - oldAmount;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            diff == 0
                ? "Không thay đổi ngân sách"
                : diff > 0
                ? "Tăng ${diff.toInt()} đ"
                : "Giảm ${diff.abs().toInt()} đ",
          ),
        ),
      );
    }
  }
}
