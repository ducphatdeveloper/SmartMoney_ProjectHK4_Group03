package fpt.aptech.server.dto.savinggoal;

import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Getter
@Builder
public class SavingGoalResponse {

    private Integer id;
    private String goalName;
    private BigDecimal targetAmount;
    private BigDecimal currentAmount;
    private LocalDate endDate;
    private Integer goalStatus;
    private Boolean notified;
    private Boolean reportable;
    private Boolean finished;
    private String currencyCode;
    private String imageUrl;

    // Các trường tính toán thêm để Frontend hiển thị
    private BigDecimal remainingAmount; // Số tiền còn thiếu
    private Double progressPercent;     // % tiến độ
}
