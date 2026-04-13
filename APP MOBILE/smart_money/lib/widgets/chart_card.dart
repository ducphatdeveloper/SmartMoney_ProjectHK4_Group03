import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../modules/transaction/providers/transaction_provider.dart';
import '../modules/transaction/models/report/daily_trend_dto.dart';
import '../modules/transaction/services/transaction_service.dart';
import '../modules/transaction/models/report/transaction_report_response.dart';

class ChartCard extends StatefulWidget {
  const ChartCard({super.key});

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

  List<DailyTrendDTO> _currentTrend = [];
  bool _isLoading = false;

  TransactionReportResponse? _currentReport;
  TransactionReportResponse? _previousReport;

  int? _lastSourceId;
  String? _lastSourceType;
  DateTime? _lastStartDate;
  DateTime? _lastEndDate;
  bool _lastProviderLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<TransactionProvider>();
    final source = provider.selectedSource;
    final range = provider.selectedDateRange;
    
    DateTime? start = provider.isAllMode ? DateTime(2000, 1, 1) : range?.startDate;
    DateTime? end = provider.isAllMode ? DateTime(2099, 12, 31) : range?.endDate;

    if (_lastSourceId != source.id || 
        _lastSourceType != source.type ||
        _lastStartDate != start ||
        _lastEndDate != end ||
        (_lastProviderLoading == true && provider.isLoading == false)) {
      
      _lastSourceId = source.id;
      _lastSourceType = source.type;
      _lastStartDate = start;
      _lastEndDate = end;
      _lastProviderLoading = provider.isLoading;
      
      if (!provider.isLoading) {
        _fetchData();
      }
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    
    final transProvider = context.read<TransactionProvider>();
    final source = transProvider.selectedSource;
    final range = transProvider.selectedDateRange;
    
    DateTime startDate = transProvider.isAllMode ? DateTime(2000, 1, 1) : (range?.startDate ?? DateTime.now());
    DateTime endDate = transProvider.isAllMode ? DateTime(2099, 12, 31) : (range?.endDate ?? DateTime.now());

    setState(() => _isLoading = true);

    try {
      final walletId = source.type == 'wallet' ? source.id : null;
      final goalId = source.type == 'saving_goal' ? source.id : null;

      final trendResponse = await TransactionService.getDailyTrend(
        startDate: startDate,
        endDate: endDate,
        walletId: walletId,
        savingGoalId: goalId,
      );

      final duration = endDate.difference(startDate);
      final prevEndDate = startDate.subtract(const Duration(seconds: 1));
      final prevStartDate = startDate.subtract(duration).subtract(const Duration(days: 1));

      final reports = await Future.wait([
        TransactionService.getReport(
          startDate: startDate, 
          endDate: endDate, 
          walletId: walletId,
          savingGoalId: goalId,
        ),
        TransactionService.getReport(
          startDate: prevStartDate, 
          endDate: prevEndDate, 
          walletId: walletId,
          savingGoalId: goalId,
        ),
      ]);

      if (mounted) {
        setState(() {
          if (trendResponse.success && trendResponse.data != null) {
            _currentTrend = trendResponse.data!;
          }
          if (reports[0].success) _currentReport = reports[0].data;
          if (reports[1].success) _previousReport = reports[1].data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildLineChartSection(),
                _buildBarChartSection(),
              ],
            ),
          ),
          _buildIndicator(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentPage == 0 ? "Cash Flow Trend" : "Spending Analysis",
                style: const TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currentPage == 0 ? "Daily income vs expenses" : "Current vs previous period",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          Row(
            children: [
              _buildNavButton(Icons.chevron_left, () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)),
              const SizedBox(width: 8),
              _buildNavButton(Icons.chevron_right, () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: Colors.white70),
      ),
    );
  }

  Widget _buildLineChartSection() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
    if (_currentTrend.isEmpty) return _buildNoData();

    return Column(
      children: [
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 24, 0),
            child: LineChart(_lineChartData()),
          ),
        ),
        _buildLegend([
          {"label": "Income", "color": Colors.greenAccent},
          {"label": "Expense", "color": Colors.redAccent},
        ]),
      ],
    );
  }

  LineChartData _lineChartData() {
    double maxVal = 0;
    for (var e in _currentTrend) {
      if (e.totalExpense > maxVal) maxVal = e.totalExpense;
      if (e.totalIncome > maxVal) maxVal = e.totalIncome;
    }
    
    double interval = (maxVal / 4).clamp(1000.0, 100000000.0);
    if (maxVal == 0) maxVal = 1000;

    return LineChartData(
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: const Color(0xFF2C2C2E).withOpacity(0.95),
          tooltipRoundedRadius: 12,
          fitInsideVertically: true, // Tự động nhảy xuống dưới nếu chạm đỉnh biểu đồ
          fitInsideHorizontally: true,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          getTooltipItems: (List<LineBarSpot> touchedSpots) {
            final dateStr = DateFormat('MMM dd').format(_currentTrend[touchedSpots.first.x.toInt()].date);
            return touchedSpots.map((LineBarSpot touchedSpot) {
              final isIncome = touchedSpot.barIndex == 0;
              return LineTooltipItem(
                touchedSpot.barIndex == 0 ? "$dateStr\n" : "", // Chỉ hiện ngày ở dòng đầu tiên
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                children: [
                  TextSpan(
                    text: isIncome ? "Income: " : "Expense: ",
                    style: TextStyle(color: isIncome ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.normal, fontSize: 11),
                  ),
                  TextSpan(
                    text: currencyFormat.format(touchedSpot.y),
                    style: TextStyle(color: isIncome ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: interval,
            reservedSize: 45,
            getTitlesWidget: (v, m) {
              if (v == 0) return const Text('0', style: TextStyle(color: Colors.grey, fontSize: 10));
              String text = v >= 1000000 ? "${(v / 1000000).toStringAsFixed(1)}M" : "${(v / 1000).toInt()}K";
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.right),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, m) {
              int idx = v.toInt();
              if (idx < 0 || idx >= _currentTrend.length) return const SizedBox();
              
              bool shouldShow = idx == 0 || 
                               idx == _currentTrend.length - 1 || 
                               (_currentTrend.length > 14 && idx == (_currentTrend.length / 2).floor());
              
              if (shouldShow) {
                return SideTitleWidget(
                  axisSide: m.axisSide,
                  space: 10,
                  child: Text(
                    DateFormat('dd/MM').format(_currentTrend[idx].date), 
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w500)
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        _lineBarData(true, Colors.greenAccent),
        _lineBarData(false, Colors.redAccent),
      ],
      minY: 0,
      maxY: maxVal * 1.3, // Tăng thêm không gian phía trên cho Tooltip
    );
  }

  LineChartBarData _lineBarData(bool isIncome, Color color) {
    return LineChartBarData(
      spots: _currentTrend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), isIncome ? e.value.totalIncome : e.value.totalExpense)).toList(),
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: _currentTrend.length < 15,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeWidth: 1,
          strokeColor: const Color(0xFF1C1C1E),
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildBarChartSection() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.deepOrangeAccent));
    if (_currentReport == null || _previousReport == null) return _buildNoData();

    final currentExpense = _currentReport!.totalExpense;
    final prevExpense = _previousReport!.totalExpense;
    final maxY = (currentExpense > prevExpense ? currentExpense : prevExpense) * 1.4;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBarSummary("PREVIOUS", prevExpense, Colors.blueGrey.shade300),
              _buildBarSummary("CURRENT", currentExpense, Colors.deepOrangeAccent),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 10, 40, 10),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY > 0 ? maxY : 1000,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, 
                      getTitlesWidget: (v, m) {
                        final bool isCurrent = v != 0;
                        final color = isCurrent ? Colors.deepOrangeAccent : Colors.blueGrey.shade300;
                        return SideTitleWidget(
                          axisSide: m.axisSide,
                          space: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withOpacity(0.2)),
                            ),
                            child: Text(
                              isCurrent ? 'CURR' : 'PREV', 
                              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                        );
                      }
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _barGroup(0, prevExpense, Colors.blueGrey.shade400, maxY > 0 ? maxY : 1000),
                  _barGroup(1, currentExpense, Colors.deepOrangeAccent, maxY > 0 ? maxY : 1000),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBarSummary(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(
          currencyFormat.format(amount),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  BarChartGroupData _barGroup(int x, double y, Color color, double maxY) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 48,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true, 
            toY: maxY, 
            color: Colors.white.withOpacity(0.03),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(List<Map<String, dynamic>> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: items.map((e) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 12, height: 4, 
                decoration: BoxDecoration(color: e['color'], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text(e['label'], style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(2, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == i ? 20 : 6, height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3), 
            color: _currentPage == i ? Colors.greenAccent : Colors.white.withOpacity(0.1),
          ),
        )),
      ),
    );
  }

  Widget _buildNoData() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.bar_chart, size: 48, color: Colors.white.withOpacity(0.1)),
        const SizedBox(height: 16),
        Text("No data available for this period", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
      ],
    );
  }
}
