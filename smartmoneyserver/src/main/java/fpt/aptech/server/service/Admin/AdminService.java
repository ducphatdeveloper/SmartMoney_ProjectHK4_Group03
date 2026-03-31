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

    // Lấy thông báo hệ thống (SYSTEM) để Admin giám sát
    List<Notification> getAdminNotifications(Integer adminId);

    // Thống kê phân bổ giao dịch toàn hệ thống (Tính % trên 100% Volume, hỗ trợ cha-con)
    Map<String, Object> getSystemTransactionStats(String rangeMode);

    // Đếm số lượng người dùng đang trực tuyến (Online)
    long countOnlineUsers();

    // Lấy toàn bộ danh sách người dùng đang trực tuyến (Tối ưu hóa mapping)
    List<AccountDto> getAllLiveOnlineUsers();

    // Quét và gửi cảnh báo giao dịch bất thường (Thông báo SYSTEM tổng hợp)
    void notifyAbnormalTransactions(BigDecimal threshold);

    // Lấy danh sách đối soát người dùng có giao dịch bất thường trên Dashboard
    List<Map<String, Object>> getAbnormalTransactionUsers(BigDecimal threshold);

    // Tự động đăng xuất (thu hồi session) cho các người dùng đã ngoại tuyến quá hạn
    void handleAutoLogout();
}