import 'package:flutter/material.dart';
import '../models/contact_request_models.dart';
import '../services/contact_service.dart';
import '../../../core/di/setup_dependencies.dart';

class ContactProvider extends ChangeNotifier {
  final ContactService _contactService = getIt<ContactService>();

  List<ContactRequestResponse> _myRequests = [];
  bool _isLoading = false;

  List<ContactRequestResponse> get myRequests => _myRequests;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> fetchMyRequests() async {
    _setLoading(true);
    try {
      final response = await _contactService.getMyRequests();
      if (response.success) {
        _myRequests = response.data ?? [];
      }
    } catch (e) {
      debugPrint("FetchMyRequests Error: $e");
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createRequest(ContactRequestCreateRequest request) async {
    _setLoading(true);
    try {
      final response = await _contactService.createRequest(request);
      if (response.success) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("CreateRequest Error: $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
