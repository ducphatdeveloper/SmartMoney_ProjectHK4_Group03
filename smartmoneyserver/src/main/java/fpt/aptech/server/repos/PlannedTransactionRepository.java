package fpt.aptech.server.repos;

import fpt.aptech.server.entity.PlannedTransaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PlannedTransactionRepository extends JpaRepository<PlannedTransaction, Integer> {
}