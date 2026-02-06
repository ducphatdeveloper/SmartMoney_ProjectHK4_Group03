package fpt.aptech.server.repos.savinggoals;

import fpt.aptech.server.entity.Savinggoals.SavingGoal;
import fpt.aptech.server.entity.Savinggoals.SavingGoalMember;
import fpt.aptech.server.entity.Savinggoals.SavingGoalTransaction;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SavingGoalTransactionRepository extends JpaRepository<SavingGoalTransaction, Integer> {
    List<SavingGoalTransaction> findBySavingGoal_Id(Integer savingGoalId);

    List<SavingGoalTransaction> findByAccount_Id(Integer accId);
    SavingGoalMember findBySavingGoal_IdAndAccount_Id(Integer goalId, Integer accId);

//    List<SavingGoalMember> findBySavingGoal_Id(Integer goalId);
}
