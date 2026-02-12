package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Wallet;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface WalletRepository extends JpaRepository<Wallet, Integer> {
    List<Wallet> findByAccountId(Integer accountId);

    List<Wallet> findByAccountIdAndWalletNameContainingIgnoreCase(Integer accountId, String walletName);


}
