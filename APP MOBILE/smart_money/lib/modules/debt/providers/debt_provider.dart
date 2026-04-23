// ===========================================================
// [2] DebtProvider — Quản lý state cho module Sổ Nợ
// ===========================================================
// Trách nhiệm:
//   • Giữ state toàn bộ module Debt (danh sách, chi tiết, giao dịch)
//   • Gọi DebtService và cập nhật UI qua notifyListeners()
//   • Phân chia list thành 2 nhóm: chưa xong / đã xong (finished)
//   • Không chứa logic UI, không BuildContext
//
// Gọi từ:
//   • DebtListScreen   → loadDebts(), deleteDebt(), updateStatus()
//   • DebtDetailScreen → loadDetail(), loadTransactions(), updateStatus()
//   • DebtEditScreen   → updateDebt()
//
// API liên quan:
//   • GET    /api/debts?debtType=...      — loadDebts
//   • GET    /api/debts/{id}              — loadDetail
//   • GET    /api/debts/{id}/transactions — loadTransactions
//   • PUT    /api/debts/{id}              — updateDebt
//   • PUT    /api/debts/{id}/status       — toggleStatus
//   • DELETE /api/debts/{id}             — deleteDebt
// ===========================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_money/core/helpers/token_helper.dart';
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';
import '../models/debt_response.dart';
import '../models/debt_update_request.dart';
import '../services/debt_service.dart';

class DebtProvider extends ChangeNotifier {

  // =============================================
  // [2.1] STATE
  // =============================================

  // --- State List Screen ---
  List<DebtResponse> _payableDebts    = [];  // Cần Trả (debtType=false), chưa xong
  List<DebtResponse> _payableDone     = [];  // Cần Trả đã trả hết (finished=true)
  List<DebtResponse> _receivableDebts = [];  // Cần Thu (debtType=true), chưa xong
  List<DebtResponse> _receivableDone  = [];  // Cần Thu đã nhận hết (finished=true)

  // --- State Detail Screen ---
  DebtResponse? _currentDebt;                // Khoản nợ đang xem chi tiết
  List<TransactionResponse> _debtTransactions = []; // Lịch sử giao dịch của khoản nợ

  // --- Loading & Error ---
  bool _isLoading     = false;  // đang tải danh sách
  bool _isLoadingDetail = false;// đang tải chi tiết + giao dịch
  bool _isSaving      = false;  // đang gửi PUT request (sửa)
  bool _isDeleting    = false;  // đang gửi DELETE request
  bool _isToggling    = false;  // đang gửi PUT /status request
  String? _errorMessage;        // lỗi từ server — hiện SnackBar ở Screen

  // =============================================
  // [2.1] GETTERS — expose state ra Screen (read-only)
  // =============================================

  List<DebtResponse> get payableDebts    => _payableDebts;    // chưa trả
  List<DebtResponse> get payableDone     => _payableDone;     // đã trả hết
  List<DebtResponse> get receivableDebts => _receivableDebts; // chưa thu
  List<DebtResponse> get receivableDone  => _receivableDone;  // đã nhận hết

  DebtResponse?              get currentDebt       => _currentDebt;
  List<TransactionResponse>  get debtTransactions  => _debtTransactions;

  bool    get isLoading       => _isLoading;
  bool    get isLoadingDetail => _isLoadingDetail;
  bool    get isSaving        => _isSaving;
  bool    get isDeleting      => _isDeleting;
  bool    get isToggling      => _isToggling;
  String? get errorMessage    => _errorMessage;

  // =============================================
  // [2.2] LOAD — Tải danh sách theo loại nợ
  // =============================================
  // Gọi khi: DebtListScreen khởi tạo hoặc user pull-to-refresh
  // Tham số:
  //   • debtType: false=Tab CẦN TRẢ, true=Tab CẦN THU
  // [NOTE] Gọi riêng cho từng tab để tránh load thừa
  Future<void> loadDebts(BuildContext context, bool debtType) async {
    // Bước 1: Bật loading, reset lỗi cũ
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Bước 2: Gọi API
      final response = await DebtService.getDebts(debtType);

      // Bước 3: Xử lý kết quả
      if (response.success && response.data != null) {
        // Thành công → phân chia list thành 2 nhóm dựa vào field finished
        final all = response.data!;
        if (!debtType) {
          // Tab Cần Trả: finished=false là chưa trả, true là đã trả hết
          _payableDebts = all.where((d) => !d.finished).toList();
          _payableDone  = all.where((d) =>  d.finished).toList();
        } else {
          // Tab Cần Thu: finished=false là chưa thu, true là đã nhận hết
          _receivableDebts = all.where((d) => !d.finished).toList();
          _receivableDone  = all.where((d) =>  d.finished).toList();
        }
      } else {
        // Thất bại → lưu message lỗi để Screen hiện SnackBar
        _errorMessage = response.message;
      }
    } catch (e) {
      _errorMessage = e.toString();
      // Xử lý 401 - Session expired
      if (e.toString().contains("Session expired")) {
        await TokenHelper.clearTokens();
        if (context.mounted) {
          context.go("/login");
        }
      }
    } finally {
      // Bước 4: Tắt loading, notify UI
      _isLoading = false;
      notifyListeners();
    }
  }

  // =============================================
  // [2.3] LOAD DETAIL — Tải chi tiết 1 khoản nợ
  // =============================================
  // [UPDATED] Chỉ load debt detail — transaction list do screen tự load
  // qua TransactionService.getTransactionList({'debtId': id})
  Future<void> loadDetail(BuildContext context, int debtId) async {
    _isLoadingDetail = true;
    _debtTransactions = [];
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await DebtService.getDebt(debtId);

      if (response.success && response.data != null) {
        _currentDebt = response.data;
      } else {
        _currentDebt = null;
        _errorMessage = response.message;
      }
    } catch (e) {
      _errorMessage = e.toString();
      // Xử lý 401 - Session expired
      if (e.toString().contains("Session expired")) {
        await TokenHelper.clearTokens();
        if (context.mounted) {
          context.go("/login");
        }
      }
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }

  // =============================================
  // [2.4] UPDATE — Sửa personName, dueDate, note
  // =============================================
  // Gọi khi: User bấm "Lưu" ở DebtEditScreen
  // Trả về: true nếu thành công, false nếu thất bại
  Future<bool> updateDebt(BuildContext context, int debtId, DebtUpdateRequest request) async {
    // Bước 1: Bật flag saving, reset lỗi
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Bước 2: Gọi API PUT /api/debts/{id}
      final response = await DebtService.updateDebt(debtId, request);

      // Bước 3: Xử lý kết quả
      bool success = false;
      if (response.success && response.data != null) {
        // Thành công → cập nhật currentDebt để Detail screen refresh ngay
        _currentDebt = response.data;
        // Cập nhật luôn item trong list (nếu đang giữ)
        _updateInList(response.data!);
        success = true;
      } else {
        // Thất bại → lưu lỗi để Screen hiện SnackBar
        _errorMessage = response.message;
      }

      // Bước 4: Tắt saving, notify
      _isSaving = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      // Xử lý 401 - Session expired
      if (e.toString().contains("Session expired")) {
        await TokenHelper.clearTokens();
        if (context.mounted) {
          context.go("/login");
        }
      }
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [2.5] TOGGLE STATUS — Đánh dấu hoàn thành / chưa hoàn thành
  // =============================================
  // Gọi khi: User bấm nút "Đánh dấu hoàn thành" ở Detail screen
  // Trả về: true nếu thành công
  Future<bool> toggleStatus(BuildContext context, int debtId) async {
    // Bước 1: Bật flag toggling
    _isToggling = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Bước 2: Gọi API PUT /api/debts/{id}/status
      final response = await DebtService.updateDebtStatus(debtId);

      // Bước 3: Xử lý kết quả
      bool success = false;
      if (response.success && response.data != null) {
        // Thành công → cập nhật currentDebt + list
        _currentDebt = response.data;
        _updateInList(response.data!);
        success = true;
      } else {
        // Thất bại → lưu lỗi để Screen hiện SnackBar
        _errorMessage = response.message;
      }

      // Bước 4: Tắt toggling, notify
      _isToggling = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      // Xử lý 401 - Session expired
      if (e.toString().contains("Session expired")) {
        await TokenHelper.clearTokens();
        if (context.mounted) {
          context.go("/login");
        }
      }
      _isToggling = false;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [2.6] DELETE — Xóa khoản nợ
  // =============================================
  // Gọi khi: User xác nhận xóa từ Dialog ở Detail screen
  // Trả về: true nếu thành công
  // [NOTE] Giao dịch liên quan KHÔNG bị xóa — backend chỉ set debt_id=null
  Future<bool> deleteDebt(BuildContext context, int debtId, bool debtType) async {
    // Bước 1: Bật flag deleting
    _isDeleting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Bước 2: Gọi API DELETE /api/debts/{id}
      final response = await DebtService.deleteDebt(debtId);

      // Bước 3: Xử lý kết quả
      bool success = false;
      if (response.success) {
        // Thành công → xóa khỏi list local (không cần reload API)
        _removeFromList(debtId, debtType);
        _currentDebt = null;
        success = true;
      } else {
        _errorMessage = response.message;
      }

      // Bước 4: Tắt deleting
      _isDeleting = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      // Xử lý 401 - Session expired
      if (e.toString().contains("Session expired")) {
        await TokenHelper.clearTokens();
        if (context.mounted) {
          context.go("/login");
        }
      }
      _isDeleting = false;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [2.7] CLEAR — Reset state khi rời module
  // =============================================
  void clearDetail() {
    _currentDebt = null;
    _debtTransactions = [];
    _errorMessage = null;
    notifyListeners();
  }

  // =============================================
  // [2.8] HELPER PRIVATE — Cập nhật list local
  // =============================================

  // Cập nhật 1 item trong list local sau khi PUT thành công
  void _updateInList(DebtResponse updated) {
    // Kiểm tra từng list — updated có thể thuộc list nào
    _payableDebts    = _replaceInList(_payableDebts, updated);
    _payableDone     = _replaceInList(_payableDone, updated);
    _receivableDebts = _replaceInList(_receivableDebts, updated);
    _receivableDone  = _replaceInList(_receivableDone, updated);
  }

  List<DebtResponse> _replaceInList(List<DebtResponse> list, DebtResponse updated) {
    return list.map((d) => d.id == updated.id ? updated : d).toList();
  }

  // Xóa 1 item khỏi list local sau khi DELETE thành công
  void _removeFromList(int debtId, bool debtType) {
    if (!debtType) {
      // Cần Trả: xóa khỏi cả 2 nhóm
      _payableDebts = _payableDebts.where((d) => d.id != debtId).toList();
      _payableDone  = _payableDone.where((d) => d.id != debtId).toList();
    } else {
      // Cần Thu: xóa khỏi cả 2 nhóm
      _receivableDebts = _receivableDebts.where((d) => d.id != debtId).toList();
      _receivableDone  = _receivableDone.where((d) => d.id != debtId).toList();
    }
  }
}
