package fpt.aptech.server.dto.request;

import lombok.Data;

@Data
public class PushNotificationRequest {
    private String title;
    private String content;
    private Integer targetUserId; // ID của người nhận (nếu gửi đích danh)
    private String targetType;    // ALL (tất cả), INDIVIDUAL (cá nhân), GROUP (nhóm)
}
