// ===========================================================
// CommonTransactionListScreen — Danh sách giao dịch dùng chung
// ===========================================================
// Trách nhiệm:
//   • Màn hình tái sử dụng cho MỌI module: Event, Debt, Planned Bill, Category
//   • Nhận title + filters động → gọi GET /api/transactions/list
//   • Hiển thị: Summary header + danh sách gom theo ngày (DailyTransactionGroup)
//   • Click giao dịch → TransactionDetailSheet (sửa/xóa)
//
// Cách gọi:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => CommonTransactionListScreen(
//       title: 'Đi vay',
//       filters: {'categoryIds': '20'},
//     ),
//   ));
//
// Các filter hỗ trợ (truyền vào Map<String, dynamic>):
//   • range, startDate, endDate — khoảng thời gian
//   • walletId, savingGoalId   — ví / mục tiêu tiết kiệm
//   • eventId                  — sự kiện
//   • debtId                   — sổ nợ
//   • plannedId                — hóa đơn / kế hoạch
//   • categoryIds              — danh mục (hỗ trợ multiple: "21,22")
//
// API: GET /api/transactions/list?...filters
// DTO: TransactionListResponse (totalIncome, totalExpense, netAmount,
//       transactionCount, List<DailyTransactionGroup>)
// ===========================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/modules/transaction/models/merge/transaction_list_response.dart';
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';
import 'package:smart_money/modules/transaction/screens/transaction_edit_screen.dart';
import 'package:smart_money/modules/transaction/services/transaction_service.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_day_group.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_detail_sheet.dart';

class CommonTransactionListScreen extends StatefulWidget {
  /// Tiêu đề hiển thị trên AppBar
  final String title;

  /// Bộ filter động truyền thẳng lên API query params
  /// Ví dụ: {'categoryIds': '20'} hoặc {'eventId': '7', 'range': 'THIS_YEAR'}
  final Map<String, dynamic> filters;

  const CommonTransactionListScreen({
    super.key,
    required this.title,
    required this.filters,
  });

  @override
  State<CommonTransactionListScreen> createState() =>
      _CommonTransactionListScreenState();
}

class _CommonTransactionListScreenState
    extends State<CommonTransactionListScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  TransactionListResponse? _data;

  // ─── Lifecycle ───────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ─── API ─────────────────────────────────────────────────
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await TransactionService.getTransactionList(
        filters: widget.filters,
      );

      if (!mounted) return;
      setState(() {
        if (response.success && response.data != null) {
          _data = response.data;
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

  // ─── Build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: _loadData,
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                ),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_data == null || _data!.dailyGroups.isEmpty) {
      return const Center(
        child: Text(
          'Không có giao dịch nào.',
          style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF4CAF50),
      child: ListView(
        children: [
          // ═══ Summary Header ═══
          _buildSummaryCard(),

          // ═══ Daily Groups ═══
          ..._data!.dailyGroups.map((group) {
            return TransactionDayGroup(
              date: group.date,
              displayDateLabel: group.displayDateLabel,
              transactions: group.transactions,
              netAmount: group.netAmount,
              onTapTransaction: (tx) => _showDetailSheet(tx),
            );
          }),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Summary Card ────────────────────────────────────────
  Widget _buildSummaryCard() {
    final data = _data!;
    final net = data.netAmount;
    final netColor = net >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF3B30);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + transaction count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng quan giao dịch',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${data.transactionCount} giao dịch',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFF3A3A3C)),

          // Income
          _summaryRow(
            'Tổng thu:',
            FormatHelper.formatVND(data.totalIncome),
            const Color(0xFF4CAF50),
          ),
          const SizedBox(height: 8),

          // Expense
          _summaryRow(
            'Tổng chi:',
            FormatHelper.formatVND(data.totalExpense),
            const Color(0xFFFF3B30),
          ),
          const SizedBox(height: 8),

          // Net
          _summaryRow(
            'Còn lại:',
            FormatHelper.formatVND(net),
            netColor,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─── Detail Sheet ────────────────────────────────────────
  void _showDetailSheet(TransactionResponse transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailSheet(
        transaction: transaction,
        onEdit: () {
          Navigator.pop(context);
          _openEditScreen(transaction);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(transaction);
        },
      ),
    );
  }

  // ─── Edit ────────────────────────────────────────────────
  Future<void> _openEditScreen(TransactionResponse transaction) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionEditScreen(transaction: transaction),
      ),
    );

    if (result == true && mounted) {
      _showSnackBar('Đã cập nhật giao dịch');
      _loadData();
    }
  }

  // ─── Delete ──────────────────────────────────────────────
  void _confirmDelete(TransactionResponse transaction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Xóa giao dịch',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có chắc muốn xóa giao dịch này?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider =
                  Provider.of<TransactionProvider>(context, listen: false);
              final success =
                  await provider.deleteTransaction(transaction.id);

              if (!mounted) return;

              if (success) {
                _showSnackBar('Đã xóa giao dịch');
                _loadData(); // Reload list
              } else {
                _showSnackBar(
                  provider.errorMessage ?? 'Có lỗi xảy ra',
                  isError: true,
                );
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ─── SnackBar ────────────────────────────────────────────
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFFF3B30) : const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

