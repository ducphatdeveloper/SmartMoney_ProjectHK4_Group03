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
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.UserDeviceRepository;
import fpt.aptech.server.repos.TransactionRepository;
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
import java.time.LocalTime;
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

    @Override
    public PageResponse<AccountDto> getUsers(String search, Boolean locked, String onlineStatus, Pageable pageable) {
        // Xác định mốc thời gian thực để coi là Online (ví dụ: 5 phút gần nhất)
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

            // Lọc Online/Offline trực tiếp trong Database trước khi phân trang
            if (onlineStatus != null && !onlineStatus.isEmpty()) {
                boolean filterOnline = "online".equalsIgnoreCase(onlineStatus);
                Subquery<Integer> onlineSubquery = query.subquery(Integer.class);
                Root<UserDevice> deviceRoot = onlineSubquery.from(UserDevice.class);
                onlineSubquery.select(deviceRoot.get("account").get("id"));
                
                // THỜI GIAN THỰC: Phải thỏa mãn cả 2: Đang loggedIn và mới hoạt động gần đây
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

        // Chỉ lấy các thiết bị thỏa mãn điều kiện thời gian thực để map lên giao diện
        Map<Integer, List<UserDevice>> activeDeviceMap = userDeviceRepository
                .findActiveDevicesByAccountIds(accountIds, activeThreshold).stream()
                .collect(Collectors.groupingBy(d -> d.getAccount().getId()));

        List<AccountDto> dtoList = accounts.stream().map(account -> {
            AccountDto dto = new AccountDto(account);
            List<UserDevice> activeSessions = activeDeviceMap.getOrDefault(account.getId(), new ArrayList<>());
            
            dto.setOnline(!activeSessions.isEmpty());
            dto.setOnlineDevicesCount(activeSessions.size());
            
            // TỐI ƯU: Nếu đang online, lấy thời gian từ session active, nếu không thì dùng field có sẵn
            dto.setLastActive(activeSessions.stream()
                    .map(UserDevice::getLastActive)
                    .filter(Objects::nonNull)
                    .max(LocalDateTime::compareTo)
                    .orElse(null));

            // TỐI ƯU: Lấy danh sách Platform thực tế từ các session đang online
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
        
        account.setLocked(true);
        // Đây là một dạng khóa mềm/vô hiệu hóa tài khoản. Dữ liệu không bị xóa vật lý.
        accountRepository.saveAndFlush(account);

        try {
            // Thu hồi toàn bộ Refresh Token để buộc đăng xuất ngay lập tức
            List<UserDevice> devices = userDeviceRepository.findAllByAccount_Id(id);
            if (devices != null && !devices.isEmpty()) {
                devices.forEach(device -> device.setRefreshToken(null));
                userDeviceRepository.saveAll(devices);
                userDeviceRepository.flush();
            }
        } catch (Exception e) {
            log.warn("Cảnh báo: Không thể thu hồi token của user {}: {}", id, e.getMessage());
        }

        try {
            NotificationContent msg = NotificationMessages.accountLocked();
            notificationService.createNotification(account, msg.title(), msg.content(), 
                    NotificationType.SYSTEM, null, LocalDateTime.now());
        } catch (Exception e) {
            log.warn("Cảnh báo: Không thể gửi thông báo khóa cho user {}: {}", id, e.getMessage());
        }
    }

    @Override
    @Transactional
    public void unlockAccount(Integer id) {
        Account account = accountRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy tài khoản ID: " + id));
        
        account.setLocked(false);
        accountRepository.save(account);
        accountRepository.flush();

        try {
            NotificationContent msg = NotificationMessages.accountUnlocked();
            notificationService.createNotification(account, msg.title(), msg.content(), 
                    NotificationType.SYSTEM, null, LocalDateTime.now());
        } catch (Exception e) {
            log.warn("Cảnh báo: Không thể gửi thông báo mở khóa cho user {}: {}", id, e.getMessage());
        }
    }

    @Override
    public Map<String, Object> getDashboardOverview() {
        LocalDateTime activeThreshold = LocalDateTime.now().minusMinutes(5);
        Map<String, Object> stats = new HashMap<>();
        stats.put("totalUsers", accountRepository.count());
        stats.put("totalTransactions", transactionRepository.count());
        stats.put("onlineUsers", userDeviceRepository.countActiveUsers(activeThreshold)); // Người dùng online thực tế
        stats.put("activeDevices", userDeviceRepository.countByLoggedInTrue()); // Tổng phiên đang logged_in
        stats.put("newUsersGrowth", accountRepository.countNewUsersByMonth()); // Thống kê biểu đồ line
        return stats;
    }

    @Override
    public List<Notification> getAdminNotifications(Integer adminId) {
        // Lấy tất cả thông báo loại SYSTEM (Hành động quản trị, Cảnh báo bảo mật)
        // Đây là luồng thông báo tập trung để Admin theo dõi biến động hệ thống.
        return notificationService.getNotificationsByType(NotificationType.SYSTEM.getValue());
    }

    /**
     * [1.4] Xem lịch sử giao dịch của một người dùng cụ thể (Có phân trang).
     */
    @Override
    @Transactional(readOnly = true)
    public PageResponse<TransactionDto> getUserTransactions(Integer userId, Pageable pageable) {
        // Sử dụng phương thức findAllByAccount_IdOrderByTransDateDesc từ Repository
        Page<Transaction> transactions = transactionRepository.findAllByAccount_IdOrderByTransDateDesc(userId, pageable);
        List<TransactionDto> dtoList = transactions.getContent().stream().map(TransactionDto::new).collect(Collectors.toList());
        return new PageResponse<>(new PageImpl<>(dtoList, pageable, transactions.getTotalElements()));
    }

    /**
     * [1.5] Lấy toàn bộ lịch sử giao dịch của một người dùng cụ thể (Không phân trang - Dùng cho xuất báo cáo).
     */
    @Override
    @Transactional(readOnly = true)
    public List<TransactionDto> getAllUserTransactions(Integer userId) {
        // Sử dụng phương thức List từ Repository
        return transactionRepository.findAllByAccount_IdOrderByTransDateDesc(userId)
                .stream()
                .map(TransactionDto::new)
                .collect(Collectors.toList());
    }

    /**
     * [1.1] Thống kê tỷ trọng giao dịch:
     * Tính % dựa trên tổng khối lượng giao dịch (Thu + Chi = 100%)
     * Hiển thị rõ danh mục Cha và Con.
     */
    @Override
    public Map<String, Object> getSystemTransactionStats(String rangeMode) {
        LocalDateTime startDate, endDate;
        LocalDate today = LocalDate.now();

        if ("DAILY".equalsIgnoreCase(rangeMode)) {
            startDate = today.atStartOfDay(); endDate = today.atTime(LocalTime.MAX);
        } else {
            startDate = today.with(TemporalAdjusters.firstDayOfMonth()).atStartOfDay();
            endDate = today.with(TemporalAdjusters.lastDayOfMonth()).atTime(LocalTime.MAX);
        }

        List<Object[]> rawStats = transactionRepository.getGlobalCategoryStats(startDate, endDate);
        BigDecimal totalVolume = BigDecimal.ZERO;
        BigDecimal income = BigDecimal.ZERO; BigDecimal expense = BigDecimal.ZERO;

        for (Object[] row : rawStats) {
            BigDecimal amount = row[1] != null ? (BigDecimal) row[1] : BigDecimal.ZERO;

            totalVolume = totalVolume.add(amount);
            if (Boolean.TRUE.equals(row[2])) income = income.add(amount);
            else expense = expense.add(amount);
        }

        List<Map<String, Object>> breakdown = new ArrayList<>();
        for (Object[] row : rawStats) {
            String ctgName = (String) row[0];
            BigDecimal amount = row[1] != null ? (BigDecimal) row[1] : BigDecimal.ZERO;
            Boolean ctgType = (Boolean) row[2];
            String ctgIconUrl = (String) row[3];
            String parentName = (String) row[4];

            BigDecimal pct = (totalVolume.compareTo(BigDecimal.ZERO) > 0)
                    ? amount.multiply(new BigDecimal("100")).divide(totalVolume, 2, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;

            Map<String, Object> item = new HashMap<>();
            item.put("categoryName", ctgName);
            item.put("parentName", parentName != null ? parentName : "");
            item.put("isChild", parentName != null);
            item.put("displayName", parentName != null ? parentName + " > " + ctgName : ctgName);
            item.put("amount", amount);
            item.put("percentage", pct);
            item.put("type", Boolean.TRUE.equals(ctgType) ? "INCOME" : "EXPENSE");
            item.put("iconUrl", ctgIconUrl);
            breakdown.add(item);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("totalSystemVolume", totalVolume); // Mốc 100%
        result.put("summary", Map.of(
                "incomeTotal", income,
                "expenseTotal", expense,
                "incomePercentage", totalVolume.compareTo(BigDecimal.ZERO) > 0
                        ? income.multiply(new BigDecimal("100")).divide(totalVolume, 2, RoundingMode.HALF_UP) : BigDecimal.ZERO,
                "expensePercentage", totalVolume.compareTo(BigDecimal.ZERO) > 0
                        ? expense.multiply(new BigDecimal("100")).divide(totalVolume, 2, RoundingMode.HALF_UP) : BigDecimal.ZERO
        ));
        result.put("breakdown", breakdown);
        result.put("range", rangeMode);
        result.put("generatedAt", LocalDateTime.now());
        return result;
    }

    /**
     * [1.2] Thông báo giao dịch bất thường:
     * Phân tích hành vi: Phát hiện tần suất giao dịch cao và tổng khối lượng chi tiêu lớn trên từng ví.
     */
    @Override
    @Transactional
    public void notifyAbnormalTransactions(BigDecimal threshold) {
        // Ngưỡng tần suất: ví dụ hơn 10 giao dịch chi tiêu/ngày là bất thường
        int frequencyThreshold = 10; 
        LocalDateTime since = LocalDateTime.now().minusDays(1);

        // 1. Lấy tất cả giao dịch trong 24h qua (Khớp với phương thức Repository mới)
        List<Transaction> recentTransactions = transactionRepository.findAllByTransDateAfter(since);

        // 2. Gom nhóm theo Ví và lọc các giao dịch CHI TIÊU (Expense)
        Map<Wallet, List<Transaction>> walletActivity = recentTransactions.stream()
                .filter(t -> t.getCategory() != null && Boolean.FALSE.equals(t.getCategory().getCtgType()))
                .filter(t -> t.getWallet() != null)
                .collect(Collectors.groupingBy(Transaction::getWallet));

        walletActivity.forEach((wallet, transList) -> {
            BigDecimal walletTotalExpense = transList.stream()
                    .map(Transaction::getAmount)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            int activityCount = transList.size();

            // 3. Kiểm tra điều kiện: (Tổng tiền chi > ngưỡng) HOẶC (Số lượng giao dịch > ngưỡng tần suất)
            if (walletTotalExpense.compareTo(threshold) > 0 || activityCount >= frequencyThreshold) {
                Account userAccount = transList.get(0).getAccount();
                // Lấy tên thật của Ví từ thực thể
                String walletName = (wallet.getWalletName() != null && !wallet.getWalletName().isEmpty()) 
                        ? wallet.getWalletName() : "Ví người dùng";
                
                // Gửi thông báo cho User về chiếc ví cụ thể đang có vấn đề
                NotificationContent userMsg = NotificationMessages.abnormalWalletActivity(
                        walletName, activityCount, walletTotalExpense);
                notificationService.createNotification(userAccount, userMsg.title(), userMsg.content(),
                        NotificationType.TRANSACTION, null, LocalDateTime.now());

                // Gửi thông báo cho Admin để theo dõi rủi ro hệ thống
                NotificationContent adminMsg = NotificationMessages.adminWalletRiskAlert(
                        userAccount.getAccEmail(), walletName, activityCount, walletTotalExpense);
                notificationService.createNotification(null, adminMsg.title(), adminMsg.content(), 
                        NotificationType.SYSTEM, null, LocalDateTime.now());
            }
        });
    }

    /**
     * [1.3] Danh sách người dùng giao dịch bất thường để Admin đối soát trên Dashboard.
     */
    @Override
    @Transactional(readOnly = true)
    public List<Map<String, Object>> getAbnormalTransactionUsers(BigDecimal threshold) {
        int frequencyThreshold = 10;
        LocalDateTime since = LocalDateTime.now().minusDays(1);
        List<Transaction> recentTransactions = transactionRepository.findAllByTransDateAfter(since);

        // Nhóm theo Account trước
        Map<Account, List<Transaction>> groupedByAccount = recentTransactions.stream()
                .filter(t -> t.getCategory() != null && Boolean.FALSE.equals(t.getCategory().getCtgType()))
                .collect(Collectors.groupingBy(Transaction::getAccount));

        return groupedByAccount.entrySet().stream().map(entry -> {
            Account acc = entry.getKey();
            List<Transaction> userTrans = entry.getValue();
            
            // Nhóm giao dịch của user này theo từng Ví
            Map<Wallet, List<Transaction>> byWallet = userTrans.stream()
                    .filter(t -> t.getWallet() != null)
                    .collect(Collectors.groupingBy(t -> t.getWallet()));

            List<Map<String, Object>> abnormalWallets = new ArrayList<>();
            BigDecimal userTotalAbnormalAmount = BigDecimal.ZERO;

            for (Map.Entry<Wallet, List<Transaction>> walletEntry : byWallet.entrySet()) {
                List<Transaction> transList = walletEntry.getValue();
                BigDecimal walletTotal = transList.stream().map(Transaction::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add);
                
                if (walletTotal.compareTo(threshold) > 0 || transList.size() >= frequencyThreshold) {
                    Map<String, Object> wMap = new HashMap<>();
                    wMap.put("walletName", walletEntry.getKey().getWalletName() != null 
                            ? walletEntry.getKey().getWalletName() : "Ví người dùng");
                    wMap.put("transactionCount", transList.size());
                    wMap.put("totalSpent", walletTotal);
                    // Bổ sung chi tiết các giao dịch để Admin đối soát
                    wMap.put("details", transList.stream()
                            .map(TransactionDto::new)
                            .collect(Collectors.toList()));

                    abnormalWallets.add(wMap);
                    userTotalAbnormalAmount = userTotalAbnormalAmount.add(walletTotal);
                }
            }

            if (abnormalWallets.isEmpty()) return null;

            Map<String, Object> userMap = new HashMap<>();
            userMap.put("userId", acc.getId());
            userMap.put("email", acc.getAccEmail());

            userMap.put("abnormalWallets", abnormalWallets);
            userMap.put("totalAbnormalAmount", userTotalAbnormalAmount);
            return userMap;
        }).filter(Objects::nonNull).collect(Collectors.toList());
    }

    @Override
    public long countOnlineUsers() {
        // Đếm tổng số người dùng hoạt động thời gian thực (5 phút gần nhất)
        LocalDateTime activeThreshold = LocalDateTime.now().minusMinutes(5);
        return userDeviceRepository.countActiveUsers(activeThreshold);
    }

    /**
     * Tối ưu hóa lấy danh sách tất cả người dùng trực tuyến thời gian thực.
     */
    @Override
    public List<AccountDto> getAllLiveOnlineUsers() {
        // Mốc thời gian thực
        LocalDateTime activeThreshold = LocalDateTime.now().minusMinutes(5);

        // Bước 1: Lấy tất cả thiết bị Online thời gian thực (Eager fetch Account)
        List<UserDevice> activeDevices = userDeviceRepository.findActiveDevicesBySince(activeThreshold);

        // Bước 2: Gom nhóm theo Account để tạo danh sách User Online
        Map<Account, List<UserDevice>> grouped = activeDevices.stream()
                .collect(Collectors.groupingBy(UserDevice::getAccount));

        return mapToOnlineAccountDtos(grouped);
    }

    /**
     * Tự động đăng xuất (thu hồi RefreshToken) cho các phiên bản đã ngoại tuyến.
     * Ngoại tuyến được định nghĩa là không có hoạt động trong 30 phút qua.
     */
    @Override
    @Transactional
    public void handleAutoLogout() {
        // Người dùng được coi là "ngoại tuyến" nếu không có hoạt động trong 30 phút qua
        LocalDateTime timeout = LocalDateTime.now().minusMinutes(30);
        
        // Lấy danh sách thiết bị đang có logged_in = 1, sau đó lọc các phiên "treo" (stale)
        List<UserDevice> staleDevices = userDeviceRepository.findAllLoggedInDevicesWithAccount()
                .stream()
                // Lọc những thiết bị có lần cuối hoạt động đã quá thời gian timeout
                .filter(d -> d.getLastActive() != null && d.getLastActive().isBefore(timeout))
                .collect(Collectors.toList());

        if (!staleDevices.isEmpty()) {
            staleDevices.forEach(device -> {
                device.setRefreshToken(null); // Thu hồi Refresh Token để chặn quyền truy cập cũ
                device.setLoggedIn(false);    // Chuyển trạng thái sang Ngoại tuyến (logger_in = 0)
            });
            userDeviceRepository.saveAll(staleDevices);
            userDeviceRepository.flush();
        }
    }

    private List<AccountDto> mapToOnlineAccountDtos(Map<Account, List<UserDevice>> grouped) {
        return grouped.entrySet().stream().map(entry -> {
            Account account = entry.getKey();
            List<UserDevice> devices = entry.getValue();

            AccountDto dto = new AccountDto(account);
            dto.setOnline(true);
            dto.setOnlineDevicesCount(devices.size());
            dto.setOnlinePlatforms(devices.stream()
                    .map(d -> d.getDeviceName() != null ? d.getDeviceName() : "Unknown")
                    .distinct().collect(Collectors.toList()));
            
            dto.setLastActive(devices.stream()
                    .map(UserDevice::getLastActive)
                    .filter(Objects::nonNull)
                    .max(LocalDateTime::compareTo)
                    .orElse(null));
            return dto;
        }).collect(Collectors.toList());
    }

    /**
     * Xem chi tiết các chỉ số tài chính của một User cụ thể (Read-only)
     */
    @Override
    @Transactional(readOnly = true)
    public Map<String, Object> getUserFinancialInsights(Integer userId) {
        Account account = accountRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Map<String, Object> insights = new HashMap<>();
        insights.put("userInfo", new AccountDto(account));
        
        // Sử dụng phương thức sumAmountByAccountAndType mới thêm vào Repository
        BigDecimal totalIncome = transactionRepository.sumAmountByAccountAndType(userId, true);
        BigDecimal totalExpense = transactionRepository.sumAmountByAccountAndType(userId, false);
        
        insights.put("totalIncome", totalIncome != null ? totalIncome : BigDecimal.ZERO);
        insights.put("totalExpense", totalExpense != null ? totalExpense : BigDecimal.ZERO);
        return insights;
    }
}