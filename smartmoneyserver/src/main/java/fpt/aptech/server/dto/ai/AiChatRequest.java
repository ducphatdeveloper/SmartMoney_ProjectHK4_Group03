package fpt.aptech.server.dto.ai;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Builder;

/**
 * [1] AiChatRequest — DTO nhận yêu cầu chat từ ứng dụng Flutter.
 * <p>
 * Nhận nội dung văn bản (hoặc lời nói đã được chuyển thành văn bản).
 */
@Builder
public record AiChatRequest(
        // Bước 1: Validate tin nhắn không rỗng và độ dài tối đa
        @NotBlank(message = "Tin nhắn không được để trống")
        @Size(max = 2000, message = "Tin nhắn không được vượt quá 2000 ký tự")
        @JsonProperty("message")
        String message,             // Nội dung tin nhắn của người dùng

        // Bước 2: Nhận loại đính kèm để phân biệt text/image/voice
        @JsonProperty("attachmentType")
        Integer attachmentType      // null = text | 1 = image | 2 = voice
) {
    @JsonCreator
    public static AiChatRequest create(
            @JsonProperty("message") String message,
            @JsonProperty("attachmentType") Integer attachmentType) {
        return new AiChatRequest(message, attachmentType);
    }
}
