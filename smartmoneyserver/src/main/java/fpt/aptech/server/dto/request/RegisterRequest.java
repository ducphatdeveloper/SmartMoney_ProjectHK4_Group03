package fpt.aptech.server.dto.request;

import lombok.Data;

@Data
public class RegisterRequest {
    private String email;
    private String password; // Mật khẩu thô để Server mã hóa
    private String phone;
}