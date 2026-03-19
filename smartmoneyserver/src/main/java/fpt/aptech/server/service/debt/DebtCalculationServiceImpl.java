package fpt.aptech.server.service.debt;

import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Debt;
import fpt.aptech.server.enums.category.SystemCategory;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.DebtRepository;
import fpt.aptech.server.repos.PlannedTransactionRepository;
import fpt.aptech.server.repos.TransactionRepository;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DebtCalculationServiceImpl implements DebtCalculationService {

    private final DebtRepository               debtRepository;
    private final TransactionRepository        transactionRepository;
    private final PlannedTransactionRepository plannedTransactionRepository;
    private final NotificationService          notificationService;

    // =================================================================================
    // CONSTANTS — Category IDs dùng để phân loại giao dịch nợ
    // =================================================================================

    // IDs giao dịch tạo ra khoản nợ ban đầu (Cho vay + Đi vay)
    private static final List<Integer> DEBT_ORIGIN_IDS = List.of(
            SystemCategory.DEBT_LENDING.getId(),   // 19 Cho vay
            SystemCategory.DEBT_BORROWING.getId()  // 20 Đi vay
    );

    // IDs giao dịch trả/thu nợ (Thu nợ + Trả nợ)
    private static final List<Integer> DEBT_PAYMENT_IDS = List.of(
            SystemCategory.DEBT_COLLECTION.getId(), // 21 Thu nợ
            SystemCategory.DEBT_REPAYMENT.getId()   // 22 Trả nợ
    );

    // =================================================================================
    // 1. TÍNH LẠI NỢ (RECALCULATE)
    // =================================================================================

    /**
     * [1.1] Tính lại toàn bộ trạng thái khoản nợ từ đầu.
     *
     * Bước 1 — Tìm Debt theo ID. Nếu không tồn tại → bỏ qua.
     * Bước 2 — Tính tổng gốc nợ (Cho vay + Đi vay).
     *           Nếu total = 0 → không còn giao dịch gốc → xóa Debt + deactivate Planned.
     * Bước 3 — Tính tổng đã trả/thu (Thu nợ + Trả nợ).
     * Bước 4 — Cập nhật totalAmount (guard CHK_Debts_TotalAmount: total_amount > 0).
     * Bước 5 — Cập nhật remainAmount (không cho âm).
     * Bước 6 — Nếu vừa chuyển trạng thái chưa xong → xong:
     *           deactivate tất cả PlannedTransaction liên kết + gửi thông báo.
     * Bước 7 — Lưu Debt.
     */
    @Override
    @Transactional
    public void recalculateDebt(Integer debtId, Account account) {
        // Bước 1: Tìm Debt
        Debt debt = debtRepository.findById(debtId).orElse(null);
        if (debt == null) return;

        // Bước 2: Tính tổng gốc nợ
        BigDecimal total = transactionRepository
                .sumAmountByDebtIdAndCategoryIds(debtId, DEBT_ORIGIN_IDS);

        // Nếu không còn giao dịch gốc → xóa debt + deactivate planned liên kết
        if (total.compareTo(BigDecimal.ZERO) <= 0) {
            plannedTransactionRepository.deactivateAllByDebtId(debtId);
            plannedTransactionRepository.setDebtIdToNullByDebtId(debtId);
            debtRepository.delete(debt);
            return;
        }

        // Bước 3: Tính tổng đã trả/thu
        BigDecimal paid = transactionRepository
                .sumAmountByDebtIdAndCategoryIds(debtId, DEBT_PAYMENT_IDS);

        // Bước 4: Cập nhật totalAmount
        // Guard: không set total_amount về 0 → vi phạm CHECK (total_amount > 0)
        if (total.compareTo(BigDecimal.ZERO) > 0) {
            debt.setTotalAmount(total);
        }

        // Bước 5: Cập nhật remainAmount (không cho âm)
        BigDecimal remain = total.subtract(paid);
        debt.setRemainAmount(remain.compareTo(BigDecimal.ZERO) < 0
                ? BigDecimal.ZERO : remain);

        // Bước 6: Kiểm tra vừa chuyển từ chưa xong → xong
        boolean wasFinished = Boolean.TRUE.equals(debt.getFinished());
        boolean isFinished  = remain.compareTo(BigDecimal.ZERO) <= 0;

        if (!wasFinished && isFinished) {
            debt.setFinished(true);

            // Deactivate tất cả PlannedTransaction liên kết với debt này
            plannedTransactionRepository.deactivateAllByDebtId(debtId);

            // Gửi thông báo đã trả/thu hết nợ (chỉ khi có account)
            if (account != null) {
                NotificationContent msg = NotificationMessages.debtFullyPaid(
                        debt.getPersonName(),
                        total,
                        !debt.getDebtType() // false=CẦN TRẢ → isPayable=true
                );
                notificationService.createNotification(
                        account,
                        msg.title(), msg.content(),
                        NotificationType.DEBT_LOAN,
                        Long.valueOf(debtId),
                        null
                );
            }
        } else {
            // Cập nhật finished cho các trường hợp còn lại (false → false, true → true)
            debt.setFinished(isFinished);
        }

        // Bước 7: Lưu Debt
        debtRepository.save(debt);
    }
}