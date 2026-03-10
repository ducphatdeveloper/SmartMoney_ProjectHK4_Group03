package fpt.aptech.server.enums.notification;

import lombok.Getter;

/**
 * Định nghĩa các loại thông báo trong hệ thống.
 * Dùng cho tNotifications.notify_type
 */
@Getter
public enum NotificationType {
    TRANSACTION(1),     // Giao dịch / Biến động số dư
    SAVING(2),          // Mục tiêu tiết kiệm / Quỹ
    BUDGET(3),          // Cảnh báo ngân sách / Vượt hạn mức
    SYSTEM(4),          // Hệ thống / Cập nhật / Bảo mật
    CHAT_AI(5),         // Thông báo từ trợ lý AI
    WALLETS(6),         // Thông báo liên quan đến ví / số dư âm
    EVENTS(7),          // Sự kiện / Lịch trình
    DEBT_LOAN(8),       // Nhắc nợ / Thu nợ
    REMINDER(9);        // Nhắc nhở chung / Daily nhắc ghi chép

    private final int value;

    NotificationType(int value) {
        this.value = value;
    }
}