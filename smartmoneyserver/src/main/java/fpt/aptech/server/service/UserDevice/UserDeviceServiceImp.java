package fpt.aptech.server.service.UserDevice;

import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.UserDevice;
import fpt.aptech.server.repos.UserDeviceRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
public class UserDeviceServiceImp implements UserDeviceService {

    @Autowired
    private UserDeviceRepository userDeviceRepository;

    @Override
    public UserDevice registerDevice(Account account, String deviceToken, String deviceType, String deviceName, String ipAddress) {
        // Tìm thiết bị theo deviceToken
        // Nếu có nhiều kết quả trả về (do lỗi dữ liệu cũ), ta sẽ lấy cái đầu tiên hoặc xử lý xóa bớt
        // Tuy nhiên, findByDeviceToken trả về Optional, nếu DB có 2 dòng trùng token sẽ ném lỗi "Query did not return a unique result"
        // Do đó, ta cần sửa logic tìm kiếm để an toàn hơn hoặc sửa DB để deviceToken là UNIQUE.
        
        // Cách xử lý an toàn ở tầng Service: Dùng findTopByDeviceToken hoặc xử lý list
        // Nhưng Repository hiện tại đang dùng Optional<UserDevice> findByDeviceToken(String deviceToken);
        // Nếu DB chưa có constraint UNIQUE cho deviceToken, lỗi này sẽ xảy ra khi có 2 dòng cùng token.
        
        // Giải pháp tạm thời: Xử lý list để lấy 1 cái, xóa các cái trùng thừa (nếu có)
        List<UserDevice> devices = userDeviceRepository.findAllByDeviceToken(deviceToken);
        
        UserDevice device;
        if (devices.isEmpty()) {
            device = new UserDevice();
        } else {
            device = devices.get(0);
            // Nếu có nhiều hơn 1, xóa các cái thừa đi để làm sạch dữ liệu
            if (devices.size() > 1) {
                for (int i = 1; i < devices.size(); i++) {
                    userDeviceRepository.delete(devices.get(i));
                }
            }
        }

        device.setAccount(account);
        device.setDeviceToken(deviceToken);
        device.setDeviceType(deviceType);
        device.setDeviceName(deviceName);
        device.setIpAddress(ipAddress);
        device.setLoggedIn(true);
        device.setLastActive(LocalDateTime.now());
        
        // Thiết lập thời gian hết hạn cho Token (ví dụ: 7 ngày)
        device.setRefreshTokenExpiredAt(LocalDateTime.now().plusDays(7));

        return userDeviceRepository.save(device);
    }

    @Override
    public List<UserDevice> getUserActiveDevices(Integer accId) {
        return userDeviceRepository.findAllByAccount_IdAndLoggedInTrue(accId);
    }

    @Override
    public void logoutDevice(String deviceToken) {
        // Tương tự, xử lý list để tránh lỗi NonUniqueResultException
        List<UserDevice> devices = userDeviceRepository.findAllByDeviceToken(deviceToken);
        if (!devices.isEmpty()) {
            UserDevice device = devices.get(0);
            device.setLoggedIn(false);
            device.setRefreshToken(null);
            userDeviceRepository.save(device);
            
            // Xóa các bản ghi trùng lặp nếu có
            if (devices.size() > 1) {
                for (int i = 1; i < devices.size(); i++) {
                    userDeviceRepository.delete(devices.get(i));
                }
            }
        }
    }
}