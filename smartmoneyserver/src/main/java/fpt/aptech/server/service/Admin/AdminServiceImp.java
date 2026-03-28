package fpt.aptech.server.service.Admin;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.dto.PageResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Transaction;
import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.entity.UserDevice;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.BudgetRepository;
import fpt.aptech.server.repos.UserDeviceRepository;
import fpt.aptech.server.repos.TransactionRepository;
import fpt.aptech.server.service.UserActivityService;
import fpt.aptech.server.service.notification.NotificationService;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import jakarta.persistence.criteria.Predicate;
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

@Service
@RequiredArgsConstructor
public class AdminServiceImp implements AdminService {

    private final AccountRepository accountRepository;
    private final UserDeviceRepository userDeviceRepository;
    private final NotificationService notificationService;
    private final TransactionRepository transactionRepository;
    private final UserActivityService userActivityService;

    @Override
    public PageResponse<AccountDto> getUsers(String search, Boolean locked, String onlineStatus, Pageable pageable) {
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
            
            return criteriaBuilder.and(predicates.toArray(new Predicate[0]));
        };

        Page<Account> accountPage = accountRepository.findAll(spec, pageable);
        List<Account> accounts = accountPage.getContent();
        List<Integer> accountIds = accounts.stream().map(Account::getId).collect(Collectors.toList());

        // Batch fetch thiết bị để tránh N+1 Query
        Map<Integer, List<UserDevice>> deviceMap = userDeviceRepository.findAllByAccount_IdIn(accountIds).stream()
                .collect(Collectors.groupingBy(d -> d.getAccount().getId()));

        LocalDateTime fiveMinutesAgo = LocalDateTime.now().minusMinutes(5);

        List<AccountDto> dtoList = accounts.stream().map(account -> {
            AccountDto dto = new AccountDto(account);
            List<UserDevice> userDevices = deviceMap.getOrDefault(account.getId(), new ArrayList<>());
            
            // Xác định các session đang hoạt động dựa trên RefreshToken và thời gian tương tác
            List<UserDevice> activeSessions = userDevices.stream()
                    .filter(d -> d.getRefreshToken() != null && d.getLastActive() != null 
                            && d.getLastActive().isAfter(fiveMinutesAgo))
                    .collect(Collectors.toList());

            dto.setOnline(!activeSessions.isEmpty());
            dto.setOnlineDevicesCount(activeSessions.size());
            dto.setLastActive(userDevices.stream()
                    .map(UserDevice::getLastActive)
                    .filter(Objects::nonNull)
                    .max(LocalDateTime::compareTo)
                    .orElse(null));
            dto.setOnlinePlatforms(new ArrayList<>()); // Trống vì không thay đổi Entity
            return dto;
        }).collect(Collectors.toList());

        if (onlineStatus != null && !onlineStatus.isEmpty()) {
            boolean filterOnline = "online".equalsIgnoreCase(onlineStatus);
            dtoList = dtoList.stream().filter(dto -> dto.isOnline() == filterOnline).collect(Collectors.toList());
            return new PageResponse<>(new PageImpl<>(dtoList, pageable, dtoList.size())); // Lưu ý: Paging in-memory
        }
        
        return new PageResponse<>(new PageImpl<>(dtoList, pageable, accountPage.getTotalElements()));
    }

    @Override
    @Transactional
    public void lockAccount(Integer id) {
        Account account = accountRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy tài khoản ID: " + id));
        
        account.setLocked(true);
        accountRepository.saveAndFlush(account);

        try {
            // Thu hồi toàn bộ Refresh Token để buộc đăng xuất ngay lập tức
            List<UserDevice> devices = userDeviceRepository.findAllByAccount_Id(id);
            if (devices != null && !devices.isEmpty()) {
                devices.forEach(device -> device.setRefreshToken(null));
                userDeviceRepository.saveAllAndFlush(devices);
            }
        } catch (Exception e) {
            System.err.println("Cảnh báo: Không thể thu hồi token của user " + id + ": " + e.getMessage());
        }

        try {
            NotificationContent msg = NotificationMessages.accountLocked();
            notificationService.createNotification(account, msg.title(), msg.content(), 
                    NotificationType.SYSTEM, null, LocalDateTime.now());
        } catch (Exception e) {
            System.err.println("Cảnh báo: Không thể gửi thông báo khóa cho user " + id);
        }
    }

    @Override
    @Transactional
    public void unlockAccount(Integer id) {
        Account account = accountRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy tài khoản ID: " + id));
        
        account.setLocked(false);
        accountRepository.saveAndFlush(account);

        try {
            NotificationContent msg = NotificationMessages.accountUnlocked();
            notificationService.createNotification(account, msg.title(), msg.content(), 
                    NotificationType.SYSTEM, null, LocalDateTime.now());
        } catch (Exception e) {
            System.err.println("Cảnh báo: Không thể gửi thông báo mở khóa cho user " + id);
        }
    }

    @Override
    public Map<String, Object> getDashboardOverview() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("totalUsers", accountRepository.count());
        stats.put("totalTransactions", transactionRepository.count());
        stats.put("activeDevices", userDeviceRepository.countByRefreshTokenIsNotNull()); // Online thực tế
        stats.put("newUsersGrowth", accountRepository.countNewUsersByMonth()); // Thống kê biểu đồ line
        return stats;
    }

    @Override
    public List<Notification> getAdminNotifications(Integer adminId) {
        // Lấy tất cả thông báo loại SYSTEM (Hành động quản trị, Cảnh báo bảo mật)
        // Đây là luồng thông báo tập trung để Admin theo dõi biến động hệ thống.
        return notificationService.getNotificationsByType(NotificationType.SYSTEM); 
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
     * Quét các giao dịch lớn của tất cả người dùng trong 24h qua.
     */
    @Override
    @Transactional
    public void notifyAbnormalTransactions(BigDecimal threshold) {
        LocalDateTime since = LocalDateTime.now().minusDays(1);
        List<Transaction> largeTransactions = transactionRepository.findAllByAmountGreaterThanAndTransDateAfter(threshold, since);

        for (Transaction trans : largeTransactions) {
            // 1. Gửi cảnh báo trực tiếp cho Người dùng (Loại TRANSACTION)
            NotificationContent content = NotificationMessages.largeTransactionAlert(
                trans.getAmount(), 
                trans.getCategory().getCtgName()
            );
            notificationService.createNotification(
                trans.getAccount(),
                content.title(),
                content.content(),
                NotificationType.TRANSACTION,
                trans.getId().longValue(),
                LocalDateTime.now()
            );

            // 2. Tạo Log hệ thống cho Admin (Loại SYSTEM)
            // Việc này giúp Admin thấy được các giao dịch đáng ngờ trong danh sách thông báo Admin
            String adminTitle = "Cảnh báo bảo mật: Giao dịch lớn";
            String adminContent = String.format("Phát hiện giao dịch bất thường: %s VNĐ từ tài khoản %s", 
                    trans.getAmount().toString(), trans.getAccount().getAccEmail());
            
            notificationService.createNotification(
                null, // Thông báo chung cho hệ thống
                adminTitle,
                adminContent,
                NotificationType.SYSTEM,
                trans.getId().longValue(),
                LocalDateTime.now()
            );
        }
    }

    /**
     * [1.3] Danh sách người dùng giao dịch bất thường để Admin đối soát trên Dashboard.
     */
    @Override
    public List<Map<String, Object>> getAbnormalTransactionUsers(BigDecimal threshold) {
        LocalDateTime since = LocalDateTime.now().minusDays(1);
        List<Transaction> largeTransactions = transactionRepository.findAllByAmountGreaterThanAndTransDateAfter(threshold, since);

        Map<Account, List<Transaction>> groupedByAccount = largeTransactions.stream()
                .collect(Collectors.groupingBy(Transaction::getAccount));

        return groupedByAccount.entrySet().stream().map(entry -> {
            Account acc = entry.getKey();
            List<Transaction> userTrans = entry.getValue();

            Map<String, Object> userMap = new HashMap<>();
            userMap.put("userId", acc.getId());
            userMap.put("email", acc.getAccEmail());
            
            List<Map<String, Object>> transDetails = userTrans.stream().map(t -> {
                Map<String, Object> d = new HashMap<>();
                d.put("id", t.getId());
                d.put("amount", t.getAmount());
                d.put("category", t.getCategory().getCtgName());
                d.put("time", t.getTransDate());
                return d;
            }).collect(Collectors.toList());

            userMap.put("abnormalTransactions", transDetails);
            userMap.put("totalViolatingAmount", userTrans.stream().map(Transaction::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add));
            return userMap;
        }).collect(Collectors.toList());
    }

    @Override
    public long countOnlineUsers() {
        // Lấy số lượng user active trong 5 phút gần nhất từ bộ nhớ
        return userActivityService.countOnlineUsers(5);
    }
}