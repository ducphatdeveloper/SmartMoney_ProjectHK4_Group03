package fpt.aptech.server.service.Auth;

import fpt.aptech.server.dto.request.LoginRequest;
import fpt.aptech.server.dto.request.RegisterRequest;
import fpt.aptech.server.dto.UserInfoDTO;
import fpt.aptech.server.dto.response.AuthResponse;
import fpt.aptech.server.entity.Account;

public interface AuthService {
    AuthResponse authenticate(LoginRequest loginRequest, String ipAddress);
    
    // Thêm phương thức này cho Google Login
    AuthResponse authenticateGoogle(String idToken, String deviceToken, String deviceType, String deviceName, String ipAddress);

    Account login(String username, String password);
    Account register(RegisterRequest request);
    void logout(String deviceToken);
    
    String generateResetToken(String username);
    void resetPassword(String username, String otp, String newPassword);
    
    UserInfoDTO convertToUserInfoDTO(Account account);
    
    String generateAndSaveRefreshToken(Account account, String deviceToken, String deviceType, String deviceName, String ipAddress, Boolean loggedIn);
    String generateAccessToken(Account account);
}
