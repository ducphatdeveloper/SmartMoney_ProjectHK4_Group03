package fpt.aptech.server.repos.wallet;

import fpt.aptech.server.entity.Wallet;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface WalletRepository extends JpaRepository<Wallet, Integer> {
    List<Wallet> findByAccount_Id(Integer accId);

    List<Wallet> findByAccount_IdAndReportableTrue(Integer accId);
}
