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
     *   - totalAmount  = SUM giao dịch Cho vay + Đi vay (nếu có)
     *                    Nếu không có → fallback về debt.totalAmount đã lưu (khoản nợ thủ công)
     *   - paidAmount   = SUM giao dịch Thu nợ + Trả nợ
     *   - remainAmount = totalAmount - paidAmount
     *   - Nếu remain <= 0 → finished=true, deactivate tất cả PlannedTransaction liên kết
     *
     * ⚠️ KHÔNG tự xóa debt. Việc xóa được uỷ quyền cho deleteDebtIfOrphaned()
     *    được gọi từ TransactionServiceImpl.deleteTransaction() khi xóa giao dịch gốc.
     *
     * @param debtId  ID khoản nợ cần tính lại
     * @param account Account của user (để gửi notification debtFullyPaid — có thể null)
     */
    void recalculateDebt(Integer debtId, Account account);

    /**
     * Xóa khoản nợ nếu không còn giao dịch gốc nào liên kết (Cho vay / Đi vay).
     *
     * Được gọi từ TransactionServiceImpl.deleteTransaction() khi user xóa một giao dịch
     * thuộc loại Cho vay (19) hoặc Đi vay (20). Nếu vẫn còn giao dịch gốc khác thì
     * không làm gì (caller sẽ gọi recalculateDebt() để cập nhật lại số liệu).
     *
     * Quy trình:
     *   1. Tính lại SUM(origin transactions) — nếu > 0 → không xóa, return
     *   2. setDebtIdToNull cho tất cả Transaction liên kết
     *   3. deactivateAll + setDebtIdToNull cho PlannedTransaction liên kết
     *   4. JPQL DELETE Debt (không qua entity lifecycle, tránh TransientObjectException)
     *
     * @param debtId ID khoản nợ cần kiểm tra và xóa nếu không còn giao dịch gốc
     */
    void deleteDebtIfOrphaned(Integer debtId);
}