package fpt.aptech.server.service.Admin;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.dto.TransactionDto;
import fpt.aptech.server.dto.PageResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Transaction;
import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.entity.UserDevice;
import fpt.aptech.server.entity.Wallet;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.enums.contact.ContactRequestType;
import fpt.aptech.server.enums.contact.ContactRequestStatus;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.UserDeviceRepository;
import fpt.aptech.server.repos.TransactionRepository;
import fpt.aptech.server.repos.ContactRequestRepository; // Import ContactRequestRepository
import fpt.aptech.server.service.notification.NotificationService;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import jakarta.persistence.criteria.Subquery;
import lombok.extern.slf4j.Slf4j;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Objects;
import java.util.Map;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class AdminServiceImp implements AdminService {

    private final AccountRepository accountRepository;
    private final UserDeviceRepository userDeviceRepository;
    private final NotificationService notificationService;
    private final TransactionRepository transactionRepository;
    private final ContactRequestRepository contactRequestRepository; // Inject ContactRequestRepository

    @Override
    public PageResponse<AccountDto> getUsers(String search, Boolean locked, String onlineStatus, Pageable pageable) {
        LocalDateTime activeThreshold = LocalDateTime.now().minusMinutes(5);

        Specification<Account> spec = (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(criteriaBuilder.equal(root.get("role").get("id"), 2));
            
            if (search != null && !search.trim().isEmpty()) {
                String searchKey = "%" + search.toLowerCase() + "%";
                predicates.add(criteriaBuilder.or(
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("accEmail")), searchKey),
                        criteriaBuilder.like(root.get("accPhone"), "%" + search + "%")
                ));
            }
            if (locked != null) predicates.add(criteriaBuilder.equal(root.get("locked"), locked));

            if (onlineStatus != null && !onlineStatus.isEmpty()) {
                boolean filterOnline = "online".equalsIgnoreCase(onlineStatus);
                Subquery<Integer> onlineSubquery = query.subquery(Integer.class);
                Root<UserDevice> deviceRoot = onlineSubquery.from(UserDevice.class);
                onlineSubquery.select(deviceRoot.get("account").get("id"));
                
                onlineSubquery.where(
                        criteriaBuilder.isTrue(deviceRoot.get("loggedIn")),
                        criteriaBuilder.greaterThan(deviceRoot.get("lastActive"), activeThreshold)
                );

                if (filterOnline) {
                    predicates.add(root.get("id").in(onlineSubquery));
                } else {
                    predicates.add(criteriaBuilder.not(root.get("id").in(onlineSubquery)));
                }
            }
            
            return criteriaBuilder.and(predicates.toArray(new Predicate[0]));
        };

        Page<Account> accountPage = accountRepository.findAll(spec, pageable);
        List<Account> accounts = accountPage.getContent();
        List<Integer> accountIds = accounts.stream().map(Account::getId).collect(Collectors.toList());

        Map<Integer, List<UserDevice>> activeDeviceMap = userDeviceRepository
                .findActiveDevicesByAccountIds(accountIds, activeThreshold).stream()
                .collect(Collectors.groupingBy(d -> d.getAccount().getId()));

        List<AccountDto> dtoList = accounts.stream().map(account -> {
            AccountDto dto = new AccountDto(account);
            List<UserDevice> activeSessions = activeDeviceMap.getOrDefault(account.getId(), new ArrayList<>());
            dto.setOnline(!activeSessions.isEmpty());
            dto.setOnlineDevicesCount(activeSessions.size());
            dto.setLastActive(activeSessions.stream()
                    .map(UserDevice::getLastActive)
                    .filter(Objects::nonNull)
                    .max(LocalDateTime::compareTo)
                    .orElse(null));
            dto.setOnlinePlatforms(activeSessions.stream()
                    .map(d -> d.getDeviceName() != null ? d.getDeviceName() : "Unknown")
                    .distinct().collect(Collectors.toList()));
            return dto;
        }).collect(Collectors.toList());

        return new PageResponse<>(new PageImpl<>(dtoList, pageable, accountPage.getTotalElements()));
    }

    @Override
    @Transactional
    public void lockAccount(Integer id) {
        Account account = accountRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy tài khoản ID: " + id));

        // Check for an APPROVED ContactRequest of type ACCOUNT_LOCK
        contactRequestRepository.findFirstByAccountIdAndRequestTypeAndRequestStatusOrderByCreatedAtDesc(
                id, ContactRequestType.ACCOUNT_LOCK, ContactRequestStatus.APPROVED)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy yêu cầu khóa tài khoản đã được duyệt cho ID: " + id));

        account.setLocked(true);
        accountRepository.saveAndFlush(account);
        try {
            List<UserDevice> devices = userDeviceRepository.findAllByAccount_Id(id);
            if (devices != null && !devices.isEmpty()) {
                devices.forEach(device -> device.setRefreshToken(null));
                userDeviceRepository.saveAll(devices);
                userDeviceRepository.flush();
            }
        } catch (Exception e) { log.warn("Không thể thu hồi token: {}", e.getMessage()); }
        try {
            NotificationContent msg = NotificationMessages.accountLocked();
            notificationService.createNotification(account, msg.title(), msg.content(), NotificationType.SYSTEM, null, LocalDateTime.now());
        } catch (Exception e) { log.warn("Không thể gửi thông báo khóa: {}", e.getMessage()); }
    }

    @Override
    @Transactional
    public void unlockAccount(Integer id) {
        Account account = accountRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy tài khoản ID: " + id));

        // Check for an APPROVED ContactRequest of type ACCOUNT_UNLOCK
        contactRequestRepository.findFirstByAccountIdAndRequestTypeAndRequestStatusOrderByCreatedAtDesc(
                id, ContactRequestType.ACCOUNT_UNLOCK, ContactRequestStatus.APPROVED)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy yêu cầu mở khóa tài khoản đã được duyệt cho ID: " + id));

        account.setLocked(false);
        accountRepository.save(account);
        accountRepository.flush();
        try {
            NotificationContent msg = NotificationMessages.accountUnlocked();
            notificationService.createNotification(account, msg.title(), msg.content(), NotificationType.SYSTEM, null, LocalDateTime.now());
        } catch (Exception e) { log.warn("Không thể gửi thông báo mở khóa: {}", e.getMessage()); }
    }

    @Override
    public Map<String, Object> getDashboardOverview() {
        LocalDateTime activeThreshold = LocalDateTime.now().minusMinutes(5);
        Map<String, Object> stats = new HashMap<>();
        stats.put("totalUsers", accountRepository.count());
        stats.put("totalTransactions", transactionRepository.count());
        stats.put("onlineUsers", userDeviceRepository.countActiveUsers(activeThreshold));
        stats.put("activeDevices", userDeviceRepository.countByLoggedInTrue());
        stats.put("newUsersGrowth", accountRepository.countNewUsersByMonth());
        return stats;
    }

    @Override
    public List<Notification> getAdminNotifications(Integer adminId) {
        return notificationService.getNotificationsByType(NotificationType.SYSTEM.getValue());
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<TransactionDto> getUserTransactions(Integer userId, Pageable pageable, String deletedStatus, String type) {
        boolean includeDeleted = "ALL".equalsIgnoreCase(deletedStatus) || "DELETED".equalsIgnoreCase(deletedStatus);
        boolean onlyDeleted = "DELETED".equalsIgnoreCase(deletedStatus);
        Boolean isIncome = parseType(type);
        Page<Transaction> transactions = transactionRepository.findAllUserTransactionsWithFilter(userId, includeDeleted, onlyDeleted, isIncome, pageable);
        List<TransactionDto> dtoList = transactions.getContent().stream().map(TransactionDto::new).collect(Collectors.toList());
        return new PageResponse<>(new PageImpl<>(dtoList, pageable, transactions.getTotalElements()));
    }

    @Override
    @Transactional(readOnly = true)
    public List<TransactionDto> getAllUserTransactions(Integer userId, String deletedStatus, String type) {
        boolean includeDeleted = "ALL".equalsIgnoreCase(deletedStatus) || "DELETED".equalsIgnoreCase(deletedStatus);
        boolean onlyDeleted = "DELETED".equalsIgnoreCase(deletedStatus);
        Boolean isIncome = parseType(type);
        return transactionRepository.findAllUserTransactionsWithFilter(userId, includeDeleted, onlyDeleted, isIncome).stream().map(TransactionDto::new).collect(Collectors.toList());
    }

    private Boolean parseType(String type) {
        if ("INCOME".equalsIgnoreCase(type)) return true;
        if ("EXPENSE".equalsIgnoreCase(type)) return false;
        return null;
    }

    /**
     * [CẬP NHẬT] Thống kê hệ thống dựa trên startDate và endDate thực tế từ Client.
     * Tính tổng của bảng Transaction (toàn bộ User) theo startDate và endDate là 100%.
     * Các hạng mục Category và Saving Goal là % dựa theo tổng giao dịch toàn hệ thống.
     */
    @Override
    public Map<String, Object> getSystemTransactionStats(LocalDateTime startDate, LocalDateTime endDate) {
        // Dự phòng nếu Client không gửi ngày (mặc định lấy tháng hiện tại)
        if (startDate == null) startDate = LocalDate.now().with(TemporalAdjusters.firstDayOfMonth()).atStartOfDay();
        if (endDate == null) endDate = LocalDateTime.now();

        // 1. Tổng volume thực tế TOÀN HỆ THỐNG = 100%
        BigDecimal totalVolume = transactionRepository.getTotalVolumeRange(startDate, endDate);
        if (totalVolume == null) totalVolume = BigDecimal.ZERO;

        // 2. Thống kê theo danh mục (Category) của TOÀN HỆ THỐNG
        List<Object[]> rawStats = transactionRepository.getGlobalCategoryStats(startDate, endDate);
        BigDecimal income = BigDecimal.ZERO; 
        BigDecimal expense = BigDecimal.ZERO;

        List<Map<String, Object>> breakdown = new ArrayList<>();
        for (Object[] row : rawStats) {
            String ctgName = (String) row[0];
            BigDecimal amount = row[1] != null ? (BigDecimal) row[1] : BigDecimal.ZERO;
            Boolean ctgType = (Boolean) row[2];
            String ctgIconUrl = (String) row[3];
            String parentName = (String) row[4];

            if (Boolean.TRUE.equals(ctgType)) income = income.add(amount);
            else expense = expense.add(amount);

            // Tính % dựa trên tổng volume của toàn hệ thống (không phải của 1 user)
            BigDecimal pct = (totalVolume.compareTo(BigDecimal.ZERO) > 0)
                    ? amount.multiply(new BigDecimal("100")).divide(totalVolume, 4, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;

            Map<String, Object> item = new HashMap<>();
            item.put("categoryName", ctgName);
            item.put("parentName", parentName != null ? parentName : "");
            item.put("amount", amount);
            item.put("percentage", pct);
            item.put("type", Boolean.TRUE.equals(ctgType) ? "INCOME" : "EXPENSE");
            item.put("iconUrl", ctgIconUrl);
            breakdown.add(item);
        }

        // 3. Thống kê theo mục tiêu tiết kiệm (Saving Goals) của TOÀN HỆ THỐNG
        List<Object[]> goalStats = transactionRepository.getGlobalGoalStats(startDate, endDate);
        List<Map<String, Object>> goalBreakdown = new ArrayList<>();
        for (Object[] row : goalStats) {
            String goalName = (String) row[0];
            BigDecimal amount = row[1] != null ? (BigDecimal) row[1] : BigDecimal.ZERO;
            
            // Tính % dựa trên tổng volume của toàn hệ thống
            BigDecimal pct = (totalVolume.compareTo(BigDecimal.ZERO) > 0)
                    ? amount.multiply(new BigDecimal("100")).divide(totalVolume, 4, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;

            Map<String, Object> item = new HashMap<>();
            item.put("goalName", goalName);
            item.put("amount", amount);
            item.put("percentage", pct);
            goalBreakdown.add(item);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("totalSystemVolume", totalVolume);
        result.put("summary", Map.of(
                "incomeTotal", income,
                "expenseTotal", expense,
                "incomePercentage", totalVolume.compareTo(BigDecimal.ZERO) > 0 ? income.multiply(new BigDecimal("100")).divide(totalVolume, 2, RoundingMode.HALF_UP) : 0,
                "expensePercentage", totalVolume.compareTo(BigDecimal.ZERO) > 0 ? expense.multiply(new BigDecimal("100")).divide(totalVolume, 2, RoundingMode.HALF_UP) : 0
        ));
        result.put("breakdown", breakdown);
        result.put("goalBreakdown", goalBreakdown);
        result.put("generatedAt", LocalDateTime.now());
        result.put("startDate", startDate);
        result.put("endDate", endDate);

        return result;
    }
//
//    @Override
//    public void notifyAbnormalTransactions(BigDecimal threshold) {
//        int frequencyThreshold = 10;
//        LocalDateTime since = LocalDateTime.now().minusDays(1);
//        List<Transaction> recentTransactions = transactionRepository.findAllByTransDateAfter(since);
//        Map<Wallet, List<Transaction>> walletActivity = recentTransactions.stream()
//                .filter(t -> t.getCategory() != null && Boolean.FALSE.equals(t.getCategory().getCtgType()))
//                .filter(t -> t.getWallet() != null)
//                .collect(Collectors.groupingBy(Transaction::getWallet));
//
//        walletActivity.forEach((wallet, transList) -> {
//            BigDecimal walletTotalExpense = transList.stream().map(Transaction::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add);
//            if (walletTotalExpense.compareTo(threshold) > 0 || transList.size() >= frequencyThreshold) {
//                Account userAccount = transList.get(0).getAccount();
//                String walletName = wallet.getWalletName() != null ? wallet.getWalletName() : "Ví người dùng";
//                NotificationContent userMsg = NotificationMessages.abnormalWalletActivity(walletName, transList.size(), walletTotalExpense);
//                notificationService.createNotification(userAccount, userMsg.title(), userMsg.content(), NotificationType.TRANSACTION, null, LocalDateTime.now());
//
//                NotificationContent adminMsg = NotificationMessages.adminWalletRiskAlert(userAccount.getAccEmail(), walletName, transList.size(), walletTotalExpense);
//                List<Account> admins = accountRepository.findByRole_RoleCode("ROLE_ADMIN");
//                for (Account admin : admins) {
//                    notificationService.createNotification(admin, adminMsg.title(), adminMsg.content(), NotificationType.SYSTEM, null, LocalDateTime.now());
//                }
//            }
//        });
//    }
//
//    @Override
//    public List<Map<String, Object>> getAbnormalTransactionUsers(BigDecimal threshold) {
//        int frequencyThreshold = 10;
//        LocalDateTime since = LocalDateTime.now().minusDays(1);
//        List<Transaction> recentTransactions = transactionRepository.findAllByTransDateAfter(since);
//        Map<Account, List<Transaction>> groupedByAccount = recentTransactions.stream()
//                .filter(t -> t.getCategory() != null && Boolean.FALSE.equals(t.getCategory().getCtgType()))
//                .collect(Collectors.groupingBy(Transaction::getAccount));
//
//        return groupedByAccount.entrySet().stream().map(entry -> {
//            Account acc = entry.getKey();
//            Map<Wallet, List<Transaction>> byWallet = entry.getValue().stream().filter(t -> t.getWallet() != null).collect(Collectors.groupingBy(Transaction::getWallet));
//            List<Map<String, Object>> abnormalWallets = new ArrayList<>();
//            BigDecimal userTotal = BigDecimal.ZERO;
//            for (Map.Entry<Wallet, List<Transaction>> wEntry : byWallet.entrySet()) {
//                BigDecimal wTotal = wEntry.getValue().stream().map(Transaction::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add);
//                if (wTotal.compareTo(threshold) > 0 || wEntry.getValue().size() >= frequencyThreshold) {
//                    abnormalWallets.add(Map.of("walletName", wEntry.getKey().getWalletName(), "transactionCount", wEntry.getValue().size(), "totalSpent", wTotal));
//                    userTotal = userTotal.add(wTotal);
//                }
//            }
//            if (abnormalWallets.isEmpty()) return null;
//            return Map.of("userId", acc.getId(), "username", acc.getFullname() != null ? acc.getFullname() : acc.getAccEmail(), "abnormalWallets", abnormalWallets, "totalAmount", userTotal, "transactionCount", entry.getValue().size());
//        }).filter(Objects::nonNull).collect(Collectors.toList());
//    }

    @Override
    public long countOnlineUsers() { return userDeviceRepository.countActiveUsers(LocalDateTime.now().minusMinutes(5)); }

    @Override
    public List<AccountDto> getAllLiveOnlineUsers() {
        LocalDateTime threshold = LocalDateTime.now().minusMinutes(5);
        return userDeviceRepository.findActiveDevicesBySince(threshold).stream()
                .collect(Collectors.groupingBy(UserDevice::getAccount))
                .entrySet().stream().map(e -> {
                    AccountDto d = new AccountDto(e.getKey());
                    d.setOnline(true); d.setOnlineDevicesCount(e.getValue().size());
                    d.setLastActive(e.getValue().stream().map(UserDevice::getLastActive).filter(Objects::nonNull).max(LocalDateTime::compareTo).orElse(null));
                    return d;
                }).collect(Collectors.toList());
    }

    @Override
    @Transactional
    public void handleAutoLogout() {
        LocalDateTime timeout = LocalDateTime.now().minusMinutes(30);
        List<UserDevice> stale = userDeviceRepository.findAllLoggedInDevicesWithAccount().stream().filter(d -> d.getLastActive() != null && d.getLastActive().isBefore(timeout)).collect(Collectors.toList());
        if (!stale.isEmpty()) {
            stale.forEach(d -> { d.setRefreshToken(null); d.setLoggedIn(false); });
            userDeviceRepository.saveAll(stale);
        }
    }

    @Override
    @Transactional(readOnly = true)
    public Map<String, Object> getUserFinancialInsights(Integer userId) {
        Account acc = accountRepository.findById(userId).orElseThrow(() -> new RuntimeException("User not found"));
        return Map.of("userInfo", new AccountDto(acc), "totalIncome", transactionRepository.sumAmountByAccountAndType(userId, true), "totalExpense", transactionRepository.sumAmountByAccountAndType(userId, false));
    }

    @Override
    @Transactional
    public void restoreTransaction(Long transactionId) {
        Transaction transaction = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy giao dịch ID: " + transactionId));
        if (Boolean.FALSE.equals(transaction.getDeleted())) {
            throw new RuntimeException("Giao dịch này hiện không bị xóa.");
        }
        transactionRepository.restoreTransaction(transactionId);
        log.info("Admin đã khôi phục giao dịch ID: {}", transactionId);
    }

    @Override
    @Transactional
    public void restoreAllUserTransactions(Integer userId) {
        accountRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy người dùng ID: " + userId));
        transactionRepository.restoreAllUserTransactions(userId);
        log.info("Admin đã khôi phục tất cả giao dịch cho người dùng ID: {}", userId);
    }
}
