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

  // Cache lưu trữ dữ liệu riêng biệt cho từng trạng thái
  final Map<bool, List<EventResponse>> _cache = {};

  // =============================================
  // LOAD EVENTS
  // =============================================
  Future<void> loadEvents(bool isFinished, {bool forceRefresh = false}) async {
    // Luôn cập nhật filter hiện tại để đồng bộ với UI
    _currentFilter = isFinished;

    // Nếu không ép buộc làm mới và đã có dữ liệu trong cache thì dùng luôn
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
      _cache[isFinished] = res.data!;

      // CHỈ gán vào _events nếu isFinished đang khớp với tab người dùng nhìn thấy
      // Điều này tránh lỗi "nhầm dữ liệu" khi người dùng chuyển tab nhanh
      if (_currentFilter == isFinished) {
        _events = _cache[isFinished]!;
      }
    } else {
      if (_currentFilter == isFinished) {
        _events = [];
        _errorMessage = res.message;
      }
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
      // Sau khi tạo mới, mặc định chuyển về tab Active để xem
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
      // Làm mới dữ liệu tại tab hiện tại
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
    // Xóa cache và tải lại dữ liệu tab hiện tại
    _cache.clear();
    await loadEvents(_currentFilter, forceRefresh: true);
  }

  // =============================================
  // TOGGLE STATUS (Hàm quan trọng nhất cho yêu cầu của bạn)
  // =============================================
  Future<void> toggleStatus(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await EventService.toggleStatus(id);

      if (res.success) {
        // 1. Xóa sạch cache cũ vì trạng thái các sự kiện đã thay đổi
        _cache.clear();

        // 2. Tải song song cả 2 danh sách để cập nhật cache đầy đủ cho cả 2 tab
        final results = await Future.wait([
          EventService.getEvents(false), // Lấy Active
          EventService.getEvents(true),  // Lấy Finished
        ]);

        if (results[0].success) _cache[false] = results[0].data!;
        if (results[1].success) _cache[true] = results[1].data!;

        // 3. Cập nhật biến hiển thị _events theo Tab mà UI vừa chuyển đến
        // Nếu UI gọi onTabChanged() trước khi hàm này kết thúc, _currentFilter đã thay đổi
        _events = _cache[_currentFilter] ?? [];
      }
    } catch (e) {
      _errorMessage = "Failed to toggle status: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =============================================
  // HELPERS
  // =============================================
  void clearCache() {
    _cache.clear();
    _events = [];
    notifyListeners();
  }
}