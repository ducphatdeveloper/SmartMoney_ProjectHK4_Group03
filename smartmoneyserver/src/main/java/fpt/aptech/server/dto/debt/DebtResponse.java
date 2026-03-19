package fpt.aptech.server.dto.debt;

import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * DTO để trả về thông tin chi tiết của một khoản nợ.
 */
@Builder(toBuilder = true)
public record DebtResponse(
        Integer id,
        String personName,
        Boolean debtType, // false: Cần Trả, true: Cần Thu
        BigDecimal totalAmount,
        BigDecimal remainAmount,
        BigDecimal paidAmount, // = totalAmount - remainAmount (tính trong service)
        Boolean finished,
        LocalDateTime dueDate,
        String note,
        LocalDateTime createdAt
) {}
