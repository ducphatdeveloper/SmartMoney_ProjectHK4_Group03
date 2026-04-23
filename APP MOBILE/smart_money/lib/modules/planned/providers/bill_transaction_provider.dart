// ===========================================================
// [2] BillTransactionProvider — Quản lý state danh sách giao dịch của hóa đơn
// ===========================================================
// Trách nhiệm:
//   • Lưu trữ BillTransactionListResponse
//   • Gọi PlannedService để lấy dữ liệu giao dịch của hóa đơn
//   • Thông báo UI rebuild khi dữ liệu thay đổi (notifyListeners)
//
// Cách dùng trong Screen:
//   final provider = Provider.of<BillTransactionProvider>(context);
//   provider.loadBillTransactions(billId);
// ===========================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_money/core/helpers/token_helper.dart';
import 'package:smart_money/modules/planned/services/planned_service.dart';
import 'package:smart_money/modules/transaction/models/view/bill_transaction_list_response.dart';

class BillTransactionProvider extends ChangeNotifier {

  // =============================================
  // [2.1] STATE
  // =============================================
  BillTransactionListResponse? _billTransactions;
  BillTransactionListResponse? get billTransactions => _billTransactions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // =============================================
  // [2.2] LOAD — Lấy danh sách giao dịch của hóa đơn
  // =============================================
  // Gọi khi: Mở màn hình BillTransactionListScreen
  // API: GET /api/bills/{id}/transactions
  Future<void> loadBillTransactions(BuildContext context, int billId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await PlannedService.getBillTransactions(billId);

      if (response.success && response.data != null) {
        _billTransactions = response.data;
      } else {
        _billTransactions = null;
        _errorMessage = response.message ?? 'Cannot load bill transactions.';
      }
    } catch (e) {
      _errorMessage = e.toString();
      // Xử lý 401 - Session expired
      if (e.toString().contains("Session expired")) {
        await TokenHelper.clearTokens();
        if (context.mounted) {
          context.go("/login");
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =============================================
  // [2.3] CLEAR — Xóa thông báo lỗi
  // =============================================
  void clearMessages() {
    _errorMessage = null;
    notifyListeners();
  }
}
