import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/modules/budget/models/budget_response.dart';
import 'package:smart_money/modules/budget/enums/budget_type.dart';
import 'package:smart_money/modules/budget/providers/budget_provider.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:smart_money/modules/budget/widget/budget_filter_tabs.dart';

class ExpiredBudgetScreen extends StatefulWidget {
  const ExpiredBudgetScreen({super.key});

  @override
  State<ExpiredBudgetScreen> createState() => _ExpiredBudgetScreenState();
}

class _ExpiredBudgetScreenState extends State<ExpiredBudgetScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  BudgetType _selected = BudgetType.monthly;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetProvider>().loadExpiredBudgets(
          walletId: context.read<BudgetProvider>().selectedWalletId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onFilterChanged(BudgetType type) {
    setState(() => _selected = type);
    _controller.forward(from: 0);
  }

  double percent(double spent, double total) {
    if (total <= 0) return 0;
    return (spent / total).clamp(0.0, 1.0);
  }

  Color getColor(double p) {
    if (p >= 1) return Colors.red;
    if (p >= 0.75) return Colors.orange;
    return Colors.greenAccent;
  }

  String formatMoney(double value) {
    final format = NumberFormat("#,###", "vi_VN");
    return "${format.format(value)} đ";
  }

  String getFullTimeLabel(BudgetResponse b) {
    final formatter = DateFormat('dd/MM');
    final start = b.beginDate;
    final end = b.endDate;
    final range = "(${formatter.format(start)} - ${formatter.format(end)})";

    switch (b.budgetType) {
      case BudgetType.weekly:
        return "Tuần này $range";
      case BudgetType.monthly:
        return "Tháng này $range";
      case BudgetType.yearly:
        return "Năm nay $range";
      case BudgetType.custom:
        return "Tùy chỉnh $range";
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BudgetProvider>();
    final budgets = provider.expiredBudgets;

    if (provider.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final availableTypes = budgets.map((b) => b.budgetType).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    final safeSelected = availableTypes.contains(_selected)
        ? _selected
        : (availableTypes.isNotEmpty ? availableTypes.first : BudgetType.monthly);

    final filteredBudgets =
    budgets.where((b) => b.budgetType == safeSelected).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Ngân sách hết hạn"),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadExpiredBudgets(
              walletId: provider.selectedWalletId);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (availableTypes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BudgetFilterTabs(
                  selected: safeSelected,
                  availableTypes: availableTypes,
                  onChanged: _onFilterChanged,
                ),
              ),
            if (filteredBudgets.isEmpty)
              Center(
                child: Text(
                  "Không có ngân sách hết hạn cho tab này",
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              )
            else
              Column(
                children: filteredBudgets.map((b) => _budgetItem(b)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _budgetItem(BudgetResponse b) {
    final p = percent(b.spentAmount, b.amount);
    final left = b.amount - b.spentAmount;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconHelper.buildCircleAvatar(
                iconUrl: b.primaryCategoryIconUrl,
                radius: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (b.categories?.isNotEmpty ?? false)
                          ? b.categories!.first.ctgName
                          : "Tất cả",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      getFullTimeLabel(b),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text("${(p * 100).toInt()}%",
                  style: TextStyle(
                    color: getColor(p),
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: p,
            minHeight: 8,
            color: getColor(p),
            backgroundColor: Colors.grey.shade800,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${formatMoney(b.spentAmount)} / ${formatMoney(b.amount)}",
                  style: const TextStyle(color: Colors.grey)),
              Text(
                left >= 0
                    ? "Còn ${formatMoney(left)}"
                    : "⚠️ Vượt ${formatMoney(left.abs())}",
                style: TextStyle(
                    color: left >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
