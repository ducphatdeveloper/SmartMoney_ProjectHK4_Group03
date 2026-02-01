package fpt.aptech.server.dto.response;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.*;
import java.time.LocalDateTime;
import java.util.Set;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AuthResponse {

    private Integer userId;
    private String accPhone;
    private String accEmail;
    private String avatarUrl;
    private String currency;

    // Role & Permissions
    @JsonProperty("roleCode")
    private String roleCode;
    @JsonProperty("roleName")
    private String roleName;
    private Set<String> permissions;

    // JWT Tokens
    private String accessToken;
    private String refreshToken;
    private Long accessTokenExpiry;  // milliseconds
    private Long refreshTokenExpiry; // milliseconds

    private LocalDateTime loginAt;

    private String message;
}