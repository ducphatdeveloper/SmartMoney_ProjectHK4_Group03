package fpt.aptech.server.repos.savinggoals;

import fpt.aptech.server.entity.Savinggoals.SavingGoalMember;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SavingGoalMemberRepository
        extends JpaRepository<SavingGoalMember, Integer> {

    boolean existsBySavingGoal_IdAndAccount_Id(Integer goalId, Integer accId);

    SavingGoalMember findBySavingGoal_IdAndAccount_Id(Integer goalId, Integer accId);

    List<SavingGoalMember> findBySavingGoal_Id(Integer goalId);
    List<SavingGoalMember> findByAccount_Id(Integer accId);
}
