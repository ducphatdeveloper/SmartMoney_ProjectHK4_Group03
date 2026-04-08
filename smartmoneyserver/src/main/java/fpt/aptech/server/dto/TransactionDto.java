package fpt.aptech.server.dto;

import fpt.aptech.server.entity.Transaction;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TransactionDto {
    private Long id;
    private BigDecimal amount;
    private String description;
    private LocalDateTime transDate;
    private String categoryName;
    private String categoryIconUrl;
    private Boolean isIncome; // true if income, false if expense
    private String walletName;
    private String accountEmail;
    private Boolean deleted;
    private LocalDateTime deletedAt;

    public TransactionDto(Transaction transaction) {
        this.id = transaction.getId();
        this.amount = transaction.getAmount();
        this.description = transaction.getNote();
        this.transDate = transaction.getTransDate();
        this.deleted = transaction.getDeleted();
        this.deletedAt = transaction.getDeletedAt();

        if (transaction.getCategory() != null) {
            this.categoryName = transaction.getCategory().getCtgName();
            this.categoryIconUrl = transaction.getCategory().getCtgIconUrl();
            this.isIncome = transaction.getCategory().getCtgType();
        }

        if (transaction.getWallet() != null) {
            this.walletName = transaction.getWallet().getWalletName(); 
        } else if (transaction.getSavingGoal() != null) {
            this.walletName = transaction.getSavingGoal().getGoalName();
        }

        if (transaction.getAccount() != null) {
            this.accountEmail = transaction.getAccount().getAccEmail();
        }
    }
}
