// modules/transaction/screens/transaction_report_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
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
  int _touchedIndex = -1;

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
          _categoryExpenses = categoryRes.data!
              .where((c) => c.categoryType == false && c.totalAmount > 0)
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
    if (_categoryExpenses.isEmpty) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(Icons.pie_chart_outline_rounded, 'Category report'),
            const SizedBox(height: 20),
            const Center(
              child: Text('No expense data for this period',
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
          _sectionTitle(Icons.pie_chart_outline_rounded, 'Category report'),
          const SizedBox(height: 20),
          
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: _buildPieSections(),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          ...List.generate(_categoryExpenses.length, (index) {
            final item = _categoryExpenses[index];
            final color = _chartColors[index % _chartColors.length];
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                },
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item.categoryName,
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(FormatHelper.formatVND(item.totalAmount),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        Text('${item.percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    return List.generate(_categoryExpenses.length, (i) {
      final isTouched = i == _touchedIndex;
      final item = _categoryExpenses[i];
      
      final double radius = isTouched ? 75.0 : 65.0;
      final double fontSize = isTouched ? 16.0 : 10.0;

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
        titlePositionPercentageOffset: 0.7,
      );
    });
  }

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
          _debtRow(Icons.arrow_circle_down_rounded, 'Amount of Debt', debtAmount, Colors.orange),
          _debtRow(Icons.arrow_circle_up_rounded, 'Loan amount', loanAmount, Colors.amber),
          _debtRow(otherIcon, 'Paid / Received', otherAmount, otherColor),
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

  Widget _debtRow(IconData icon, String label, double amount, Color color) {
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
