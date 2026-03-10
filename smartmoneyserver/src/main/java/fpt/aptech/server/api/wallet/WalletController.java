package fpt.aptech.server.api.wallet;

import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.dto.wallet.TotalBalanceResponse;
import fpt.aptech.server.dto.wallet.WalletResponse;
import fpt.aptech.server.dto.wallet.WalletRequest;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.wallet.WalletService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/user/wallets")
@RequiredArgsConstructor
@PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
public class WalletController {

    private final WalletService walletService;

    // ================= CREATE =================
    @PostMapping
    public ResponseEntity<ApiResponse<WalletResponse>> createWallet(
            @Valid @RequestBody WalletRequest request,
            @AuthenticationPrincipal Account currentUser
    ) {
        WalletResponse response =
                walletService.createWallet(currentUser.getId(), request);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(ApiResponse.success(response, "Tạo ví thành công"));
    }

    // ================= UPDATE =================
    @PutMapping("/{walletId}")
    public ResponseEntity<ApiResponse<WalletResponse>> updateWallet(
            @PathVariable Integer walletId,
            @Valid @RequestBody WalletRequest request,
            @AuthenticationPrincipal Account currentUser
    ) {
        WalletResponse response =
                walletService.updateWallet(currentUser.getId(), walletId, request);

        return ResponseEntity.ok(
                ApiResponse.success(response, "Cập nhật ví thành công")
        );
    }

    // ================= DELETE =================
    @DeleteMapping("/{walletId}")
    public ResponseEntity<ApiResponse<Void>> deleteWallet(
            @PathVariable Integer walletId,
            @AuthenticationPrincipal Account currentUser
    ) {
        walletService.deleteWallet(currentUser.getId(), walletId);

        return ResponseEntity.ok(
                ApiResponse.success(null, "Xóa ví thành công")
        );
    }

    // ================= DETAIL =================
    @GetMapping("/{walletId}")
    public ResponseEntity<ApiResponse<WalletResponse>> getWalletDetail(
            @PathVariable Integer walletId,
            @AuthenticationPrincipal Account currentUser
    ) {
        WalletResponse response =
                walletService.getWalletById(currentUser.getId(), walletId);

        return ResponseEntity.ok(
                ApiResponse.success(response)
        );
    }

    // ================= LIST + SEARCH =================
    @GetMapping
    public ResponseEntity<ApiResponse<List<WalletResponse>>> getAllWallets(
            @RequestParam(required = false) String search,
            @AuthenticationPrincipal Account currentUser
    ) {
        List<WalletResponse> response =
                walletService.getAllWallets(currentUser.getId(), search);

        return ResponseEntity.ok(
                ApiResponse.success(response)
        );
    }

    // ================= TOTAL BALANCE =================
    @GetMapping("/total-balance")
    public ResponseEntity<ApiResponse<TotalBalanceResponse>> getTotalBalance(
            @AuthenticationPrincipal Account currentUser
    ) {
        TotalBalanceResponse total = walletService.getTotalBalance(currentUser.getId());
        return ResponseEntity.ok(
                ApiResponse.success(total)
        );
    }
}
