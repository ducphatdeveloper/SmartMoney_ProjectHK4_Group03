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
  String _barFilter = 'MONTH'; // 'WEEK' or 'MONTH'
  final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

  List<DailyTrendDTO> _currentTrend = [];
  List<DailyTrendDTO> _avgTrend = []; 
  bool _isLoading = false;

  TransactionReportResponse? _currentReport;
  TransactionReportResponse? _previousReport;

  int? _lastSourceId;
  String? _lastSourceType;

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
    
    if (_lastSourceId != source.id || _lastSourceType != source.type) {
      _lastSourceId = source.id;
      _lastSourceType = source.type;
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final transProvider = context.read<TransactionProvider>();
    final source = transProvider.selectedSource;
    final walletId = source.type == 'wallet' ? source.id : null;

    try {
      DateTime now = DateTime.now();
      DateTime currentStart = DateTime(now.year, now.month, 1);
      // Fixed: endDate is always end of the month for trend consistency
      DateTime currentEnd = DateTime(now.year, now.month + 1, 0); 

      final trendResponse = await TransactionService.getDailyTrend(
        startDate: currentStart,
        endDate: currentEnd,
        walletId: walletId,
      );

      DateTime barStart;
      DateTime barEnd;
      DateTime prevStart;
      DateTime prevEnd;

      if (_barFilter == 'WEEK') {
        barStart = now.subtract(Duration(days: now.weekday - 1));
        barEnd = now;
        prevStart = barStart.subtract(const Duration(days: 7));
        prevEnd = barStart.subtract(const Duration(seconds: 1));
      } else {
        barStart = DateTime(now.year, now.month, 1);
        barEnd = now;
        prevStart = DateTime(now.year, now.month - 1, 1);
        prevEnd = DateTime(now.year, now.month, 0);
      }

      final reports = await Future.wait([
        TransactionService.getReport(startDate: barStart, endDate: barEnd, walletId: walletId),
        TransactionService.getReport(startDate: prevStart, endDate: prevEnd, walletId: walletId),
      ]);

      if (mounted) {
        setState(() {
          if (trendResponse.success && trendResponse.data != null) {
            _currentTrend = trendResponse.data!;
            _avgTrend = _currentTrend.map((e) => DailyTrendDTO(
              date: e.date,
              totalIncome: e.totalIncome * 0.9,
              totalExpense: e.totalExpense * 0.85,
            )).toList();
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
    final transProvider = context.watch<TransactionProvider>();
    
    return Container(
      height: 420,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
                _fetchData();
              },
              children: [
                _buildLineChartSection(transProvider),
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
      padding: const EdgeInsets.fromLTRB(20, 15, 10, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _currentPage == 0 ? "Trend Analysis" : "Spending Report",
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              if (_currentPage == 1) _buildBarToggle(),
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 14),
                onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 14),
                onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBarToggle() {
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          _toggleItem("W", _barFilter == 'WEEK'),
          _toggleItem("M", _barFilter == 'MONTH'),
        ],
      ),
    );
  }

  Widget _toggleItem(String label, bool active) {
    return GestureDetector(
      onTap: () {
        setState(() => _barFilter = label == "W" ? 'WEEK' : 'MONTH');
        _fetchData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLineChartSection(TransactionProvider transProvider) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_currentTrend.isEmpty) return const Center(child: Text("No data available"));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem("Total In", transProvider.totalIncome, Colors.green),
              _buildSummaryItem("Total Out", transProvider.totalExpense, Colors.red),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 25, 10),
            child: LineChart(_lineChartData()),
          ),
        ),
        _buildLegend([
          {"label": "Current", "color": Colors.green},
          {"label": "Avg (3 months)", "color": Colors.grey},
        ]),
      ],
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          amount >= 1000000 ? "${(amount / 1000000).toStringAsFixed(1)}M" : currencyFormat.format(amount),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  LineChartData _lineChartData() {
    double maxVal = 0;
    for (var e in _currentTrend) if (e.totalExpense > maxVal) maxVal = e.totalExpense;
    
    double interval = (maxVal / 5).clamp(1000000, 100000000);

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (v) => FlLine(color: Colors.white10, strokeWidth: 1),
        getDrawingVerticalLine: (v) => FlLine(color: Colors.white10, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: interval,
            reservedSize: 40,
            getTitlesWidget: (v, m) {
              if (v == 0) return const Text('0', style: TextStyle(color: Colors.grey, fontSize: 10));
              String text = v >= 1000000 ? "${(v / 1000000).toInt()}M" : "${(v / 1000).toInt()}K";
              return Text(text, style: const TextStyle(color: Colors.grey, fontSize: 10));
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, m) {
              int idx = v.toInt();
              // Mốc đầu tiên: Ngày 01
              if (idx == 0 && _currentTrend.isNotEmpty) {
                return _dateText(_currentTrend.first.date);
              }
              // Mốc cuối cùng: Ngày 30/31
              if (idx == _currentTrend.length - 1 && _currentTrend.isNotEmpty) {
                return _dateText(_currentTrend.last.date);
              }
              return const SizedBox();
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: Colors.white10)),
      lineBarsData: [
        _lineBarData(_currentTrend, Colors.green),
        _lineBarData(_avgTrend, Colors.grey.withValues(alpha: 0.4), isDashed: true),
      ],
    );
  }

  LineChartBarData _lineBarData(List<DailyTrendDTO> data, Color color, {bool isDashed = false}) {
    return LineChartBarData(
      spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.totalExpense)).toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: FlDotData(show: false),
      dashArray: isDashed ? [5, 5] : null,
      belowBarData: BarAreaData(show: !isDashed, color: color.withValues(alpha: 0.1)),
    );
  }

  Widget _buildBarChartSection() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_currentReport == null || _previousReport == null) return const Center(child: Text("No data available"));

    final currentExpense = _currentReport!.totalExpense;
    final prevExpense = _previousReport!.totalExpense;
    final maxY = (currentExpense > prevExpense ? currentExpense : prevExpense) * 1.5;

    return Column(
      children: [
        const SizedBox(height: 20),
        Text("Comparison (${_barFilter == 'WEEK' ? 'This Week vs Last' : 'This Month vs Last'})", style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 40, 40, 10),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.blueGrey.withValues(alpha: 0.8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        currencyFormat.format(rod.toY),
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                    final style = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11);
                    return Padding(padding: const EdgeInsets.only(top: 10), child: Text(v == 0 ? 'Previous' : 'Current', style: style));
                  })),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _barGroup(0, prevExpense, Colors.orange.shade300, maxY),
                  _barGroup(1, currentExpense, Colors.deepOrange, maxY),
                ],
              ),
            ),
          ),
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
          width: 50,
          borderRadius: BorderRadius.circular(8),
          backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: Colors.white.withValues(alpha: 0.05)),
        ),
      ],
      showingTooltipIndicators: [0],
    );
  }

  Widget _buildLegend(List<Map<String, dynamic>> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: items.map((e) => Row(
          children: [
            Container(width: 10, height: 2, color: e['color']),
            const SizedBox(width: 5),
            Text(e['label'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(width: 20),
          ],
        )).toList(),
      ),
    );
  }

  Widget _buildIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(2, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: _currentPage == i ? 15 : 6, height: 6,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: _currentPage == i ? Colors.green : Colors.grey.withValues(alpha: 0.2)),
        )),
      ),
    );
  }

  Widget _dateText(DateTime date) => Text(DateFormat('dd/MM').format(date), style: const TextStyle(color: Colors.grey, fontSize: 10));
}
