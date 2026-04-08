// modules/transaction/screens/transaction_report_screen.dart
// Báo cáo tài chính theo giai đoạn — dùng được cả inline (TransactionReportPanel)
//
// [TransactionReportPanel] — widget công khai, nhúng inline vào TransactionListScreen
//   • Dùng Consumer<TransactionProvider> nội bộ để tự đọc startDate/endDate/source
//   • Dùng ValueKey để tự reload khi người dùng đổi range hoặc đổi ví
//   • Chỉ gọi 1 API: GET /api/transactions/report/summary
//
// Cấu trúc widget:
//   TransactionReportPanel (StatelessWidget, public)
//     └─ Consumer<TransactionProvider>
//           └─ _ReportLoader (StatefulWidget, private — xử lý API + UI)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/modules/transaction/models/report/transaction_report_response.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';
import 'package:smart_money/modules/transaction/screens/common_transaction_list_screen.dart';
import 'package:smart_money/modules/transaction/services/transaction_service.dart';

// =============================================================================
// TransactionReportPanel — PUBLIC widget, nhúng vào bất kỳ screen nào
// =============================================================================
class TransactionReportPanel extends StatelessWidget {
  /// Callback khi user bấm "← Quay lại" để thoát chế độ báo cáo
  final VoidCallback onClose;

  const TransactionReportPanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        // ── Xác định khoảng thời gian từ provider ──────────────
        DateTime startDate;
        DateTime endDate;
        String periodLabel;

        if (provider.isAllMode) {
          startDate = DateTime(2000, 1, 1);
          endDate = DateTime(2099, 12, 31, 23, 59, 59);
          periodLabel = 'Tất cả thời gian';
        } else if (provider.selectedDateRange != null) {
          startDate = provider.selectedDateRange!.startDate;
          endDate = provider.selectedDateRange!.endDate;
          periodLabel = provider.selectedDateRange!.label;
        } else {
          // Chưa chọn khoảng thời gian
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Chưa chọn khoảng thời gian',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.arrow_back, color: Colors.green),
                  label: const Text('Quay lại',
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

        // ValueKey → _ReportLoader tự rebuild + gọi lại API khi params thay đổi
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

// =============================================================================
// _ReportLoader — PRIVATE StatefulWidget: gọi API + hiển thị kết quả
// =============================================================================
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

  // ─── Lifecycle ───────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  // ─── API ─────────────────────────────────────────────────────
  Future<void> _loadReport() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await TransactionService.getReport(
        startDate: widget.startDate,
        endDate: widget.endDate,
        walletId: widget.walletId,
        savingGoalId: widget.savingGoalId,
      );

      if (!mounted) return;
      setState(() {
        if (response.success && response.data != null) {
          _report = response.data;
        } else {
          _errorMessage = response.message;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lỗi: ${e.toString()}';
      });
    }
  }

  // ─── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadReport,
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

  // ─── Header ──────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: widget.onClose,
          tooltip: 'Quay lại danh sách',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Báo cáo tài chính',
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
          onPressed: _loadReport,
          tooltip: 'Tải lại',
        ),
      ],
    );
  }

  // ─── Error ───────────────────────────────────────────────────
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
              onPressed: _loadReport,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Card: Số dư đầu / cuối kỳ ──────────────────────────────
  Widget _buildBalanceCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.account_balance_wallet_outlined, 'Số dư'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _balanceCol('Đầu kỳ', _report!.openingBalance, Colors.grey),
              ),
              Container(width: 1, height: 36, color: Colors.grey[800]),
              Expanded(
                child: _balanceCol('Cuối kỳ', _report!.closingBalance, Colors.white, end: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Card: Thu nhập ròng ────────────────────────────────────
  Widget _buildIncomeExpenseCard() {
    final net = _report!.netIncome;
    final isPositive = net >= 0;
    final netColor = isPositive ? Colors.green : Colors.red;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ──────────────────────────────────────
          Row(
            children: [
              // ? icon giải thích
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
              const Text('Thu nhập ròng',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => _navigateToTransactionList('Tất cả giao dịch', {}),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Xem chi tiết',
                        style: TextStyle(color: Colors.green[400], fontSize: 12)),
                    Icon(Icons.chevron_right, color: Colors.green[400], size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Net income với circle icon +/- ─────────────────
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

          // ── Tiền vào / Tiền ra ─────────────────────────────
          Row(
            children: [
              Expanded(
                child: _balanceCol('Tiền vào', _report!.totalIncome, Colors.blue),
              ),
              Container(width: 1, height: 36, color: Colors.grey[800]),
              Expanded(
                child: _balanceCol('Tiền ra', _report!.totalExpense, Colors.red, end: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Popup giải thích — dùng AlertDialog Flutter chuẩn
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

  // ─── Card: Báo cáo theo nhóm (placeholder) ──────────────────
  Widget _buildCategoryReportCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.pie_chart_outline_rounded, 'Báo cáo theo nhóm'),
          const SizedBox(height: 14),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Coming soon...',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
          ),
        ],
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
          _sectionTitle(Icons.handshake_outlined, 'Nợ & Vay'),
          const SizedBox(height: 14),
          // Dòng 1 — Nợ (Đi vay) → categoryIds=20
          _debtRow(
            Icons.arrow_circle_down_rounded, 'Khoản Nợ', debtAmount, Colors.orange,
            onTap: () => _navigateToTransactionList('Đi vay', {'categoryIds': '20'}),
          ),
          // Dòng 2 — Cho vay → categoryIds=19
          _debtRow(
            Icons.arrow_circle_up_rounded, 'Khoản cho vay', loanAmount, Colors.amber,
            onTap: () => _navigateToTransactionList('Cho vay', {'categoryIds': '19'}),
          ),
          // Dòng 3 — Khác (Thu nợ − Trả nợ) → categoryIds=21,22
          _debtRow(
            otherIcon, 'Đã trả / Đã thu', otherAmount, otherColor,
            onTap: () => _navigateToTransactionList('Thu/Trả nợ', {'categoryIds': '21,22'}),
          ),
        ],
      ),
    );
  }

  /// Điều hướng đến CommonTransactionListScreen — tự động truyền date range hiện tại
  void _navigateToTransactionList(String title, Map<String, dynamic> extraFilters) {
    // Luôn truyền khoảng thời gian đang hiển thị trên slider vào danh sách chi tiết
    final mergedFilters = <String, dynamic>{
      'range': 'CUSTOM',
      'startDate': widget.startDate.toIso8601String(),
      'endDate': widget.endDate.toIso8601String(),
      ...extraFilters, // categoryIds, eventId, debtId, v.v.
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

  // ─── UI Helpers ──────────────────────────────────────────────
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


