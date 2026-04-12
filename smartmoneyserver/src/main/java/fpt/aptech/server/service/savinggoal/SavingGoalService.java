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
    List<SavingGoalResponse> getSavingGoalsByAccount(Integer userId, String search);

    SavingGoalResponse getSavingGoalDetail(Integer id, Integer userId);

    // ── TOGGLE ACTIVE / CANCELLED ─────────────────────────────────────────────
    // ACTIVE → CANCELLED (finished=true)  : tạm dừng / kết thúc sớm
    // CANCELLED → ACTIVE (finished=false) : kích hoạt lại
    // OVERDUE   → ACTIVE (finished=false) : kích hoạt lại mục tiêu quá hạn
    SavingGoalResponse togglePauseSavingGoal(Integer id, Integer userId);

}
