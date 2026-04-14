import 'package:flutter/material.dart';
import '../models/wallet_request.dart';
import '../models/wallet_response.dart';
import '../services/wallet_service.dart';

class WalletProvider with ChangeNotifier {
  final WalletService _service = WalletService();

  List<WalletResponse> wallets = [];
  double totalBalance = 0;

  bool isLoading = false;
  String? error;

  // ================= LOAD ALL =================
  Future<void> loadAll() async {
    try {
      isLoading = true;
      notifyListeners();

      final results = await Future.wait([
        _service.getWallets(),
        _service.getTotalBalance(),
      ]);

      wallets = results[0] as List<WalletResponse>;
      totalBalance = results[1] as double;

    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ================= CREATE =================
  Future<bool> createWallet(WalletRequest request) async {
    try {
      await _service.createWallet(request);
      // Reload all data to get the correct total balance from the server
      await loadAll();
      return true;

    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ================= UPDATE =================
  Future<bool> updateWallet(int id, WalletRequest request) async {
    try {
      await _service.updateWallet(id, request);
      await loadAll();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ================= DELETE =================
  Future<void> deleteWallet(int id) async {
    try {
      await _service.deleteWallet(id);
      // Reload all data to get the correct total balance from the server
      await loadAll();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }
}
