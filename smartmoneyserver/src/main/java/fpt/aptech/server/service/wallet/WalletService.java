package fpt.aptech.server.service.wallet;

import fpt.aptech.server.dto.wallet.reponse.WalletResponse;
import fpt.aptech.server.dto.wallet.request.CreateBasicWalletRequest;
import fpt.aptech.server.dto.wallet.request.UpdateBasicWalletRequest;

import java.util.List;

public interface WalletService {

    // ================== BASIC WALLET ==================

    WalletResponse createBasicWallet(CreateBasicWalletRequest request);

    WalletResponse updateBasicWallet(Integer id, UpdateBasicWalletRequest request);

    void deleteBasicWallet(Integer id);

    List<WalletResponse> getWalletsByAccount(Integer accId);


    // =================List Basic Wallet
    List<WalletResponse> getBasicWallets(Integer accId);

//    TotalWalletResponse getTotalWallet(Integer accId, String currencyCode);

    // ================= Total Runtime =============

}
