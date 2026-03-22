/// [2.3] Service gọi API Transaction từ backend.
/// 
/// Trách nhiệm:
///   • Fetch danh sách giao dịch theo nhật ký (journal view) — grouped by date
///   • Fetch danh sách giao dịch theo nhóm (grouped view) — grouped by category
///   • Fetch báo cáo giao dịch (report) — tổng hợp theo category/wallet/period
/// 
/// Hai view mode chính:
///   1. Journal: Group by date (DailyTransactionGroup) — hiện netAmount per day
///   2. Grouped: Group by category (CategoryTransactionGroup) — hiện totalAmount per category
///
/// API Endpoints:
///   • GET /api/transactions/journal → DailyTransactionGroup[]
///   • GET /api/transactions/grouped → CategoryTransactionGroup[]
///   • GET /api/transactions/report → TransactionReportResponse (không dùng trong v1)

import 'package:smart_money/core/helpers/api_handler.dart';
import 'package:smart_money/core/models/api_response.dart';
import 'package:smart_money/core/constants/app_constants.dart';
import 'package:smart_money/modules/transaction/models/view/daily_transaction_group.dart';
import 'package:smart_money/modules/transaction/models/view/category_transaction_group.dart';
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';
import 'package:smart_money/modules/transaction/models/report/transaction_report_response.dart';

class TransactionService {
  // Sử dụng baseUrl từ AppConstants thay vì hardcoded localhost
  static String get _baseUrl => AppConstants.baseUrl;

  // ===== 1. JOURNAL - Gom nhóm theo ngày =====
  static Future<ApiResponse<List<DailyTransactionGroup>>> getJournalTransactions({
    required DateTime startDate,
    required DateTime endDate,
    int? walletId,
    int? savingGoalId,
  }) async {
    final params = <String, dynamic>{
      'range': 'CUSTOM',
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };

    if (walletId != null) {
      params['walletId'] = walletId;
    }
    if (savingGoalId != null) {
      params['savingGoalId'] = savingGoalId;
    }

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    final url = '$_baseUrl/transactions/journal?$queryString';

    return ApiHandler.get<List<DailyTransactionGroup>>(
      url,
      fromJson: (json) {
        if (json is List) {
          return json
              .map((e) => DailyTransactionGroup.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      },
    );
  }

  // ===== 2. GROUPED - Gom nhóm theo danh mục =====
  static Future<ApiResponse<List<CategoryTransactionGroup>>> getGroupedTransactions({
    required DateTime startDate,
    required DateTime endDate,
    int? walletId,
    int? savingGoalId,
  }) async {
    final params = <String, dynamic>{
      'range': 'CUSTOM',
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };

    if (walletId != null) {
      params['walletId'] = walletId;
    }
    if (savingGoalId != null) {
      params['savingGoalId'] = savingGoalId;
    }

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    final url = '$_baseUrl/transactions/grouped?$queryString';

    return ApiHandler.get<List<CategoryTransactionGroup>>(
      url,
      fromJson: (json) {
        if (json is List) {
          return json
              .map((e) => CategoryTransactionGroup.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      },
    );
  }

  // ===== 3. REPORT - Lấy báo cáo tóm tắt =====
  static Future<ApiResponse<TransactionReportResponse>> getTransactionReport({
    required DateTime startDate,
    required DateTime endDate,
    int? walletId,
    int? savingGoalId,
  }) async {
    final params = <String, dynamic>{
      'range': 'CUSTOM',
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };

    if (walletId != null) {
      params['walletId'] = walletId;
    }
    if (savingGoalId != null) {
      params['savingGoalId'] = savingGoalId;
    }

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    final url = '$_baseUrl/transactions/report/summary?$queryString';

    return ApiHandler.get<TransactionReportResponse>(
      url,
      fromJson: (json) => TransactionReportResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // ===== 4. GET SINGLE TRANSACTION =====
  static Future<ApiResponse<TransactionResponse>> getTransactionById(int id) async {
    return ApiHandler.get<TransactionResponse>(
      '$_baseUrl/transactions/$id',
      fromJson: (json) => TransactionResponse.fromJson(json as Map<String, dynamic>),
    );
  }
}

