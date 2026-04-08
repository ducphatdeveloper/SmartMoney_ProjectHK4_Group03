package fpt.aptech.server.dto.transaction.report;

import lombok.Builder;

import java.math.BigDecimal;
import java.util.List;

/**
 * DTO tổng hợp cho màn hình Dashboard "All-in-One".
 * Chứa tất cả thông tin cần thiết để hiển thị bức tranh tài chính toàn cảnh.
 */
@Builder
public record FinancialReportResponse(
    // 2. Tổng tài sản hiện tại của người dùng (Tất cả các ví)
    BigDecimal totalCurrentBalance,

    // 3. Danh sách chi tiết cho biểu đồ Chi phí (Kèm trung bình ngày)
    List<CategoryReportDTO> expenseCategories,

    // 4. Danh sách chi tiết cho biểu đồ Thu nhập (Kèm trung bình ngày)
    List<CategoryReportDTO> incomeCategories
) {}
