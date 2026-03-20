import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/wallet_model.dart';

class WalletService {

  static const String baseUrl =
      "http://10.0.2.2:8080/api/user/wallets";

  // GET WALLETS
  Future<List<WalletModel>> getWallets(String token) async {

    final response = await http.get(
      Uri.parse(baseUrl),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
    );

    if (response.statusCode == 200) {

      final body = jsonDecode(response.body);

      List data = body['data'];

      return data
          .map((e) => WalletModel.fromJson(e))
          .toList();

    } else {
      throw Exception("Failed to load wallets");
    }
  }

  // CREATE WALLET
  Future<WalletModel> createWallet(
      WalletModel wallet,
      String token
      ) async {

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(wallet.toJson()),
    );

    if (response.statusCode == 200 ||
        response.statusCode == 201) {

      final body = jsonDecode(response.body);

      return WalletModel.fromJson(body['data']);

    } else {
      throw Exception("Create wallet failed");
    }
  }
}
