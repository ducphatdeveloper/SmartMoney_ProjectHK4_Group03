package fpt.aptech.server.service.notification;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import fpt.aptech.server.entity.UserDevice;
import fpt.aptech.server.repos.UserDeviceRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;

// @Service: Đây là implementation Firebase của IPushNotificationService.
// Spring Boot sẽ tự inject class này khi có nơi nào @Autowired IPushNotificationService.
@Service
@RequiredArgsConstructor
@Slf4j
public class FirebasePushNotificationService implements IPushNotificationService {

    private final UserDeviceRepository userDeviceRepository;

    // Bước 1: Override method từ interface, thực thi bằng Firebase FCM.
    @Override
    public void sendToUser(Integer accId, String title, String body) {

        // Bước 2: Lấy tất cả thiết bị đang đăng nhập của user từ DB.
        List<UserDevice> devices = userDeviceRepository.findAllByAccount_IdAndLoggedInTrue(accId);

        // Bước 3: Nếu không có thiết bị nào đang đăng nhập → bỏ qua.
        if (devices.isEmpty()) {
            log.info("  -> Người dùng (ID: {}) không có thiết bị nào đang đăng nhập. Bỏ qua gửi thông báo.", accId);
            return;
        }

        // Bước 4: Lặp qua từng thiết bị, gửi thông báo riêng cho từng device token.
        for (UserDevice device : devices) {
            try {
                // Bước 4.1: Tạo nội dung thông báo (title + body).
                Notification notification = Notification.builder()
                        .setTitle(title)
                        .setBody(body)
                        .build();

                // Bước 4.2: Tạo Message gắn với device token cụ thể của thiết bị.
                Message message = Message.builder()
                        .setNotification(notification)
                        .setToken(device.getDeviceToken())
                        .build();

                // Bước 4.3: Gọi Firebase API gửi thông báo → Firebase lo việc chuyển phát.
                String response = FirebaseMessaging.getInstance().send(message);
                log.info("  -> Gửi thông báo tới thiết bị (Token: {}...) thành công. Response: {}",
                        device.getDeviceToken().substring(0, 20), response);

            } catch (Exception e) {
                // Nếu 1 thiết bị lỗi → log cảnh báo và tiếp tục gửi cho thiết bị khác.
                log.error("  -> Gửi thông báo tới thiết bị (ID: {}) thất bại. Lý do (có thể do Token giả/không hợp lệ): {}", device.getId(), e.getMessage());
            }
        }
    }
}
