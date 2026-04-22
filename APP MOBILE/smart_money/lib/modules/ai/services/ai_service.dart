// ===========================================================
// [1] AiService — Gọi API AI Chat & OCR từ Spring Boot
// ===========================================================
// Trách nhiệm:
//   • Là lớp DUY NHẤT gọi HTTP cho module AI
//   • Tất cả method là static — gọi trực tiếp không cần instance
//   • Không chứa logic UI, không setState, không BuildContext
//
// Gọi từ:
//   • AiProvider → gọi tất cả hàm bên dưới
//
// API liên quan:
//   • POST   /api/ai/chat              — Gửi tin nhắn cho AI
//   • POST   /api/ai/upload-receipt    — Upload ảnh hóa đơn OCR
//   • GET    /api/ai/history           — Lấy lịch sử chat (có phân trang)
//   • DELETE /api/ai/history           — Xóa toàn bộ lịch sử
//   • DELETE /api/ai/history/{id}      — Xóa 1 conversation
//   • POST   /api/ai/execute           — Thực thi hành động AI đề xuất
// ===========================================================

import 'package:smart_money/core/helpers/api_handler.dart';
import 'package:smart_money/core/models/api_response.dart';
import 'package:smart_money/core/constants/app_constants.dart';
import 'package:smart_money/modules/ai/models/request/ai_chat_request.dart';
import 'package:smart_money/modules/ai/models/request/ai_execute_request.dart';
import 'package:smart_money/modules/ai/models/response/ai_chat_response.dart';
import 'package:smart_money/modules/ai/models/response/chat_history_item.dart';

class AiService {
  // URL gốc lấy từ AppConstants — KHÔNG hardcode
  static String get _base => AppConstants.aiBase;

  // -----------------------------------------------------------
  // [1.1] CHAT — Gửi tin nhắn cho AI
  // -----------------------------------------------------------
  // Gọi khi: User nhập tin nhắn và bấm gửi
  // API: POST /api/ai/chat
  // Body: AiChatRequest (message, attachmentType)
  // Trả về: AiChatResponse (conversationId, reply, intent, action...)
  static Future<ApiResponse<AiChatResponse>> chat(AiChatRequest request) async {
    return ApiHandler.post<AiChatResponse>(
      AppConstants.aiChat, // POST /api/ai/chat
      body: request.toJson(),
      fromJson: (json) => AiChatResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.2] UPLOAD RECEIPT — Upload ảnh hóa đơn để OCR
  // -----------------------------------------------------------
  // Gọi khi: User chọn ảnh từ gallery để AI đọc hóa đơn
  // API: POST /api/ai/upload-receipt (multipart/form-data)
  // Params: image (File), walletId (optional)
  // Trả về: AiChatResponse (conversationId, reply, receiptId...)
  static Future<ApiResponse<AiChatResponse>> uploadReceipt({
    required String imagePath, // Đường dẫn file ảnh local
    int? walletId, // (Optional) Ví muốn tạo giao dịch ngay
  }) async {
    // Bước 1: Build query params
    final params = <String, dynamic>{};
    if (walletId != null) params['walletId'] = walletId;

    // Bước 2: Gọi API multipart upload
    return ApiHandler.uploadMultipartFile<AiChatResponse>(
      AppConstants.aiUploadReceipt, // POST /api/ai/upload-receipt
      filePath: imagePath,
      fieldKey: 'image', // Tên field backend nhận
      queryParams: params,
      fromJson: (json) => AiChatResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.3] GET HISTORY — Lấy lịch sử chat (có phân trang)
  // -----------------------------------------------------------
  // Gọi khi: Mở màn hình chat / kéo xuống để tải thêm
  // API: GET /api/ai/history?page=0&size=20
  // Trả về: List<ChatHistoryItem>
  static Future<ApiResponse<List<ChatHistoryItem>>> getHistory({
    int page = 0,
    int size = 20,
  }) async {
    // Bước 1: Build query params
    final params = 'page=$page&size=$size';
    final url = '${AppConstants.aiHistory}?$params';

    // Bước 2: Gọi API và parse kết quả
    return ApiHandler.get<List<ChatHistoryItem>>(
      url,
      fromJson: (json) => _parseChatHistoryList(json),
    );
  }

  // -----------------------------------------------------------
  // [1.4] CLEAR HISTORY — Xóa toàn bộ lịch sử chat
  // -----------------------------------------------------------
  // Gọi khi: User bấm "Xóa toàn bộ lịch sử" trong menu
  // API: DELETE /api/ai/history
  static Future<ApiResponse<void>> clearHistory() async {
    return ApiHandler.delete<void>(AppConstants.aiHistory);
  }

  // -----------------------------------------------------------
  // [1.5] DELETE CONVERSATION — Xóa 1 conversation theo ID
  // -----------------------------------------------------------
  // Gọi khi: User bấm xóa 1 tin nhắn cụ thể
  // API: DELETE /api/ai/history/{conversationId}
  static Future<ApiResponse<void>> deleteConversation(int conversationId) async {
    return ApiHandler.delete<void>(
      AppConstants.aiDeleteConversation(conversationId),
    );
  }

  // -----------------------------------------------------------
  // [1.6] EXECUTE ACTION — Thực thi hành động AI đề xuất
  // -----------------------------------------------------------
  // Gọi khi: User bấm xác nhận hành động (VD: "Lưu giao dịch")
  // API: POST /api/ai/execute
  // Body: AiExecuteRequest (actionType, params)
  // Trả về: AiChatResponse (kết quả sau khi thực thi)
  static Future<ApiResponse<AiChatResponse>> executeAction(AiExecuteRequest request) async {
    return ApiHandler.post<AiChatResponse>(
      AppConstants.aiExecute, // POST /api/ai/execute
      body: request.toJson(),
      fromJson: (json) => AiChatResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.7] Helper — Parse List<ChatHistoryItem> từ JSON
  // -----------------------------------------------------------
  static List<ChatHistoryItem> _parseChatHistoryList(dynamic json) {
    if (json is List) {
      return json
          .map((e) => ChatHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return []; // Trả rỗng nếu server không trả List
  }
}
