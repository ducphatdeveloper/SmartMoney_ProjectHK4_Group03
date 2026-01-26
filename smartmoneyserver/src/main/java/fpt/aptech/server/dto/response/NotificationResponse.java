package fpt.aptech.server.dto.response;

import lombok.Data;

import java.time.Instant;

@Data
public class NotificationResponse {
    private Integer id;
    private String title;
    private String content;
    private Instant scheduledTime;
    private Boolean isSent;
    private String notificationType; // Ví dụ: SYSTEM, TRANSACTION, PROMOTION
}