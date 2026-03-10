package fpt.aptech.server.enums.debt;

import lombok.Getter;

/**
 * Định nghĩa loại nợ trong sổ nợ.
 * Dùng cho tDebts.debt_type
 */
@Getter
public enum DebtType {
    PAYABLE(0),         // Khoản phải trả (Đi vay)
    RECEIVABLE(1);      // Khoản phải thu (Cho vay)

    private final int value;

    DebtType(int value) {
        this.value = value;
    }
}