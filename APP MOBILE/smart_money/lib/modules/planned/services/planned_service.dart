// ===========================================================
// [1] PlannedService — Gọi API giao dịch định kỳ & hóa đơn từ Spring Boot
// ===========================================================
// Trách nhiệm:
//   • Là lớp DUY NHẤT gọi HTTP cho module Planned Transaction
//   • Tất cả method là static — gọi trực tiếp không cần instance
//   • Không chứa logic UI, không setState, không BuildContext
//
// Gọi từ:
//   • RecurringProvider → gọi getRecurring, createRecurring, updateRecurring, deleteRecurring, toggleRecurring
//   • BillProvider → gọi getBills, createBill, updateBill, deleteBill, toggleBill, payBill
//   • BillTransactionProvider → gọi getBillTransactions
//
// API liên quan:
//   • GET    /api/recurring?active=true|false  — lấy danh sách giao dịch định kỳ
//   • POST   /api/recurring                    — tạo mới giao dịch định kỳ
//   • PUT    /api/recurring/{id}               — cập nhật giao dịch định kỳ
//   • DELETE /api/recurring/{id}               — xóa giao dịch định kỳ
//   • PATCH  /api/recurring/{id}/toggle        — bật/tắt active
//   • GET    /api/bills?active=true|false      — lấy danh sách hóa đơn
//   • POST   /api/bills                        — tạo mới hóa đơn
//   • PUT    /api/bills/{id}                   — cập nhật hóa đơn
//   • DELETE /api/bills/{id}                   — xóa hóa đơn
//   • PATCH  /api/bills/{id}/toggle            — đánh dấu hoàn tất/chưa
//   • POST   /api/bills/{id}/pay               — trả tiền hóa đơn → tạo Transaction
//   • GET    /api/bills/{id}/transactions      — lấy danh sách giao dịch của hóa đơn
// ===========================================================

import 'package:smart_money/core/helpers/api_handler.dart';
import 'package:smart_money/core/models/api_response.dart';
import 'package:smart_money/core/constants/app_constants.dart';
import 'package:smart_money/modules/planned/models/planned_transaction_request.dart';
import 'package:smart_money/modules/planned/models/planned_transaction_response.dart';
import 'package:smart_money/modules/transaction/models/view/bill_transaction_list_response.dart'; // Import mới

class PlannedService {

  // ── RECURRING (Giao dịch định kỳ) ─────────────────────────

  // -----------------------------------------------------------
  // [1.1] Lấy danh sách Recurring theo trạng thái active
  // -----------------------------------------------------------
  // Tham số: active — true = đang hoạt động, false = đã kết thúc
  // API: GET /api/recurring?active=true|false
  static Future<ApiResponse<List<PlannedTransactionResponse>>> getRecurring({
    required bool active,
  }) async {
    final url = '${AppConstants.recurringBase}?active=$active';
    return ApiHandler.get<List<PlannedTransactionResponse>>(
      url,
      fromJson: (json) => _parseList(json),
    );
  }

  // -----------------------------------------------------------
  // [1.2] Tạo Recurring mới
  // -----------------------------------------------------------
  // API: POST /api/recurring
  // Body: PlannedTransactionRequest.toJson()
  static Future<ApiResponse<PlannedTransactionResponse>> createRecurring(
    PlannedTransactionRequest request,
  ) async {
    return ApiHandler.post<PlannedTransactionResponse>(
      AppConstants.recurringBase,
      body: request.toJson(),
      fromJson: (json) => PlannedTransactionResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.3] Cập nhật Recurring
  // -----------------------------------------------------------
  // API: PUT /api/recurring/{id}
  static Future<ApiResponse<PlannedTransactionResponse>> updateRecurring(
    int id,
    PlannedTransactionRequest request,
  ) async {
    final url = AppConstants.recurringById(id);
    return ApiHandler.put<PlannedTransactionResponse>(
      url,
      body: request.toJson(),
      fromJson: (json) => PlannedTransactionResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.4] Xóa Recurring
  // -----------------------------------------------------------
  // API: DELETE /api/recurring/{id}
  static Future<ApiResponse<void>> deleteRecurring(int id) async {
    final url = AppConstants.recurringById(id);
    return ApiHandler.delete<void>(url);
  }

  // -----------------------------------------------------------
  // [1.5] Toggle Recurring — bật/tắt active
  // -----------------------------------------------------------
  // API: PATCH /api/recurring/{id}/toggle
  static Future<ApiResponse<PlannedTransactionResponse>> toggleRecurring(int id) async {
    final url = AppConstants.recurringToggle(id);
    return ApiHandler.patch<PlannedTransactionResponse>(
      url,
      fromJson: (json) => PlannedTransactionResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // ── BILLS (Hóa đơn) ───────────────────────────────────────

  // -----------------------------------------------------------
  // [1.6] Lấy danh sách Bill theo trạng thái active
  // -----------------------------------------------------------
  // Tham số: active — true = đang áp dụng, false = đã kết thúc
  // API: GET /api/bills?active=true|false
  static Future<ApiResponse<List<PlannedTransactionResponse>>> getBills({
    required bool active,
  }) async {
    final url = '${AppConstants.billsBase}?active=$active';
    return ApiHandler.get<List<PlannedTransactionResponse>>(
      url,
      fromJson: (json) => _parseList(json),
    );
  }

  // -----------------------------------------------------------
  // [1.7] Tạo Bill mới
  // -----------------------------------------------------------
  // API: POST /api/bills
  static Future<ApiResponse<PlannedTransactionResponse>> createBill(
    PlannedTransactionRequest request,
  ) async {
    return ApiHandler.post<PlannedTransactionResponse>(
      AppConstants.billsBase,
      body: request.toJson(),
      fromJson: (json) => PlannedTransactionResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.8] Cập nhật Bill
  // -----------------------------------------------------------
  // API: PUT /api/bills/{id}
  static Future<ApiResponse<PlannedTransactionResponse>> updateBill(
    int id,
    PlannedTransactionRequest request,
  ) async {
    final url = AppConstants.billById(id);
    return ApiHandler.put<PlannedTransactionResponse>(
      url,
      body: request.toJson(),
      fromJson: (json) => PlannedTransactionResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.9] Xóa Bill
  // -----------------------------------------------------------
  // API: DELETE /api/bills/{id}
  static Future<ApiResponse<void>> deleteBill(int id) async {
    final url = AppConstants.billById(id);
    return ApiHandler.delete<void>(url);
  }

  // -----------------------------------------------------------
  // [1.10] Toggle Bill — đánh dấu hoàn tất/chưa
  // -----------------------------------------------------------
  // API: PATCH /api/bills/{id}/toggle
  static Future<ApiResponse<PlannedTransactionResponse>> toggleBill(int id) async {
    final url = AppConstants.billToggle(id);
    return ApiHandler.patch<PlannedTransactionResponse>(
      url,
      fromJson: (json) => PlannedTransactionResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.11] Trả tiền Bill — tạo Transaction thật
  // -----------------------------------------------------------
  // API: POST /api/bills/{id}/pay
  // Backend: tạo Transaction, cập nhật nextDueDate, lastExecutedAt
  static Future<ApiResponse<PlannedTransactionResponse>> payBill(int id) async {
    final url = AppConstants.billPay(id);
    return ApiHandler.post<PlannedTransactionResponse>(
      url,
      fromJson: (json) => PlannedTransactionResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.12] Lấy danh sách giao dịch của một Bill
  // -----------------------------------------------------------
  // API: GET /api/bills/{id}/transactions
  static Future<ApiResponse<BillTransactionListResponse>> getBillTransactions(int id) async {
    final url = AppConstants.billTransactions(id);
    return ApiHandler.get<BillTransactionListResponse>(
      url,
      fromJson: (json) => BillTransactionListResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.13] Helper nội bộ — Parse List<PlannedTransactionResponse> từ JSON
  // -----------------------------------------------------------
  static List<PlannedTransactionResponse> _parseList(dynamic json) {
    if (json is List) {
      return json
          .map((item) => PlannedTransactionResponse.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return []; // trả rỗng nếu json không phải List
  }
}
