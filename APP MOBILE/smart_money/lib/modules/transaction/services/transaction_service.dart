// ===========================================================
// [1] TransactionService — Gọi API giao dịch từ Spring Boot
// ===========================================================
// Trách nhiệm:
//   • Là lớp DUY NHẤT gọi HTTP cho module Transaction
//   • Tất cả method là static — gọi trực tiếp không cần instance
//   • Không chứa logic UI, không setState, không BuildContext
//
// Gọi từ:
//   • TransactionProvider → gọi tất cả hàm bên dưới
//
// API liên quan:
//   • GET    /api/transactions/journal           — xem nhật ký (gom theo ngày)
//   • GET    /api/transactions/grouped           — xem theo nhóm (gom theo danh mục)
//   • GET    /api/transactions/report/summary    — báo cáo tóm tắt
//   • GET    /api/transactions/{id}              — xem chi tiết 1 giao dịch
//   • POST   /api/transactions                   — tạo giao dịch mới
//   • POST   /api/transactions/search            — tìm kiếm nâng cao
//   • PUT    /api/transactions/{id}              — cập nhật giao dịch
//   • DELETE /api/transactions/{id}              — xóa giao dịch
// ===========================================================

import 'package:smart_money/core/helpers/api_handler.dart';
import 'package:smart_money/core/models/api_response.dart';
import 'package:smart_money/core/constants/app_constants.dart';
import 'package:smart_money/modules/transaction/models/merge/transaction_list_response.dart';
import 'package:smart_money/modules/transaction/models/view/daily_transaction_group.dart';
import 'package:smart_money/modules/transaction/models/view/category_transaction_group.dart';
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';
import 'package:smart_money/modules/transaction/models/request/transaction_request.dart';
import 'package:smart_money/modules/transaction/models/request/transaction_search_request.dart';
import 'package:smart_money/modules/transaction/models/report/transaction_report_response.dart';
import 'package:smart_money/modules/transaction/models/report/category_report_dto.dart';
import 'package:smart_money/modules/transaction/models/report/daily_trend_dto.dart';

class TransactionService {
  // URL gốc lấy từ AppConstants — KHÔNG hardcode
  static String get _base => AppConstants.transactionsBase;

  // -----------------------------------------------------------
  // [1.1] JOURNAL — Lấy danh sách gom theo ngày (chế độ Nhật ký)
  // -----------------------------------------------------------
  // Gọi khi: Mở màn hình / đổi khoảng thời gian / đổi ví
  // API: GET /api/transactions/journal?range=CUSTOM&startDate=...&endDate=...
  // Tham số:
  //   • startDate / endDate: khoảng thời gian cần lấy
  //   • walletId: lọc theo ví (null = tất cả)
  //   • savingGoalId: lọc theo mục tiêu tiết kiệm (null = tất cả)
  // Trả về: List<DailyTransactionGroup> — đã gom theo ngày, có netAmount
  static Future<ApiResponse<List<DailyTransactionGroup>>> getJournalTransactions({
    required DateTime startDate,
    required DateTime endDate,
    int? walletId,
    int? savingGoalId,
  }) async {
    // Bước 1: Build query params
    final params = _buildDateParams(startDate, endDate, walletId, savingGoalId);
    final url = '$_base/journal?$params';

    // Bước 2: Gọi API và parse kết quả
    return ApiHandler.get<List<DailyTransactionGroup>>(
      url,
      fromJson: (json) => _parseDailyGroupList(json),
    );
  }

  // -----------------------------------------------------------
  // [1.2] GROUPED — Lấy danh sách gom theo danh mục (chế độ Nhóm)
  // -----------------------------------------------------------
  // Gọi khi: User chọn "Xem theo nhóm" từ menu 3 chấm
  // API: GET /api/transactions/grouped?range=CUSTOM&startDate=...&endDate=...
  // Trả về: List<CategoryTransactionGroup> — gom theo category, có totalAmount
  static Future<ApiResponse<List<CategoryTransactionGroup>>> getGroupedTransactions({
    required DateTime startDate,
    required DateTime endDate,
    int? walletId,
    int? savingGoalId,
  }) async {
    final params = _buildDateParams(startDate, endDate, walletId, savingGoalId);
    final url = '$_base/grouped?$params';

    return ApiHandler.get<List<CategoryTransactionGroup>>(
      url,
      fromJson: (json) => _parseCategoryGroupList(json),
    );
  }

  // -----------------------------------------------------------
  // [1.3] REPORT SUMMARY — Lấy báo cáo tóm tắt thu/chi
  // -----------------------------------------------------------
  // Gọi khi: User bấm "Xem báo cáo cho giai đoạn này"
  // API: GET /api/transactions/report/summary
  // Trả về: TransactionReportResponse (totalIncome, totalExpense, balance...)
  static Future<ApiResponse<TransactionReportResponse>> getReport({
    required DateTime startDate,
    required DateTime endDate,
    int? walletId,
    int? savingGoalId,
  }) async {
    final params = _buildDateParams(startDate, endDate, walletId, savingGoalId);
    final url = '$_base/report/summary?$params';

    return ApiHandler.get<TransactionReportResponse>(
      url,
      fromJson: (json) => TransactionReportResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.3b] REPORT CATEGORY — Lấy báo cáo chi tiết theo danh mục (biểu đồ tròn)
  // -----------------------------------------------------------
  // Gọi khi: Mở TransactionReportScreen
  // API: GET /api/transactions/report/category
  // Trả về: List<CategoryReportDTO> (tên, tổng, %, trung bình ngày, icon)
  static Future<ApiResponse<List<CategoryReportDTO>>> getCategoryReport({
    required DateTime startDate,
    required DateTime endDate,
    int? walletId,
    int? savingGoalId,
  }) async {
    final params = _buildDateParams(startDate, endDate, walletId, savingGoalId);
    final url = '$_base/report/category?$params';

    return ApiHandler.get<List<CategoryReportDTO>>(
      url,
      fromJson: (json) {
        if (json is List) {
          return json
              .map((e) => CategoryReportDTO.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      },
    );
  }

  // -----------------------------------------------------------
  // [1.3c] REPORT TREND — Lấy xu hướng thu/chi theo ngày (biểu đồ cột)
  // -----------------------------------------------------------
  // Gọi khi: Mở TransactionReportScreen
  // API: GET /api/transactions/report/trend
  // Trả về: List<DailyTrendDTO> (date, totalIncome, totalExpense)
  static Future<ApiResponse<List<DailyTrendDTO>>> getDailyTrend({
    required DateTime startDate,
    required DateTime endDate,
    int? walletId,
    int? savingGoalId,
  }) async {
    final params = _buildDateParams(startDate, endDate, walletId, savingGoalId);
    final url = '$_base/report/trend?$params';

    return ApiHandler.get<List<DailyTrendDTO>>(
      url,
      fromJson: (json) {
        if (json is List) {
          return json
              .map((e) => DailyTrendDTO.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      },
    );
  }

  // -----------------------------------------------------------
  // [1.4] GET BY ID — Lấy chi tiết 1 giao dịch
  // -----------------------------------------------------------
  // Gọi khi: User bấm vào 1 giao dịch trong danh sách
  // API: GET /api/transactions/{id}
  // Trả về: TransactionResponse
  static Future<ApiResponse<TransactionResponse>> getById(int id) async {
    return ApiHandler.get<TransactionResponse>(
      '$_base/$id',
      fromJson: (json) => TransactionResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.5] CREATE — Tạo giao dịch mới
  // -----------------------------------------------------------
  // Gọi khi: User bấm "Lưu" ở TransactionCreateScreen
  // API: POST /api/transactions
  // Body: TransactionRequest (amount, categoryId, walletId/goalId, note, transDate...)
  // Trả về: TransactionResponse (giao dịch vừa tạo)
  // Lỗi server có thể trả:
  //   • "Số tiền phải lớn hơn 0" (400 — validate amount)
  //   • "Không tìm thấy ví" (400 — walletId không tồn tại)
  //   • "Không tìm thấy danh mục" (400 — categoryId không tồn tại)
  //   • "Dữ liệu không hợp lệ" (400 — @Valid fail, data là Map field errors)
  static Future<ApiResponse<TransactionResponse>> create(TransactionRequest request) async {
    return ApiHandler.post<TransactionResponse>(
      _base, // POST /api/transactions
      body: request.toJson(),
      fromJson: (json) => TransactionResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.6] UPDATE — Cập nhật giao dịch
  // -----------------------------------------------------------
  // Gọi khi: User bấm "Lưu" ở TransactionEditScreen
  // API: PUT /api/transactions/{id}
  // Lỗi server:
  //   • "Bạn không có quyền sửa giao dịch này." (403)
  //   • "Giao dịch không tồn tại." (400)
  static Future<ApiResponse<TransactionResponse>> update(int id, TransactionRequest request) async {
    return ApiHandler.put<TransactionResponse>(
      '$_base/$id', // PUT /api/transactions/23
      body: request.toJson(),
      fromJson: (json) => TransactionResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.7] DELETE — Xóa giao dịch (soft delete)
  // -----------------------------------------------------------
  // Gọi khi: User xác nhận xóa ở dialog
  // API: DELETE /api/transactions/{id}
  // Lỗi server:
  //   • "Bạn không có quyền xóa giao dịch này." (403)
  //   • "Giao dịch không tồn tại." (400)
  static Future<ApiResponse<void>> delete(int id) async {
    return ApiHandler.delete<void>(
      '$_base/$id', // DELETE /api/transactions/23
    );
  }

  // -----------------------------------------------------------
  // [1.8] SEARCH — Tìm kiếm giao dịch nâng cao
  // -----------------------------------------------------------
  // Gọi khi: User bấm "Tìm" ở màn hình tìm kiếm
  // API: POST /api/transactions/search
  // Body: TransactionSearchRequest (minAmount, maxAmount, walletId, categoryIds...)
  // Trả về: List<TransactionResponse>
  static Future<ApiResponse<List<TransactionResponse>>> search(TransactionSearchRequest request) async {
    return ApiHandler.post<List<TransactionResponse>>(
      '$_base/search',
      body: request.toJson(),
      fromJson: (json) => _parseTransactionList(json),
    );
  }

  // -----------------------------------------------------------
  // [1.8b] LIST — Danh sách giao dịch dùng chung với filter động
  // -----------------------------------------------------------
  // API: GET /api/transactions/list?categoryIds=21,22&eventId=7&debtId=9&plannedId=39...
  // Dùng cho: Event, Debt, Planned Bill, Category — tất cả module dùng chung
  // Trả về: TransactionListResponse (totalIncome, totalExpense, netAmount, transactionCount, dailyGroups)
  static Future<ApiResponse<TransactionListResponse>> getTransactionList({
    Map<String, dynamic> filters = const {},
  }) async {
    final params = <String>[];

    filters.forEach((key, value) {
      if (value != null) {
        params.add('$key=${Uri.encodeComponent(value.toString())}');
      }
    });

    final queryString = params.isNotEmpty ? '?${params.join('&')}' : '';
    final url = '$_base/list$queryString';

    return ApiHandler.get<TransactionListResponse>(
      url,
      fromJson: (json) => TransactionListResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.9] Helper — Build query params cho date range
  // -----------------------------------------------------------
  static String _buildDateParams(
    DateTime startDate,
    DateTime endDate,
    int? walletId,
    int? savingGoalId,
  ) {
    final params = <String, dynamic>{
      'range': 'CUSTOM',
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };

    // Thêm walletId nếu đang lọc theo ví
    if (walletId != null) params['walletId'] = walletId;
    // Thêm savingGoalId nếu đang lọc theo mục tiêu tiết kiệm
    if (savingGoalId != null) params['savingGoalId'] = savingGoalId;

    return params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
  }

  // -----------------------------------------------------------
  // [1.10] Helper — Parse List<DailyTransactionGroup> từ JSON
  // -----------------------------------------------------------
  static List<DailyTransactionGroup> _parseDailyGroupList(dynamic json) {
    if (json is List) {
      return json
          .map((e) => DailyTransactionGroup.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return []; // trả rỗng nếu server không trả List
  }

  // -----------------------------------------------------------
  // [1.11] Helper — Parse List<CategoryTransactionGroup> từ JSON
  // -----------------------------------------------------------
  static List<CategoryTransactionGroup> _parseCategoryGroupList(dynamic json) {
    if (json is List) {
      return json
          .map((e) => CategoryTransactionGroup.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  // -----------------------------------------------------------
  // [1.12] Helper — Parse List<TransactionResponse> từ JSON
  // -----------------------------------------------------------
  static List<TransactionResponse> _parseTransactionList(dynamic json) {
    if (json is List) {
      return json
          .map((e) => TransactionResponse.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
