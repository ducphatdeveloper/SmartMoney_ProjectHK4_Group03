package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Wallet;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface WalletRepository extends JpaRepository<Wallet, Integer> {
    List<Wallet> findByAccount_Id(Integer accId);

    List<Wallet> findByAccount_IdAndReportableTrue(Integer accId);
}
