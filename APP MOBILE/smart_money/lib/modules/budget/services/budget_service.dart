import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as ApiClient;

import '../../../core/constants/app_constants.dart';
import '../../../core/helpers/api_handler.dart';
import '../../../core/models/api_response.dart';
import '../models/budget_request.dart';
import 'package:smart_money/modules/budget/models/budget_response.dart';

class BudgetService {
  static final String base = AppConstants.budgetsBase;

  /// GET /budgets
  Future<ApiResponse<List<BudgetResponse>>> getBudgets(int? walletId) {
    final url = walletId != null
        ? "$base?walletId=$walletId"
        : base;

    debugPrint("📡 API URL: $url");

    return ApiHandler.get<List<BudgetResponse>>(
      url,
      fromJson: (data) {
        // ✅ data ở đây chính là json["data"]
        if (data is List) {
          return data
              .map((e) => BudgetResponse.fromJson(e))
              .toList();
        }
        return [];
      },
    );
  }

  /// GET /budgets/expired
   Future<ApiResponse<List<BudgetResponse>>> getExpired() async {
    return ApiHandler.get(
      "$base/expired",
      fromJson: (json) => (json as List)
          .map((e) => BudgetResponse.fromJson(e))
          .toList(),
    );
  }

  /// POST /budgets
   Future<ApiResponse<BudgetResponse>> create(
      BudgetRequest request) async {
    return ApiHandler.post(
      base,
      body: request.toJson(),
      fromJson: (json) => BudgetResponse.fromJson(json),
    );
  }

  /// DELETE
   Future<ApiResponse<void>> delete(int id) async {
    return ApiHandler.delete(
      "$base/$id",
      fromJson: (_) {},
    );
  }

  Future<ApiResponse<BudgetResponse>> update(
      int id,
      BudgetRequest request,
      ) {
    return ApiHandler.put(
      "$base/$id",
      body: request.toJson(),
      fromJson: (json) => BudgetResponse.fromJson(json),
    );
  }
}
