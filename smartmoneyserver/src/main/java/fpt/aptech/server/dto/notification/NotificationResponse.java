package fpt.aptech.server.dto.notification;

import lombok.Builder;
import java.time.LocalDateTime;

/**
 * DTO để trả về thông tin chi tiết của một thông báo.
 * Dùng record để code ngắn gọn và bất biến (immutable).
 */
@Builder
public record NotificationResponse(
    Integer id,
    Integer notifyType,
    Long relatedId,
    String title,
    String content,
    LocalDateTime scheduledTime,
    Boolean notifySent,
    Boolean notifyRead,
    LocalDateTime createdAt
) {}
