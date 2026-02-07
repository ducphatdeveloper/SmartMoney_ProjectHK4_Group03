package fpt.aptech.server.service.Admin;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.dto.PageResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.entity.UserDevice;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.UserDeviceRepository;
import fpt.aptech.server.service.Notification.NotificationService;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
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
            notificationService.createNotification(
                    account,
                    "Tài khoản bị khóa",
                    "Tài khoản của bạn đã bị khóa bởi quản trị viên. Vui lòng liên hệ hỗ trợ để biết thêm chi tiết.",
                    4, // SYSTEM
                    null
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
            notificationService.createNotification(
                    account,
                    "Tài khoản được mở khóa",
                    "Tài khoản của bạn đã được mở khóa. Bạn có thể tiếp tục sử dụng dịch vụ.",
                    4, // SYSTEM
                    null
            );
        });
    }

    @Override
    public Map<String, Object> getStats() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("totalUsers", accountRepository.count());
        stats.put("totalTransactions", 0L);
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
}