package fpt.aptech.server.service.Auth;

import fpt.aptech.server.dto.request.RegisterRequest;
import fpt.aptech.server.dto.UserInfoDTO;
import fpt.aptech.server.entity.Account;

public interface AuthService {
    // Trả về Account nếu thông tin đăng nhập đúng
    Account login(String email, String password);

    // Tạo và lưu Refresh Token cho thiết bị mới
    String generateAndSaveRefreshToken(Account account, String deviceToken, String deviceType);
    
    // Tạo Access Token JWT
    String generateAccessToken(Account account);
    
    // Chuyển đổi Account thành UserInfoDTO
    UserInfoDTO convertToUserInfoDTO(Account account);
    
    // Đăng ký tài khoản mới
    Account register(RegisterRequest registerRequest);
    
    // đăng xuất
    void logout(String deviceToken);
}
