package fpt.aptech.server.service.savinggoal;

import fpt.aptech.server.dto.savinggoal.SavingGoalRequest;
import fpt.aptech.server.dto.savinggoal.SavingGoalResponse;


import java.math.BigDecimal;
import java.util.List;

public interface SavingGoalService {

    // ── CRUD ─────────────────────────────────────────────────────────────────
    SavingGoalResponse createSavingGoal(SavingGoalRequest request, Integer userId);

    SavingGoalResponse updateSavingGoalInfo(Integer id, SavingGoalRequest request, Integer userId);

    SavingGoalResponse depositToSavingGoal(Integer id, BigDecimal amount, Integer userId);

    void deleteSavingGoal(Integer id, Integer userId);

    // ── READ ──────────────────────────────────────────────────────────────────
    List<SavingGoalResponse> getSavingGoalsByAccount(Integer userId, String search, Boolean isFinished);

    SavingGoalResponse getSavingGoalDetail(Integer id, Integer userId);
    SavingGoalResponse withdrawFromSavingGoal(Integer id, BigDecimal amount, Integer userId); //[4.1] Rút tiền từ mục tiêu tiết kiệm (giảm currentAmount).
    SavingGoalResponse completeSavingGoal(Integer id, Integer walletId, Integer userId); //[5.1] Chốt sổ mục tiêu: finished=true + đổ toàn bộ tiền về wallet được chọn.
    SavingGoalResponse cancelSavingGoal(Integer id, Integer walletId, Integer userId); //[6.1] Hủy mục tiêu: CANCELLED + finished=true + đổ tiền còn lại về wallet.
}
