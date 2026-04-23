package fpt.aptech.server.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class ResetPasswordRequest {
    @NotBlank(message = "Email cannot be empty")
    private String email;

    @NotBlank(message = "OTP code cannot be empty")
    private String otp;

    @NotBlank(message = "New password cannot be empty")
    @Size(min = 6, message = "Password must be at least 6 characters")
    private String newPassword;
}