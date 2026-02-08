package fpt.aptech.server.repos.savinggoal;

import fpt.aptech.server.entity.SavingGoal;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SavingGoalRepository  extends JpaRepository<SavingGoal, Integer> {

    List<SavingGoal> findByAccount_Id(Integer accId);

}
