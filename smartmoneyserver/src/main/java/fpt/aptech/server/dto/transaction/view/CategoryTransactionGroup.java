package fpt.aptech.server.dto.transaction.view;

import lombok.Builder;

import java.math.BigDecimal;
import java.util.List;

/**
 * DTO cho giao diện gom nhóm giao dịch theo danh mục.
 */
@Builder
public record CategoryTransactionGroup(
    // Thông tin của nhóm (dùng cho header)
    Integer categoryId,
    String categoryName,
    String categoryIconUrl,
    Boolean categoryType,

    // Dữ liệu tóm tắt của nhóm
    BigDecimal totalAmount,
    int transactionCount,

    // Danh sách chi tiết các giao dịch trong nhóm
    List<TransactionResponse> transactions
) {}
