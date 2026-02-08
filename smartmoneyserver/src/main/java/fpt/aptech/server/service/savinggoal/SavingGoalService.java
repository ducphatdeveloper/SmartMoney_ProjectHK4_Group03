package fpt.aptech.server.service.savinggoal;

import fpt.aptech.server.dto.savinggoal.reponse.SavingGoalResponse;
import fpt.aptech.server.dto.savinggoal.request.CreateSavingGoalRequest;
import fpt.aptech.server.dto.savinggoal.request.UpdateSavingGoalRequest;

import java.util.List;

public interface SavingGoalService {
    // ================== SAVING GOAL ==================

    SavingGoalResponse createSavingGoal(CreateSavingGoalRequest request);

    SavingGoalResponse updateSavingGoal(Integer id, UpdateSavingGoalRequest request);




    void deleteSavingGoal(Integer id, Integer accId);

    List<SavingGoalResponse> getSavingGoalsByAccount(Integer accId);

}
