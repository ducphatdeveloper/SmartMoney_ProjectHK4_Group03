// ===========================================================
// [3] BillProvider — Quản lý state module Hóa đơn
// ===========================================================
// Trách nhiệm:
//   • Lưu trữ danh sách hóa đơn (active + expired)
//   • Gọi PlannedService để CRUD + toggle + pay
//   • Lọc theo ví (walletId) — lọc local không gọi API lại
//   • Thông báo UI khi dữ liệu thay đổi (notifyListeners)
//
// Cách dùng trong Screen:
//   final provider = Provider.of<BillProvider>(context);
//   provider.loadAll();
//
// API liên quan:
//   • GET    /api/bills?active=true    — lấy danh sách đang áp dụng
//   • GET    /api/bills?active=false   — lấy danh sách đã kết thúc
//   • POST   /api/bills                — tạo mới
//   • PUT    /api/bills/{id}           — cập nhật
//   • DELETE /api/bills/{id}           — xóa
//   • PATCH  /api/bills/{id}/toggle    — đánh dấu hoàn tất/chưa
//   • POST   /api/bills/{id}/pay       — trả tiền hóa đơn → tạo Transaction
// ===========================================================

import 'package:flutter/foundation.dart';
import 'package:smart_money/modules/planned/models/planned_transaction_request.dart';
import 'package:smart_money/modules/planned/models/planned_transaction_response.dart';
import 'package:smart_money/modules/planned/services/planned_service.dart';

class BillProvider extends ChangeNotifier {

  // =============================================
  // [3.1] STATE — Danh sách hóa đơn
  // =============================================

  List<PlannedTransactionResponse> _activeItems = [];  // hóa đơn đang áp dụng (active=true)
  List<PlannedTransactionResponse> _expiredItems = [];  // hóa đơn đã kết thúc (active=false)

  bool _isLoading = false;      // đang gọi API — hiện CircularProgressIndicator
  bool get isLoading => _isLoading;

  String? _errorMessage;        // lỗi từ server — hiện SnackBar đỏ
  String? get errorMessage => _errorMessage;

  String? _successMessage;      // thành công — hiện SnackBar xanh
  String? get successMessage => _successMessage;

  int? _selectedWalletId;       // null = "Tất cả ví", có giá trị = lọc theo ví
  int? get selectedWalletId => _selectedWalletId;

  // Set of item ids that are currently being processed (toggle/pay/delete)
  final Set<int> _processingIds = {};
  bool isProcessing(int id) => _processingIds.contains(id);

  // =============================================
  // [3.1b] FILTERED ITEMS — Lọc theo ví đã chọn
  // =============================================
  // Nếu _selectedWalletId = null → trả toàn bộ
  // Nếu có giá trị → lọc local, không gọi API lại
  List<PlannedTransactionResponse> get activeItems {
    if (_selectedWalletId == null) return _activeItems;
    return _activeItems.where((e) => e.walletId == _selectedWalletId).toList();
  }

  List<PlannedTransactionResponse> get expiredItems {
    if (_selectedWalletId == null) return _expiredItems;
    return _expiredItems.where((e) => e.walletId == _selectedWalletId).toList();
  }

  // =============================================
  // [3.2] LOAD ALL — Lấy danh sách hóa đơn (active + expired song song)
  // =============================================
  // Gọi khi: Mở màn hình, sau khi tạo/sửa/xóa/toggle/pay
  // API: GET /api/bills?active=true + GET /api/bills?active=false
  Future<void> loadAll() async {
    // Bước 1: Bật loading, xóa lỗi cũ
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Bước 2: Gọi 2 API song song — tăng tốc load
    final results = await Future.wait([
      PlannedService.getBills(active: true),
      PlannedService.getBills(active: false),
    ]);

    // Bước 3: Xử lý kết quả active
    if (results[0].success && results[0].data != null) {
      _activeItems = results[0].data!;
    } else {
      _activeItems = [];
      _errorMessage = results[0].message;
    }

    // Bước 4: Xử lý kết quả expired
    if (results[1].success && results[1].data != null) {
      _expiredItems = results[1].data!;
    } else {
      _expiredItems = [];
      // Chỉ ghi đè errorMessage nếu chưa có lỗi trước đó
      _errorMessage ??= results[1].message;
    }

    // Bước 5: Tắt loading, thông báo UI cập nhật
    _isLoading = false;
    notifyListeners();
  }

  // =============================================
  // [3.3] SET WALLET FILTER — Lọc danh sách theo ví
  // =============================================
  // Gọi khi: User chọn ví trong dropdown
  // Lọc local — không gọi API lại
  void setWalletFilter(int? walletId) {
    _selectedWalletId = walletId;
    notifyListeners();
  }

  // =============================================
  // [3.4] CREATE — Tạo hóa đơn mới
  // =============================================
  // Gọi khi: User bấm "Lưu" ở PlannedFormScreen (planType = bill)
  // API: POST /api/bills
  // Trả về: true nếu thành công, false nếu thất bại
  Future<bool> create(PlannedTransactionRequest request) async {
    // Bước 1: Gọi API
    final response = await PlannedService.createBill(request);

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
  // [3.5] UPDATE — Cập nhật hóa đơn
  // =============================================
  // Gọi khi: User bấm "Lưu" ở PlannedFormScreen (chế độ sửa)
  // API: PUT /api/bills/{id}
  Future<bool> update(int id, PlannedTransactionRequest request) async {
    final response = await PlannedService.updateBill(id, request);

    if (response.success) {
      _successMessage = response.message;
      await loadAll();
      return true;
    } else {
      _errorMessage = response.message;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [3.6] DELETE — Xóa hóa đơn (optimistic update)
  // =============================================
  // Gọi khi: User xác nhận xóa trong Dialog
  // API: DELETE /api/bills/{id}
  // [NOTE] Dùng optimistic update: xóa khỏi list trước, gọi API sau
  Future<bool> delete(int id) async {
    // Bước 1: Tìm item trong active hoặc expired, lưu bản sao
    int removedIndex = _activeItems.indexWhere((e) => e.id == id);
    bool wasActive = true;
    PlannedTransactionResponse? removed;

    if (removedIndex != -1) {
      // Tìm thấy trong active
      removed = _activeItems[removedIndex];
      _activeItems.removeAt(removedIndex);
    } else {
      // Tìm trong expired
      removedIndex = _expiredItems.indexWhere((e) => e.id == id);
      if (removedIndex == -1) return false; // không tìm thấy
      removed = _expiredItems[removedIndex];
      _expiredItems.removeAt(removedIndex);
      wasActive = false;
    }
    notifyListeners();

    // Bước 2: Gọi API xóa
    final response = await PlannedService.deleteBill(id);

    // Bước 3: Xử lý kết quả
    if (response.success) {
      _successMessage = "Đã xóa hóa đơn";
      return true;
    } else {
      // Thất bại → rollback thêm lại vào list
      if (wasActive) {
        _activeItems.insert(removedIndex, removed);
      } else {
        _expiredItems.insert(removedIndex, removed);
      }
      _errorMessage = response.message;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [3.7] TOGGLE — Đánh dấu hoàn tất/chưa hóa đơn
  // =============================================
  // Gọi khi: User bấm "Đánh dấu hoàn tất" trong BillDetailSheet
  // API: PATCH /api/bills/{id}/toggle
  Future<bool> toggle(int id) async {
    final response = await PlannedService.toggleBill(id);

    if (response.success) {
      _successMessage = response.message;
      // Reload lại vì item chuyển giữa active ↔ expired
      await loadAll();
      return true;
    } else {
      _errorMessage = response.message;
      notifyListeners(); // ✅ Notify để UI hiển thị error message rõ ràng
      return false;
    }
  }

  // =============================================
  // [3.8] PAY BILL — Trả tiền hóa đơn → tạo Transaction thật
  // =============================================
  // Gọi khi: User bấm "Trả tiền" ở BillDetailSheet
  // API: POST /api/bills/{id}/pay
  // Backend: tạo Transaction + cập nhật nextDueDate + lastExecutedAt
  Future<bool> payBill(int id) async {
    final response = await PlannedService.payBill(id);

    if (response.success) {
      _successMessage = response.message.isNotEmpty
          ? response.message
          : "Đã thanh toán hóa đơn";
      await loadAll();
      return true;
    } else {
      _errorMessage = response.message;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [3.9] CLEAR — Xóa thông báo sau khi UI đã hiện
  // =============================================
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    // KHÔNG cần notifyListeners — thường gọi sau khi đã pop màn hình
  }
}

