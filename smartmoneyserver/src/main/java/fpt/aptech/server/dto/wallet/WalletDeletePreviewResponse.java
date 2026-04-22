package fpt.aptech.server.dto.wallet;

import fpt.aptech.server.dto.budget.BudgetResponse;
import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Getter
@Builder
public class WalletDeletePreviewResponse {
    // Thông tin ví đang xóa
    private WalletResponse wallet;

    // Danh sách ngân sách liên quan đến ví này
    private List<BudgetResponse> relatedBudgets;

    // Số lượng giao dịch thuộc ví
    private Long transactionCount;

    // Danh sách ví khác của user (để chuyển tiền nếu cần)
    private List<WalletResponse> otherWallets;

    // Số dư hiện tại của ví
    private java.math.BigDecimal currentBalance;
}
