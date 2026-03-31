import 'package:flutter/foundation.dart';
import '../models/event_response.dart';
import '../models/event_create_request.dart';
import '../models/event_update_request.dart';
import '../services/event_service.dart';

class EventProvider extends ChangeNotifier {

  // =============================================
  // STATE
  // =============================================
  List<EventResponse> _events = [];
  List<EventResponse> get events => _events;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // active = false | finished = true
  bool _currentFilter = false;
  bool get currentFilter => _currentFilter;

  final Map<bool, List<EventResponse>> _cache = {};

  // =============================================
  // LOAD EVENTS
  // =============================================
  Future<void> loadEvents(bool isFinished, {bool forceRefresh = false}) async {

    _currentFilter = isFinished;

    if (!forceRefresh && _cache.containsKey(isFinished)) {
      _events = _cache[isFinished]!;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await EventService.getEvents(isFinished);

    if (res.success && res.data != null) {
      _events = res.data!;
      _cache[isFinished] = res.data!;
    } else {
      _events = [];
      _errorMessage = res.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  // =============================================
  // CREATE
  // =============================================
  Future<bool> create(EventCreateRequest request) async {
    final res = await EventService.create(request);

    if (res.success) {
      await loadEvents(false, forceRefresh: true);
      return true;
    }
    return false;
  }

  // =============================================
  // UPDATE
  // =============================================
  Future<bool> update(int id, EventUpdateRequest request) async {
    final res = await EventService.update(id, request);

    if (res.success) {
      await loadEvents(_currentFilter, forceRefresh: true);
      return true;
    }
    return false;
  }

  // =============================================
  // DELETE
  // =============================================
  Future<void> delete(int id) async {
    await EventService.delete(id);
    await loadEvents(_currentFilter, forceRefresh: true);
  }

  // =============================================
  // TOGGLE STATUS
  // =============================================
  Future<void> toggleStatus(int id) async {
    await EventService.toggleStatus(id);

    _cache.clear(); // clear cache để reload cả 2 tab
    await loadEvents(_currentFilter, forceRefresh: true);
  }

  void clearCache() {
    _cache.clear();
    _events = [];
  }
}