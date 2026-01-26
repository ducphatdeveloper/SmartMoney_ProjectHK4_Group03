package fpt.aptech.server.service.Admin;

import java.util.List;
import java.util.Map;

public interface DashboardService {
    // Lấy số liệu thống kê nhanh (Tổng user, thiết bị online...)
    Map<String, Object> getQuickStats();

    // Lấy dữ liệu tăng trưởng người dùng theo thời gian để vẽ biểu đồ
    List<Map<String, Object>> getUserGrowthStats();
}