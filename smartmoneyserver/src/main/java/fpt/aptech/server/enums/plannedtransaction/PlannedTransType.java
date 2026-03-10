package fpt.aptech.server.enums.plannedtransaction;

import lombok.Getter;

/**
 * Phân loại giao dịch sẽ được sinh ra từ một giao dịch dự kiến.
 * Dùng cho tPlannedTransactions.trans_type
 */
@Getter
public enum PlannedTransType {
    EXPENSE(1),         // Khoản chi
    INCOME(2),          // Khoản thu
    LOAN_OUT(3),        // Cho vay
    LOAN_IN(4),         // Đi vay
    DEBT_COLLECT(5),    // Thu nợ
    DEBT_REPAY(6);      // Trả nợ

    private final int value;

    PlannedTransType(int value) {
        this.value = value;
    }
}