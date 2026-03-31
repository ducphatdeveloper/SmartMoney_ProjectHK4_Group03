import 'package:smart_money/core/helpers/api_handler.dart';

import 'package:smart_money/core/models/api_response.dart';

import 'package:smart_money/core/constants/app_constants.dart';

import '../models/saving_goal_response.dart';

import '../models/saving_goal_request.dart';



class SavingGoalService {

// Lấy gốc là http://192.168.1.101:9999/api/saving-goals

  static String get _base => AppConstants.savingGoalsBase;




// -----------------------------------------------------------

// [1.1] Lấy danh sách (GET .../api/saving-goals/getAll)

// -----------------------------------------------------------

  static Future<ApiResponse<List<SavingGoalResponse>>> getAll({String? search}) async {

// Backend của bạn dùng /getAll

    String url = '$_base/getAll';

    if (search != null && search.isNotEmpty) {

      url += '?search=${Uri.encodeComponent(search)}';

    }



    return ApiHandler.get<List<SavingGoalResponse>>(

      url,

      fromJson: (json) => _parseList(json),

    );

  }



// -----------------------------------------------------------

// [1.2] Tạo mục tiêu mới (POST .../api/saving-goals/create)

// -----------------------------------------------------------

  static Future<ApiResponse<SavingGoalResponse>> create(SavingGoalRequest request) async {

// Quan trọng: Backend của bạn định nghĩa là /create

    final url = '$_base/create';



    return ApiHandler.post<SavingGoalResponse>(

      url,

      body: request.toJson(),

      fromJson: (json) => SavingGoalResponse.fromJson(json as Map<String, dynamic>),

    );

  }



// -----------------------------------------------------------

// [1.3] Lấy chi tiết (GET .../api/saving-goals/getDetail/{id})

// -----------------------------------------------------------

  static Future<ApiResponse<SavingGoalResponse>> getDetail(int id) async {

    final url = '$_base/getDetail/$id';



    return ApiHandler.get<SavingGoalResponse>(

      url,

      fromJson: (json) => SavingGoalResponse.fromJson(json as Map<String, dynamic>),

    );

  }



// -----------------------------------------------------------

// [1.4] Cập nhật (PUT .../api/saving-goals/{id})

// -----------------------------------------------------------

  static Future<ApiResponse<SavingGoalResponse>> update(int id, SavingGoalRequest request) async {

    final url = '$_base/$id'; // Khớp với @PutMapping("/{id}")

    // print("🔗 URL UPDATE: $url");
    // print("📦 DỮ LIỆU GỬI ĐI: ${request.toJson()}");

    return ApiHandler.put<SavingGoalResponse>(

      url,

      body: request.toJson(),

      fromJson: (json) => SavingGoalResponse.fromJson(json as Map<String, dynamic>),

    );
    

  }



// -----------------------------------------------------------

// [1.5] Xóa (DELETE .../api/saving-goals/{id})

// -----------------------------------------------------------

  static Future<ApiResponse<void>> delete(int id) async {

    final url = '$_base/$id'; // Khớp với @DeleteMapping("/{id}")

    return ApiHandler.delete<void>(url);

  }



// -----------------------------------------------------------

// [1.6] Nạp tiền (POST .../api/saving-goals/{id}/deposit?amount=xxx)

// -----------------------------------------------------------

  static Future<ApiResponse<SavingGoalResponse>> deposit(int id, double amount) async {

    final url = '$_base/$id/deposit?amount=$amount';



    return ApiHandler.post<SavingGoalResponse>(

      url,

      fromJson: (json) => SavingGoalResponse.fromJson(json as Map<String, dynamic>),

    );

  }



// Helper parse list

  static List<SavingGoalResponse> _parseList(dynamic json) {
    if (json is List) {
      return json

          .map((item) =>
          SavingGoalResponse.fromJson(item as Map<String, dynamic>))

          .toList();
    }

    return [];
  }
}