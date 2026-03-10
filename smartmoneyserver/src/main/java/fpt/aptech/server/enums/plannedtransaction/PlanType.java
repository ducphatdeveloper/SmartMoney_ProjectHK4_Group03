package fpt.aptech.server.enums.plannedtransaction;

import lombok.Getter;

/**
 * Phân loại nghiệp vụ của một giao dịch dự kiến.
 * Dùng cho tPlannedTransactions.plan_type
 */
@Getter
public enum PlanType {
    BILL(1),            // Hóa đơn (cần duyệt tay, số tiền có thể thay đổi)
    RECURRING(2);       // Giao dịch lặp lại (tự động, số tiền cố định)

    private final int value;

    PlanType(int value) {
        this.value = value;
    }
}