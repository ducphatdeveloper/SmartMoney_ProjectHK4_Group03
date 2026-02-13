package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Budget;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface BudgetRepository extends JpaRepository<Budget , Integer> {

}
