// ===========================================================
// [8.1] BillTransactionListScreen — Danh sách giao dịch của một hóa đơn
// ===========================================================
// Đã refactor: sài CommonTransactionListScreen + DTO mới TransactionListResponse
//
// API: GET /api/transactions/list?plannedId={billId}
// DTO: TransactionListResponse (totalIncome, totalExpense, netAmount,
//      transactionCount, List<DailyTransactionGroup>)
//
// Gọi từ:
//   • BillScreen → khi user bấm nút "Giao dịch" trong BillDetailSheet
// ===========================================================

import 'package:flutter/material.dart';
import 'package:smart_money/modules/transaction/screens/common_transaction_list_screen.dart';

class BillTransactionListScreen extends StatelessWidget {
  final int billId;
  final String billName;

  const BillTransactionListScreen({
    super.key,
    required this.billId,
    required this.billName,
  });

  @override
  Widget build(BuildContext context) {
    return CommonTransactionListScreen(
      title: 'Transactions of: $billName',
      filters: {'plannedId': billId.toString()},
    );
  }
}
