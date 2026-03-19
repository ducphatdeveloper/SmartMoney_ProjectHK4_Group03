package fpt.aptech.server.service.planned;

import fpt.aptech.server.dto.planned.PlannedTransactionRequest;
import fpt.aptech.server.dto.planned.PlannedTransactionResponse;

import java.util.List;

public interface PlannedTransactionService {

    // ── Recurring (plan_type=2) ──────────────────────────────────────────
    List<PlannedTransactionResponse> getRecurring(Integer userId, Boolean active);
    PlannedTransactionResponse       getRecurringById(Integer id, Integer userId);
    PlannedTransactionResponse       createRecurring(PlannedTransactionRequest request, Integer userId);
    PlannedTransactionResponse       updateRecurring(Integer id, PlannedTransactionRequest request, Integer userId);
    void                             deleteRecurring(Integer id, Integer userId);
    PlannedTransactionResponse       toggleRecurring(Integer id, Integer userId); // bật/tắt active

    // ── Bills (plan_type=1) ──────────────────────────────────────────────
    List<PlannedTransactionResponse> getBills(Integer userId, Boolean active);
    PlannedTransactionResponse       getBillById(Integer id, Integer userId);
    PlannedTransactionResponse       createBill(PlannedTransactionRequest request, Integer userId);
    PlannedTransactionResponse       updateBill(Integer id, PlannedTransactionRequest request, Integer userId);
    void                             deleteBill(Integer id, Integer userId);
    PlannedTransactionResponse       payBill(Integer id, Integer userId); // user bấm "Trả tiền" → tạo Transaction
    PlannedTransactionResponse       toggleBill(Integer id, Integer userId); // đánh dấu hoàn tất/chưa
}