package fpt.aptech.server.service.UserDevice;

import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.UserDevice;

import java.util.List;

public interface UserDeviceService {
    // Lưu hoặc cập nhật thông tin thiết bị khi login
    UserDevice registerDevice(Account account, String deviceToken, String deviceType, String deviceName);

    // Lấy danh sách thiết bị đang hoạt động của người dùng
    List<UserDevice> getUserActiveDevices(Integer accId);

    // Đăng xuất một thiết bị cụ thể
    void logoutDevice(String deviceToken);
}
