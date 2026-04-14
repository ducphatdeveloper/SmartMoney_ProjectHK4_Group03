import 'package:smart_money/core/helpers/api_handler.dart';
import 'package:smart_money/core/models/api_response.dart';
import 'package:smart_money/core/constants/app_constants.dart';
import '../models/saving_goal_response.dart';
import '../models/saving_goal_request.dart';

class SavingGoalService {
  // URL gốc lấy từ AppConstants: /api/saving-goals
  static String get _base => AppConstants.savingGoalsBase;

  // -----------------------------------------------------------
  // [1.1] Lấy danh sách THEO TRẠNG THÁI (Phục vụ chuyển Tab)
  // Logic:
  //   isFinished = false → Tab Active (ACTIVE, COMPLETED chưa chốt, OVERDUE)
  //   isFinished = true  → Tab Finished (COMPLETED+finished=true, CANCELLED+finished=true)
  // -----------------------------------------------------------
  static Future<ApiResponse<List<SavingGoalResponse>>> getByStatus({
    required bool isFinished,
    String? search,
  }) async {
    // Xây dựng query params — isFinished để backend lọc đúng tab
    String url = '$_base/getAll?isFinished=$isFinished';

    // Thêm từ khóa tìm kiếm nếu có
    if (search != null && search.isNotEmpty) {
      url += '&search=${Uri.encodeComponent(search)}';
    }

    return ApiHandler.get<List<SavingGoalResponse>>(
      url,
      fromJson: (json) => _parseList(json),
    );
  }

  // -----------------------------------------------------------
  // [1.2] Lấy danh sách hợp lệ cho Dropdown chọn nguồn tiền (Transaction)
  // Chỉ lấy: deleted=false AND finished=false
  // Trả về: ACTIVE(1), COMPLETED(2-chưa chốt), OVERDUE(4)
  // Loại bỏ: CANCELLED+finished=true, COMPLETED+finished=true
  // Dùng ở: transaction_create_screen.dart, transaction_edit_screen.dart
  // -----------------------------------------------------------
  static Future<ApiResponse<List<SavingGoalResponse>>> getAvailableForDropdown() async {
    // Truyền finished=false để backend dùng query findAvailableForTransaction
    final String url = '$_base/getAll?isFinished=false';

    return ApiHandler.get<List<SavingGoalResponse>>(
      url,
      fromJson: (json) => _parseList(json),
    );
  }

  // -----------------------------------------------------------
  // [1.3] Tạo mục tiêu mới
  // -----------------------------------------------------------
  static Future<ApiResponse<SavingGoalResponse>> create(SavingGoalRequest request) async {
    final url = '$_base/create';
    return ApiHandler.post<SavingGoalResponse>(
      url,
      body: request.toJson(),
      fromJson: (json) => SavingGoalResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.4] Lấy chi tiết mục tiêu
  // -----------------------------------------------------------
  static Future<ApiResponse<SavingGoalResponse>> getDetail(int id) async {
    final url = '$_base/getDetail/$id';
    return ApiHandler.get<SavingGoalResponse>(
      url,
      fromJson: (json) => SavingGoalResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.5] Cập nhật thông tin mục tiêu (tên, target, ngày, ảnh...)
  // Chỉ cho phép khi mục tiêu đang ACTIVE
  // -----------------------------------------------------------
  static Future<ApiResponse<SavingGoalResponse>> update(int id, SavingGoalRequest request) async {
    final url = '$_base/$id';
    return ApiHandler.put<SavingGoalResponse>(
      url,
      body: request.toJson(),
      fromJson: (json) => SavingGoalResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.6] Xóa mục tiêu (Soft Delete)
  // Record bị ẩn hoàn toàn khỏi mọi query — KHÔNG thể phục hồi
  // Cascade xóa mềm transactions, debts, events liên quan
  // -----------------------------------------------------------
  static Future<ApiResponse<void>> delete(int id) async {
    final url = '$_base/$id';
    return ApiHandler.delete<void>(url);
  }

  // -----------------------------------------------------------
  // [1.7] Nạp tiền vào quỹ tiết kiệm
  // API: POST /api/saving-goals/{id}/deposit?amount=...
  // Chặn nếu: finished=true, CANCELLED, hoặc vượt quá target
  // -----------------------------------------------------------
  static Future<ApiResponse<SavingGoalResponse>> deposit(int id, double amount) async {
    // Truyền amount qua query param vì backend nhận @RequestParam
    final url = '$_base/$id/deposit?amount=$amount';
    return ApiHandler.post<SavingGoalResponse>(
      url,
      fromJson: (json) => SavingGoalResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.8] Rút tiền từ quỹ tiết kiệm (giảm currentAmount)
  // API: POST /api/saving-goals/{id}/withdraw?amount=...
  // Nếu rút xuống dưới 100% → tự về ACTIVE (từ COMPLETED)
  // Chặn nếu: finished=true hoặc CANCELLED
  // -----------------------------------------------------------
  static Future<ApiResponse<SavingGoalResponse>> withdraw(int id, double amount) async {
    // Truyền amount qua query param vì backend nhận @RequestParam
    final url = '$_base/$id/withdraw?amount=$amount';
    return ApiHandler.post<SavingGoalResponse>(
      url,
      fromJson: (json) => SavingGoalResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.9] Chốt sổ mục tiêu — đổ tiền về ví được chọn
  // API: POST /api/saving-goals/{id}/complete?walletId=...
  // Điều kiện: goalStatus = COMPLETED (đủ 100%) VÀ finished=false
  // Sau khi chốt: currentAmount=0, finished=true — KHÔNG thể hoàn tác
  //
  // [walletId] ID ví nhận tiền (null = chỉ đóng goal, không đổ tiền)
  // -----------------------------------------------------------
  static Future<ApiResponse<SavingGoalResponse>> completeSavingGoal(
      int id, {
        int? walletId,
      }) async {
    // Build URL — thêm walletId nếu user có chọn ví
    String url = '$_base/$id/complete';
    if (walletId != null) url += '?walletId=$walletId';

    return ApiHandler.post<SavingGoalResponse>(
      url,
      fromJson: (json) => SavingGoalResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.10] Hủy mục tiêu — đổ tiền còn lại về ví được chọn
  // API: POST /api/saving-goals/{id}/cancel?walletId=...
  // Khác Delete: record vẫn còn DB, chỉ đổi trạng thái CANCELLED+finished=true
  // Sau khi hủy: currentAmount=0, goalStatus=CANCELLED, finished=true — KHÔNG hoàn tác
  //
  // [walletId] ID ví nhận tiền hoàn trả (null = không đổ tiền về đâu)
  // -----------------------------------------------------------
  static Future<ApiResponse<SavingGoalResponse>> cancelSavingGoal(
      int id, {
        int? walletId,
      }) async {
    // Build URL — thêm walletId nếu user có chọn ví
    String url = '$_base/$id/cancel';
    if (walletId != null) url += '?walletId=$walletId';

    return ApiHandler.post<SavingGoalResponse>(
      url,
      fromJson: (json) => SavingGoalResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // HELPER - Phân tích dữ liệu danh sách từ JSON
  // -----------------------------------------------------------
  static List<SavingGoalResponse> _parseList(dynamic json) {
    // Kiểm tra json có phải List không trước khi map
    if (json is List) {
      return json
          .map((item) => SavingGoalResponse.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return []; // Trả rỗng nếu server không trả List
  }
}