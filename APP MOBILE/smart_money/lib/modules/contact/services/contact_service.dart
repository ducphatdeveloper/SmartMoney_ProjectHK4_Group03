import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../../core/helpers/token_helper.dart';
import '../../../core/models/api_response.dart';
import '../models/contact_request_models.dart';

class ContactService {
  Future<Map<String, String>> _getHeaders() async {
    final token = await TokenHelper.getAccessToken();
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  Future<ApiResponse<ContactRequestResponse>> createRequest(ContactRequestCreateRequest request) async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.contactRequestsBase),
        headers: await _getHeaders(),
        body: jsonEncode(request.toJson()),
      );
      return ApiResponse<ContactRequestResponse>.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)),
        (data) => ContactRequestResponse.fromJson(data),
      );
    } catch (e) {
      return ApiResponse<ContactRequestResponse>(success: false, message: "Error submitting request.");
    }
  }

  Future<ApiResponse<List<ContactRequestResponse>>> getMyRequests() async {
    try {
      final response = await http.get(
        Uri.parse(AppConstants.myContactRequests),
        headers: await _getHeaders(),
      );
      return ApiResponse<List<ContactRequestResponse>>.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)),
        (data) => (data as List).map((i) => ContactRequestResponse.fromJson(i)).toList(),
      );
    } catch (e) {
      return ApiResponse<List<ContactRequestResponse>>(success: false, message: "Error fetching request history.");
    }
  }
}
