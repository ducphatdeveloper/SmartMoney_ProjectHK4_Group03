// ================= BUDGET DETAIL SCREEN =================
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:smart_money/modules/budget/models/budget_response.dart';
import 'package:smart_money/modules/budget/enums/budget_type.dart';
import 'package:smart_money/modules/budget/screens/edit_details_screens.dart';
import 'package:smart_money/modules/budget/services/budget_service.dart';
import '../../wallet/models/wallet_response.dart';
import '../../transaction/models/view/transaction_response.dart';
import '../../../core/helpers/icon_helper.dart';
import 'package:smart_money/modules/budget/providers/budget_provider.dart';


class BudgetDetailScreen extends StatefulWidget {
  final BudgetResponse budget;
  final WalletResponse wallet;
  final BudgetProvider provider;
  final Function(BudgetResponse)? onUpdated;

  const BudgetDetailScreen({
    super.key,
    required this.budget,
    required this.wallet,
    required this.provider,
    this.onUpdated,
  });

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen>
    with SingleTickerProviderStateMixin {
  late BudgetResponse _budget;
  List<TransactionResponse> transactions = [];
  bool isLoading = true;

  late AnimationController _controller;
  late Animation<double> _animation;

  double get spent =>
      transactions.fold(0.0, (s, t) => s + (t.amount > 0 ? t.amount : 0));

  double get total => _budget.amount == 0 ? 1 : _budget.amount;

  // 🔥 FIX: Cho phép progress > 1.0 để hiển thị "vượt ngân sách" như backend
  double get percent => spent / total;

  double get remaining => total - spent;

  @override
  void initState() {
    super.initState();
    _budget = widget.budget;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final service = BudgetService();
    final res = await service.getBudgetTransactions(_budget.id);

    if (res?.success == true) {
      transactions = res?.data ?? [];
      transactions.sort((a, b) => b.transDate.compareTo(a.transDate));
    }

    setState(() => isLoading = false);
    _controller.forward();
  }

  int _remainDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(
        _budget.endDate.year, _budget.endDate.month, _budget.endDate.day);
    final diff = end
        .difference(today)
        .inDays;
    return diff < 0 ? 0 : diff;
  }

  String _getRemainText() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(
        _budget.endDate.year, _budget.endDate.month, _budget.endDate.day);
    final diff = end
        .difference(today)
        .inDays;

    if (diff < 0) return "Overdue by ${diff.abs()} days";
    if (diff == 0) return "Expires today";
    return "$diff days remaining";
  }

  String _formatDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  String formatMoney(double value) =>
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
          .format(value);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1720),
      body: SafeArea(
        child: Column(
          children: [
            _appBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _header(),
                  const SizedBox(height: 16),
                  _suggestionCard(), // ── Card hiển thị gợi ý dựa trên lịch sử 3 tháng
                  const SizedBox(height: 16),
                  _chart(),
                  const SizedBox(height: 16),
                  _previewTransaction(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Nút Back
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          // Tiêu đề
          Expanded(
            child: Text(
              "Budget #${_budget.id}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          // Nút Edit
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () async {
              final updatedBudget = await Navigator.push<BudgetResponse>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditBudgetDetailScreen(
                        budget: _budget,
                        wallet: widget.wallet,
                      ),
                ),
              );

              if (updatedBudget != null) {
                setState(() => _budget = updatedBudget);
                widget.onUpdated?.call(updatedBudget);
                await _loadTransactions();
              }
            },
          ),
          // Nút Delete
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) =>
                    AlertDialog(
                      title: const Text("Confirm delete"),
                      content: const Text(
                          "Are you sure you want to delete this budget?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Delete", style: TextStyle(
                              color: Colors.red)),
                        ),
                      ],
                    ),
              );

              if (confirm == true) {
                // 🔥 dùng provider truyền trực tiếp từ cha
                final success = await widget.provider.deleteBudget(_budget.id);
                if (success) {
                  Navigator.pop(context); // Quay về màn hình trước
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Budget deleted successfully")),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to delete budget")),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }


  Widget _header() {
    final b = _budget;
    final w = widget.wallet;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row icon + category
          Row(
            children: [
              IconHelper.buildCircleAvatar(
                  iconUrl: b.primaryCategoryIconUrl, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  b.categories.isNotEmpty ? b.categories.first.ctgName : "Category",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tổng ngân sách
          Text(formatMoney(total),
              style: const TextStyle(
                  fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          // Row "Đã chi" - "Còn lại" với thanh % bên dưới
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _moneyInfo("Spent", spent, crossAlign: CrossAxisAlignment.start),
                  _moneyInfo(percent >= 1.0 ? "Over" : "Remaining", percent >= 1.0 ? _budget.overBudgetAmount : remaining,
                      color: percent >= 1.0 ? Colors.redAccent : Colors.greenAccent,
                      crossAlign: CrossAxisAlignment.end),
                ],
              ),
              const SizedBox(height: 6),
              // Line hiển thị % full width
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  // 🔥 FIX: Cho phép progress > 1.0 để hiển thị "vượt ngân sách" như backend
                  // Clamp ở 1.0 cho visual, nhưng percent thực tế có thể > 1.0
                  widthFactor: percent.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: percent >= 1.0
                            ? [Colors.redAccent, Colors.red]
                            : percent >= 0.75
                            ? [Colors.orangeAccent, Colors.deepOrange]
                            : [Color(0xFF00E5FF), Color(0xFF00E676)],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              // ── Hiển thị cảnh báo khi sắp vượt ngân sách (80-99%) ────────
              if (percent >= 0.8 && percent < 1.0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 12),
                      const SizedBox(width: 4),
                      const Text(
                        "Approaching budget limit",
                        style: TextStyle(color: Colors.orange, fontSize: 11),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),
          // Ngày bắt đầu - kết thúc ngân sách
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${_formatDate(b.beginDate)} - ${_formatDate(b.endDate)}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(_getRemainText(),
                      style: TextStyle(
                          color: _remainDays() == 0 ? Colors.orange : Colors.grey,
                          fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Thông tin ví
          Row(
            children: [
              IconHelper.buildCircleAvatar(iconUrl: w.goalImageUrl, radius: 22),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.walletName ?? w.walletName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(w.currencyCode ?? "VND",
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Card hiển thị gợi ý theo type (tuần/tháng/năm/custom) ─────────────────────────
  Widget _suggestionCard() {
    final b = _budget;

    // Chỉ hiển thị nếu có dữ liệu gợi ý và không phải ngân sách "Khác"
    if (b.suggestedAmount <= 0 && b.suggestedDailySpend <= 0) {
      return const SizedBox.shrink();
    }

    if (b.isOther) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                _getSuggestionTitle(b),
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow("Suggested budget", formatMoney(b.suggestedAmount)),
          const SizedBox(height: 8),
          _infoRow("Recommended daily spend", formatMoney(b.suggestedDailySpend)),
          const SizedBox(height: 8),
          if (b.amount > 0)
            _infoRow(
              "Difference from current",
              formatMoney(b.suggestedAmount - b.amount),
              color: (b.suggestedAmount - b.amount) >= 0 ? Colors.greenAccent : Colors.redAccent,
            ),
        ],
      ),
    );
  }

  // ── Hàm lấy title gợi ý theo type ────────
  String _getSuggestionTitle(BudgetResponse b) {
    final formatter = DateFormat('dd/MM');
    final start = b.beginDate;
    final end = b.endDate;

    switch (b.budgetType) {
      case BudgetType.weekly:
        return "Suggested this week (${formatter.format(start)} - ${formatter.format(end)})";
      case BudgetType.monthly:
        return "Suggested this month (${formatter.format(start)} - ${formatter.format(end)})";
      case BudgetType.yearly:
        return "Suggested this year (${formatter.format(start)} - ${formatter.format(end)})";
      case BudgetType.custom:
        return "Suggested (${formatter.format(start)} - ${formatter.format(end)})";
    }
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _moneyInfo(String title, double value,
      {Color? color, CrossAxisAlignment crossAlign = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: crossAlign,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(formatMoney(value),
            style: TextStyle(
                color: color ?? Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _chart() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        final v = percent * _animation.value;
        Color startColor;
        Color endColor;

        if (percent >= 1) {
          startColor = Colors.redAccent;
          endColor = Colors.red;
        } else if (percent >= 0.75) {
          startColor = Colors.orangeAccent;
          endColor = Colors.deepOrange;
        } else {
          startColor = const Color(0xFF00E5FF);
          endColor = const Color(0xFF00E676);
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        centerSpaceRadius: 70,
                        sectionsSpace: 2,
                        sections: [
                          PieChartSectionData(
                              value: v,
                              radius: 16,
                              showTitle: false,
                              gradient: LinearGradient(
                                  colors: [startColor, endColor])),
                          PieChartSectionData(value: 1 - v,
                              radius: 14,
                              showTitle: false,
                              color: Colors.white12),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${(percent * 100).toInt()}%",
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text("Spent",
                            style: TextStyle(color: Colors.grey[400],
                                fontSize: 12)),
                        const SizedBox(height: 6),
                        Text(formatMoney(spent),
                            style: TextStyle(fontWeight: FontWeight.w600,
                                color: startColor)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _infoItem("Budget", formatMoney(total)),
                  _infoItem(percent >= 1 ? "Over" : "Remaining",
                      formatMoney(percent >= 1 ? spent - total : remaining),
                      color: percent >= 1 ? Colors.redAccent : Colors
                          .greenAccent),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoItem(String title, String value, {Color? color}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(
          color: color ?? Colors.white, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _previewTransaction() {
    final preview = transactions.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Transactions", style: TextStyle(fontSize: 16)),
          TextButton(
              onPressed: _showAllTransactions, child: const Text("View all")),
        ]),
        const SizedBox(height: 8),
        if (preview.isEmpty) const Text("No transactions"),
        ...preview.map(_item),
      ],
    );
  }

  void _showAllTransactions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (_) =>
          DraggableScrollableSheet(
            expand: false,
            builder: (_, controller) =>
                ListView.builder(
                  controller: controller,
                  itemCount: transactions.length,
                  itemBuilder: (_, i) => _item(transactions[i]),
                ),
          ),
    );
  }

  Widget _item(TransactionResponse t) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Category icon + name + amount
              Row(
                children: [
                  t.categoryIconUrl != null
                      ? IconHelper.buildCircleAvatar(iconUrl: t.categoryIconUrl, radius: 20)
                      : const CircleAvatar(radius: 20, child: Icon(Icons.category)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.categoryName ?? "Other",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                  ),
                  Text(
                    "-${formatMoney(t.amount)}",
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Chi tiết từng trường
              if (t.transDate != null)
                _detailRow("Transaction date",
                    DateFormat('dd/MM/yyyy • HH:mm').format(t.transDate)),
              if (t.note != null && t.note!.isNotEmpty) _detailRow("Note", t.note!),
              if (t.withPerson != null && t.withPerson!.isNotEmpty)
                _detailRow("With whom", t.withPerson!),
              if (t.eventName != null && t.eventName!.isNotEmpty)
                _detailRow("Event", t.eventName!),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Divider(color: Colors.white24, thickness: 1),
        const SizedBox(height: 6),
      ],
    );
  }

  /// Widget con hiển thị 1 hàng chi tiết "label → value"
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              "$label:",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
