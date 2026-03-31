// ignore_for_file: use_build_context_synchronously

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:smart_money/modules/budget/models/budget_response.dart';
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';
import 'edit_details_screens.dart';

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

class _BudgetDetailScreenState extends State<BudgetDetailScreen>
    with SingleTickerProviderStateMixin {
  late BudgetResponse budget;

  bool showTransactions = false;

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    budget = widget.budget;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final spent =
    widget.transactions.fold<double>(0.0, (s, t) => s + t.amount);

    final total = (budget.amount <= 0 ? 1 : budget.amount).toDouble();
    final remaining = total - spent;
    final percent = (spent / total).clamp(0.0, 1.0);
    final isOver = spent > total;

    final lastMonthSpent = spent * 0.75;
    final diffPercent = lastMonthSpent == 0
        ? 0
        : (((spent - lastMonthSpent) / lastMonthSpent) * 100).toInt();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0B0F14),
              Color(0xFF121821),
              Color(0xFF1A2230),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _appBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _pieChart(percent, spent, total),
                    const SizedBox(height: 16),
                    _summary(spent, remaining, isOver),
                    if (isOver) ...[
                      const SizedBox(height: 12),
                      _warning(),
                    ],
                    const SizedBox(height: 16),
                    _compare(diffPercent),
                    const SizedBox(height: 16),
                    _transactionSection(),
                    const SizedBox(height: 20),
                    _deleteButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= APP BAR =================

  Widget _appBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              "Budget #${budget.id}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: _editBudget,
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
    );
  }

  // ================= GLASS =================

  Widget glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: child,
        ),
      ),
    );
  }

  // ================= PIE CHART (ANIMATION) =================

  Widget _pieChart(double percent, double spent, double total) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        final animated = percent * _animation.value;

        return glassCard(
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        centerSpaceRadius: 55,
                        sectionsSpace: 2,
                        sections: [
                          PieChartSectionData(
                            value: animated,
                            color: const Color(0xFF5B8DEF),
                            radius: 22,
                            title: "",
                          ),
                          PieChartSectionData(
                            value: 1 - animated,
                            color: Colors.white.withOpacity(0.06),
                            radius: 20,
                            title: "",
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "${(animated * 100).toInt()}%",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text("${spent.toInt()} / ${total.toInt()} đ"),
            ],
          ),
        );
      },
    );
  }

  // ================= SUMMARY =================

  Widget _summary(double spent, double remaining, bool isOver) {
    return glassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _info(Icons.flag, "Mục tiêu", budget.amount),
          _info(Icons.wallet, "Đã chi", spent),
          _info(
            Icons.savings,
            isOver ? "Vượt" : "Còn",
            remaining.abs(),
            color: isOver ? Colors.red : Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String label, double value, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.white70),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
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
    return glassCard(
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Expanded(child: Text("Bạn đã vượt ngân sách")),
        ],
      ),
    );
  }

  // ================= COMPARE =================

  Widget _compare(int diff) {
    final isUp = diff >= 0;

    return glassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("So với tháng trước"),
          Text(
            "${diff.abs()}%",
            style: TextStyle(
              color: isUp ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ================= TRANSACTION TOGGLE =================

  Widget _transactionSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              showTransactions = !showTransactions;
            });
          },
          child: glassCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Danh sách giao dịch"),
                Icon(
                  showTransactions
                      ? Icons.expand_less
                      : Icons.expand_more,
                ),
              ],
            ),
          ),
        ),
        if (showTransactions) ...[
          const SizedBox(height: 10),
          _transactionList(),
        ]
      ],
    );
  }

  // ================= TRANSACTION LIST =================

  Widget _transactionList() {
    if (widget.transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text("Chưa có giao dịch"),
      );
    }

    return Column(
      children: widget.transactions.map((t) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: glassCard(
            child: Row(
              children: [
                const Icon(Icons.shopping_cart, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "${t.transDate.day}/${t.transDate.month}",
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  "-${t.amount.toInt()} đ",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ================= DELETE =================

  Widget _deleteButton() {
    return GestureDetector(
      onTap: _confirmDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            "Xóa ngân sách",
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Xóa ngân sách"),
        content: const Text("Bạn chắc chưa?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, "deleted");
            },
            child: const Text("Xóa",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ================= EDIT =================

  void _editBudget() async {
    final updated = await Navigator.push<BudgetResponse>(
      context,
      MaterialPageRoute(
        builder: (_) => EditBudgetDetailScreen(budget: budget),
      ),
    );

    if (updated != null) {
      setState(() {
        budget = updated;
      });
    }
  }
}