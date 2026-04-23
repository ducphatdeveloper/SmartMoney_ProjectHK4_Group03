package fpt.aptech.server.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class LoginRequest {
    @NotBlank(message = "Username cannot be empty")
    private String username;

    @NotBlank(message = "Password cannot be empty")
    private String password;

    private String deviceToken; // Để lưu vào tUserDevices
    private String deviceType;
    private String deviceName;
}