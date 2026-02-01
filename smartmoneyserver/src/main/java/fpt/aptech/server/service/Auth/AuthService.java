package fpt.aptech.server.service.Auth;

import fpt.aptech.server.dto.request.LoginRequest;
import fpt.aptech.server.dto.request.RegisterRequest;
import fpt.aptech.server.dto.response.AuthResponse;
import fpt.aptech.server.dto.UserInfoDTO;
import fpt.aptech.server.entity.Account;

public interface AuthService {
    // Phương thức xác thực tập trung "tất cả trong một" 🚀
    AuthResponse authenticate(LoginRequest loginRequest, String ipAddress);

    // Các phương thức bổ trợ
    Account login(String username, String password);
    String generateAndSaveRefreshToken(Account account, String deviceToken, String deviceType, String deviceName, String ipAddress, Boolean loggedIn);
    String generateAccessToken(Account account);
    UserInfoDTO convertToUserInfoDTO(Account account);
    Account register(RegisterRequest registerRequest);
    void logout(String deviceToken);
}