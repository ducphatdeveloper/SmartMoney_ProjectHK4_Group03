package fpt.aptech.server.dto.savinggoals.request;

import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Getter
@Setter
public class UpdateSavingGoalRequest {

    private String goalName;
    private BigDecimal targetAmount;
    private LocalDate endDate;
    private String goalImageUrl;
    private Boolean notified;
    private Boolean reportable;
}
