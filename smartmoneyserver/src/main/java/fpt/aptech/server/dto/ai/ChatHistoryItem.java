package fpt.aptech.server.dto.ai;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Builder;

import java.time.LocalDateTime;

/**
 * DTO hiển thị một tin nhắn trong lịch sử chat AI.
 *
 * 1. id              — ID tin nhắn
 * 2. messageContent  — Nội dung tin nhắn
 * 3. senderType      — false=User | true=AI
 * 4. intent          — Mục đích: 1-5 hoặc null
 * 5. attachmentUrl   — URL file đính kèm (nếu có)
 * 6. attachmentType  — 1=image | 2=voice | null=text
 * 7. createdAt       — Thời gian gửi
 */
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ChatHistoryItem(
    Integer id,
    String messageContent,
    Boolean senderType,
    Integer intent,
    String attachmentUrl,
    Integer attachmentType,
    LocalDateTime createdAt
) {}

