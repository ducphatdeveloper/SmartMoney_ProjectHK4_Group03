package fpt.aptech.server.service.Admin;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.dto.PageResponse;
import fpt.aptech.server.entity.Notification;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

public interface AdminService {
    PageResponse<AccountDto> getUsers(String search, Boolean locked, String onlineStatus, Pageable pageable);

    void lockAccount(Integer id);

    void unlockAccount(Integer id);
    // Tổng quan Dashboard
    Map<String, Object> getDashboardOverview();


    List<Notification> getAdminNotifications(Integer adminId);

    // Thống kê giao dịch toàn hệ thống (Pie chart)
    Map<String, Object> getSystemTransactionStats(String rangeMode);

    long countOnlineUsers();
    // Thống kê ngân sách vượt mức (Overspent budgets)

    // Cảnh báo giao dịch bất thường (giá trị lớn)
    void notifyAbnormalTransactions(BigDecimal threshold);

    // Lấy danh sách người dùng có giao dịch bất thường
    List<Map<String, Object>> getAbnormalTransactionUsers(BigDecimal threshold);
}