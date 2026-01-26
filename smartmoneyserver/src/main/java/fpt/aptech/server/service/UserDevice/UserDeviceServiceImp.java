package fpt.aptech.server.service.UserDevice;

import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.UserDevice;
import fpt.aptech.server.repos.UserDeviceRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;

@Service
public class UserDeviceServiceImp implements UserDeviceService {

    @Autowired
    private UserDeviceRepository userDeviceRepository;

    @Override
    public UserDevice registerDevice(Account account, String deviceToken, String deviceType, String deviceName) {
        UserDevice device = userDeviceRepository.findByDeviceToken(deviceToken)
                .orElse(new UserDevice());

        device.setAccount(account);
        device.setDeviceToken(deviceToken);
        device.setDeviceType(deviceType);
        device.setDeviceName(deviceName);
        device.setLoggedIn(true);
        device.setLastActive(LocalDateTime.now());

        return userDeviceRepository.save(device);
    }

    @Override
    public List<UserDevice> getUserActiveDevices(Integer accId) {
        return userDeviceRepository.findAllByAccount_IdAndLoggedInTrue(accId);
    }

    @Override
    public void logoutDevice(String deviceToken) {
        userDeviceRepository.findByDeviceToken(deviceToken).ifPresent(device -> {
            device.setLoggedIn(false);
            userDeviceRepository.save(device);
        });
    }
}
