package fpt.aptech.server.dto.planned;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDate;

@Builder
public record PlannedTransactionRequest(

        @NotNull(message = "Please select a wallet")
        Integer walletId,

        @NotNull(message = "Amount cannot be empty")
        @DecimalMin(value = "0.0", inclusive = false, message = "Amount must be greater than 0")
        BigDecimal amount,

        @NotNull(message = "Please select a category")
        Integer categoryId,

        // NULL nếu ctg không phải nợ/vay
        Integer debtId,

        String note,

        // 1: Bill | 2: Recurring
        @NotNull(message = "Invalid plan type")
        Integer planType,

        // 1: Ngày | 2: Tuần | 3: Tháng | 4: Năm
        @NotNull(message = "Please select repeat schedule")
        Integer repeatType,

        @NotNull(message = "Repeat interval cannot be empty")
        Integer repeatInterval,

        // Bitmask cho lặp tuần (CN=1,T2=2,T3=4,T4=8,T5=16,T6=32,T7=64)
        Integer repeatOnDayVal,

        @NotNull(message = "Please select start date")
        LocalDate beginDate,

        // "FOREVER" | "UNTIL_DATE" | "COUNT"
        @NotNull(message = "Please select end date option")
        String endDateOption,

        // Dùng khi endDateOption = "UNTIL_DATE"
        LocalDate endDateValue,

        // Dùng khi endDateOption = "COUNT" (số lần lặp)
        Integer repeatCount
) {}