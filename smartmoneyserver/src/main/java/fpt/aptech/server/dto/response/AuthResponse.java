package fpt.aptech.server.dto.response;

import fpt.aptech.server.dto.UserInfoDTO;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data // Tự động tạo Getter, Setter, toString... 🛠️
@AllArgsConstructor // Tạo Constructor với tất cả tham số
@NoArgsConstructor  // Tạo Constructor mặc định không tham số
public class AuthResponse {
    private String accessToken;
    private String refreshToken;
    private UserInfoDTO userInfo;
}