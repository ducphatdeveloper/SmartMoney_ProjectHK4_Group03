package fpt.aptech.server.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class LoginRequest {
    @NotBlank(message = "Tên đăng nhập không được để trống")
    private String username;

    @NotBlank(message = "Mật khẩu không được để trống")
    private String password;

    private String deviceToken; // Để lưu vào tUserDevices
    private String deviceType;
    private String deviceName;
}