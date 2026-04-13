import 'package:smart_money/core/helpers/api_handler.dart';
import 'package:smart_money/core/models/api_response.dart';
import 'package:smart_money/core/constants/app_constants.dart';
import '../models/saving_goal_response.dart';
import '../models/saving_goal_request.dart';

class SavingGoalService {
  // Lấy gốc từ AppConstants: /api/saving-goals
  static String get _base => AppConstants.savingGoalsBase;

  // -----------------------------------------------------------
  // [1.1] Lấy danh sách THEO TRẠNG THÁI (Phục vụ chuyển Tab)
  // Logic tương tự EventService:
  // isFinished = false -> Tab Active
  // isFinished = true  -> Tab Finished
  // -----------------------------------------------------------
  static Future<ApiResponse<List<SavingGoalResponse>>> getByStatus({
    required bool isFinished,
    String? search,
  }) async {
    // Xây dựng query params
    String url = '$_base/getAll?isFinished=$isFinished';

    if (search != null && search.isNotEmpty) {
      url += '&search=${Uri.encodeComponent(search)}';
    }

    return ApiHandler.get<List<SavingGoalResponse>>(
      url,
      fromJson: (json) => _parseList(json),
    );
  }

  // -----------------------------------------------------------
  // [1.2] Tạo mục tiêu mới
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
  // [1.3] Lấy chi tiết mục tiêu
  // -----------------------------------------------------------
  static Future<ApiResponse<SavingGoalResponse>> getDetail(int id) async {
    final url = '$_base/getDetail/$id';
    return ApiHandler.get<SavingGoalResponse>(
      url,
      fromJson: (json) => SavingGoalResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.4] Cập nhật mục tiêu
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
  // [1.5] Xóa mục tiêu
  // -----------------------------------------------------------
  static Future<ApiResponse<void>> delete(int id) async {
    final url = '$_base/$id';
    return ApiHandler.delete<void>(url);
  }

  // -----------------------------------------------------------
  // [1.6] Nạp tiền vào quỹ tiết kiệm
  // -----------------------------------------------------------
  static Future<ApiResponse<SavingGoalResponse>> deposit(int id, double amount) async {
    // API: POST /api/saving-goals/{id}/deposit?amount=...
    final url = '$_base/$id/deposit?amount=$amount';
    return ApiHandler.post<SavingGoalResponse>(
      url,
      fromJson: (json) => SavingGoalResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.7] Đổi trạng thái (Mấu chốt để di chuyển item giữa 2 tab)
  // Khi gọi hàm này, item sẽ nhảy từ tab "Đang thực hiện" sang "Hoàn thành" và ngược lại
  // -----------------------------------------------------------
  static Future<ApiResponse<SavingGoalResponse>> toggleStatus(int id) async {
    // PATCH /api/saving-goals/{id}/toggle-pause
    // ACTIVE → CANCELLED (tạm dừng) | CANCELLED/OVERDUE → ACTIVE (kích hoạt lại)
    final url = '$_base/$id/toggle-pause';
    return ApiHandler.patch<SavingGoalResponse>(
      url,
      fromJson: (json) => SavingGoalResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // HELPER - Phân tích dữ liệu danh sách
  // -----------------------------------------------------------
  static List<SavingGoalResponse> _parseList(dynamic json) {
    if (json is List) {
      return json
          .map((item) => SavingGoalResponse.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}