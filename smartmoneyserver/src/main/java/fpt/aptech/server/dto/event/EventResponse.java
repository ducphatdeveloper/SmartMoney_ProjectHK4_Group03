package fpt.aptech.server.dto.event;

import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * DTO để trả về thông tin chi tiết của một sự kiện.
 * Bao gồm các trường tính toán sẵn để Frontend dễ dàng hiển thị.
 */
@Builder(toBuilder = true) // Bật tính năng toBuilder()
public record EventResponse(
        Integer id,
        String eventName,
        String eventIconUrl,
        LocalDate beginDate,
        LocalDate endDate,
        Boolean finished,
        String currencyCode,

        // Các trường tính toán thêm
        BigDecimal totalIncome,
        BigDecimal totalExpense,
        BigDecimal netAmount // = totalIncome - totalExpense
) {}
