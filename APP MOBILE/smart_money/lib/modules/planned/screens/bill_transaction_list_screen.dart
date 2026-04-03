// ===========================================================
// [8.1] BillTransactionListScreen — Danh sách giao dịch của một hóa đơn
// ===========================================================
// Trách nhiệm:
//   • Hiển thị tổng quan (totalCount, totalIncome, totalExpense)
//   • Hiển thị danh sách giao dịch được nhóm theo ngày
//
// Layout:
//   • AppBar: "Giao dịch của: [Tên hóa đơn]"
//   • Body:
//     - Phần tổng quan (summary)
//     - Danh sách groupedTransactions (DailyTransactionGroup)
//   • Click transaction → TransactionDetailSheet (icon category, sửa, xóa)
//
// Flow:
//   1. initState: Gọi BillTransactionProvider để load dữ liệu
//   2. Hiển thị loading/error/data
//   3. User tap transaction → TransactionDetailSheet (tái sử dụng widget chuẩn)
//   4. Sửa → TransactionEditScreen → reload list
//   5. Xóa → confirm dialog → provider.deleteTransaction() → reload list
//
// Gọi từ:
//   • BillScreen → khi user bấm nút "Giao dịch" trong BillDetailSheet
//
// API liên quan:
//   • GET    /api/bills/{id}/transactions — lấy danh sách giao dịch của hóa đơn
//   • PUT    /api/transactions/{id}       — cập nhật giao dịch (qua TransactionEditScreen)
//   • DELETE /api/transactions/{id}       — xóa giao dịch
// ===========================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/modules/planned/providers/bill_transaction_provider.dart';
import 'package:smart_money/modules/transaction/models/view/daily_transaction_group.dart' as model_daily_transaction_group;
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';
import 'package:smart_money/modules/transaction/screens/transaction_edit_screen.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_day_group.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_detail_sheet.dart';

class BillTransactionListScreen extends StatefulWidget {
  final int billId;
  final String billName;

  const BillTransactionListScreen({
    super.key,
    required this.billId,
    required this.billName,
  });

  @override
  State<BillTransactionListScreen> createState() => _BillTransactionListScreenState();
}

class _BillTransactionListScreenState extends State<BillTransactionListScreen> {

  // =============================================
  // [8.1.1] initState
  // =============================================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BillTransactionProvider>(context, listen: false)
          .loadBillTransactions(widget.billId);
    });
  }

  // =============================================
  // [8.1.2] BUILD
  // =============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Giao dịch của: ${widget.billName}',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Consumer<BillTransactionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)));
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Text(
                provider.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          }

          if (provider.billTransactions == null) {
            return const Center(
              child: Text(
                'Không có dữ liệu giao dịch cho hóa đơn này.',
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
              ),
            );
          }

          final billTransactions = provider.billTransactions!;
          final summary = billTransactions.summary;

          return ListView(
            children: [
              // =============================================
              // [8.1.3] SUMMARY SECTION
              // =============================================
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng quan giao dịch',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const Divider(height: 20, color: Color(0xFF3A3A3C)),
                    _buildSummaryRow('Tổng số giao dịch:', '${billTransactions.totalCount}', Colors.white),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Tổng thu:', FormatHelper.formatVND(summary.totalIncome), const Color(0xFF4CAF50)),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Tổng chi:', FormatHelper.formatVND(summary.totalExpense), const Color(0xFFFF3B30)),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Còn lại:',
                      FormatHelper.formatVND(summary.totalIncome - summary.totalExpense),
                      (summary.totalIncome - summary.totalExpense) >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF3B30),
                    ),
                  ],
                ),
              ),

              // =============================================
              // [8.1.4] GROUPED TRANSACTIONS SECTION
              // =============================================
              if (billTransactions.groupedTransactions.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Không có giao dịch nào trong khoảng thời gian này.',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                    ),
                  ),
                )
              else
                // [FIX] Dùng TransactionDayGroup với callback mở TransactionDetailSheet
                // → tái sử dụng widget chuẩn (có icon category, nút Sửa/Xóa)
                ...billTransactions.groupedTransactions.map((group) {
                  final model_daily_transaction_group.DailyTransactionGroup typedGroup = group;
                  return TransactionDayGroup(
                    date: typedGroup.date,
                    displayDateLabel: typedGroup.displayDateLabel,
                    transactions: typedGroup.transactions,
                    netAmount: typedGroup.netAmount,
                    onTapTransaction: (TransactionResponse tx) {
                      // [FIX] Tái sử dụng TransactionDetailSheet — giống trang danh sách giao dịch
                      // Có đầy đủ: icon category, số tiền, ngày, ví, ghi chú, nút Sửa + Xóa
                      _showDetailSheet(tx);
                    },
                  );
                }).toList(),
            ],
          );
        },
      ),
    );
  }

  // =============================================
  // [8.1.5] HELPER — Build Summary Row
  // =============================================
  Widget _buildSummaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // =============================================
  // [8.1.6] DETAIL SHEET — Tái sử dụng TransactionDetailSheet chuẩn
  // =============================================
  // [FIX] Dùng TransactionDetailSheet thay vì custom bottom sheet
  // Giống hệt transaction_list.dart → nhất quán toàn app
  void _showDetailSheet(TransactionResponse transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailSheet(
        transaction: transaction,
        onEdit: () {
          Navigator.pop(context); // Đóng sheet trước
          _openEditScreen(transaction);
        },
        onDelete: () {
          Navigator.pop(context); // Đóng sheet trước
          _confirmDelete(transaction);
        },
      ),
    );
  }

  // =============================================
  // [8.1.7] NAVIGATE — Mở form sửa giao dịch
  // =============================================
  // Gọi khi: User bấm "Sửa" trong TransactionDetailSheet
  Future<void> _openEditScreen(TransactionResponse transaction) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionEditScreen(transaction: transaction),
      ),
    );

    // Bước: Sau khi sửa thành công → reload danh sách giao dịch hóa đơn
    if (result == true && mounted) {
      _showSnackBar('Đã cập nhật giao dịch');
      Provider.of<BillTransactionProvider>(context, listen: false)
          .loadBillTransactions(widget.billId);
    }
  }

  // =============================================
  // [8.1.8] DIALOG — Xác nhận xóa giao dịch
  // =============================================
  // Gọi khi: User bấm "Xóa" trong TransactionDetailSheet
  void _confirmDelete(TransactionResponse transaction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Xóa giao dịch', style: TextStyle(color: Colors.white)),
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
              final provider = Provider.of<TransactionProvider>(context, listen: false);
              final success = await provider.deleteTransaction(transaction.id);

              // [IMPORTANT] Kiểm tra mounted sau await
              if (!mounted) return;

              if (success) {
                _showSnackBar('Đã xóa giao dịch');
                // Reload danh sách sau khi xóa thành công
                Provider.of<BillTransactionProvider>(context, listen: false)
                    .loadBillTransactions(widget.billId);
              } else {
                _showSnackBar(provider.errorMessage ?? 'Có lỗi xảy ra', isError: true);
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // =============================================
  // [8.1.9] HELPER — Hiện SnackBar
  // =============================================
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFFF3B30) : const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
