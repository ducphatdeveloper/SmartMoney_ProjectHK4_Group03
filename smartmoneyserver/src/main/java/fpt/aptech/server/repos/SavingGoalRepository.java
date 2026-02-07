package fpt.aptech.server.repos;

import fpt.aptech.server.entity.SavingGoal;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SavingGoalRepository  extends JpaRepository<SavingGoal, Integer> {

    List<SavingGoal> findByAccount_Id(Integer accId);

}
