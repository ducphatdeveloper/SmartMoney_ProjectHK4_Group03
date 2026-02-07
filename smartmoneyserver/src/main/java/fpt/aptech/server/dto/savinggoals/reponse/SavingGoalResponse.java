package fpt.aptech.server.dto.savinggoals.reponse;

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


    // category (flatten – không trả entity)
    private Integer categoryId;
    private String categoryName;
    private String categoryIconUrl;
}
