package fpt.aptech.server.dto;

import fpt.aptech.server.entity.Transaction;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
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

    public TransactionDto(Transaction transaction) {
        this.id = transaction.getId();
        this.amount = transaction.getAmount();
        this.transDate = transaction.getTransDate();

        if (transaction.getCategory() != null) {
            this.categoryName = transaction.getCategory().getCtgName();
            this.categoryIconUrl = transaction.getCategory().getCtgIconUrl();
            this.isIncome = transaction.getCategory().getCtgType();
        }

        if (transaction.getWallet() != null) {
            // Giả định Wallet entity có phương thức getName() hoặc toString()
            // Nếu Wallet là một entity phức tạp, bạn có thể cần một WalletDto nhỏ
            this.walletName = transaction.getWallet().toString(); 
        }

        if (transaction.getAccount() != null) {
            this.accountEmail = transaction.getAccount().getAccEmail();
        }
    }
}