package fpt.aptech.server.dto.transaction.request;

import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Builder
public record TransactionSearchRequest(
    BigDecimal minAmount,
    BigDecimal maxAmount,
    Integer walletId,
    Integer savingGoalId,
    LocalDateTime startDate,
    LocalDateTime endDate,
    String note,
    List<Integer> categoryIds,
    String withPerson
) {}