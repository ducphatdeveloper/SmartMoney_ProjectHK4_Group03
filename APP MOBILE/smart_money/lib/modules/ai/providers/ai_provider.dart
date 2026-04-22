// ===========================================================
// [1] AiProvider — Quản lý state module AI Chat & OCR
// ===========================================================
// Trách nhiệm:
//   • Lưu trữ lịch sử trò chuyện với AI
//   • Gọi AiService để thực hiện chat, upload receipt, execute action
//   • Thông báo UI rebuild khi dữ liệu thay đổi (notifyListeners)
//
// Cách dùng trong Screen:
//   final provider = Provider.of<AiProvider>(context);
//   provider.loadHistory(); // load lịch sử chat
//   provider.sendMessage(request); // gửi tin nhắn
//
// API liên quan:
//   • POST   /api/ai/chat              — Gửi tin nhắn cho AI
//   • POST   /api/ai/upload-receipt    — Upload ảnh hóa đơn OCR
//   • GET    /api/ai/history           — Lấy lịch sử chat
//   • DELETE /api/ai/history           — Xóa toàn bộ lịch sử
//   • DELETE /api/ai/history/{id}      — Xóa 1 conversation
//   • POST   /api/ai/execute           — Thực thi hành động AI đề xuất
// ===========================================================

import 'package:flutter/foundation.dart';
import 'package:smart_money/modules/ai/models/request/ai_chat_request.dart';
import 'package:smart_money/modules/ai/models/request/ai_execute_request.dart';
import 'package:smart_money/modules/ai/models/response/ai_chat_response.dart';
import 'package:smart_money/modules/ai/models/response/chat_history_item.dart';
import 'package:smart_money/modules/ai/services/ai_service.dart';

class AiProvider extends ChangeNotifier {

  // =============================================
  // [1.1] STATE — Khai báo biến state
  // =============================================

  // --- Lịch sử trò chuyện ---
  List<ChatHistoryItem> _chatHistory = [];
  List<ChatHistoryItem> get chatHistory => _chatHistory;

  // --- Phân trang ---
  int _currentPage = 0;
  int get currentPage => _currentPage;

  int _pageSize = 20;
  int get pageSize => _pageSize;

  bool _hasMore = true; // còn dữ liệu để load thêm không
  bool get hasMore => _hasMore;

  // --- Phản hồi AI cuối cùng ---
  AiChatResponse? _lastResponse;
  AiChatResponse? get lastResponse => _lastResponse;

  // --- UI state ---
  bool _isLoading = false; // đang gọi API — hiện CircularProgressIndicator
  bool get isLoading => _isLoading;

  bool _isSending = false; // đang gửi tin nhắn — hiện loading ở input
  bool get isSending => _isSending;

  String? _errorMessage; // lỗi từ server — hiện SnackBar đỏ
  String? get errorMessage => _errorMessage;

  String? _successMessage; // thành công — hiện SnackBar xanh
  String? get successMessage => _successMessage;

  // =============================================
  // [1.2] CONSTRUCTOR
  // =============================================

  AiProvider();

  // =============================================
  // [1.3] LOAD HISTORY — Tải lịch sử chat
  // =============================================
  // Gọi khi: Mở màn hình chat / kéo xuống để load thêm
  // Flow:
  //   1. Reset page nếu là load lần đầu
  //   2. Gọi API getHistory với page + size
  //   3. Append vào list (hoặc replace nếu load lần đầu)
  Future<void> loadHistory({bool refresh = false}) async {
    // Bước 1: Reset nếu refresh
    if (refresh) {
      _currentPage = 0;
      _hasMore = true;
      _chatHistory = [];
    }

    // Bước 2: Kiểm tra còn dữ liệu không
    if (!_hasMore) return;

    // Bước 3: Bật loading
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Bước 4: Gọi API
      final response = await AiService.getHistory(
        page: _currentPage,
        size: _pageSize,
      );

      // Bước 5: Xử lý kết quả
      if (response.success && response.data != null) {
        final newItems = response.data!;

        // Bước 5.1: Sắp xếp theo createdAt ASC (cũ nhất trước) để hiển thị đúng thứ tự như Zalo/Facebook
        newItems.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        // Nếu load lần đầu → replace list
        if (_currentPage == 0) {
          _chatHistory = newItems;
        } else {
          // Nếu load thêm → append
          _chatHistory.addAll(newItems);
        }

        // Cập nhật trạng thái phân trang
        _hasMore = newItems.length >= _pageSize;
        _currentPage++;

        // Tắt loading
        _isLoading = false;
        notifyListeners();
      } else {
        // Lỗi server
        _errorMessage = _extractErrorMessage(response);
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      // Lỗi bất ngờ
      _isLoading = false;
      _errorMessage = 'Lỗi khi tải lịch sử: ${e.toString()}';
      notifyListeners();
    }
  }

  // =============================================
  // [1.4] SEND MESSAGE — Gửi tin nhắn cho AI
  // =============================================
  // Gọi khi: User nhập tin nhắn và bấm gửi
  // API: POST /api/ai/chat
  // Trả về: true nếu thành công, false nếu thất bại
  Future<bool> sendMessage(AiChatRequest request) async {
    // Bước 1: Thêm tin nhắn user vào local state ngay lập tức (UI hiển thị ngay)
    final userMessage = ChatHistoryItem(
      id: DateTime.now().millisecondsSinceEpoch, // Tạm thời dùng timestamp làm ID
      messageContent: request.message,
      senderType: false, // false = User
      intent: null,
      attachmentUrl: null,
      attachmentType: null,
      createdAt: DateTime.now(),
    );
    _chatHistory.add(userMessage);
    notifyListeners();

    // Bước 2: Bật sending, xóa thông báo cũ
    _isSending = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // Bước 3: Gọi API
      final response = await AiService.chat(request);

      // Bước 4: Xử lý kết quả
      if (response.success && response.data != null) {
        // Lưu phản hồi cuối cùng
        _lastResponse = response.data;

        // Reload lịch sử để sync với server (sẽ thay thế tin nhắn tạm thời bằng tin nhắn thật từ DB)
        await loadHistory(refresh: true);

        // Tắt sending
        _isSending = false;
        notifyListeners();
        return true;
      } else {
        // Thất bại - xóa tin nhắn tạm thời
        _chatHistory.removeLast();
        _errorMessage = _extractErrorMessage(response);
        _isSending = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Lỗi bất ngờ - xóa tin nhắn tạm thời
      _chatHistory.removeLast();
      _isSending = false;
      _errorMessage = 'Lỗi khi gửi tin nhắn: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [1.5] UPLOAD RECEIPT — Upload ảnh hóa đơn OCR
  // =============================================
  // Gọi khi: User chọn ảnh từ gallery để AI đọc hóa đơn
  // API: POST /api/ai/upload-receipt (multipart/form-data)
  // Trả về: true nếu thành công, false nếu thất bại
  Future<bool> uploadReceipt({
    required String imagePath,
    int? walletId,
  }) async {
    // Bước 1: Bật sending
    _isSending = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // Bước 2: Gọi API
      final response = await AiService.uploadReceipt(
        imagePath: imagePath,
        walletId: walletId,
      );

      // Bước 3: Xử lý kết quả
      if (response.success && response.data != null) {
        // Lưu phản hồi cuối cùng
        _lastResponse = response.data;

        _successMessage = 'Đã tải lên hóa đơn';

        // Reload lịch sử để sync với server
        await loadHistory(refresh: true);

        // Tắt sending
        _isSending = false;
        notifyListeners();
        return true;
      } else {
        // Thất bại
        _errorMessage = _extractErrorMessage(response);
        _isSending = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Lỗi bất ngờ
      _isSending = false;
      _errorMessage = 'Lỗi khi tải lên hóa đơn: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [1.6] EXECUTE ACTION — Thực thi hành động AI đề xuất
  // =============================================
  // Gọi khi: User bấm xác nhận hành động (VD: "Lưu giao dịch")
  // API: POST /api/ai/execute
  // Trả về: true nếu thành công, false nếu thất bại
  Future<bool> executeAction(AiExecuteRequest request) async {
    // Bước 1: Bật sending
    _isSending = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // Bước 2: Gọi API
      final response = await AiService.executeAction(request);

      // Bước 3: Xử lý kết quả
      if (response.success && response.data != null) {
        // Lưu phản hồi cuối cùng
        _lastResponse = response.data;

        _successMessage = 'Đã thực thi hành động';

        // Reload lịch sử để sync với server
        await loadHistory(refresh: true);

        // Tắt sending
        _isSending = false;
        notifyListeners();
        return true;
      } else {
        // Thất bại
        _errorMessage = _extractErrorMessage(response);
        _isSending = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Lỗi bất ngờ
      _isSending = false;
      _errorMessage = 'Lỗi khi thực thi hành động: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [1.7] CLEAR HISTORY — Xóa toàn bộ lịch sử
  // =============================================
  // Gọi khi: User bấm "Xóa toàn bộ lịch sử"
  // API: DELETE /api/ai/history
  // Trả về: true nếu thành công, false nếu thất bại
  Future<bool> clearHistory() async {
    // Bước 1: Bật loading
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // Bước 2: Gọi API
      final response = await AiService.clearHistory();

      // Bước 3: Xử lý kết quả
      if (response.success) {
        _successMessage = response.message;

        // Xóa list local
        _chatHistory = [];
        _currentPage = 0;
        _hasMore = true;

        // Tắt loading
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Thất bại
        _errorMessage = _extractErrorMessage(response);
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Lỗi bất ngờ
      _isLoading = false;
      _errorMessage = 'Lỗi khi xóa lịch sử: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [1.8] DELETE CONVERSATION — Xóa 1 conversation
  // =============================================
  // Gọi khi: User bấm xóa 1 tin nhắn cụ thể
  // API: DELETE /api/ai/history/{conversationId}
  // Trả về: true nếu thành công, false nếu thất bại
  Future<bool> deleteConversation(int conversationId) async {
    // Bước 1: Bật loading
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // Bước 2: Gọi API
      final response = await AiService.deleteConversation(conversationId);

      // Bước 3: Xử lý kết quả
      if (response.success) {
        _successMessage = response.message;

        // Xóa khỏi list local
        _chatHistory.removeWhere((item) => item.id == conversationId);

        // Tắt loading
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Thất bại
        _errorMessage = _extractErrorMessage(response);
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Lỗi bất ngờ
      _isLoading = false;
      _errorMessage = 'Lỗi khi xóa tin nhắn: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [1.9] Helper — Extract error message từ ApiResponse
  // =============================================
  String _extractErrorMessage(dynamic response) {
    // Nếu response có message → dùng message
    if (response.message != null && response.message!.isNotEmpty) {
      return response.message!;
    }

    // Nếu response có data là Map → extract field errors
    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      final errors = <String>[];
      data.forEach((key, value) {
        if (value is List) {
          errors.add('$key: ${value.join(', ')}');
        } else {
          errors.add('$key: $value');
        }
      });
      if (errors.isNotEmpty) {
        return errors.join('\n');
      }
    }

    // Mặc định
    return 'Có lỗi xảy ra. Vui lòng thử lại.';
  }

  // =============================================
  // [1.10] CLEAR MESSAGES — Xóa thông báo lỗi/thành công
  // =============================================
  // Gọi khi: UI hiện SnackBar xong → xóa message để không hiện lại
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
