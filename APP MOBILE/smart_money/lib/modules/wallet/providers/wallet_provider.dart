import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/wallet_request.dart';
import '../models/wallet_response.dart';
import '../models/transfer_request.dart';
import '../models/wallet_delete_preview_response.dart';
import '../services/wallet_service.dart';
import '../../../core/helpers/token_helper.dart';

class WalletProvider with ChangeNotifier {
  final WalletService _service = WalletService();

  List<WalletResponse> wallets = [];
  double totalBalance = 0;

  bool isLoading = false;
  String? error;

  // ================= LOAD ALL =================
  Future<void> loadAll(BuildContext context) async {
    try {
      isLoading = true;
      error = null; // Reset error khi bắt đầu load
      notifyListeners();

      final results = await Future.wait([
        _service.getWallets(),
        _service.getTotalBalance(),
      ]);

      wallets = results[0] as List<WalletResponse>;
      totalBalance = results[1] as double;

    } catch (e) {
      error = e.toString();
      // Xử lý 401 - Session expired
      if (e.toString().contains("Session expired")) {
        await TokenHelper.clearTokens();
        if (context.mounted) {
          context.go("/login");
        }
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ================= CREATE =================
  Future<bool> createWallet(BuildContext context, WalletRequest request) async {
    try {
      await _service.createWallet(request);
      // Reload all data to get the correct total balance from the server
      await loadAll(context);
      return true;

    } catch (e) {
      error = e.toString();
      // Xử lý 401 - Session expired
      if (e.toString().contains("Session expired")) {
        await TokenHelper.clearTokens();
        if (context.mounted) {
          context.go("/login");
        }
      }
      notifyListeners();
      return false;
    }
  }

  // ================= UPDATE =================
  Future<bool> updateWallet(BuildContext context, int id, WalletRequest request) async {
    try {
      await _service.updateWallet(id, request);
      await loadAll(context);
      return true;
    } catch (e) {
      error = e.toString();
      // Xử lý 401 - Session expired
      if (e.toString().contains("Session expired")) {
        await TokenHelper.clearTokens();
        if (context.mounted) {
          context.go("/login");
        }
      }
      notifyListeners();
      return false;
    }
  }

  // ================= DELETE =================
  Future<void> deleteWallet(BuildContext context, int id) async {
    try {
      await _service.deleteWallet(id);
      // Reload all data to get the correct total balance from the server
      await loadAll(context);
    } catch (e) {
      error = e.toString();
      // Xử lý 401 - Session expired
      if (e.toString().contains("Session expired")) {
        await TokenHelper.clearTokens();
        if (context.mounted) {
          context.go("/login");
        }
      }
      notifyListeners();
    }
  }

  // ================= TRANSFER =================
  Future<bool> transferMoney(BuildContext context, TransferRequest request) async {
    try {
      await _service.transferMoney(request);
      // Reload all data để cập nhật số dư mới
      await loadAll(context);
      return true;
    } catch (e) {
      error = e.toString();
      // Xử lý 401 - Session expired
      if (e.toString().contains("Session expired")) {
        await TokenHelper.clearTokens();
        if (context.mounted) {
          context.go("/login");
        }
      }
      notifyListeners();
      return false;
    }
  }

  // ================= DELETE PREVIEW =================
  Future<WalletDeletePreviewResponse?> getDeletePreview(int walletId) async {
    try {
      return await _service.getDeletePreview(walletId);
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ================= GET DETAIL =================
  Future<WalletResponse?> getWalletDetail(int walletId) async {
    try {
      return await _service.getWalletDetail(walletId);
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }
}
