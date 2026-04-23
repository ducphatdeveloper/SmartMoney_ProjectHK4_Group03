package fpt.aptech.server.dto.request;

import jakarta.validation.constraints.*;
import lombok.Data;

@Data
public class RegisterRequest {
    // Regex: ^( ... )?$ cho phép chuỗi rỗng hoặc đúng định dạng số điện thoại
    @Pattern(regexp = "^(0\\d{9,10})?$", message = "Phone number must start with 0 and have 10 or 11 digits")
    private String accPhone;


    @Email(message = "Invalid email format")
    private String accEmail;

    @NotBlank(message = "Password cannot be empty")
    @Size(min = 6, max = 50, message = "Password must be between 6-50 characters")
    private String password;

    @NotBlank(message = "Confirm password cannot be empty")
    private String confirmPassword;

    // Custom validation: Phải có ít nhất phone HOẶC email
    @AssertTrue(message = "Must provide at least phone number or email")
    public boolean isValidIdentity() {
        return (accPhone != null && !accPhone.isBlank()) ||
                (accEmail != null && !accEmail.isBlank());
    }

    // Custom validation: Password phải trùng confirmPassword
    @AssertTrue(message = "Password confirmation does not match")
    public boolean isPasswordMatching() {
        if (password == null) return false;
        return password.equals(confirmPassword);
    }
}