import '../../../core/constants/app_constants.dart';
import '../../../core/helpers/api_handler.dart';
import '../../../core/models/api_response.dart';

import '../models/wallet_request.dart';
import '../models/wallet_response.dart';

class WalletService {

  // ================= LIST =================
  Future<List<WalletResponse>> getWallets({String? search}) async {

    String url = AppConstants.walletsBase;

    if (search != null && search.isNotEmpty) {
      url += "?search=${Uri.encodeComponent(search)}";
    }

    final response = await ApiHandler.get<List<WalletResponse>>(
      url,
      fromJson: (data) => (data as List)
          .map((e) => WalletResponse.fromJson(e))
          .toList(),
    );

    if (!response.success) throw Exception(response.message);

    return response.data ?? [];
  }


  // ================= DETAIL =================
  Future<WalletResponse> getWalletDetail(int id) async {

    final response = await ApiHandler.get<WalletResponse>(
      "${AppConstants.walletsBase}/$id",
      fromJson: (data) => WalletResponse.fromJson(data),
    );

    if (!response.success) throw Exception(response.message);
    return response.data!;
  }

  // ================= CREATE =================
  Future<WalletResponse> createWallet(WalletRequest request) async {

    final response = await ApiHandler.post<WalletResponse>(
      AppConstants.walletsBase,
      body: request.toJson(),
      fromJson: (data) => WalletResponse.fromJson(data),
    );

    if (!response.success) throw Exception(response.message);

    return response.data!;
  }

  // ================= UPDATE =================
  Future<void> updateWallet(int id, WalletRequest request) async {

    final response = await ApiHandler.put(
      "${AppConstants.walletsBase}/$id",
      body: request.toJson(),
    );

    if (!response.success) throw Exception(response.message);
  }

  // ================= DELETE =================
  Future<void> deleteWallet(int id) async {

    final response = await ApiHandler.delete(
      "${AppConstants.walletsBase}/$id",
    );

    if (!response.success) throw Exception(response.message);
  }

  // ================= TOTAL =================
  Future<double> getTotalBalance() async {

    final response = await ApiHandler.get<double>(
      "${AppConstants.walletsBase}/total-balance",
      fromJson: (data) => (data['totalBalance'] as num).toDouble(),
    );

    if (!response.success) throw Exception(response.message);
    return response.data!;
  }
}

