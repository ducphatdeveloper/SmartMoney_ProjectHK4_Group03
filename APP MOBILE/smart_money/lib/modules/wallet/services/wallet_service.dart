import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/wallet_response.dart';

class WalletService {

  static const String baseUrl =
      "http://10.0.2.2:8080/api/user/wallets";

  // GET WALLETS
  Future<List<WalletResponse>> getWallets(String token) async {

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
          .map((e) => WalletResponse.fromJson(e))
          .toList();

    } else {
      throw Exception("Failed to load wallets");
    }
  }

  // CREATE WALLET
  Future<WalletResponse> createWallet(
      Map<String, dynamic> walletData,
      String token
      ) async {

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(walletData),
    );

    if (response.statusCode == 200 ||
        response.statusCode == 201) {

      final body = jsonDecode(response.body);

      return WalletResponse.fromJson(body['data']);

    } else {
      throw Exception("Create wallet failed");
    }
  }
}
