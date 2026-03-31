// ignore_for_file: use_build_context_synchronously
import 'dart:math';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/helpers/icon_helper.dart';
import 'package:smart_money/modules/budget/models/budget_response.dart';

import 'package:smart_money/modules/budget/enums/budget_type.dart';
import 'package:smart_money/modules/budget/providers/budget_provider.dart';
import 'package:smart_money/modules/wallet/models/wallet_response.dart';
import 'package:smart_money/modules/wallet/screens/SelectWalletScreen.dart';
import 'package:smart_money/modules/budget/widget/budget_filter_tabs.dart';
import 'ExpiredBudgetScreen.dart';
import 'add_budget_screens.dart';
import 'budget_details_screens.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
    with SingleTickerProviderStateMixin {
  WalletResponse? selectedWallet;
  bool hasSelectedWallet = false;


  late AnimationController _controller;
  /// 👉 MỞ Fill theo thang , ngay , nam khi tao budget
  BudgetType _selected = BudgetType.monthly;
  bool _initialized = false;

  void _onFilterChanged(BudgetType type) {
    setState(() {
      _selected = type;
    });

    _controller.forward(from: 0); // 🔥 animate lại chart
  }

  String getCurrentLabel(List<BudgetResponse> filteredBudgets) {
    switch (_selected) {
      case BudgetType.weekly:
        return "Tuần này";
      case BudgetType.monthly:
        return "Tháng này";
      case BudgetType.yearly:
        return "Năm nay";
      case BudgetType.custom:
        return filteredBudgets.isNotEmpty
            ? getTimeLabel(filteredBudgets.first)
            : "";
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  // ================= PICK WALLET =================
  Future<void> _pickWallet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SelectWalletScreen(),
      ),
    );

    if (result != null) {
      setState(() => selectedWallet = result);

      await context.read<BudgetProvider>().loadBudgets(
        walletId: result.id,
      );

      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ================= ADD =================
  Future<void> addBudget() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddBudgetScreen(wallet: selectedWallet),
      ),
    );

    if (result == true && mounted) {
      await context.read<BudgetProvider>().loadBudgets(
        walletId: selectedWallet?.id,
      );

      _controller.forward(from: 0);
    }
  }

  // ================= HELPERS =================
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

  String getTimeLabel(BudgetResponse b) {
    switch (b.budgetType) {
      case BudgetType.weekly:
        return "Tuần này";
      case BudgetType.monthly:
        return "Tháng này";
      case BudgetType.yearly:
        return "Năm nay";
      case BudgetType.custom:
        final start = b.beginDate;
        final end = b.endDate;
        return "${start.day}/${start.month} - ${end.day}/${end.month}";
    }
  }
  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BudgetProvider>();
    final budgets = provider.displayBudgets;
    final isLoading = provider.isLoading;
    final hasSelectedWallet = provider.selectedWalletId != null;

    final availableTypes = budgets
        .map((b) => b.budgetType)
        .toSet()
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized && availableTypes.isNotEmpty) {
        setState(() {
          _selected = availableTypes.first;_selected = availableTypes.contains(BudgetType.monthly)
              ? BudgetType.monthly
              : availableTypes.first;
          _initialized = true;
        });
      }
    });

    final filteredBudgets = budgets
        .where((b) => b.budgetType == _selected)
        .toList();

    if (filteredBudgets.isEmpty && availableTypes.isNotEmpty) {
      _selected = availableTypes.first;
    }

    final totalBudget = filteredBudgets.fold<double>(
      0,
          (sum, b) => sum + b.amount,
    );

    final totalSpent = filteredBudgets.fold<double>(
      0,
          (sum, b) => sum + b.spentAmount,
    );



    /// trigger animation khi có data
    if (!isLoading && hasSelectedWallet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.status != AnimationStatus.forward) {
          _controller.forward(from: 0);
        }
      });
    }




    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            const Text(
              "Ngân sách",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const Spacer(),

            /// ✅ CHỈ HIỂN THỊ KHI ĐÃ CHỌN VÍ
            if (selectedWallet != null)
              GestureDetector(
                onTap: _pickWallet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      IconHelper.buildCircleAvatar(
                        iconUrl: selectedWallet!.goalImageUrl,
                        radius: 10,
                      ),
                      const SizedBox(width: 6),
                      Text(selectedWallet!.walletName),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExpiredBudgetScreen(),
                  ),
                );
              },
              child: const Icon(Icons.more_horiz),
            ),
          ],
        ),
      ),

      body: !hasSelectedWallet
          ? _selectWalletFirst()
          : isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async {
          await context.read<BudgetProvider>().loadBudgets(
            walletId: provider.selectedWalletId,
          );
        },
        child: budgets.isEmpty
            ? ListView(children: [_empty(context)])
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [

            /// 🔥 FILTER
            if (availableTypes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BudgetFilterTabs(
                  selected: _selected,
                  onChanged: _onFilterChanged,
                  availableTypes: availableTypes,
                ),
              ),

            /// 🔥 LABEL TIME (FIX CHUẨN)
            if (budgets.isNotEmpty)
              Padding(
                padding:
                const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  getCurrentLabel(filteredBudgets),
                  style:
                  const TextStyle(color: Colors.grey),
                ),
              ),

            _overview(totalBudget, totalSpent),
            const SizedBox(height: 20),
            _budgetSection(filteredBudgets),
          ],
        ),
      ),
    );
  }



  // ================= OVERVIEW =================
  Widget _overview(double totalBudget, double totalSpent) {
    final remain = totalBudget - totalSpent;

    final p =
    totalBudget <= 0 ? 0 : (totalSpent / totalBudget).clamp(0.0, 1.0);

    final animationValue =
    Curves.easeOutCubic.transform(_controller.value);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          /// ARC

          SizedBox(
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    return CustomPaint(
                      size: const Size(260, 260), // 👈 vuông
                      painter: ArcPainter(progress: p * animationValue),
                    );
                  },
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    const Text("Số tiền bạn có thể chi",
                        style: TextStyle(color: Colors.grey)),
                    Text(
                      formatMoney(remain),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: remain >= 0
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ),

                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _info(totalBudget, "Ngân sách"),
              _divider(),
              _info(totalSpent, "Đã chi"),
              _divider(),
              _info(p * 100, "Tiến độ"),
            ],
          ),

          const SizedBox(height: 20),

          Center(
            child: SizedBox(
              width: 200, // 👈 chỉnh độ rộng bạn muốn
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: addBudget,
                child: const Text("Tạo ngân sách"),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(double value, String title) {
    return Column(
      children: [
        Text(
          title == "Tiến độ"
              ? "${value.toInt()}%"
              : formatMoney(value),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  // ================= LIST =================
  Widget _budgetSection(List<BudgetResponse> budgets) {
    return Column(
      children: budgets.map((b) => _budgetItem(b)).toList(),
    );
  }

  Widget _budgetItem(BudgetResponse b) {
    final p = percent(b.spentAmount, b.amount);
    final left = b.amount - b.spentAmount;

    return OpenContainer(
      closedColor: Colors.transparent,
      openColor: Colors.black,
      closedElevation: 0,
      openBuilder: (_, __) => BudgetDetailScreen(
        budget: b,
        transactions: const [],
      ),
      closedBuilder: (_, open) {
        return GestureDetector(
          onTap: open,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconHelper.buildCircleAvatar(
                      iconUrl: b.primaryCategoryIconUrl,
                      radius: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        b.categories.isNotEmpty
                            ? b.categories.first.ctgName
                            : "Tất cả",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    Text(
                      "${(p * 100).toInt()}%",
                      style: TextStyle(color: getColor(p)),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: p,
                  minHeight: 8,
                  color: getColor(p),
                  backgroundColor: Colors.grey.shade800,
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    left >= 0
                        ? "Còn ${formatMoney(left)}"
                        : "⚠️ Vượt ${formatMoney(left.abs())}",
                    style: TextStyle(
                        color: left >= 0 ? Colors.green : Colors.red),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // ================= EMPTY =================
  Widget _selectWalletFirst() {
    return Center(
      child: ElevatedButton(
        onPressed: _pickWallet,
        child: const Text("Chọn ví"),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 64,
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "Chưa có ngân sách",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Tạo ngân sách để theo dõi chi tiêu\nvà kiểm soát tài chính tốt hơn.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: addBudget, // ✅ CHUẨN NHẤT
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text("Tạo ngân sách"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 30, color: Colors.grey);
  }
}

/// ================= ARC =================
class ArcPainter extends CustomPainter {
  final double progress;

  ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 14.0;

    final radius = size.width / 2;

    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius - strokeWidth,
    );

    /// ===== BACKGROUND =====
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, pi, pi, false, bgPaint);

    /// ===== COLOR =====
    Color startColor;
    Color endColor;

    if (progress >= 1) {
      startColor = Colors.redAccent;
      endColor = Colors.red;
    } else if (progress >= 0.75) {
      startColor = Colors.orangeAccent;
      endColor = Colors.deepOrange;
    } else {
      startColor = const Color(0xFF00E5FF);
      endColor = const Color(0xFF00E676);
    }

    final gradient = LinearGradient(
      colors: [startColor, endColor],
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final sweepAngle = pi * progress;

    canvas.drawArc(rect, pi, sweepAngle, false, progressPaint);

    /// ===== DOT =====
    final angle = pi + sweepAngle;

    final dx = size.width / 2 + (radius - strokeWidth) * cos(angle);
    final dy = size.height / 2 + (radius - strokeWidth) * sin(angle);

    final dotPaint = Paint()
      ..color = endColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(dx, dy), 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant ArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}