package fpt.aptech.server.service.Admin;

import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.UserDeviceRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class DashboardServiceImp implements DashboardService {

    @Autowired
    private AccountRepository accountRepository;

    @Autowired
    private UserDeviceRepository userDeviceRepository;

    @Override
    public Map<String, Object> getQuickStats() {
        Map<String, Object> stats = new HashMap<>();
        // Đếm tổng số tài khoản trong hệ thống
        stats.put("totalUsers", accountRepository.count());
        // Đếm các thiết bị đang ở trạng thái đăng nhập
        stats.put("onlineDevices", userDeviceRepository.countByLoggedInTrue());
        return stats;
    }

    @Override
    public List<Map<String, Object>> getUserGrowthStats() {
        // Gọi câu query custom từ Repository đã tạo ở bước trước
        return accountRepository.countNewUsersByMonth();
    }
}