package fpt.aptech.server.service.savinggoal;

import fpt.aptech.server.dto.savinggoal.SavingGoalRequest;
import fpt.aptech.server.dto.savinggoal.SavingGoalResponse;


import java.math.BigDecimal;
import java.util.List;

public interface SavingGoalService {
    // ================== SAVING GOAL ==================

    SavingGoalResponse createSavingGoal(SavingGoalRequest request, Integer userId);

    SavingGoalResponse updateSavingGoalInfo(Integer id, SavingGoalRequest request, Integer userId);

    SavingGoalResponse depositToSavingGoal(Integer id, BigDecimal amount, Integer userId);

    // ================= CREATE =================

    void deleteSavingGoal(Integer id, Integer userId);

    List<SavingGoalResponse> getSavingGoalsByAccount(Integer userId, String search);

    SavingGoalResponse getSavingGoalDetail(Integer id, Integer userId);



}
