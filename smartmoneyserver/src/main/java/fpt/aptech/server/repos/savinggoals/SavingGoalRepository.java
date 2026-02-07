package fpt.aptech.server.repos.savinggoals;

import fpt.aptech.server.entity.Savinggoals.SavingGoal;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SavingGoalRepository  extends JpaRepository<SavingGoal, Integer> {
}
