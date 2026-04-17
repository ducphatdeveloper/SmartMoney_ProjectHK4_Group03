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
import 'package:smart_money/modules/budget/screens/ExpiredBudgetScreen.dart';

import '../../transaction/models/view/transaction_response.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../services/budget_service.dart';
import 'add_budget_screens.dart';
import 'budget_details_screens.dart';

class BudgetScreen extends StatefulWidget {
  final WalletResponse? initialWallet;
  const BudgetScreen({super.key , this.initialWallet});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
    with TickerProviderStateMixin  {
  WalletResponse? selectedWallet;
  //load budget theo ví từ trang walletdelete
  WalletResponse? tempInitialWallet;
  List<TransactionResponse> transaction = [];
  late AnimationController _controller;
  late Animation<double> _animation;
  bool isLoading = true;
  bool isPreviewBeforeDelete = false;

  // AnimationController? _controller;

  /// 👉 MỞ Fill theo thang , ngay , nam khi tao budget
  BudgetType _selected = BudgetType.monthly;

  void _onFilterChanged(BudgetType type) {
    setState(() => _selected = type);
    _controller?.forward(from: 0);
  }



  String getFullTimeLabel(BudgetResponse b) {
    final formatter = DateFormat('dd/MM');
    final start = b.beginDate;
    DateTime end = b.endDate;

    /// 🔥 CHỈ trừ 1 ngày nếu endDate là exclusive
    if (_isEndExclusive(b)) {
      end = end.subtract(const Duration(days: 1));
    }

    final range =
        "(${formatter.format(start)} - ${formatter.format(end)})";

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

  bool _isEndExclusive(BudgetResponse b) {
    final diff = b.endDate.difference(b.beginDate).inDays;

    switch (b.budgetType) {
      case BudgetType.weekly:
        return diff == 7;
      case BudgetType.monthly:
        return diff >= 28 && diff <= 31;
      case BudgetType.yearly:
        return diff >= 365;
      case BudgetType.custom:
        return false;
    }
  }



  // @override
  // void initState() {
  //   super.initState();
  //   _controller = AnimationController(
  //     vsync: this,
  //     duration: const Duration(milliseconds: 600),
  //   );
  //
  //   // Gọi load lần đầu
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     context.read<BudgetProvider>().refreshAllData();
  //   });
  //
  //   final provider = context.read<BudgetProvider>();
  //
  //   tempInitialWallet = widget.initialWallet; // ✅ THÊM
  //
  //   if (widget.initialWallet != null) {
  //     isPreviewBeforeDelete = true; // ✅ THÊM DÒNG NÀY
  //
  //     provider.setWallet(widget.initialWallet!);
  //
  //     Future.microtask(() {
  //       provider.loadBudgets(walletId: widget.initialWallet!.id);
  //     });
  //   }
  //
  //
  // }
  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    tempInitialWallet = widget.initialWallet;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BudgetProvider>();

      // 🔥 CASE 1: đi từ xoá ví → preview
      if (widget.initialWallet != null) {
        isPreviewBeforeDelete = true;
        provider.setWallet(widget.initialWallet!); // chỉ 1 API
      }
      // 🔥 CASE 2: vào bình thường
      else {
        provider.refreshAllData(); // chỉ 1 API
      }
    });
  }



  // Hàm này dùng chung cho cả việc tạo mới và đóng chi tiết
  Future<void> _handleDataChange() async {
    final provider = context.read<BudgetProvider>();
    await provider.refreshAllData(); // refreshAllData đã tự loadExpiredBudgets
    _controller.forward(from: 0);
  }

  // Future<void> _loadInitialData() async {
  //   final provider = context.read<BudgetProvider>();
  //   if (provider.selectedWalletId != null) {
  //     await provider.loadBudgets(walletId: provider.selectedWalletId);
  //     await _loadTransactions(provider.selectedWalletId!);
  //   }
  // }
  //
  // Future<void> _loadTransactions(int walletId) async {
  //   setState(() => isLoading = true);
  //   final service = BudgetService();
  //   final res = await service.getBudgetTransactions(walletId);
  //   if (res?.success == true) {
  //     transaction = res?.data ?? [];
  //     transaction.sort((a, b) => b.transDate.compareTo(a.transDate));
  //   }
  //   setState(() => isLoading = false);
  //   _controller.forward();
  // }



  Future<void> _pickWallet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SelectWalletScreen(),
      ),
    );

    if (result == null) return;

    final provider = context.read<BudgetProvider>();

    await provider.setWallet(result); // 🔥 load xong mới update UI

    // 🔥 Load lại ngân sách hết hạn sau khi chọn ví mới
    await provider.loadExpiredBudgets(walletId: provider.selectedWalletId);

    if (!mounted) return;
    _controller.forward(from: 0);
  }


  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }



  // ================= ADD =================
  Future<void> addBudget() async {
    final provider = context.read<BudgetProvider>();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddBudgetScreen(
          wallet: provider.selectedWallet,
        ),
      ),
    );

    if (result != null && result is BudgetResponse) {
      /// 🔥 RELOAD DATA
      await provider.loadBudgets(
        walletId: provider.selectedWalletId,
        forceRefresh: true,
      );

      /// 🔥 Load lại ngân sách hết hạn để cập nhật badge
      await provider.loadExpiredBudgets(walletId: provider.selectedWalletId);

      /// 🔥 SET FILTER THEO TYPE MỚI
      setState(() {
        _selected = result.budgetType;
      });
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
    final walletProvider = context.watch<WalletProvider>();
    final budgets = provider.displayBudgets;
    final isLoading = provider.isLoading;
    final selectedWallet = provider.selectedWallet;
    final walletExists = selectedWallet != null &&
        walletProvider.wallets.any((w) => w.id == selectedWallet.id);

    final hasSelectedWallet = walletExists;



    // final availableTypes = provider.budgets
    //     .map((b) => b.budgetType)
    //     .toSet()
    //     .toList()
    //   ..sort((a, b) => a.index.compareTo(b.index));

    final availableTypes = provider.budgets.map((b) => b.budgetType).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    final safeSelected = availableTypes.contains(_selected)
        ? _selected
        : (availableTypes.isNotEmpty ? availableTypes.first : BudgetType.monthly);

    // 🔥 Chỉ update _selected khi cần thiết
    if (!availableTypes.contains(_selected) && mounted) {
      setState(() {
        _selected = availableTypes.isNotEmpty
            ? availableTypes.first
            : BudgetType.monthly;
      });
    }

    final filteredBudgets = budgets
        .where((b) => b.budgetType == safeSelected)
        .toList();

    final totalBudget = filteredBudgets.fold<double>(
      0,
          (sum, b) => sum + b.amount,
    );

    final totalSpent = filteredBudgets.fold<double>(
      0,
          (sum, b) => sum + b.spentAmount,
    );

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
            Builder(
              builder: (context) {
                final budgetProvider = context.watch<BudgetProvider>();
                final walletProvider = context.watch<WalletProvider>();

                final selectedWallet = budgetProvider.selectedWallet;

                final walletExists = selectedWallet != null &&
                    walletProvider.wallets.any((w) => w.id == selectedWallet.id);

                if (selectedWallet == null || !walletExists) {
                  return const SizedBox();
                }

                return GestureDetector(
                  onTap: _pickWallet,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        IconHelper.buildCircleAvatar(
                          iconUrl: selectedWallet.goalImageUrl ?? "",
                          radius: 10,
                        ),
                        const SizedBox(width: 6),
                        Text(selectedWallet.walletName),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Spacer(),
            Builder(
              builder: (context) {
                final budgetProvider = context.watch<BudgetProvider>();
                final expiredCount = budgetProvider.expiredBudgets.length;

                // 🔥 Chỉ hiển thị badge khi đã chọn ví
                if (budgetProvider.selectedWalletId == null) {
                  return const SizedBox();
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExpiredBudgetScreen(),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          const Icon(Icons.archive_outlined, color: Colors.grey),
                          if (expiredCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "$expiredCount",
                                  style: const TextStyle(color: Colors.white, fontSize: 9),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "Hết hạn",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            )


          ],
        ),
      ),

      // ✅ FIX CHUẨN Ở ĐÂY
      body: Builder(
        builder: (context) {
          final budgetProvider = context.watch<BudgetProvider>();
          final walletProvider = context.watch<WalletProvider>();

          final selectedWallet = budgetProvider.selectedWallet;

          final walletExists = selectedWallet != null &&
              walletProvider.wallets.any((w) => w.id == selectedWallet.id);

          // ❗ CASE 1: chưa chọn ví
          if (selectedWallet == null) {
            return _selectWalletFirst();
          }

          // ❗ CASE 2: ví đã bị xoá
          if (!walletExists && !isPreviewBeforeDelete) {
            return _walletDeletedState();
          }


          // ❗ CASE 3: loading
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // ❗ CASE 4: bình thường
          return RefreshIndicator(
            onRefresh: () async {
              await context.read<BudgetProvider>().refreshAllData(); // refreshAllData đã tự loadExpiredBudgets
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // 🔥 CHÈN NGAY ĐÂY (TRÊN CÙNG)
                if (isPreviewBeforeDelete)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),

                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning_amber, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Bạn đang xem ngân sách của ví này trước khi xóa",
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),

                  ),

                // 🔽 logic cũ giữ nguyên
                if (budgets.isEmpty)
                  _empty(context)
                else ...[
                  if (availableTypes.isNotEmpty)
                    BudgetFilterTabs(
                      selected: _selected,
                      availableTypes: availableTypes,
                      onChanged: _onFilterChanged,
                    ),
                  const SizedBox(height: 30),
                  _overview(totalBudget, totalSpent),
                  const SizedBox(height: 30),
                  _budgetSection(filteredBudgets),
                ],
              ],
            ),

          );
        },
      ),
    );

  }

  // ================= LIST =================
  Widget _budgetSection(List<BudgetResponse> budgets) {
    if (budgets.isEmpty) {
      return const SizedBox();
    }

    return Column(
      children: budgets.map((b) => _budgetItem(b)).toList(),
    );
  }
  


  // ================= ITEM =================
  Widget _budgetItem(BudgetResponse b) {
    final provider = context.watch<BudgetProvider>();
    final p = (b.spentAmount / (b.amount == 0 ? 1 : b.amount)).clamp(0.0, 1.0);
    final left = b.amount - b.spentAmount;

    // 👉 Xác định icon và tên hiển thị
    String? iconUrl;
    String displayName;

    if (b.isOther == true) {
      // Ngân sách "Other" - hiển thị icon mặc định
      iconUrl = null;
      displayName = "Khác";
    } else if (b.allCategories == true) {
      // Ngân sách all categories
      iconUrl = b.primaryCategoryIconUrl;
      displayName = "Tất cả";
    } else if (b.categories?.isNotEmpty ?? false) {
      // Ngân sách theo category cụ thể
      iconUrl = b.categories!.first.ctgIconUrl;
      displayName = b.categories!.first.ctgName;
    } else {
      // Fallback
      iconUrl = b.primaryCategoryIconUrl;
      displayName = "Tất cả";
    }

    return OpenContainer<BudgetResponse>(
      closedColor: Colors.transparent,
      openColor: Colors.black,
      closedElevation: 0,
      openBuilder: (context, _) => BudgetDetailScreen(
        budget: b,
        provider: provider,
        wallet: provider.selectedWallet!,
        onUpdated: (_) => _handleDataChange(), // 🔥 reload after update
      ),
      onClosed: (_) => _handleDataChange(), // reload when closing detail
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
                          Text(
                            displayName,
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
          ),
        );
      },
    );
  }



  // ================= OVERVIEW =================
  Widget _overview(double totalBudget, double totalSpent) {
    final remain = (totalBudget - totalSpent).clamp(-double.infinity, double.infinity);
    final p = totalBudget <= 0 ? 0.0 : (totalSpent / totalBudget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => CustomPaint(
                    size: const Size(260, 260),
                    painter: ArcPainter(progress: p),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      remain >= 0
                          ? "Số tiền bạn có thể chi"
                          : "⚠️ Bạn đã vượt ngân sách",
                      style: TextStyle(
                        color: remain >= 0 ? Colors.grey : Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      formatMoney(remain),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: remain >= 0 ? Colors.greenAccent : Colors.redAccent,
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
              width: 200,
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
        Text(title,
            style: const TextStyle(color: Colors.grey)),
      ],
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
  // ================= Hiển thị chọn lại ví nếu ví đã bị xóa =================
  Widget _walletDeletedState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.redAccent, size: 40),

          const SizedBox(height: 8),

          const Text(
            "Ví trước đó đã bị xóa",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            "Vui lòng chọn ví khác để tiếp tục",
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 12),

          ElevatedButton(
            onPressed: _pickWallet,
            child: const Text("Chọn ví khác"),
          ),
        ],
      ),
    );
  }


  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
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
              onPressed: addBudget,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
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
    return Container(
        width: 1, height: 30, color: Colors.grey);
  }
}

// ================= ARC =================
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





