// ===========================================================
// [8.1] BillTransactionListScreen — Danh sách giao dịch của một hóa đơn
// ===========================================================
// Trách nhiệm:
//   • Hiển thị tổng quan (totalCount, totalIncome, totalExpense)
//   • Hiển thị danh sách giao dịch được nhóm theo ngày
//
// Layout:
//   • AppBar: "Giao dịch của hóa đơn: [Tên hóa đơn]"
//   • Body:
//     - Phần tổng quan (summary)
//     - Danh sách groupedTransactions (DailyTransactionGroup)
//
// Flow:
//   1. initState: Gọi BillTransactionProvider để load dữ liệu
//   2. Hiển thị loading/error/data
//
// Gọi từ:
//   • BillScreen → khi user bấm nút "Giao dịch" trong BillDetailSheet
//
// API liên quan:
//   • GET /api/bills/{id}/transactions — lấy danh sách giao dịch của hóa đơn
// ===========================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/modules/planned/providers/bill_transaction_provider.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_day_group.dart';
import 'package:smart_money/modules/transaction/models/view/daily_transaction_group.dart' as model_daily_transaction_group; // Import với alias
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart'; // Import TransactionResponse

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
                ...billTransactions.groupedTransactions.map((group) {
                  // Sử dụng alias để đảm bảo đúng DailyTransactionGroup được tham chiếu
                  final model_daily_transaction_group.DailyTransactionGroup typedGroup = group;
                  return TransactionDayGroup(
                    date: typedGroup.date,
                    displayDateLabel: typedGroup.displayDateLabel,
                    transactions: typedGroup.transactions,
                    netAmount: typedGroup.netAmount,
                    onTapTransaction: (TransactionResponse tx) {
                      // [TODO] Xử lý khi người dùng bấm vào một giao dịch
                      // Có thể mở một sheet chi tiết giao dịch
                      debugPrint('Tapped on transaction: ${tx.id}');
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
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
