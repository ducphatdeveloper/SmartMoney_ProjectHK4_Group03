package fpt.aptech.server.scheduler.wallet;

import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Wallet;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.TransactionRepository;
import fpt.aptech.server.repos.WalletRepository;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Scheduler phát hiện hoạt động chi tiêu bất thường trên ví.
 *
 * ─── LỊCH CHẠY (CRON) ──────────────────────────────────────────────────
 *   JOB 1 — checkAbnormalActivity():  20:00 mỗi tối → Quét chi tiêu bất thường 24h qua
 * ────────────────────────────────────────────────────────────────────────
 * Lý do 20h tối: Cuối ngày là thời điểm tổng hợp giao dịch cả ngày, phát hiện bất thường
 * sau khi user đã hoàn tất hầu hết giao dịch trong ngày. Cùng khung giờ buổi tối với
 * ReminderScheduler.weeklyDigest() (Chủ nhật 20:00).
 *
 * Thông báo được tạo ra (tất cả gọi từ NotificationMessages):
 *   1. abnormalWalletActivity()  → "Cảnh báo chi tiêu bất thường 🚩" — cho USER sở hữu ví
 *   2. adminWalletRiskAlert()    → "Cảnh báo rủi ro ví người dùng 🚨" — cho ADMIN
 *
 * Bảo mật:
 *   - Thông báo user: gắn wallet.getAccount() → chỉ chủ sở hữu ví nhận được.
 *   - Thông báo admin: gắn từng Account admin → chỉ admin nhận được.
 *
 * NotificationType: WALLETS (6) cho user, SYSTEM (4) cho admin
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class WalletScheduler {

    private final TransactionRepository transactionRepository;
    private final WalletRepository walletRepository;
    private final AccountRepository accountRepository;
    private final NotificationService notificationService;

    // Ngưỡng bất thường: > 5 giao dịch chi trong 24h trên cùng 1 ví
    private static final long ABNORMAL_THRESHOLD = 5;

    // ══════════════════════════════════════════════════════════════════════
    // JOB 1 — Quét chi tiêu bất thường (20:00 mỗi tối)
    // Lý do 20h tối: Cuối ngày tổng hợp giao dịch, phát hiện ví nào có > 5 giao dịch chi
    // trong 24h qua → cảnh báo user + admin.
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Quét ví nào có > 5 giao dịch chi tiêu trong 24h qua.
     *
     * Tạo 2 loại thông báo cho MỖI ví bất thường:
     *
     * (A) Cho USER — NotificationMessages.abnormalWalletActivity()
     *     Thông báo: Title="Cảnh báo chi tiêu bất thường 🚩"
     *     Content="Ví 'MoMo' phát sinh 8 giao dịch chi tiêu với tổng 12.500.000 ₫ trong 24h qua. Hãy kiểm tra lại!"
     *
     * (B) Cho ADMIN — NotificationMessages.adminWalletRiskAlert()
     *     Thông báo: Title="Cảnh báo rủi ro ví người dùng 🚨"
     *     Content="Người dùng [minh.pham@gmail.com] tại ví 'MoMo' phát sinh 8 giao dịch bất thường (12.500.000 ₫)."
     */
    @Scheduled(cron = "0 0 20 * * ?") // 20:00 mỗi tối
    public void checkAbnormalActivity() {
        LocalDateTime since = LocalDateTime.now().minusHours(24); // Mốc: 24h trước

        log.info("[WalletScheduler] Checking abnormal spending in last 24h...");

        // Bước 1: Truy vấn ví nào có > ABNORMAL_THRESHOLD giao dịch chi trong 24h
        // Kết quả: [walletId, txCount, totalAmount]
        List<Object[]> abnormalWallets = transactionRepository
                .findAbnormalExpenseWallets(since, ABNORMAL_THRESHOLD);

        // Bước 2: Nếu không có ví bất thường → log và return
        if (abnormalWallets.isEmpty()) {
            log.info("[WalletScheduler] No abnormal spending detected.");
            return;
        }

        // Bước 3: Lấy danh sách Admin để gửi cảnh báo rủi ro (tìm theo role_code)
        List<Account> admins = accountRepository.findByRole_RoleCode("ROLE_ADMIN");

        // Bước 4: Xử lý từng ví bất thường
        int count = 0;
        for (Object[] row : abnormalWallets) {
            try {
                Integer walletId    = (Integer) row[0];   // ID ví
                long txCount        = (Long) row[1];       // Số giao dịch chi
                BigDecimal totalAmt = (BigDecimal) row[2]; // Tổng số tiền chi

                // Bước 4.1: Tìm ví để lấy thông tin + account chủ sở hữu
                Wallet wallet = walletRepository.findById(walletId).orElse(null);
                if (wallet == null) continue; // Ví không tồn tại → bỏ qua

                // Bước 4.2: Gửi cảnh báo cho USER — NotificationMessages.abnormalWalletActivity()
                //   → Title="Cảnh báo chi tiêu bất thường 🚩"
                //   → Content="Ví 'MoMo' phát sinh 8 giao dịch chi tiêu với tổng 12.500.000 ₫ trong 24h qua. Hãy kiểm tra lại!"
                NotificationContent userMsg = NotificationMessages.abnormalWalletActivity(
                        wallet.getWalletName(), (int) txCount, totalAmt);
                notificationService.createNotification(
                        wallet.getAccount(),             // Bảo mật: chỉ chủ ví nhận
                        userMsg.title(), userMsg.content(),
                        NotificationType.WALLETS,        // type = 6 (WALLETS)
                        Long.valueOf(walletId),           // related_id = wallet.id (để Flutter navigate)
                        null                              // scheduledTime = null → gửi ngay
                );

                // Bước 4.3: Gửi cảnh báo cho từng ADMIN — NotificationMessages.adminWalletRiskAlert()
                //   → Title="Cảnh báo rủi ro ví người dùng 🚨"
                //   → Content="Người dùng [minh.pham@gmail.com] tại ví 'MoMo' phát sinh 8 giao dịch bất thường (12.500.000 ₫)."
                for (Account admin : admins) {
                    NotificationContent adminMsg = NotificationMessages.adminWalletRiskAlert(
                            wallet.getAccount().getAccEmail(),  // Email user bị cảnh báo
                            wallet.getWalletName(), (int) txCount, totalAmt);
                    notificationService.createNotification(
                            admin,                       // Bảo mật: chỉ admin nhận
                            adminMsg.title(), adminMsg.content(),
                            NotificationType.SYSTEM,     // type = 4 (SYSTEM) — admin notification
                            Long.valueOf(walletId),       // related_id = wallet.id
                            null                          // scheduledTime = null → gửi ngay
                    );
                }

                count++;
                log.warn("[WalletScheduler] Wallet '{}' (id={}) abnormal: {} transactions, total {}",
                        wallet.getWalletName(), walletId, txCount, totalAmt);
            } catch (Exception e) {
                log.error("[WalletScheduler] Error processing abnormal wallet: {}", e.getMessage());
            }
        }

        log.info("[WalletScheduler] Warned {} abnormal wallets.", count);
    }
}

