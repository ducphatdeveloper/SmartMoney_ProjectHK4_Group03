package fpt.aptech.server.enums.transaction;

import lombok.Getter;

/**
 * Định nghĩa nguồn gốc tạo ra một giao dịch.
 * <p>
 * Dùng cho trường {@code tTransactions.source_type} để biết giao dịch
 * được người dùng nhập tay hay do AI tạo ra.
 */
@Getter
public enum TransactionSourceType {
    MANUAL(1),          // Người dùng nhập thủ công trên form
    CHAT(2),            // Người dùng chat với AI để thêm (VD: "chi 50k cafe")
    VOICE(3),           // Người dùng dùng giọng nói để thêm
    RECEIPT(4),         // Giao dịch được tạo tự động sau khi quét hóa đơn (OCR)
    PLANNED(5);         // Giao dịch được tạo tự động từ PlannedTransaction (Scheduler hoặc Pay Bill)

    private final int value;

    TransactionSourceType(int value) {
        this.value = value;
    }
}
