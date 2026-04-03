// ===========================================================
// [2] RecurringProvider — Quản lý state module Giao dịch định kỳ
// ===========================================================
// Trách nhiệm:
//   • Lưu trữ danh sách giao dịch định kỳ (active + inactive)
//   • Gọi PlannedService để CRUD + toggle
//   • Lọc theo ví (walletId) — lọc local không gọi API lại
//   • Thông báo UI khi dữ liệu thay đổi (notifyListeners)
//
// Cách dùng trong Screen:
//   final provider = Provider.of<RecurringProvider>(context);
//   provider.loadAll();
//
// API liên quan:
//   • GET    /api/recurring?active=true   — lấy danh sách đang hoạt động
//   • GET    /api/recurring?active=false  — lấy danh sách đã kết thúc
//   • POST   /api/recurring               — tạo mới
//   • PUT    /api/recurring/{id}          — cập nhật
//   • DELETE /api/recurring/{id}          — xóa
//   • PATCH  /api/recurring/{id}/toggle   — bật/tắt active
// ===========================================================

import 'package:flutter/foundation.dart';
import 'package:smart_money/modules/planned/models/planned_transaction_request.dart';
import 'package:smart_money/modules/planned/models/planned_transaction_response.dart';
import 'package:smart_money/modules/planned/services/planned_service.dart';

class RecurringProvider extends ChangeNotifier {

  // =============================================
  // [2.1] STATE — Danh sách giao dịch định kỳ
  // =============================================

  List<PlannedTransactionResponse> _activeItems = [];  // danh sách đang hoạt động (active=true)
  List<PlannedTransactionResponse> _inactiveItems = []; // danh sách đã kết thúc/tạm dừng (active=false)

  bool _isLoading = false;      // đang gọi API — hiện CircularProgressIndicator
  bool get isLoading => _isLoading;

  String? _errorMessage;        // lỗi từ server — hiện SnackBar đỏ
  String? get errorMessage => _errorMessage;

  String? _successMessage;      // thành công — hiện SnackBar xanh
  String? get successMessage => _successMessage;

  int? _selectedWalletId;       // null = "Tất cả ví", có giá trị = lọc theo ví
  int? get selectedWalletId => _selectedWalletId;

  // =============================================
  // [2.1b] FILTERED ITEMS — Lọc theo ví đã chọn
  // =============================================
  // Nếu _selectedWalletId = null → trả toàn bộ
  // Nếu có giá trị → lọc local, không gọi API lại
  List<PlannedTransactionResponse> get activeItems {
    if (_selectedWalletId == null) return _activeItems;
    return _activeItems.where((e) => e.walletId == _selectedWalletId).toList();
  }

  List<PlannedTransactionResponse> get inactiveItems {
    if (_selectedWalletId == null) return _inactiveItems;
    return _inactiveItems.where((e) => e.walletId == _selectedWalletId).toList();
  }

  // =============================================
  // [2.2] LOAD ALL — Lấy danh sách giao dịch định kỳ (active + inactive song song)
  // =============================================
  // Gọi khi: Mở màn hình, sau khi tạo/sửa/xóa/toggle
  // API: GET /api/recurring?active=true + GET /api/recurring?active=false
  Future<void> loadAll() async {
    // Bước 1: Bật loading, xóa lỗi cũ
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Bước 2: Gọi 2 API song song — tăng tốc load
    final results = await Future.wait([
      PlannedService.getRecurring(active: true),
      PlannedService.getRecurring(active: false),
    ]);

    // Bước 3: Xử lý kết quả active
    if (results[0].success && results[0].data != null) {
      _activeItems = results[0].data!;
    } else {
      _activeItems = [];
      _errorMessage = results[0].message;
    }

    // Bước 4: Xử lý kết quả inactive
    if (results[1].success && results[1].data != null) {
      _inactiveItems = results[1].data!;
    } else {
      _inactiveItems = [];
      // Chỉ ghi đè errorMessage nếu chưa có lỗi trước đó
      _errorMessage ??= results[1].message;
    }

    // Bước 5: Tắt loading, thông báo UI cập nhật
    _isLoading = false;
    notifyListeners();
  }

  // =============================================
  // [2.3] SET WALLET FILTER — Lọc danh sách theo ví
  // =============================================
  // Gọi khi: User chọn ví trong dropdown
  // Lọc local — không gọi API lại
  void setWalletFilter(int? walletId) {
    _selectedWalletId = walletId;
    notifyListeners();
  }

  // =============================================
  // [2.4] CREATE — Tạo giao dịch định kỳ mới
  // =============================================
  // Gọi khi: User bấm "Lưu" ở PlannedFormScreen (planType = recurring)
  // API: POST /api/recurring
  // Trả về: true nếu thành công, false nếu thất bại
  Future<bool> create(PlannedTransactionRequest request) async {
    // Bước 1: Gọi API
    final response = await PlannedService.createRecurring(request);

    // Bước 2: Xử lý kết quả
    if (response.success) {
      // Thành công → reload danh sách
      _successMessage = response.message;
      await loadAll(); // reload cả 2 tab
      return true;
    } else {
      // Thất bại → lưu lỗi
      _errorMessage = response.message;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [2.5] UPDATE — Cập nhật giao dịch định kỳ
  // =============================================
  // Gọi khi: User bấm "Lưu" ở PlannedFormScreen (chế độ sửa)
  // API: PUT /api/recurring/{id}
  Future<bool> update(int id, PlannedTransactionRequest request) async {
    // Bước 1: Gọi API
    final response = await PlannedService.updateRecurring(id, request);

    // Bước 2: Xử lý kết quả
    if (response.success) {
      _successMessage = response.message;
      await loadAll(); // reload cả 2 tab
      return true;
    } else {
      _errorMessage = response.message;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [2.6] DELETE — Xóa giao dịch định kỳ (optimistic update)
  // =============================================
  // Gọi khi: User xác nhận xóa trong Dialog
  // API: DELETE /api/recurring/{id}
  // [NOTE] Dùng optimistic update: xóa khỏi list trước, gọi API sau
  Future<bool> delete(int id) async {
    // Bước 1: Tìm item trong active hoặc inactive, lưu bản sao
    int removedIndex = _activeItems.indexWhere((e) => e.id == id);
    bool wasActive = true;
    PlannedTransactionResponse? removed;

    if (removedIndex != -1) {
      // Tìm thấy trong active
      removed = _activeItems[removedIndex];
      _activeItems.removeAt(removedIndex);
    } else {
      // Tìm trong inactive
      removedIndex = _inactiveItems.indexWhere((e) => e.id == id);
      if (removedIndex == -1) return false; // không tìm thấy
      removed = _inactiveItems[removedIndex];
      _inactiveItems.removeAt(removedIndex);
      wasActive = false;
    }
    notifyListeners();

    // Bước 2: Gọi API xóa
    final response = await PlannedService.deleteRecurring(id);

    // Bước 3: Xử lý kết quả
    if (response.success) {
      _successMessage = "Đã xóa giao dịch định kỳ";
      return true;
    } else {
      // Thất bại → rollback thêm lại vào list
      if (wasActive) {
        _activeItems.insert(removedIndex, removed!);
      } else {
        _inactiveItems.insert(removedIndex, removed!);
      }
      _errorMessage = response.message;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [2.7] TOGGLE — Bật/tắt active giao dịch định kỳ
  // =============================================
  // Gọi khi: User bấm switch trong RecurringDetailSheet
  // API: PATCH /api/recurring/{id}/toggle
  Future<bool> toggle(int id) async {
    // Optimistic update: Cập nhật UI ngay lập tức
    _updateItemToggleStatus(id);
    
    // Gọi API toggle
    final response = await PlannedService.toggleRecurring(id);

    if (response.success) {
      _successMessage = response.message;
      return true;
    } else {
      _errorMessage = response.message;
      notifyListeners(); // ✅ Notify trước khi reload để UI hiển thị error message
      await loadAll();
      return false;
    }
  }
  
  // Optimistic update: Cập nhật trạng thái toggle ngay lập tức
  void _updateItemToggleStatus(int id) {
    // Tìm trong active items
    final activeIndex = _activeItems.indexWhere((item) => item.id == id);
    if (activeIndex != -1) {
      final item = _activeItems[activeIndex];
      // Chuyển từ active → inactive
      _activeItems.removeAt(activeIndex);
      _inactiveItems.insert(0, item);
      notifyListeners();
      return;
    }
    
    // Tìm trong inactive items
    final inactiveIndex = _inactiveItems.indexWhere((item) => item.id == id);
    if (inactiveIndex != -1) {
      final item = _inactiveItems[inactiveIndex];
      // Chuyển từ inactive → active
      _inactiveItems.removeAt(inactiveIndex);
      _activeItems.insert(0, item);
      notifyListeners();
    }
  }

  // =============================================
  // [2.8] CLEAR — Xóa thông báo sau khi UI đã hiện
  // =============================================
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    // KHÔNG cần notifyListeners — thường gọi sau khi đã pop màn hình
  }
}
