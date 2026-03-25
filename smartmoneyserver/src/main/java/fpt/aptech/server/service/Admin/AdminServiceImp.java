package fpt.aptech.server.service.Admin;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.dto.PageResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Budget;
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
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AdminServiceImp implements AdminService {

    private final AccountRepository accountRepository;
    private final UserDeviceRepository userDeviceRepository;
    private final NotificationService notificationService;
    private final TransactionRepository transactionRepository;
    private final BudgetRepository budgetRepository;
    private final UserActivityService userActivityService;

    @Override
    public PageResponse<AccountDto> getUsers(String search, Boolean locked, String onlineStatus, Pageable pageable) {
        Specification<Account> spec = (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();

            // Thêm điều kiện: Chỉ lấy các tài khoản có role_id = 2 (vai trò người dùng thông thường)
            predicates.add(criteriaBuilder.equal(root.get("role").get("id"), 2));

            if (search != null && !search.trim().isEmpty()) {
                String searchKey = "%" + search.toLowerCase() + "%";
                Predicate emailLike = criteriaBuilder.like(criteriaBuilder.lower(root.get("accEmail")), searchKey);
                Predicate phoneLike = criteriaBuilder.like(root.get("accPhone"), "%" + search + "%");
                predicates.add(criteriaBuilder.or(emailLike, phoneLike));
            }

            if (locked != null) {
                predicates.add(criteriaBuilder.equal(root.get("locked"), locked));
            }

            return criteriaBuilder.and(predicates.toArray(new Predicate[0]));
        };

        // Lấy danh sách Account từ DB
        Page<Account> accountPage = accountRepository.findAll(spec, pageable);

        // Chuyển đổi sang DTO và bổ sung thông tin Online/Offline
        List<AccountDto> dtoList = accountPage.getContent().stream().map(account -> {
            AccountDto dto = new AccountDto(account);

            // Kiểm tra trạng thái online (loggedIn = true VÀ lastActive > 5 phút trước)
            LocalDateTime fiveMinutesAgo = LocalDateTime.now().minusMinutes(5);
            boolean isOnline = userDeviceRepository.isUserOnline(account.getId(), fiveMinutesAgo);
            LocalDateTime lastActive = userDeviceRepository.findLatestActiveTime(account.getId());

            dto.setOnline(isOnline);
            dto.setLastActive(lastActive);
            return dto;
        }).collect(Collectors.toList());

        // Lọc theo onlineStatus nếu có yêu cầu (Lưu ý: Lọc sau khi phân trang có thể làm giảm số lượng kết quả trên trang hiện tại)
        // Để tối ưu hơn, nên join bảng UserDevice trong Specification, nhưng logic online phức tạp nên xử lý ở đây tạm thời.
        if (onlineStatus != null && !onlineStatus.isEmpty()) {
            boolean filterOnline = "online".equalsIgnoreCase(onlineStatus);
            dtoList = dtoList.stream()
                    .filter(dto -> dto.isOnline() == filterOnline)
                    .collect(Collectors.toList());
            
            // Cập nhật lại Page object vì số lượng phần tử đã thay đổi (đây là cách đơn giản, chưa tối ưu phân trang)
            return new PageResponse<>(new PageImpl<>(dtoList, pageable, dtoList.size()));
        }

        return new PageResponse<>(new PageImpl<>(dtoList, pageable, accountPage.getTotalElements()));
    }

    @Override
    @Transactional
    public void lockAccount(Integer id) {
        accountRepository.findById(id).ifPresent(account -> {
            account.setLocked(true);
            accountRepository.save(account);

            // Force logout: Set loggedIn = false cho tất cả thiết bị của user này
            List<UserDevice> devices = userDeviceRepository.findAllByAccount_Id(id);
            for (UserDevice device : devices) {
                device.setLoggedIn(false);
                device.setRefreshToken(null); // Xóa refresh token để chặn lấy access token mới
            }
            userDeviceRepository.saveAll(devices);

            // Gửi thông báo cho người dùng bị khóa
            NotificationContent msg = NotificationMessages.accountLocked();
            notificationService.createNotification(
                    account,
                    msg.title(), msg.content(),
                    NotificationType.SYSTEM,
                    null,
                    LocalDateTime.now()
            );
        });
    }

    @Override
    @Transactional
    public void unlockAccount(Integer id) {
        accountRepository.findById(id).ifPresent(account -> {
            account.setLocked(false);
            accountRepository.save(account);

            // Gửi thông báo cho người dùng được mở khóa
            NotificationContent msg = NotificationMessages.accountUnlocked();
            notificationService.createNotification(
                    account,
                    msg.title(), msg.content(),
                    NotificationType.SYSTEM,
                    null,
                    LocalDateTime.now()
            );
        });
    }

    @Override
    public Map<String, Object> getStats() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("totalUsers", accountRepository.count());
        stats.put("totalTransactions", transactionRepository.count()); // Đếm tổng số giao dịch thực tế từ DB
        stats.put("activeDevices", userDeviceRepository.countByLoggedInTrue());

        // Thêm thống kê người dùng mới theo tháng
        List<Map<String, Object>> newUsersByMonth = accountRepository.countNewUsersByMonth();
        stats.put("newUsersByMonth", newUsersByMonth);

        return stats;
    }

    @Override
    public List<Notification> getAdminNotifications(Integer adminId) {
        return notificationService.getMyNotifications(adminId);
    }

    @Override
    public Map<String, Object> getSystemTransactionStats(String rangeMode) {
        LocalDateTime startDate, endDate;
        LocalDate today = LocalDate.now();

        // 1. Xác định khoảng thời gian
        if ("DAILY".equalsIgnoreCase(rangeMode)) {
            startDate = today.atStartOfDay();
            endDate = today.atTime(LocalTime.MAX);
        } else { // Default: MONTHLY
            startDate = today.with(TemporalAdjusters.firstDayOfMonth()).atStartOfDay();
            endDate = today.with(TemporalAdjusters.lastDayOfMonth()).atTime(LocalTime.MAX);
        }
        // 2. Gọi Repo lấy dữ liệu tổng hợp
        List<Object[]> rawStats = transactionRepository.getGlobalCategoryStats(startDate, endDate);

        // 3. Xử lý dữ liệu
        BigDecimal totalIncome = BigDecimal.ZERO;
        BigDecimal totalExpense = BigDecimal.ZERO;
        List<Map<String, Object>> categoryStats = new ArrayList<>();

        for (Object[] row : rawStats) {
            String ctgName = (String) row[0];
            BigDecimal amount = (BigDecimal) row[1];
            Boolean ctgType = (Boolean) row[2]; // true=Thu, false=Chi
            String ctgIconUrl = (String) row[3];

            if (Boolean.TRUE.equals(ctgType)) {
                totalIncome = totalIncome.add(amount);
            } else {
                totalExpense = totalExpense.add(amount);
            }
            Map<String, Object> item = new HashMap<>();
            item.put("categoryName", ctgName);
            item.put("amount", amount);
            item.put("type", Boolean.TRUE.equals(ctgType) ? "INCOME" : "EXPENSE");
            item.put("iconUrl", ctgIconUrl);
            categoryStats.add(item);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("totalIncome", totalIncome);
        result.put("totalExpense", totalExpense);
        result.put("breakdown", categoryStats);
        result.put("range", rangeMode);

        return result;
    }

    @Override
    public List<Map<String, Object>> getSystemOverspentBudgets(String rangeMode) {
        LocalDate startDate, endDate;
        LocalDate today = LocalDate.now();

        // 1. Xác định khoảng thời gian
        if ("DAILY".equalsIgnoreCase(rangeMode)) {
            startDate = today;
            endDate = today;
        } else { // Default: MONTHLY
            startDate = today.with(TemporalAdjusters.firstDayOfMonth());
            endDate = today.with(TemporalAdjusters.lastDayOfMonth());
        }

        // 2. Lấy tất cả budget active trong khoảng thời gian này
        List<Budget> budgets = budgetRepository.findAllActiveBudgetsInRange(startDate, endDate);
        List<Map<String, Object>> overspentList = new ArrayList<>();
        // 3. Tính toán chi tiêu cho từng budget
        for (Budget budget : budgets) {
            // Tái sử dụng query sumExpenseForBudget có sẵn trong TransactionRepository (theo Blueprint)
            BigDecimal spentAmount = transactionRepository.sumExpenseForBudget(
                    budget.getAccount().getId(),
                    budget.getBeginDate().atStartOfDay(),
                    budget.getEndDate().atTime(LocalTime.MAX),
                    budget.getWallet() != null ? budget.getWallet().getId() : null, // walletId
                    budget.getAllCategories(),
                    budget.getCategories().stream().map(c -> c.getId()).collect(Collectors.toSet()) // categoryIds
            );
            if (spentAmount == null) spentAmount = BigDecimal.ZERO;

            // 4. Nếu tiêu vượt quá hạn mức -> thêm vào list báo cáo
            if (spentAmount.compareTo(budget.getAmount()) > 0) {
                Map<String, Object> info = new HashMap<>();
                info.put("userEmail", budget.getAccount().getAccEmail());
                info.put("budgetName", budget.getCategories().isEmpty() ? "Tất cả danh mục" : budget.getCategories().iterator().next().getCtgName());
                info.put("limitAmount", budget.getAmount());
                info.put("spentAmount", spentAmount);
                info.put("overAmount", spentAmount.subtract(budget.getAmount()));
                info.put("endDate", budget.getEndDate());

                overspentList.add(info);
            }
        }
        return overspentList;
    }
    @Override
    public long countOnlineUsers() {
        // Lấy số lượng user active trong 5 phút gần nhất từ bộ nhớ
        return userActivityService.countOnlineUsers(5);
    }
}