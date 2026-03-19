package fpt.aptech.server.dto.ai;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Builder;

import java.util.Map;

/**
 * DTO phản hồi từ AI Chat trả về cho client.
 *
 * 1. conversationId  — ID tin nhắn AI (dùng để gắn aiChatId khi execute)
 * 2. reply           — Nội dung AI phản hồi (hiển thị trên giao diện chat)
 * 3. intent          — Mục đích phân loại: 1=add_transaction | 2=report | 3=budget | 4=general | 5=remind
 * 4. action          — Hành động gợi ý (null nếu là general_chat)
 */
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public record AiChatResponse(

    Integer conversationId,

    String reply,

    Integer intent,

    AiAction action

) {

    /**
     * Mô tả hành động AI gợi ý hoặc đã thực thi.
     *
     * 1. type      — Loại hành động: "create_transaction", "query_report", ...
     * 2. executed  — true nếu AI đã tự động thực thi (auto-commit), false nếu cần user xác nhận hoặc gợi ý.
     * 3. params    — Tham số chi tiết (categoryId, walletId, amount, note, ...)
     * 4. suggestions — Danh sách các lựa chọn nhanh cho user (VD: ["Ăn sáng", "Ăn trưa", "Cafe"])
     */
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record AiAction(
        String type,
        Boolean executed,
        Map<String, Object> params,
        java.util.List<String> suggestions
    ) {}
}
