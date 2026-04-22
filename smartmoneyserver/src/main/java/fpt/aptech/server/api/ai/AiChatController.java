package fpt.aptech.server.api.ai;

import fpt.aptech.server.dto.ai.AiChatRequest;
import fpt.aptech.server.dto.ai.AiChatResponse;
import fpt.aptech.server.dto.ai.AiExecuteRequest;
import fpt.aptech.server.dto.ai.ChatHistoryItem;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.ai.AIConversationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

/**
 * Controller xử lý các request liên quan đến AI Chat và OCR Hóa đơn.
 */
@Slf4j
@RestController
@RequestMapping("/api/ai")
@RequiredArgsConstructor
public class AiChatController {

    private final AIConversationService aiService; // Biến service xử lý logic AI

    // =========================================================================
    // NHÓM API TRÒ CHUYỆN VÀ XỬ LÝ AI
    // =========================================================================

    /**
     * [1.1] Xử lý tin nhắn văn bản từ người dùng gửi cho AI.
     * <p>
     * <b>Cách dùng:</b><br>
     * 1. Gửi chuỗi nội dung tin nhắn và loại đính kèm (nếu có).<br>
     * 2. AI sẽ phân tích và trả về phản hồi kèm theo intent tương ứng.
     */
    @PostMapping("/chat")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<AiChatResponse>> chat(
            @Valid @RequestBody AiChatRequest request,
            @AuthenticationPrincipal Account currentUser) {

        // Bước 1: Ghi log request
        log.info("[AI Controller] User id={} gửi tin nhắn chat", currentUser.getId());
        
        // Bước 2: Gọi Service để xử lý tin nhắn
        AiChatResponse response = aiService.chat(currentUser, request);

        // Bước 3: Trả về kết quả (thông báo tiếng Anh theo yêu cầu)
        return ResponseEntity.ok(ApiResponse.success(response, "Processed successfully"));
    }

    /**
     * [1.2] Tải lên ảnh hóa đơn để AI nhận diện (OCR).
     * <p>
     * <b>Cách dùng:</b><br>
     * 1. Gửi file ảnh hóa đơn qua form-data.<br>
     * 2. Truyền walletId (nếu muốn tạo giao dịch ngay).<br>
     * 3. AI đọc ảnh và tự động trích xuất thông tin giao dịch.
     */
    @PostMapping("/upload-receipt")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<AiChatResponse>> uploadReceipt(
            @RequestParam("image") MultipartFile image,
            @RequestParam(value = "walletId", required = false) Integer walletId,
            @AuthenticationPrincipal Account currentUser) {

        // Bước 1: Ghi log request
        log.info("[AI Controller] User id={} tải lên ảnh hóa đơn OCR", currentUser.getId());
        
        // Bước 2: Gọi Service upload và phân tích OCR
        AiChatResponse response = aiService.uploadReceipt(currentUser, image, walletId);

        // Bước 3: Trả về kết quả (thông báo tiếng Anh)
        return ResponseEntity.ok(ApiResponse.success(response, "Receipt processed successfully"));
    }

    // =========================================================================
    // NHÓM API QUẢN LÝ LỊCH SỬ TRÒ CHUYỆN
    // =========================================================================

    /**
     * [2.1] Lấy lịch sử trò chuyện của người dùng với AI (có phân trang).
     */
    @GetMapping("/history")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<ChatHistoryItem>>> getHistory(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @AuthenticationPrincipal Account currentUser) {

        // Bước 1: Ghi log request
        log.info("[AI Controller] User id={} lấy lịch sử chat (page={}, size={})", currentUser.getId(), page, size);
        
        // Bước 2: Gọi Service lấy lịch sử phân trang
        List<ChatHistoryItem> history = aiService.getChatHistory(currentUser, page, size);

        // Bước 3: Trả về kết quả (thông báo tiếng Anh)
        return ResponseEntity.ok(ApiResponse.success(history, "History retrieved successfully"));
    }

    /**
     * [2.2] Xóa toàn bộ lịch sử trò chuyện của người dùng hiện tại.
     */
    @DeleteMapping("/history")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> clearHistory(
            @AuthenticationPrincipal Account currentUser) {

        // Bước 1: Ghi log request
        log.info("[AI Controller] User id={} xóa toàn bộ lịch sử", currentUser.getId());

        // Bước 2: Gọi Service xóa dữ liệu DB
        aiService.clearHistory(currentUser);

        // Bước 3: Trả về trạng thái thành công (thông báo tiếng Anh)
        return ResponseEntity.ok(ApiResponse.success(null, "All chat history cleared"));
    }

    /**
     * [2.3] Xóa một cuộc trò chuyện riêng lẻ theo ID.
     */
    @DeleteMapping("/history/{conversationId}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> deleteConversationById(
            @PathVariable Integer conversationId,
            @AuthenticationPrincipal Account currentUser) {

        // Bước 1: Ghi log request
        log.info("[AI Controller] User id={} xóa conversation id={}", currentUser.getId(), conversationId);

        // Bước 2: Gọi Service xóa dữ liệu DB
        aiService.deleteConversationById(conversationId, currentUser.getId());

        // Bước 3: Trả về trạng thái thành công (thông báo tiếng Anh)
        return ResponseEntity.ok(ApiResponse.success(null, "Conversation deleted successfully"));
    }

    // =========================================================================
    // NHÓM API THỰC THI HÀNH ĐỘNG AI
    // =========================================================================

    /**
     * [3.1] Xác nhận thực thi một hành động mà AI đề xuất (Ví dụ: lưu giao dịch).
     */
    @PostMapping("/execute")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<AiChatResponse>> executeAction(
            @Valid @RequestBody AiExecuteRequest request,
            @AuthenticationPrincipal Account currentUser) {

        // Bước 1: Ghi log request
        log.info("[AI Controller] User id={} yêu cầu thực thi hành động: {}", currentUser.getId(), request.actionType());
        
        // Bước 2: Gọi Service thực thi action tương ứng
        AiChatResponse response = aiService.executeAction(currentUser, request);

        // Bước 3: Trả về kết quả sau khi thực thi (thông báo tiếng Anh)
        return ResponseEntity.ok(ApiResponse.success(response, "Action executed successfully"));
    }
}
