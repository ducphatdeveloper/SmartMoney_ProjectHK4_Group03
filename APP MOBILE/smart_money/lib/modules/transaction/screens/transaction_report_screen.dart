// modules/transaction/screens/transaction_report_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:smart_money/core/models/api_response.dart';
import 'package:smart_money/modules/transaction/models/report/transaction_report_response.dart';
import 'package:smart_money/modules/transaction/models/report/category_report_dto.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';
import 'package:smart_money/modules/transaction/screens/common_transaction_list_screen.dart';
import 'package:smart_money/modules/transaction/services/transaction_service.dart';

class TransactionReportPanel extends StatelessWidget {
  final VoidCallback onClose;

  const TransactionReportPanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        DateTime startDate;
        DateTime endDate;
        String periodLabel;

        if (provider.isAllMode) {
          startDate = DateTime(2000, 1, 1);
          endDate = DateTime(2099, 12, 31, 23, 59, 59);
          periodLabel = 'All the time';
        } else if (provider.selectedDateRange != null) {
          startDate = provider.selectedDateRange!.startDate;
          endDate = provider.selectedDateRange!.endDate;
          periodLabel = provider.selectedDateRange!.label;
        } else {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Time period not selected',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.arrow_back, color: Colors.green),
                  label: const Text('Go back',
                      style: TextStyle(color: Colors.green)),
                ),
              ],
            ),
          );
        }

        final walletId = provider.selectedSource.type == 'wallet'
            ? provider.selectedSource.id
            : null;
        final savingGoalId = provider.selectedSource.type == 'saving_goal'
            ? provider.selectedSource.id
            : null;

        return _ReportLoader(
          key: ValueKey('$startDate|$endDate|$walletId|$savingGoalId'),
          startDate: startDate,
          endDate: endDate,
          walletId: walletId,
          savingGoalId: savingGoalId,
          periodLabel: periodLabel,
          onClose: onClose,
        );
      },
    );
  }
}

class _ReportLoader extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final int? walletId;
  final int? savingGoalId;
  final String periodLabel;
  final VoidCallback onClose;

  const _ReportLoader({
    super.key,
    required this.startDate,
    required this.endDate,
    this.walletId,
    this.savingGoalId,
    required this.periodLabel,
    required this.onClose,
  });

  @override
  State<_ReportLoader> createState() => _ReportLoaderState();
}

class _ReportLoaderState extends State<_ReportLoader> {
  bool _isLoading = true;
  String? _errorMessage;
  TransactionReportResponse? _report;
  List<CategoryReportDTO> _categoryExpenses = [];
  List<CategoryReportDTO> _categoryIncomes = [];
  int _touchedExpenseIndex = -1;
  int _touchedIncomeIndex = -1;
  final PageController _pageController = PageController();
  int _currentChartPage = 0;

  final List<Color> _chartColors = [
    Colors.blue,
    Colors.red,
    Colors.orange,
    Colors.green,
    Colors.purple,
    Colors.amber,
    Colors.cyan,
    Colors.pink,
    Colors.indigo,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        TransactionService.getReport(
          startDate: widget.startDate,
          endDate: widget.endDate,
          walletId: widget.walletId,
          savingGoalId: widget.savingGoalId,
        ),
        TransactionService.getCategoryReport(
          startDate: widget.startDate,
          endDate: widget.endDate,
          walletId: widget.walletId,
          savingGoalId: widget.savingGoalId,
        ),
      ]);

      final reportRes = results[0] as ApiResponse<TransactionReportResponse>;
      final categoryRes = results[1] as ApiResponse<List<CategoryReportDTO>>;

      if (!mounted) return;
      setState(() {
        if (reportRes.success && reportRes.data != null) {
          _report = reportRes.data;
        } else {
          _errorMessage = reportRes.message;
        }

        if (categoryRes.success && categoryRes.data != null) {
          final allCategories = categoryRes.data!;
          _categoryExpenses = allCategories
              .where((c) => c.categoryType == false && c.totalAmount > 0)
              .toList()
            ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

          _categoryIncomes = allCategories
              .where((c) => c.categoryType == true && c.totalAmount > 0)
              .toList()
            ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: Colors.green,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: CircularProgressIndicator(color: Colors.green),
                ),
              )
            else if (_errorMessage != null)
              _buildError()
            else if (_report != null) ...[
              _buildBalanceCard(),
              const SizedBox(height: 12),
              _buildIncomeExpenseCard(),
              const SizedBox(height: 12),
              _buildCategoryReportCard(),
              const SizedBox(height: 12),
              _buildDebtCard(),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: widget.onClose,
          tooltip: 'Return to list',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Financial report',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              Text(widget.periodLabel,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.grey, size: 18),
          onPressed: _loadAllData,
          tooltip: 'Reload',
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(_errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadAllData,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.account_balance_wallet_outlined, 'Balance'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _balanceCol('Opening Balance', _report!.openingBalance, Colors.grey),
              ),
              Container(width: 1, height: 36, color: Colors.grey[800]),
              Expanded(
                child: _balanceCol('Closing Balance', _report!.closingBalance, Colors.white, end: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseCard() {
    final net = _report!.netIncome;
    final isPositive = net >= 0;
    final netColor = isPositive ? Colors.green : Colors.red;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _showNetIncomeTooltip(context),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey, width: 1.5),
                  ),
                  child: const Center(
                    child: Text('?',
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Net income',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => _navigateToTransactionList('All transactions', {}),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('See details',
                        style: TextStyle(color: Colors.green[400], fontSize: 12)),
                    Icon(Icons.chevron_right, color: Colors.green[400], size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: netColor.withValues(alpha: 0.15),
                  border: Border.all(color: netColor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Center(
                  child: Icon(
                    isPositive ? Icons.add : Icons.remove,
                    color: netColor,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  FormatHelper.formatVND(net.abs()),
                  style: TextStyle(
                      color: netColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey[800], height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _balanceCol('Total Income', _report!.totalIncome, Colors.blue),
              ),
              Container(width: 1, height: 36, color: Colors.grey[800]),
              Expanded(
                child: _balanceCol('Total Expense', _report!.totalExpense, Colors.red, end: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNetIncomeTooltip(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('💡 Net Income'),
        content: const Text(
          'Net income is the remaining income after deducting all '
          'expenses during the period you\'re viewing.\n\n'
          'Formula: Total Income − Total Expense = Net Income',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryReportCard() {
    if (_categoryExpenses.isEmpty && _categoryIncomes.isEmpty) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(Icons.pie_chart_outline_rounded, 'Category report'),
            const SizedBox(height: 20),
            const Center(
              child: Text('No data for this period',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle(Icons.pie_chart_outline_rounded, 'Category report'),
              _buildChartToggle(),
            ],
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            height: 520, // Tăng thêm chiều cao để danh sách không bị cắt
            child: PageView(
              controller: _pageController,
              onPageChanged: (idx) => setState(() => _currentChartPage = idx),
              children: [
                _buildPieChartPage('Expenses', _categoryExpenses, true),
                _buildPieChartPage('Incomes', _categoryIncomes, false),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          _buildPageIndicator(),
        ],
      ),
    );
  }

  Widget _buildChartToggle() {
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _toggleItem("Expense", _currentChartPage == 0),
          _toggleItem("Income", _currentChartPage == 1),
        ],
      ),
    );
  }

  Widget _toggleItem(String label, bool active) {
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          label == "Expense" ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.green.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.green : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPieChartPage(String title, List<CategoryReportDTO> data, bool isExpense) {
    if (data.isEmpty) {
      return Center(
        child: Text('No $title data', style: const TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      if (isExpense) _touchedExpenseIndex = -1; else _touchedIncomeIndex = -1;
                      return;
                    }
                    if (isExpense) {
                      _touchedExpenseIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    } else {
                      _touchedIncomeIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    }
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: _buildPieSections(data, isExpense),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 20), // Thêm padding đáy cho list
            physics: const BouncingScrollPhysics(),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14), // Tăng khoảng cách dòng
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _chartColors[index % _chartColors.length].withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: IconHelper.buildCategoryIcon(
                          iconName: item.categoryIcon,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.categoryName, 
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    ),
                    const SizedBox(width: 8),
                    Text(
                      FormatHelper.formatVND(item.totalAmount), 
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(width: 12),
                    // Cột phần trăm rõ ràng, thẳng hàng
                    SizedBox(
                      width: 45,
                      child: Text(
                        '${item.percentage.toStringAsFixed(1)}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: Colors.green[400], fontSize: 11, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _indicatorDot(_currentChartPage == 0),
        const SizedBox(width: 6),
        _indicatorDot(_currentChartPage == 1),
      ],
    );
  }

  Widget _indicatorDot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 12 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? Colors.green : Colors.grey[700],
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(List<CategoryReportDTO> data, bool isExpense) {
    return List.generate(data.length, (i) {
      final isTouched = i == (isExpense ? _touchedExpenseIndex : _touchedIncomeIndex);
      final item = data[i];
      final double radius = isTouched ? 75.0 : 65.0;
      final double fontSize = isTouched ? 12.0 : 9.0;
      final double iconSize = isTouched ? 22.0 : 18.0;

      return PieChartSectionData(
        color: _chartColors[i % _chartColors.length],
        value: item.totalAmount,
        title: '${item.percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
        ),
        titlePositionPercentageOffset: 0.55,
        badgeWidget: _buildPieBadge(item.categoryIcon, iconSize),
        badgePositionPercentageOffset: 0.95,
      );
    });
  }

  Widget _buildPieBadge(String? iconName, double size) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: IconHelper.buildCategoryIcon(
          iconName: iconName,
          size: size,
        ),
      ),
    );
  }

  // ─── Card: Nợ & Vay ─────────────────────────────────────────
  // debtAmount  : DEBT_BORROWING (20)  — Đi vay
  // loanAmount  : DEBT_LENDING   (19)  — Cho vay
  // otherAmount : DEBT_COLLECTION(21) − DEBT_REPAYMENT(22) — Khác (có thể âm)
  Widget _buildDebtCard() {
    final debtAmount  = _report!.debtAmount;
    final loanAmount  = _report!.loanAmount;
    final otherAmount = _report!.otherAmount;
    final otherColor  = otherAmount >= 0 ? Colors.green : Colors.red;
    final otherIcon   = otherAmount >= 0 ? Icons.trending_up : Icons.trending_down;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.handshake_outlined, 'Debt and Loans'),
          const SizedBox(height: 14),
          // Dòng 1 — Nợ (Đi vay) → categoryIds=20
          _debtRow(
            Icons.arrow_circle_down_rounded, 'Amount of Debt', debtAmount, Colors.orange,
            onTap: () => _navigateToTransactionList('Borrow money', {'categoryIds': '20'}),
          ),
          // Dòng 2 — Cho vay → categoryIds=19
          _debtRow(
            Icons.arrow_circle_up_rounded, 'Loan amount', loanAmount, Colors.amber,
            onTap: () => _navigateToTransactionList('Loan', {'categoryIds': '19'}),
          ),
          // Dòng 3 — Khác (Thu nợ − Trả nợ) → categoryIds=21,22
          _debtRow(
            otherIcon, 'Paid / Received', otherAmount, otherColor,
            onTap: () => _navigateToTransactionList('Debt Collection/Repayment', {'categoryIds': '21,22'}),
          ),
        ],
      ),
    );
  }

  void _navigateToTransactionList(String title, Map<String, dynamic> extraFilters) {
    final mergedFilters = <String, dynamic>{
      'range': 'CUSTOM',
      'startDate': widget.startDate.toIso8601String(),
      'endDate': widget.endDate.toIso8601String(),
      ...extraFilters,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommonTransactionListScreen(
          title: title,
          filters: mergedFilters,
        ),
      ),
    );
  }

  Widget _debtRow(IconData icon, String label, double amount, Color color,
      {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          Text(
            FormatHelper.formatVND(amount),
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onTap,
              child: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 18),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _balanceCol(String label, double amount, Color color,
      {bool end = false}) {
    return Padding(
      padding: EdgeInsets.only(left: end ? 16 : 0, right: end ? 0 : 16),
      child: Column(
        crossAxisAlignment:
            end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            FormatHelper.formatVND(amount),
            style:
                TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
