package fpt.aptech.server.api.ai;

import fpt.aptech.server.dto.ai.AiChatRequest;
import fpt.aptech.server.dto.ai.AiChatResponse;
import fpt.aptech.server.dto.ai.AiExecuteRequest;
import fpt.aptech.server.dto.ai.ChatHistoryItem;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.ai.AiChatService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Controller xử lý API cho module AI Chat.
 *
 * Endpoints:
 * 1. POST /api/ai/chat    — Gửi tin nhắn chat → AI phân tích → trả gợi ý hành động
 * 2. POST /api/ai/execute — Xác nhận thực thi hành động AI gợi ý (tạo giao dịch, ...)
 * 3. GET  /api/ai/history — Lấy lịch sử chat của người dùng (cũ → mới)
 */
@RestController
@RequestMapping("/api/ai")
@RequiredArgsConstructor
public class AiChatController {

    private final AiChatService aiChatService;

    // =========================================================================
    // 1. CHAT — Gửi tin nhắn → AI phân tích
    // =========================================================================

    /**
     * [1.1] Gửi tin nhắn chat cho AI phân tích.
     * AI sẽ phân loại intent và trả về gợi ý hành động (nếu có).
     * Client hiển thị reply + action params cho user xác nhận trước khi execute.
     */
    @PostMapping("/chat")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<AiChatResponse>> chat(
            @Valid @RequestBody AiChatRequest request,
            @AuthenticationPrincipal Account currentUser) {

        Integer userId = currentUser.getId();
        AiChatResponse response = aiChatService.chat(request, userId);

        return ResponseEntity.ok(ApiResponse.success(response));
    }

    // =========================================================================
    // 2. EXECUTE — Xác nhận thực thi hành động
    // =========================================================================

    /**
     * [2.1] Xác nhận và thực thi hành động AI gợi ý.
     * Hiện tại hỗ trợ: "create_transaction".
     * Client gửi params đã được AI phân tích + aiChatId để tạo giao dịch.
     */
    @PostMapping("/execute")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Object>> execute(
            @Valid @RequestBody AiExecuteRequest request,
            @AuthenticationPrincipal Account currentUser) {

        Integer userId = currentUser.getId();
        Object result = aiChatService.execute(request, userId);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(ApiResponse.success(result, "Thực thi hành động thành công."));
    }

    // =========================================================================
    // 3. HISTORY — Lấy lịch sử chat
    // =========================================================================

    /**
     * [3.1] Lấy toàn bộ lịch sử chat của người dùng.
     * Sắp xếp từ cũ → mới (hiển thị chat tự nhiên).
     */
    @GetMapping("/history")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<ChatHistoryItem>>> getHistory(
            @AuthenticationPrincipal Account currentUser) {

        Integer userId = currentUser.getId();
        List<ChatHistoryItem> history = aiChatService.getHistory(userId);

        return ResponseEntity.ok(ApiResponse.success(history));
    }
}

