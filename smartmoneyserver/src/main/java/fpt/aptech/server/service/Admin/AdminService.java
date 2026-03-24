package fpt.aptech.server.service.Admin;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.dto.PageResponse;
import fpt.aptech.server.entity.Notification;
import org.springframework.data.domain.Pageable;

import java.util.List;
import java.util.Map;

public interface AdminService {
    PageResponse<AccountDto> getUsers(String search, Boolean locked, String onlineStatus, Pageable pageable);
    void lockAccount(Integer id);
    void unlockAccount(Integer id);
    Map<String, Object> getStats();
    List<Notification> getAdminNotifications(Integer adminId);
    // Thống kê giao dịch toàn hệ thống (Pie chart)
    Map<String, Object> getSystemTransactionStats(String rangeMode);
    long countOnlineUsers();
    // Thống kê ngân sách vượt mức (Overspent budgets)
    List<Map<String, Object>> getSystemOverspentBudgets(String rangeMode);
}