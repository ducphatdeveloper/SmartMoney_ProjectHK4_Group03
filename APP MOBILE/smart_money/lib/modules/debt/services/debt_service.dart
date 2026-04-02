// ===========================================================
// [1] DebtService — Gọi API khoản nợ từ Spring Boot
// ===========================================================
// Trách nhiệm:
//   • Là lớp DUY NHẤT gọi HTTP cho module Debt
//   • Tất cả method là static — gọi trực tiếp không cần instance
//   • Không chứa logic UI, không setState, không BuildContext
//
// Gọi từ:
//   • DebtProvider → gọi tất cả 6 hàm bên dưới
//
// API liên quan:
//   • GET    /api/debts?debtType=false/true    — danh sách theo loại
//   • GET    /api/debts/{id}                  — chi tiết 1 khoản nợ
//   • GET    /api/debts/{id}/transactions     — lịch sử giao dịch
//   • PUT    /api/debts/{id}                  — sửa personName/dueDate/note
//   • PUT    /api/debts/{id}/status           — toggle finished
//   • DELETE /api/debts/{id}                  — xóa khoản nợ
//
// Ghi chú:
//   • POST (tạo mới) KHÔNG có — Debt tự sinh khi tạo transaction "Đi vay/Cho vay"
// ===========================================================

import 'package:smart_money/core/constants/app_constants.dart';
import 'package:smart_money/core/helpers/api_handler.dart';
import 'package:smart_money/core/models/api_response.dart';
import '../models/debt_response.dart';
import '../models/debt_update_request.dart';

// [NOTE] Import TransactionResponse từ module transaction vì
// GET /api/debts/{id}/transactions trả về List<TransactionResponse>
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';

class DebtService {

  // URL gốc lấy từ AppConstants — KHÔNG hardcode
  static String get _base => AppConstants.debtsBase;

  // -----------------------------------------------------------
  // [1.1] getDebts — Lấy danh sách khoản nợ theo loại
  // -----------------------------------------------------------
  // API: GET /api/debts?debtType=false (CẦN TRẢ)
  //            hoặc  ?debtType=true  (CẦN THU)
  // Tham số:
  //   • debtType: false=Cần Trả, true=Cần Thu
  // Trả về: List<DebtResponse> (cả đã xong lẫn chưa xong)
  // [NOTE] Flutter tự chia header CHƯA TRẢ / ĐÃ TRẢ HẾT dựa field finished
  static Future<ApiResponse<List<DebtResponse>>> getDebts(bool debtType) async {
    final url = '$_base?debtType=$debtType';
    return ApiHandler.get<List<DebtResponse>>(
      url,
      fromJson: (json) => (json as List)
          .map((e) => DebtResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // -----------------------------------------------------------
  // [1.2] getDebt — Lấy chi tiết 1 khoản nợ
  // -----------------------------------------------------------
  // API: GET /api/debts/{id}
  // Lỗi server:
  //   • "Khoản nợ không tồn tại hoặc bạn không có quyền truy cập." (403)
  static Future<ApiResponse<DebtResponse>> getDebt(int debtId) async {
    return ApiHandler.get<DebtResponse>(
      '$_base/$debtId',
      fromJson: (json) => DebtResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.3] getDebtTransactions — Lấy lịch sử giao dịch của khoản nợ
  // -----------------------------------------------------------
  // API: GET /api/debts/{id}/transactions
  // Trả về: List<TransactionResponse> — flat list, mới nhất trước
  // Bao gồm: giao dịch gốc (Đi vay/Cho vay) + các lần trả/thu
  static Future<ApiResponse<List<TransactionResponse>>> getDebtTransactions(
      int debtId) async {
    return ApiHandler.get<List<TransactionResponse>>(
      '$_base/$debtId/transactions',
      fromJson: (json) => (json as List)
          .map((e) => TransactionResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // -----------------------------------------------------------
  // [1.4] updateDebt — Sửa personName, dueDate, note
  // -----------------------------------------------------------
  // API: PUT /api/debts/{id}
  // Tham số:
  //   • debtId: ID khoản nợ cần sửa
  //   • request: chỉ chứa personName, dueDate, note
  // Lỗi server:
  //   • "Tên người liên quan không được để trống." (400 — validate)
  //   • "Tên người liên quan không được quá 200 ký tự." (400 — validate)
  //   • "Ghi chú không được quá 500 ký tự." (400 — validate)
  static Future<ApiResponse<DebtResponse>> updateDebt(
      int debtId, DebtUpdateRequest request) async {
    return ApiHandler.put<DebtResponse>(
      '$_base/$debtId',
      body: request.toJson(),
      fromJson: (json) => DebtResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.5] updateDebtStatus — Toggle trạng thái finished
  // -----------------------------------------------------------
  // API: PUT /api/debts/{id}/status
  // Không cần body — backend tự toggle finished: false→true hoặc true→false
  // Dùng cho nút "Đánh dấu hoàn thành" / "Đánh dấu chưa hoàn thành"
  static Future<ApiResponse<DebtResponse>> updateDebtStatus(int debtId) async {
    return ApiHandler.put<DebtResponse>(
      '$_base/$debtId/status',
      fromJson: (json) => DebtResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.6] deleteDebt — Xóa khoản nợ
  // -----------------------------------------------------------
  // API: DELETE /api/debts/{id}
  // [NOTE] Giao dịch liên quan KHÔNG bị xóa — chỉ set debt_id=null
  // Lỗi server:
  //   • "Khoản nợ không tồn tại hoặc bạn không có quyền truy cập." (403)
  static Future<ApiResponse<void>> deleteDebt(int debtId) async {
    return ApiHandler.delete<void>('$_base/$debtId');
  }
}
