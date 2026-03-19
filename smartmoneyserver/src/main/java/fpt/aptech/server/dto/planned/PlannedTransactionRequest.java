package fpt.aptech.server.dto.planned;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDate;

@Builder
public record PlannedTransactionRequest(

        @NotNull(message = "Vui lòng chọn ví")
        Integer walletId,

        @NotNull(message = "Số tiền không được để trống")
        @DecimalMin(value = "0.0", inclusive = false, message = "Số tiền phải lớn hơn 0")
        BigDecimal amount,

        @NotNull(message = "Vui lòng chọn danh mục")
        Integer categoryId,

        // NULL nếu ctg không phải nợ/vay
        Integer debtId,

        String note,

        // 1: Bill | 2: Recurring
        @NotNull(message = "Loại kế hoạch không hợp lệ")
        Integer planType,

        // 1: Ngày | 2: Tuần | 3: Tháng | 4: Năm
        @NotNull(message = "Vui lòng chọn lịch lặp lại")
        Integer repeatType,

        @NotNull(message = "Khoảng lặp không được để trống")
        Integer repeatInterval,

        // Bitmask cho lặp tuần (CN=1,T2=2,T3=4,T4=8,T5=16,T6=32,T7=64)
        Integer repeatOnDayVal,

        @NotNull(message = "Vui lòng chọn ngày bắt đầu")
        LocalDate beginDate,

        // "FOREVER" | "UNTIL_DATE" | "COUNT"
        @NotNull(message = "Vui lòng chọn ngày kết thúc")
        String endDateOption,

        // Dùng khi endDateOption = "UNTIL_DATE"
        LocalDate endDateValue,

        // Dùng khi endDateOption = "COUNT" (số lần lặp)
        Integer repeatCount
) {}