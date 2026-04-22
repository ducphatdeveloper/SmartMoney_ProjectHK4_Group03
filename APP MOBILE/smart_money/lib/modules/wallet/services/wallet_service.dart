import '../../../core/constants/app_constants.dart';
import '../../../core/helpers/api_handler.dart';

import '../models/wallet_request.dart';
import '../models/wallet_response.dart';
import '../models/total_balance_response.dart';
import '../models/transfer_request.dart';
import '../models/transfer_response.dart';
import '../models/wallet_delete_preview_response.dart';

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

    final response = await ApiHandler.get<TotalBalanceResponse>(
      "${AppConstants.walletsBase}/total-balance",
      fromJson: (data) => TotalBalanceResponse.fromJson(data),
    );

    if (!response.success) throw Exception(response.message);
    return response.data?.totalBalance ?? 0.0;
  }

  // ================= TRANSFER =================
  Future<String> transferMoney(TransferRequest request) async {
    final response = await ApiHandler.post<TransferResponse>(
      "${AppConstants.walletsBase}/transfer",
      body: request.toJson(),
      fromJson: (data) => TransferResponse.fromJson(data),
    );

    if (!response.success) throw Exception(response.message);
    return response.data?.message ?? "Transfer successful";
  }

  // ================= DELETE PREVIEW =================
  Future<WalletDeletePreviewResponse> getDeletePreview(int walletId) async {
    final response = await ApiHandler.get<WalletDeletePreviewResponse>(
      "${AppConstants.walletsBase}/$walletId/delete-preview",
      fromJson: (data) => WalletDeletePreviewResponse.fromJson(data),
    );

    if (!response.success) throw Exception(response.message);
    return response.data!;
  }
}
