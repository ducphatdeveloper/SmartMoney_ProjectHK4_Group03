package fpt.aptech.server.service.Admin;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.dto.TransactionDto;
import fpt.aptech.server.dto.PageResponse;
import fpt.aptech.server.entity.Notification;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

public interface AdminService {
    PageResponse<AccountDto> getUsers(String search, Boolean locked, String onlineStatus, Pageable pageable);
    void lockAccount(Integer id);
    void unlockAccount(Integer id);
    Map<String, Object> getDashboardOverview();
    List<Notification> getAdminNotifications(Integer adminId);
    
    // [NEW] Quản lý trạng thái đọc thông báo cho Admin
    void markNotificationAsRead(Integer notificationId);
    void markAllNotificationsAsRead();

    Map<String, Object> getUserFinancialInsights(Integer userId);

    // CẬP NHẬT: Nhận startDate và endDate trực tiếp từ Client
    Map<String, Object> getSystemTransactionStats(LocalDateTime startDate, LocalDateTime endDate);

    long countOnlineUsers();
    List<AccountDto> getAllLiveOnlineUsers();

    void handleAutoLogout();
    PageResponse<TransactionDto> getUserTransactions(Integer userId, Pageable pageable, String deletedStatus, String type);
    List<TransactionDto> getAllUserTransactions(Integer userId, String deletedStatus, String type);

    /**
     * Khôi phục một giao dịch đã xóa mềm.
     * Sử dụng Stored Procedure sp_RestoreTransaction để đảm bảo Trigger cập nhật số dư chạy đúng.
     */
    void restoreTransaction(Long transactionId);

    /**
     * Khôi phục tất cả giao dịch đã xóa mềm của một người dùng.
     */
    void restoreAllUserTransactions(Integer userId);

    /**
     * Lấy danh sách giao dịch đã bị xóa mềm trên toàn hệ thống (Dành cho Admin theo dõi).
     * Tận dụng View vAdminDeletedTransactions trong Database.
     */
    List<Map<String, Object>> getGlobalDeletedTransactions();
}
