package fpt.aptech.server.service.wallet;

import fpt.aptech.server.dto.savinggoals.request.CreateSavingGoalRequest;
import fpt.aptech.server.dto.savinggoals.request.UpdateSavingGoalRequest;
import fpt.aptech.server.dto.savinggoals.reponse.SavingGoalResponse;
import fpt.aptech.server.dto.wallet.reponse.TotalWalletResponse;
import fpt.aptech.server.dto.wallet.reponse.WalletResponse;
import fpt.aptech.server.dto.wallet.request.CreateBasicWalletRequest;
import fpt.aptech.server.dto.wallet.request.UpdateBasicWalletRequest;

import java.math.BigDecimal;
import java.util.List;

public interface WalletServices {

    // ================== BASIC WALLET ==================

    WalletResponse createBasicWallet(CreateBasicWalletRequest request);

    WalletResponse updateBasicWallet(Integer id, UpdateBasicWalletRequest request);

    void deleteBasicWallet(Integer id);

    // ================== SAVING GOAL ==================

    SavingGoalResponse createSavingGoal(CreateSavingGoalRequest request);

    SavingGoalResponse updateSavingGoal(Integer id, UpdateSavingGoalRequest request);

    void deleteSavingGoal(Integer id);

    List<WalletResponse> getWalletsByAccount(Integer accId);

    List<SavingGoalResponse> getSavingGoalsByAccount(Integer accId);

    // =================List Basic Wallet
    List<WalletResponse> getBasicWallets(Integer accId);

//    TotalWalletResponse getTotalWallet(Integer accId, String currencyCode);

    // ================= Total Runtime ==============
    TotalWalletResponse getTotalWallet(Integer accId);
}
