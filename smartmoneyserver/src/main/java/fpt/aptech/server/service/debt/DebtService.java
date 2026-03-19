package fpt.aptech.server.service.debt;

import fpt.aptech.server.dto.debt.DebtResponse;
import fpt.aptech.server.dto.debt.DebtUpdateRequest;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;

import java.util.List;

public interface DebtService {

    /**
     * Lấy danh sách các khoản nợ theo loại (Cần trả / Cần thu).
     * Flutter tự chia 2 header: "CHƯA TRẢ/CHƯA THU" và "ĐÃ TRẢ/ĐÃ THU" dựa theo field finished.
     */
    List<DebtResponse> getDebts(Integer accId, Boolean debtType);

    /**
     * Lấy chi tiết một khoản nợ.
     */
    DebtResponse getDebt(Integer debtId, Integer accId);

    /**
     * Lấy lịch sử giao dịch của một khoản nợ (flat list).
     */
    List<TransactionResponse> getDebtTransactions(Integer debtId, Integer accId);

    /**
     * Cập nhật thông tin một khoản nợ.
     * Chỉ cho phép sửa: personName, dueDate, note.
     * KHÔNG cho phép sửa: totalAmount, debtType (tính từ transaction).
     */
    DebtResponse updateDebt(Integer debtId, DebtUpdateRequest request, Integer accId);

    /**
     * Toggle trạng thái finished của khoản nợ.
     * Dùng cho nút "Đánh dấu hoàn thành" / "Đánh dấu chưa hoàn thành".
     */
    DebtResponse updateDebtStatus(Integer debtId, Integer accId);

    /**
     * Xóa một khoản nợ.
     * Các giao dịch liên quan sẽ được set debt_id = null (không bị xóa).
     */
    void deleteDebt(Integer debtId, Integer accId);
}