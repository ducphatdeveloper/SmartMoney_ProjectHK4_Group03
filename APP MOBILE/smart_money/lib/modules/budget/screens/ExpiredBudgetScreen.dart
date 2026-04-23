import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/modules/budget/models/budget_response.dart';
import 'package:smart_money/modules/budget/models/budget_request.dart';
import 'package:smart_money/modules/budget/enums/budget_type.dart';
import 'package:smart_money/modules/budget/providers/budget_provider.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:smart_money/modules/budget/widget/budget_filter_tabs.dart';
import 'package:smart_money/modules/budget/screens/add_budget_screens.dart';
import 'package:smart_money/modules/wallet/models/wallet_response.dart';

// ── Formatter tự động format số tiền Việt khi nhập ────────────────────────
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Loại bỏ tất cả ký tự không phải số
    String text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Nếu rỗng thì trả về
    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    
    // Format số với dấu chấm phân cách hàng nghìn
    final number = int.tryParse(text);
    if (number == null) {
      return oldValue;
    }
    
    final format = NumberFormat("#,###", "vi_VN");
    String formatted = format.format(number);
    
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

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
        return "This week $range";
      case BudgetType.monthly:
        return "This month $range";
      case BudgetType.yearly:
        return "This year $range";
      case BudgetType.custom:
        return "Custom $range";
    }
  }


  // ── Xóa ngân sách hết hạn ────────────────────────────────────────
  void _deleteBudget(BudgetResponse budget) async {
    final provider = context.read<BudgetProvider>();
    final wallet = provider.selectedWallet;

    // Hiển thị dialog xác nhận
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          "Delete budget",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "Are you sure you want to delete this budget?",
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await provider.deleteBudget(budget.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Budget deleted")),
        );
        // Refresh lại danh sách
        if (wallet != null) {
          await provider.loadExpiredBudgets(walletId: wallet.id);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Delete failed")),
        );
      }
    }
  }

  // ── Clone ngân sách cũ ───────────────────────────────────────────
  void _cloneBudget(BudgetResponse budget) async {
    final provider = context.read<BudgetProvider>();
    final wallet = provider.selectedWallet;

    if (wallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wallet not found")),
      );
      return;
    }

    // Tính toán thời gian mới dựa trên budgetType
    final now = DateTime.now();
    DateTime newBeginDate, newEndDate;

    switch (budget.budgetType) {
      case BudgetType.weekly:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        newBeginDate = startOfWeek;
        newEndDate = startOfWeek.add(const Duration(days: 6));
        break;
      case BudgetType.monthly:
        newBeginDate = DateTime(now.year, now.month, 1);
        newEndDate = DateTime(now.year, now.month + 1, 0);
        break;
      case BudgetType.yearly:
        newBeginDate = DateTime(now.year, 1, 1);
        newEndDate = DateTime(now.year, 12, 31);
        break;
      case BudgetType.custom:
        // Hỏi user chọn thời gian mới
        final selectedRange = await showDateRangePicker(
          context: context,
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
        );
        if (selectedRange == null) return;
        newBeginDate = selectedRange.start;
        newEndDate = selectedRange.end;
        break;
    }

    // Hiển thị dialog xác nhận clone
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          "Clone budget",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "New period: ${DateFormat('dd/MM/yyyy').format(newBeginDate)} - ${DateFormat('dd/MM/yyyy').format(newEndDate)}",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              "Amount: ${formatMoney(budget.amount)}",
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Clone",
              style: TextStyle(color: Colors.amber),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Tạo ngân sách mới bằng API create
      final success = await provider.createBudget(
        BudgetRequest(
          walletId: wallet.id,
          amount: budget.amount,
          beginDate: newBeginDate,
          endDate: newEndDate,
          repeating: budget.repeating,
          allCategories: budget.allCategories,
          categoryId: budget.categories.isNotEmpty ? budget.categories.first.id : null,
          budgetType: budget.budgetType.apiValue,
        ),
      );

      if (success && mounted) {
        // Xóa ngân sách gốc sau khi clone thành công
        await provider.deleteBudget(budget.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Budget cloned successfully")),
        );
        // Refresh lại danh sách
        await provider.refreshBudgets();
        await provider.loadExpiredBudgets(walletId: wallet.id);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Clone failed")),
        );
      }
    }
  }

  // ── Gia hạn nhanh ngân sách ─────────────────────────────────────
  void _renewBudget(BudgetResponse budget) async {
    final provider = context.read<BudgetProvider>();
    final wallet = provider.selectedWallet;

    if (wallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wallet not found")),
      );
      return;
    }

    // Tính toán thời gian mới dựa trên budgetType
    final now = DateTime.now();
    DateTime newBeginDate, newEndDate;
    double newAmount = budget.amount;

    switch (budget.budgetType) {
      case BudgetType.weekly:
        final startOfNextWeek = now.add(Duration(days: 7 - now.weekday + 1));
        newBeginDate = startOfNextWeek;
        newEndDate = startOfNextWeek.add(const Duration(days: 6));
        break;
      case BudgetType.monthly:
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear = now.month == 12 ? now.year + 1 : now.year;
        newBeginDate = DateTime(nextYear, nextMonth, 1);
        newEndDate = DateTime(nextYear, nextMonth + 1, 0);
        break;
      case BudgetType.yearly:
        newBeginDate = DateTime(now.year + 1, 1, 1);
        newEndDate = DateTime(now.year + 1, 12, 31);
        break;
      case BudgetType.custom:
        final days = budget.endDate.difference(budget.beginDate).inDays;
        newBeginDate = now;
        newEndDate = now.add(Duration(days: days));
        break;
    }

    // Hiển thị dialog chọn số tiền
    final format = NumberFormat("#,###", "vi_VN");
    final amountController = TextEditingController(
      text: format.format(budget.amount.toInt()),
    );

    final selectedAmount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          "Renew budget",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "New period: ${DateFormat('dd/MM/yyyy').format(newBeginDate)} - ${DateFormat('dd/MM/yyyy').format(newEndDate)}",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              "Budget amount:",
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              inputFormatters: [CurrencyInputFormatter()],
              decoration: InputDecoration(
                hintText: format.format(budget.amount.toInt()),
                hintStyle: TextStyle(color: Colors.grey.shade600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixText: 'đ',
                suffixStyle: const TextStyle(color: Colors.grey),
              ),
            ),
            if (budget.suggestedAmount > 0) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  amountController.text = format.format(budget.suggestedAmount.toInt());
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        "Suggested: ${formatMoney(budget.suggestedAmount)}",
                        style: const TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              // Loại bỏ dấu phân cách hàng nghìn trước khi parse
              final cleanText = amountController.text.replaceAll(RegExp(r'[^\d]'), '');
              final amount = double.tryParse(cleanText);
              Navigator.pop(context, amount);
            },
            child: const Text(
              "Renew",
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );

    if (selectedAmount != null && selectedAmount! > 0 && mounted) {
      // Dùng API update để gia hạn
      final success = await provider.updateBudget(
        budget.id,
        BudgetRequest(
          walletId: wallet.id,
          amount: selectedAmount!,
          beginDate: newBeginDate,
          endDate: newEndDate,
          repeating: budget.repeating,
          allCategories: budget.allCategories,
          categoryId: budget.categories.isNotEmpty ? budget.categories.first.id : null,
          budgetType: budget.budgetType.apiValue,
        ),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Budget renewed successfully")),
        );
        // Refresh lại danh sách ngân sách hết hạn và ngân sách active
        await provider.refreshBudgets();
        await provider.loadExpiredBudgets(walletId: wallet.id);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Renewal failed")),
        );
      }
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
        title: const Text("Expired budgets"),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadExpiredBudgets(
              walletId: provider.selectedWalletId);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
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
                  "No expired budgets for this tab",
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
    final displayName = (b.categories.isNotEmpty)
        ? b.categories.first.ctgName
        : "All";
    final iconUrl = b.primaryCategoryIconUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: b.exceeded ? Colors.red.withOpacity(0.3) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconHelper.buildCircleAvatar(
                iconUrl: iconUrl,
                radius: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        if (b.exceeded) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Over",
                              style: TextStyle(color: Colors.red, fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      getFullTimeLabel(b),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    // ── Hiển thị gợi ý ngân sách ────────
                    if (!b.isOther && b.suggestedAmount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          "Suggested: ${formatMoney(b.suggestedAmount)}",
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text("${(p * 100).toInt()}%",
                  style: TextStyle(
                    color: getColor(p),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
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
          _budgetInfoRow(b, left),
          // ── Nút hành động ────────
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _cloneBudget(b),
                  icon: const Icon(Icons.content_copy, size: 16),
                  label: const Text("Clone", style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: const BorderSide(color: Colors.amber),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _renewBudget(b),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text("Renew", style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _deleteBudget(b),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text("Delete", style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Widget hiển thị thông tin ngân sách (spent/amount, overBudgetAmount, warning) ────────
  Widget _budgetInfoRow(BudgetResponse b, double left) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text("${formatMoney(b.spentAmount)} / ${formatMoney(b.amount)}",
                  style: const TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                left >= 0
                    ? "Remaining ${formatMoney(left)}"
                    : "⚠️ Over ${formatMoney(left.abs())}",
                style: TextStyle(
                    color: left >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        // ── Hiển thị overBudgetAmount nếu vượt ngân sách ────────
        if (b.overBudgetAmount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 12),
                const SizedBox(width: 4),
                Text(
                  "Budget exceeded: ${formatMoney(b.overBudgetAmount)}",
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
