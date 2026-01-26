package fpt.aptech.server.dto.request;

import lombok.Data;
import lombok.Getter;
import lombok.Setter;

@Setter
@Getter
@Data
public class LoginRequest {
    private String email;
    private String password;
    private String deviceToken; // Để lưu vào tUserDevices
    private String deviceType;
}