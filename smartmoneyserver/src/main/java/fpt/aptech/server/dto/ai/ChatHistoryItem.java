package fpt.aptech.server.dto.ai;

import fpt.aptech.server.enums.ai.AiIntent;
import lombok.Builder;

import java.time.LocalDateTime;

/**
 * [1] ChatHistoryItem — Lịch sử trò chuyện để hiển thị trong ứng dụng Flutter.
 * <p>
 * Lưu trữ một tin nhắn riêng biệt (của người dùng hoặc AI).
 */
@Builder
public record ChatHistoryItem(
        Integer id,                 // ID trò chuyện trong hệ thống
        String messageContent,      // Nội dung tin nhắn
        Boolean senderType,         // false = Người dùng, true = AI 
        AiIntent intent,            // Ý định trò chuyện
        String attachmentUrl,       // (Optional) Đường dẫn hình ảnh 
        Integer attachmentType,     // 1 = Image, 2 = Voice, Null = Text
        LocalDateTime createdAt     // Thời gian gửi tin
) {}
