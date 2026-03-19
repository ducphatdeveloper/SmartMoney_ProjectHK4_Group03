package fpt.aptech.server.dto.ai;

import jakarta.validation.constraints.NotBlank;
import lombok.Builder;

/**
 * DTO nhận tin nhắn chat từ người dùng gửi lên AI.
 *
 * 1. message         — Nội dung tin nhắn (bắt buộc)
 * 2. attachmentType  — Loại đính kèm: null=text, 2=voice (tùy chọn)
 */
@Builder
public record AiChatRequest(

    @NotBlank(message = "Nội dung tin nhắn không được để trống.")
    String message,

    // null = chat text | 2 = voice (Flutter đã chuyển giọng nói thành text trước khi gửi)
    Integer attachmentType

) {}

