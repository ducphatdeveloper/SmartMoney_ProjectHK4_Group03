package fpt.aptech.server.service.wallet;

import fpt.aptech.server.dto.wallet.TotalBalanceResponse;
import fpt.aptech.server.dto.wallet.TransferRequest;
import fpt.aptech.server.dto.wallet.TransferResponse;
import fpt.aptech.server.dto.wallet.WalletDeletePreviewResponse;
import fpt.aptech.server.dto.wallet.WalletRequest;
import fpt.aptech.server.dto.wallet.WalletResponse;

import java.math.BigDecimal;
import java.util.List;

public interface WalletService {

    // ================== BASIC WALLET ==================
    WalletResponse createWallet(Integer accountId, WalletRequest request);

    WalletResponse updateWallet(Integer accountId, Integer walletId, WalletRequest request);

    void deleteWallet(Integer accountId, Integer walletId);

    WalletResponse getWalletById(Integer accountId, Integer walletId);

    List<WalletResponse> getAllWallets(Integer accountId , String search);

    // Lấy tổng số dư hiện tại của người dùng
    TotalBalanceResponse getTotalBalance(Integer accountId);

    // ================== TRANSFER MONEY ==================
    TransferResponse transferMoney(Integer accountId, TransferRequest request);

    // ================== DELETE PREVIEW ==================
    WalletDeletePreviewResponse getDeletePreview(Integer accountId, Integer walletId);
}
