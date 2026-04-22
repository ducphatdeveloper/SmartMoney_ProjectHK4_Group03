package fpt.aptech.server.enums.ai;

import lombok.Getter;

/**
 * [1] AiIntent — Định nghĩa mục đích của tin nhắn AI (Intent).
 * <p>
 * Dùng cho trường {@code tAIConversations.intent} để biết người dùng
 * đang muốn thực hiện thao tác gì với ứng dụng.
 */
@Getter
public enum AiIntent {
    ADD_TRANSACTION(1),   // Thêm giao dịch mới
    VIEW_REPORT(2),       // Xem báo cáo chi tiêu
    VIEW_BUDGET(3),       // Xem ngân sách
    GENERAL_CHAT(4),      // Trò chuyện, tư vấn tài chính chung
    REMIND_TASK(5);       // Đặt nhắc nhở

    private final int value; // Giá trị lưu vào database

    AiIntent(int value) {
        this.value = value;
    }

    // =========================================================================
    // HELPER METHODS
    // =========================================================================

    /**
     * [HELPER] Lấy enum từ giá trị integer (từ database).
     * Trả về GENERAL_CHAT nếu không tìm thấy.
     */
    public static AiIntent fromValue(Integer value) {
        // Bước 1: Kiểm tra giá trị null
        if (value == null) {
            return GENERAL_CHAT;
        }
        
        // Bước 2: Duyệt qua các enum để tìm giá trị tương ứng
        for (AiIntent intent : values()) {
            if (intent.value == value) {
                return intent;
            }
        }
        
        // Bước 3: Trả về mặc định nếu không khớp
        return GENERAL_CHAT;
    }
}
