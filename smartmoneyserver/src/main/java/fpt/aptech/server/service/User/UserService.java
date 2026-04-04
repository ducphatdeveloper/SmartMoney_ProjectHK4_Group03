package fpt.aptech.server.service.User;

import fpt.aptech.server.dto.AccountDto;
import org.springframework.web.multipart.MultipartFile;

public interface UserService {
    AccountDto getProfile(String email);
    AccountDto updateProfile(Integer accId, AccountDto dto);
    String updateAvatar(Integer accId, MultipartFile file);

    /**
     * Bước 1: Xác minh CCCD. Nếu hợp lệ, hệ thống sẽ gửi mã OTP khóa khẩn cấp vào Gmail của User.
     */
    void sendEmergencyLockOTP(Integer accId, String identityCard);

    /**
     * Bước 2: Xác thực mã OTP nhận được từ Gmail để thực hiện lệnh khóa tài khoản ngay lập tức.
     */
    void verifyAndLockAccount(Integer accId, String otpCode);
}