// modules/transaction/services/util_service.dart
// Service gọi API utils từ backend (date ranges, v.v.)

import 'package:smart_money/core/helpers/api_handler.dart';
import 'package:smart_money/core/models/api_response.dart';
import 'package:smart_money/core/models/date_range_dto.dart';
import 'package:smart_money/core/constants/app_constants.dart';
import 'package:smart_money/modules/wallet/models/wallet_response.dart';
import 'package:smart_money/modules/saving_goal/models/saving_goal_response.dart';

class UtilService {
  // Sử dụng baseUrl từ AppConstants thay vì hardcoded localhost
  // AppConstants đã tự chọn đúng URL cho từng platform
  static String get _baseUrl => AppConstants.baseUrl;

  // ===== 1. GET DATE RANGES =====
  /// Lấy danh sách khoảng thời gian cho thanh trượt
  /// mode: DAILY, WEEKLY, MONTHLY, QUARTERLY, YEARLY
  /// past: số đơn vị quá khứ (mặc định 24)
  /// future: 1 = có tab "Tương lai", 0 = không có (mặc định 1)
  static Future<ApiResponse<List<DateRangeDTO>>> getDateRanges({
    String mode = 'MONTHLY',
    int past = 24,
    int future = 1,
  }) async {
    final params = <String, dynamic>{
      'mode': mode,
      'past': past,
      'future': future,
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    final url = '$_baseUrl/utils/date-ranges?$queryString';

    return ApiHandler.get<List<DateRangeDTO>>(
      url,
      fromJson: (json) {
        if (json is List) {
          return json
              .map((e) => DateRangeDTO.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      },
    );
  }

  // ===== 2. GET ALL WALLETS =====
  static Future<ApiResponse<List<WalletResponse>>> getAllWallets() async {
    return ApiHandler.get<List<WalletResponse>>(
      '$_baseUrl/user/wallets',
      fromJson: (json) {
        print('📡 [UtilService.getAllWallets] Received JSON: $json');
        if (json is List) {
          print('📡 [UtilService.getAllWallets] Parsing ${json.length} items...');
          try {
            final result = json
                .map((e) {
                  print('   - Parsing wallet: ${(e as Map<String, dynamic>)['walletName']}');
                  return WalletResponse.fromJson(e as Map<String, dynamic>);
                })
                .toList();
            print('✅ [UtilService.getAllWallets] Successfully parsed ${result.length} wallets');
            return result;
          } catch (e) {
            print('❌ [UtilService.getAllWallets] Parse error: $e');
            return [];
          }
        }
        print('❌ [UtilService.getAllWallets] JSON is not a List, got: ${json.runtimeType}');
        return [];
      },
    );
  }

// ===== 3. GET SAVING GOALS CHO DROPDOWN TRANSACTION =====
  // Chỉ lấy goal hợp lệ để hiển thị trong Dropdown chọn nguồn tiền:
  //   • deleted=false AND finished=false
  //   • Trạng thái hợp lệ: ACTIVE(1), COMPLETED(2-chưa chốt), OVERDUE(4)
  //   • Loại bỏ: CANCELLED+finished=true, COMPLETED+finished=true
  //
  // [forDropdown] true → chỉ lấy goal chưa chốt sổ (dùng cho Transaction dropdown)
  //               false → lấy tất cả goal chưa xóa (dùng cho màn hình danh sách)
  static Future<ApiResponse<List<SavingGoalResponse>>> getAllSavingGoals({
    bool forDropdown = false,
  }) async {
    // Nếu forDropdown=true → thêm param finished=false để backend lọc đúng
    // Backend sẽ dùng query findAvailableForTransaction thay vì findByAccount_Id
    final String url = forDropdown
        ? '$_baseUrl/saving-goals/getAll?isFinished=false'
        : '$_baseUrl/saving-goals/getAll';

    return ApiHandler.get<List<SavingGoalResponse>>(
      url,
      fromJson: (json) {
        print('📡 [UtilService.getAllSavingGoals] Received JSON: $json');

        if (json is List) {
          print('📡 [UtilService.getAllSavingGoals] Parsing ${json.length} items...');
          try {
            final result = json.map((e) {
              print('   - Parsing goal: ${(e as Map<String, dynamic>)['goalName']}');
              return SavingGoalResponse.fromJson(e as Map<String, dynamic>);
            }).toList();

            print('✅ [UtilService.getAllSavingGoals] Successfully parsed ${result.length} goals');
            return result;
          } catch (e) {
            print('❌ [UtilService.getAllSavingGoals] Parse error: $e');
            return [];
          }
        }

        print('❌ [UtilService.getAllSavingGoals] JSON is not a List, got: ${json.runtimeType}');
        return [];
      },
    );
  }

  // ===== 4. GET TOTAL BALANCE (all wallets + saving goals) =====
  static Future<ApiResponse<double>> getTotalBalance() async {
    return ApiHandler.get<double>(
      '$_baseUrl/user/wallets/total-balance',
      fromJson: (json) {
        print('📡 [UtilService.getTotalBalance] Received JSON: $json');
        // json đã là {totalBalance: 35400000.00}
        if (json is Map<String, dynamic>) {
          try {
            final totalBalance = (json['totalBalance'] as num).toDouble();
            print('✅ [UtilService.getTotalBalance] Parsed totalBalance: $totalBalance');
            return totalBalance;
          } catch (e) {
            print('❌ [UtilService.getTotalBalance] Parse error: $e');
            return 0.0;
          }
        }
        print('❌ [UtilService.getTotalBalance] JSON is not a Map, got: ${json.runtimeType}');
        return 0.0;
      },
    );
  }
}

