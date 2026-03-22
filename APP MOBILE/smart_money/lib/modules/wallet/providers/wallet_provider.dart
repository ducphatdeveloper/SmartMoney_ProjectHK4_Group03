import 'package:flutter/material.dart';
import '../models/wallet_response.dart';
import '../services/wallet_service.dart';

class WalletProvider extends ChangeNotifier {

  final WalletService _service = WalletService();

  List<WalletResponse> _wallets = [];

  List<WalletResponse> get wallets => _wallets;

  bool isLoading = false;

  // LOAD WALLETS FROM API
  Future<void> fetchWallets(String token) async {

    isLoading = true;
    notifyListeners();

    try {

      _wallets = await _service.getWallets(token);

    } catch (e) {

      debugPrint(e.toString());

    }

    isLoading = false;
    notifyListeners();
  }

  // CREATE WALLET
  Future<void> addWallet(
      Map<String, dynamic> walletData,
      String token
      ) async {

    try {

      final newWallet =
      await _service.createWallet(walletData, token);

      _wallets.add(newWallet);

      notifyListeners();

    } catch (e) {

      debugPrint(e.toString());

    }

  }

}
