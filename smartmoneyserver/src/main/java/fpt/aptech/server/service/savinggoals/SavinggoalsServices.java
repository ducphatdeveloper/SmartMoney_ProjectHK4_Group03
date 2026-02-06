package fpt.aptech.server.service.savinggoals;

import fpt.aptech.server.dto.savinggoals.reponse.SavingGoalResponse;
import fpt.aptech.server.dto.savinggoals.request.AddSavingMemberRequest;
import fpt.aptech.server.dto.savinggoals.request.CreateSavingGoalRequest;
import fpt.aptech.server.dto.savinggoals.request.DepositSavingRequest;
import fpt.aptech.server.dto.savinggoals.request.UpdateSavingGoalRequest;

import java.util.List;

public interface SavinggoalsServices {
    // ================== SAVING GOAL ==================

    SavingGoalResponse createSavingGoal(CreateSavingGoalRequest request);

    SavingGoalResponse updateSavingGoal(Integer id, UpdateSavingGoalRequest request);

    void deleteSavingGoal(Integer id, Integer accId);

    List<SavingGoalResponse> getSavingGoalsByAccount(Integer accId);

    void addMember(Integer savingGoalId, Integer ownerId, AddSavingMemberRequest request);

    SavingGoalResponse deposit(Integer savingGoalId, DepositSavingRequest request);
}
