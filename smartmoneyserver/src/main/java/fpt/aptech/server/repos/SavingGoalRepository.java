package fpt.aptech.server.repos;

import fpt.aptech.server.entity.SavingGoal;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SavingGoalRepository  extends JpaRepository<SavingGoal, Integer> {

    List<SavingGoal> findByAccount_Id(Integer accId);
    Optional<SavingGoal> findByIdAndAccount_Id(Integer id, Integer userId);

    // Lấy goal chưa bị Cancelled (status != 3)
    List<SavingGoal> findByAccount_IdAndGoalStatusNot(Integer accId, Integer status);

    // Search theo tên
    List<SavingGoal> findByAccount_IdAndGoalNameContainingIgnoreCaseAndGoalStatusNot(
            Integer accId, String name, Integer status
    );

    // Detail
    Optional<SavingGoal> findByIdAndAccount_IdAndGoalStatusNot(
            Integer id, Integer userId, Integer status
    );
    boolean existsByGoalNameAndAccount_IdAndGoalStatusNot(
            String goalName, Integer accountId, Integer status);


}