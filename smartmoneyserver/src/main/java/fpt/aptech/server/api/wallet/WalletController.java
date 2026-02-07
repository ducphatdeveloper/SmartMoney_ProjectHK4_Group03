    package fpt.aptech.server.api.wallet;

    import fpt.aptech.server.dto.wallet.reponse.WalletResponse;
    import fpt.aptech.server.dto.wallet.request.CreateBasicWalletRequest;
    import fpt.aptech.server.dto.wallet.request.UpdateBasicWalletRequest;
    import fpt.aptech.server.service.wallet.WalletServices;
    import jakarta.validation.Valid;
    import lombok.RequiredArgsConstructor;
    import org.springframework.web.bind.annotation.*;

    import java.util.List;

    @RestController
    @RequestMapping("/api/wallets")
    @RequiredArgsConstructor
    public class WalletController {

        private final WalletServices walletService;

        // ================== BASIC WALLET ==================

        @PostMapping("/basic")
        public WalletResponse createBasic(
              @Valid @RequestBody CreateBasicWalletRequest req) {
            return walletService.createBasicWallet(req);
        }

        @PutMapping("/basic/{id}")
        public WalletResponse updateBasic(
                @PathVariable Integer id,
                @RequestBody UpdateBasicWalletRequest req) {
            return walletService.updateBasicWallet(id, req);
        }

        @DeleteMapping("/basic/{id}")
        public void deleteBasic(@PathVariable Integer id) {
            walletService.deleteBasicWallet(id);
        }

        // =================Lấy danh sách ví theo account
        @GetMapping("/account/{accId}")
        public List<WalletResponse> getWallets(@PathVariable Integer accId) {
            return walletService.getWalletsByAccount(accId);
        }

        // Danh sách ví cơ bản
        @GetMapping("/basic/{accId}")
        public List<WalletResponse> getBasic(@PathVariable Integer accId) {
            return walletService.getBasicWallets(accId);
        }


    }



