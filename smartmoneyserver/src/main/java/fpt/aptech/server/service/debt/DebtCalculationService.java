package fpt.aptech.server.service.debt;

import fpt.aptech.server.entity.Account;

/**
 * Service tập trung toàn bộ logic tính toán lại khoản nợ.
 *
 * Được gọi bởi:
 *   - TransactionServiceImpl  — sau khi tạo/sửa/xóa transaction liên quan debt
 *   - PlannedTransactionServiceImpl — sau khi tạo transaction từ lịch định kỳ
 *
 * Tách ra service riêng để:
 *   1. Tránh trùng lặp logic giữa 2 impl trên
 *   2. Phá vỡ Circular Dependency tiềm ẩn
 *   3. Dễ test, dễ debug khi logic nợ thay đổi
 */
public interface DebtCalculationService {

    /**
     * Tính lại toàn bộ trạng thái khoản nợ từ đầu dựa trên các giao dịch liên quan.
     *
     * Logic:
     *   - totalAmount  = SUM giao dịch Cho vay + Đi vay
     *   - paidAmount   = SUM giao dịch Thu nợ + Trả nợ
     *   - remainAmount = totalAmount - paidAmount
     *   - Nếu total = 0  → không còn giao dịch gốc → xóa debt
     *   - Nếu remain <= 0 → finished=true, deactivate tất cả PlannedTransaction liên kết
     *
     * @param debtId  ID khoản nợ cần tính lại
     * @param account Account của user (để gửi notification debtFullyPaid — có thể null)
     */
    void recalculateDebt(Integer debtId, Account account);
}