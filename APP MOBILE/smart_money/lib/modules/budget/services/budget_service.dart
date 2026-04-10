import 'package:flutter/foundation.dart';
import 'package:smart_money/modules/budget/models/budget_request.dart';
import 'package:smart_money/modules/budget/models/budget_response.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/helpers/api_handler.dart';
import '../../../core/models/api_response.dart';
import '../../transaction/models/view/transaction_response.dart';

class BudgetService {
  static final String base = AppConstants.budgetsBase;

  /// GET /budgets?walletId=...
  Future<ApiResponse<List<BudgetResponse>>> getBudgets({int? walletId}) async {
    final url = walletId != null ? "$base?walletId=$walletId" : base;
    debugPrint("📡 GET Budgets API URL: $url");

    try {
      final response = await ApiHandler.get<List<BudgetResponse>>(
        url,
        fromJson: (data) {
          if (data is List) {
            return data.map((e) => BudgetResponse.fromJson(e)).toList();
          }
          return [];
        },
      );
      return response;
    } catch (e, stack) {
      debugPrint("❌ getBudgets error: $e\n$stack");
      return ApiResponse<List<BudgetResponse>>(
        success: false,
        message: e.toString(),
        data: [],
      );
    }
  }

  /// GET /budgets/expired
  /// Lấy danh sách ngân sách đã hết hạn, có thể lọc theo walletId
  Future<ApiResponse<List<BudgetResponse>>> getExpired({int? walletId}) async {
    try {
      // Build URL, thêm query param walletId nếu có
      final query = walletId != null ? '?walletId=$walletId' : '';
      final url = "$base/expired$query";
      debugPrint("📡 GET Expired Budgets API URL: $url");

      final response = await ApiHandler.get<List<BudgetResponse>>(
        url,
        fromJson: (data) {
          if (data is List) {
            return data.map((e) => BudgetResponse.fromJson(e)).toList();
          }
          debugPrint("⚠️ getExpiredBudgets: data không phải List: $data");
          return [];
        },
      );

      // Log nếu API trả lỗi
      if (!response.success) {
        debugPrint("❌ getExpiredBudgets API failed: ${response.message}");
      } else {
        debugPrint("✅ getExpiredBudgets success, items: ${response.data?.length}");
      }

      return response;
    } catch (e, stack) {
      debugPrint("❌ getExpiredBudgets exception: $e\n$stack");
      return ApiResponse<List<BudgetResponse>>(
        success: false,
        message: e.toString(),
        data: [],
      );
    }
  }



  /// POST /budgets
  Future<ApiResponse<BudgetResponse>> create(BudgetRequest request) async {
    debugPrint("📡 POST Create Budget API URL: $base, body: ${request.toJson()}");

    try {
      final response = await ApiHandler.post(
        base,
        body: request.toJson(),
        fromJson: (json) => BudgetResponse.fromJson(json),
      );
      return response;
    } catch (e, stack) {
      debugPrint("❌ create Budget error: $e\n$stack");
      return ApiResponse<BudgetResponse>(
        success: false,
        message: e.toString(),
        data: null,
      );
    }
  }

  /// PUT /budgets/{id}
  Future<ApiResponse<BudgetResponse>> update(int id, BudgetRequest request) async {
    final url = "$base/$id";
    debugPrint("📡 PUT Update Budget API URL: $url, body: ${request.toJson()}");

    try {
      final response = await ApiHandler.put(
        url,
        body: request.toJson(),
        fromJson: (json) => BudgetResponse.fromJson(json),
      );
      return response;
    } catch (e, stack) {
      debugPrint("❌ update Budget error: $e\n$stack");
      return ApiResponse<BudgetResponse>(
        success: false,
        message: e.toString(),
        data: null,
      );
    }
  }

  /// DELETE /budgets/{id}
  Future<ApiResponse<void>> delete(int id) async {
    final url = "$base/$id";
    debugPrint("📡 DELETE Budget API URL: $url");

    try {
      final response = await ApiHandler.delete(
        url,
        fromJson: (_) {},
      );
      return response;
    } catch (e, stack) {
      debugPrint("❌ delete Budget error: $e\n$stack");
      return ApiResponse<void>(
        success: false,
        message: e.toString(),
      );
    }
  }

  /// GET /budgets/{id}/transactions
  Future<ApiResponse<List<TransactionResponse>>> getBudgetTransactions(int budgetId) async {
    final url = "$base/$budgetId/transactions";
    debugPrint("📡 GET Budget Transactions API URL: $url");

    try {
      final response = await ApiHandler.get<List<TransactionResponse>>(
        url,
        fromJson: (data) {
          if (data is List) {
            return data.map((e) => TransactionResponse.fromJson(e)).toList();
          }
          return [];
        },
      );
      return response;
    } catch (e, stack) {
      debugPrint("❌ getBudgetTransactions error: $e\n$stack");
      return ApiResponse<List<TransactionResponse>>(
        success: false,
        message: e.toString(),
        data: [],
      );
    }
  }
}
