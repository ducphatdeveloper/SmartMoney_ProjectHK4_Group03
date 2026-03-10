package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Budget;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface BudgetRepository extends JpaRepository<Budget, Integer> {
    List<Budget> findByAccount_Id(Integer accountId);

    // Tìm các ngân sách đang có hiệu lực trong ngày hôm nay
    @Query("SELECT b FROM Budget b WHERE :today BETWEEN b.beginDate AND b.endDate")
    List<Budget> findActiveBudgets(@Param("today") LocalDate today);
}
