package fpt.aptech.server.mapper.notification;

import fpt.aptech.server.dto.notification.NotificationResponse;
import fpt.aptech.server.entity.Notification;
import org.mapstruct.Mapper;

import java.util.List;

/**
 * Mapper để chuyển đổi giữa Notification Entity và DTO.
 * componentModel = "spring": Để Spring Boot có thể tự động inject Mapper này.
 */
@Mapper(componentModel = "spring")
public interface NotificationMapper {

    /**
     * Chuyển đổi một đối tượng Notification (Entity) sang NotificationResponse (DTO).
     */
    NotificationResponse toResponse(Notification notification);

    /**
     * Chuyển đổi một danh sách Notification (Entity) sang danh sách NotificationResponse (DTO).
     */
    List<NotificationResponse> toResponseList(List<Notification> notifications);
}
