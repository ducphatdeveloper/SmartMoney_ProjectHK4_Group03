package fpt.aptech.server.enums.plannedtransaction;

import lombok.Getter;

/**
 * Định nghĩa các kiểu lặp lại của giao dịch dự kiến.
 * Dùng cho tPlannedTransactions.repeat_type
 */
@Getter
public enum RepeatType {
    NONE(0),            // Không lặp lại
    DAILY(1),           // Hàng ngày
    WEEKLY(2),          // Hàng tuần
    MONTHLY(3),         // Hàng tháng
    YEARLY(4);          // Hàng năm

    private final int value;

    RepeatType(int value) {
        this.value = value;
    }
}