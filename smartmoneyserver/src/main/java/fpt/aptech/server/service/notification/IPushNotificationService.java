package fpt.aptech.server.service.notification;

/**
 * Interface định nghĩa "hợp đồng" cho việc gửi Push Notification.
 * Nếu sau này đổi từ Firebase sang provider khác (OneSignal, AWS SNS...),
 * chỉ cần tạo implementation mới mà không cần sửa code ở các Service khác.
 */
public interface IPushNotificationService {

    /**
     * Gửi Push Notification tới tất cả thiết bị đang đăng nhập của một user.
     *
     * @param accId ID tài khoản cần gửi thông báo.
     * @param title Tiêu đề thông báo hiển thị trên điện thoại.
     * @param body  Nội dung chi tiết thông báo.
     */
    void sendToUser(Integer accId, String title, String body);
}