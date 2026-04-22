package fpt.aptech.server.service.Admin;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.dto.TransactionDto;
import fpt.aptech.server.dto.PageResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Transaction;
import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.entity.UserDevice;
import fpt.aptech.server.entity.ContactRequest;
import fpt.aptech.server.enums.contact.ContactRequestStatus;
import fpt.aptech.server.enums.contact.ContactRequestType;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.*;
import fpt.aptech.server.service.debt.DebtCalculationService;
import fpt.aptech.server.service.notification.NotificationService;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.Query;
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
import java.util.Arrays;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class AdminServiceImp implements AdminService {

    private final AccountRepository accountRepository;
    private final UserDeviceRepository userDeviceRepository;
    private final NotificationService notificationService;
    private final NotificationRepository notificationRepository;
    private final TransactionRepository transactionRepository;
    private final DebtCalculationService debtCalculationService;
    private final ContactRequestRepository contactRequestRepository;

    @PersistenceContext
    private EntityManager entityManager;

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

    /**
     * Khóa tài khoản.
     * ✅ Yêu cầu: Phải dựa trên ContactRequest (ACCOUNT_LOCK) ở trạng thái APPROVED mới nhất.
     * ✅ Ràng buộc: Phải là yêu cầu mới nhất liên quan đến trạng thái tài khoản (dựa trên thời gian và ID).
     */
    @Override
    @Transactional
    public void lockAccount(Integer id) {
        Account account = accountRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy ID tài khoản: " + id));

        // 1. Lấy yêu cầu mới nhất liên quan đến LOCK/UNLOCK (Sắp xếp theo createdAt DESC, id DESC)
        ContactRequest latestRequest = contactRequestRepository.findFirstByAccountIdAndRequestTypeInOrderByCreatedAtDescIdDesc(
                        id, Arrays.asList(ContactRequestType.ACCOUNT_LOCK, ContactRequestType.ACCOUNT_UNLOCK))
                .orElseThrow(() -> new RuntimeException("Người dùng chưa tạo bất kỳ yêu cầu hỗ trợ nào liên quan đến trạng thái tài khoản."));

        // 2. Kiểm tra tính hợp lệ của yêu cầu mới nhất
        if (latestRequest.getRequestType() != ContactRequestType.ACCOUNT_LOCK) {
            throw new RuntimeException("Yêu cầu mới nhất của người dùng là " + latestRequest.getRequestType() + ". Không thể thực hiện KHÓA.");
        }

        if (latestRequest.getRequestStatus() != ContactRequestStatus.APPROVED) {
            throw new RuntimeException("Yêu cầu KHÓA TÀI KHOẢN mới nhất (#" + latestRequest.getId() + ") chưa được phê duyệt.");
        }

        // 3. Khóa tài khoản
        account.setLocked(true);
        accountRepository.save(account);

        // 4. Thu hồi toàn bộ phiên đăng nhập
        try {
            userDeviceRepository.revokeAllSessionsByAccountId(id);
        } catch (Exception e) {
            log.warn("Không thể thu hồi session cho account {}: {}", id, e.getMessage());
        }
        
        // 5. Gửi thông báo
        try {
            NotificationContent msg = NotificationMessages.accountLocked();
            notificationService.createNotification(account, msg.title(), msg.content(), NotificationType.SYSTEM, null, LocalDateTime.now());
        } catch (Exception e) { 
            log.warn("Không thể gửi thông báo khóa: {}", e.getMessage()); 
        }
    }

    /**
     * Mở khóa tài khoản.
     * ✅ Yêu cầu: Phải dựa trên ContactRequest (ACCOUNT_UNLOCK) ở trạng thái APPROVED mới nhất.
     * ✅ Ràng buộc: Phải là yêu cầu mới nhất liên quan đến trạng thái tài khoản (dựa trên thời gian và ID).
     */
    @Override
    @Transactional
    public void unlockAccount(Integer id) {
        Account account = accountRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy ID tài khoản: " + id));

        // 1. Lấy yêu cầu mới nhất liên quan đến LOCK/UNLOCK (Sắp xếp theo createdAt DESC, id DESC)
        ContactRequest latestRequest = contactRequestRepository.findFirstByAccountIdAndRequestTypeInOrderByCreatedAtDescIdDesc(
                        id, Arrays.asList(ContactRequestType.ACCOUNT_LOCK, ContactRequestType.ACCOUNT_UNLOCK))
                .orElseThrow(() -> new RuntimeException("Người dùng chưa tạo bất kỳ yêu cầu hỗ trợ nào liên quan đến trạng thái tài khoản."));

        // 2. Kiểm tra tính hợp lệ của yêu cầu mới nhất
        if (latestRequest.getRequestType() != ContactRequestType.ACCOUNT_UNLOCK) {
            throw new RuntimeException("Yêu cầu mới nhất của người dùng là " + latestRequest.getRequestType() + ". Không thể thực hiện MỞ KHÓA.");
        }

        if (latestRequest.getRequestStatus() != ContactRequestStatus.APPROVED) {
            throw new RuntimeException("Yêu cầu MỞ KHÓA TÀI KHOẢN mới nhất (#" + latestRequest.getId() + ") chưa được phê duyệt.");
        }

        // 3. Mở khóa tài khoản
        account.setLocked(false);
        accountRepository.save(account);

        // 4. Gửi thông báo
        try {
            NotificationContent msg = NotificationMessages.accountUnlocked();
            notificationService.createNotification(account, msg.title(), msg.content(), NotificationType.SYSTEM, null, LocalDateTime.now());
        } catch (Exception e) { 
            log.warn("Không thể gửi thông báo mở khóa: {}", e.getMessage());
        }
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
        // [CẬP NHẬT] Chỉ lấy thông báo hệ thống (SYSTEM) cho trang Admin, sắp xếp mới nhất
        return notificationRepository.findAllVisibleNotificationsByNotifyTypeOrderByScheduledTimeDesc(
                NotificationType.SYSTEM.getValue(), 
                LocalDateTime.now()
        );
    }

    @Override
    @Transactional
    public void markNotificationAsRead(Integer notificationId) {
        Notification n = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy thông báo"));
        if (!n.getNotifyRead()) {
            n.setNotifyRead(true);
            notificationRepository.save(n);
        }
    }

    @Override
    @Transactional
    public void markAllNotificationsAsRead() {
        // Chỉ đánh dấu các thông báo SYSTEM của Admin là đã đọc
        List<Notification> unread = notificationRepository.findAllVisibleNotificationsByNotifyTypeOrderByScheduledTimeDesc(
                NotificationType.SYSTEM.getValue(),
                LocalDateTime.now()
        ).stream().filter(n -> !n.getNotifyRead()).toList();

        if (!unread.isEmpty()) {
            unread.forEach(n -> n.setNotifyRead(true));
            notificationRepository.saveAll(unread);
        }
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<TransactionDto> getUserTransactions(Integer userId, Pageable pageable, String deletedStatus, String type) {
        int includeDeleted = ("ALL".equalsIgnoreCase(deletedStatus) || "DELETED".equalsIgnoreCase(deletedStatus)) ? 1 : 0;
        int onlyDeleted = "DELETED".equalsIgnoreCase(deletedStatus) ? 1 : 0;
        Boolean isIncome = parseType(type);
        
        Page<Transaction> transactions = transactionRepository.findAllUserTransactionsNativePage(
                userId, includeDeleted, onlyDeleted, isIncome, pageable);
                
        List<TransactionDto> dtoList = transactions.getContent().stream()
                .map(TransactionDto::new)
                .collect(Collectors.toList());
                
        return new PageResponse<>(new PageImpl<>(dtoList, pageable, transactions.getTotalElements()));
    }

    @Override
    @Transactional(readOnly = true)
    public List<TransactionDto> getAllUserTransactions(Integer userId, String deletedStatus, String type) {
        int includeDeleted = ("ALL".equalsIgnoreCase(deletedStatus) || "DELETED".equalsIgnoreCase(deletedStatus)) ? 1 : 0;
        int onlyDeleted = "DELETED".equalsIgnoreCase(deletedStatus) ? 1 : 0;
        Boolean isIncome = parseType(type);
        
        return transactionRepository.findAllUserTransactionsNative(userId, includeDeleted, onlyDeleted, isIncome)
                .stream()
                .map(TransactionDto::new)
                .collect(Collectors.toList());
    }

    private Boolean parseType(String type) {
        if ("INCOME".equalsIgnoreCase(type)) return true;
        if ("EXPENSE".equalsIgnoreCase(type)) return false;
        return null;
    }

    @Override
    public Map<String, Object> getSystemTransactionStats(LocalDateTime startDate, LocalDateTime endDate) {
        if (startDate == null) startDate = LocalDate.now().with(TemporalAdjusters.firstDayOfMonth()).atStartOfDay();
        if (endDate == null) endDate = LocalDateTime.now();

        BigDecimal totalVolume = transactionRepository.getTotalVolumeRange(startDate, endDate);
        if (totalVolume == null) totalVolume = BigDecimal.ZERO;

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

        List<Object[]> goalStats = transactionRepository.getGlobalGoalStats(startDate, endDate);
        List<Map<String, Object>> goalBreakdown = new ArrayList<>();
        for (Object[] row : goalStats) {
            String goalName = (String) row[0];
            BigDecimal amount = row[1] != null ? (BigDecimal) row[1] : BigDecimal.ZERO;
            
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
        Account acc = accountRepository.findById(userId).orElseThrow(() -> new RuntimeException("Không tìm thấy người dùng"));
        AccountDto userInfo = new AccountDto(acc);
        return Map.of(
            "userInfo", userInfo, 
            "totalIncome", transactionRepository.sumLifetimeByAccountAndType(userId, true), 
            "totalExpense", transactionRepository.sumLifetimeByAccountAndType(userId, false)
        );
    }

    @Override
    @Transactional
    public void restoreTransaction(Long transactionId) {
        Transaction tx = transactionRepository.findAnyById(transactionId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy ID giao dịch: " + transactionId));
        
        if (Boolean.FALSE.equals(tx.getDeleted())) {
            throw new RuntimeException("Giao dịch này hiện không ở trạng thái đã xóa.");
        }

        log.info("Attempting to restore transaction ID: {} (Account ID: {})", transactionId, tx.getAccount().getId());

        boolean isIncome = tx.getCategory() != null && Boolean.TRUE.equals(tx.getCategory().getCtgType());
        
        if (tx.getWallet() != null) {
            if (isIncome) transactionRepository.applyWalletBalanceForIncome(transactionId);
            else transactionRepository.applyWalletBalanceForExpense(transactionId);
        } else if (tx.getSavingGoal() != null) {
            if (isIncome) transactionRepository.applyGoalBalanceForIncome(transactionId);
            else transactionRepository.applyGoalBalanceForExpense(transactionId);
        }

        transactionRepository.restoreTransaction(transactionId);
        
        entityManager.flush();
        entityManager.refresh(tx);

        if (tx.getDebt() != null) {
            debtCalculationService.recalculateDebt(tx.getDebt().getId(), tx.getAccount());
        }

        log.info("Transaction ID: {} restored successfully. New deleted status: {}", transactionId, tx.getDeleted());

        try {
            String title = "Transaction has been restored";
            String content = "Transaction worth " + tx.getAmount().toString() + " has been successfully restored by the Admin.";
            notificationService.createNotification(tx.getAccount(), title, content, NotificationType.SYSTEM, tx.getId(), LocalDateTime.now());
        } catch (Exception e) {
            log.warn("Giao dịch đã khôi phục nhưng không thể gửi thông báo: {}", e.getMessage());
        }
    }

    @Override
    @Transactional
    public void restoreAllUserTransactions(Integer userId) {
        Account account = accountRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy ID người dùng: " + userId));
        
        log.info("Khôi phục tất cả các giao dịch đã xóa cho ID người dùng: {}", userId);

        List<Transaction> deletedTxs = transactionRepository.findAllUserTransactionsNative(userId, 0, 1, null);
        
        if (deletedTxs.isEmpty()) {
            log.info("Không tìm thấy giao dịch nào đã bị xóa cho ID người dùng này.: {}", userId);
            return;
        }

        for (Transaction tx : deletedTxs) {
            boolean isIncome = tx.getCategory() != null && Boolean.TRUE.equals(tx.getCategory().getCtgType());
            if (tx.getWallet() != null) {
                if (isIncome) transactionRepository.applyWalletBalanceForIncome(tx.getId());
                else transactionRepository.applyWalletBalanceForExpense(tx.getId());
            } else if (tx.getSavingGoal() != null) {
                if (isIncome) transactionRepository.applyGoalBalanceForIncome(tx.getId());
                else transactionRepository.applyGoalBalanceForExpense(tx.getId());
            }
        }

        transactionRepository.restoreAllUserTransactions(userId);
        
        entityManager.flush();

        deletedTxs.stream()
                .map(Transaction::getDebt)
                .filter(Objects::nonNull)
                .map(fpt.aptech.server.entity.Debt::getId)
                .distinct()
                .forEach(debtId -> debtCalculationService.recalculateDebt(debtId, account));

        try {
            String title = "Transaction has been restored";
            String content = "All of your deleted transactions have been successfully restored by the Admin.";
            notificationService.createNotification(account, title, content, NotificationType.SYSTEM, null, LocalDateTime.now());
        } catch (Exception e) {
            log.warn("Đã khôi phục nhưng không thể gửi thông báo cho user {}: {}", userId, e.getMessage());
        }

        entityManager.clear(); 
        log.info("Tất cả các giao dịch đã bị xóa cho ID người dùng: {} khôi phục thành công.", userId);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Map<String, Object>> getGlobalDeletedTransactions() {
        Query query = entityManager.createNativeQuery("SELECT * FROM vAdminDeletedTransactions ORDER BY deleted_at DESC");
        List<Object[]> results = query.getResultList();

        return results.stream().map(row -> {
            Map<String, Object> map = new HashMap<>();
            map.put("transactionId", row[0]);
            map.put("userName", row[1]);
            map.put("userEmail", row[2]);
            map.put("walletName", row[3]);
            map.put("categoryName", row[4]);
            map.put("type", row[5]);
            map.put("amount", row[6]);
            map.put("note", row[7]);
            map.put("transDate", row[8]);
            map.put("deletedAt", row[9]);
            map.put("sourceType", row[10]);
            return map;
        }).collect(Collectors.toList());
    }
}
